//
//  StatusBarManager.swift
//  Click2wakeup
//
//  Created for Click2wakeup.
//

import SwiftUI
import CoreData
import AppKit
import UserNotifications
import os

@MainActor
final class StatusBarManager: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let viewContext: NSManagedObjectContext

    private var addDeviceWindow: NSWindow?
    private var manageDevicesWindow: NSWindow?

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wand.and.rays", accessibilityDescription: "Click2wakeup")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        // Rebuild the menu each time it opens so it always reflects the store.
        menu.delegate = self
        statusItem.menu = menu

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Menu

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated { rebuildMenu() }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let devices = (try? viewContext.fetch(Device.sortedByName())) ?? []
        let wakeable = devices.compactMap(WakeTarget.init)

        if wakeable.isEmpty {
            let empty = NSMenuItem(title: "No Devices Added", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for target in wakeable {
                menu.addItem(deviceItem(for: target))
            }
        }

        menu.addItem(.separator())
        menu.addItem(menuItem("Add Device", #selector(showAddDeviceWindow)))
        menu.addItem(menuItem("Manage Devices", #selector(showManageDevicesWindow)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit", #selector(quitApp), key: "q"))
    }

    private func menuItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    /// A row showing the device with a visible button, so it's obvious that one click
    /// turns the screen on (a plain menu title doesn't say what clicking it does).
    private func deviceItem(for target: WakeTarget) -> NSMenuItem {
        let row = DeviceMenuRow(target: target) { [weak self] in
            self?.menu.cancelTracking()
            self?.wake(target)
        }
        let hosting = NSHostingView(rootView: row)
        hosting.frame.size = hosting.fittingSize

        let item = NSMenuItem()
        item.view = hosting
        item.toolTip = target.toolTip
        return item
    }

    // MARK: - Actions

    private func wake(_ target: WakeTarget) {
        Task.detached(priority: .userInitiated) {
            switch target.action {
            case .turnOnDisplay(let host):
                // Success is visible (the screen turns on), so only report failures.
                if case .failure(let error) = DisplayWaker.wake(host: host) {
                    Self.postNotification(title: "Couldn't turn on \(target.name)", body: error.message)
                }
            case .wakeOnLAN(let mac):
                switch WakeOnLAN.wake(macAddress: mac) {
                case .success(let method):
                    Self.postNotification(title: "Wake-on-LAN",
                                          body: "Sent wake-up packet to \(target.name) using \(method.rawValue)")
                case .failure:
                    Self.postNotification(title: "Wake-on-LAN",
                                          body: "Failed to send wake-up packet to \(target.name). Please check your network settings.")
                }
            }
        }
    }

    nonisolated private static func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Logger.app.error("Failed to post notification: \(error, privacy: .public)")
            }
        }
    }

    @objc private func showAddDeviceWindow() {
        if addDeviceWindow == nil {
            let view = AddDeviceView { [weak self] in
                self?.addDeviceWindow?.close()
            }
            addDeviceWindow = makeWindow(title: "Add Device", size: NSSize(width: 300, height: 200),
                                         resizable: false, root: view) { [weak self] in
                self?.addDeviceWindow = nil
            }
        }
        present(addDeviceWindow)
    }

    @objc private func showManageDevicesWindow() {
        if manageDevicesWindow == nil {
            let view = ManageDevicesView { [weak self] in
                self?.manageDevicesWindow?.close()
            }
            manageDevicesWindow = makeWindow(title: "Manage Devices", size: NSSize(width: 400, height: 300),
                                             resizable: true, root: view) { [weak self] in
                self?.manageDevicesWindow = nil
            }
        }
        present(manageDevicesWindow)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Windows

    /// Creates a window hosting a SwiftUI view. `onClose` fires however the window is closed
    /// (button or red traffic light), so the next open starts with fresh state.
    private func makeWindow<Content: View>(
        title: String, size: NSSize, resizable: Bool, root: Content, onClose: @escaping () -> Void
    ) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable]
        if resizable { style.insert(.resizable) }

        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: style, backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: root.environment(\.managedObjectContext, viewContext)
        )
        window.center()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in
            MainActor.assumeIsolated { onClose() }
        }
        return window
    }

    private func present(_ window: NSWindow?) {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

/// A snapshot of a device's wake settings, safe to hand to a background task.
private final class WakeTarget: NSObject, Sendable {
    enum Action: Sendable {
        case turnOnDisplay(host: String)
        case wakeOnLAN(mac: String)
    }

    let name: String
    let action: Action

    init?(_ device: Device) {
        guard let name = device.name else { return nil }
        if device.turnsOnDisplay, let host = device.host {
            action = .turnOnDisplay(host: host)
        } else if let mac = device.mac {
            action = .wakeOnLAN(mac: mac)
        } else {
            return nil
        }
        self.name = name
    }

    var symbolName: String {
        if case .turnOnDisplay = action { return "display" }
        return "power"
    }

    /// Host or MAC address, shown under the name.
    var detail: String {
        switch action {
        case .turnOnDisplay(let host): return host
        case .wakeOnLAN(let mac): return mac
        }
    }

    /// Shown while hovering the button, and read by VoiceOver.
    var buttonTitle: String {
        if case .turnOnDisplay = action { return "Click to turn on screen" }
        return "Click to wake"
    }

    var buttonColor: Color {
        if case .turnOnDisplay = action { return .orange }
        return .green
    }

    var buttonSymbol: String {
        if case .turnOnDisplay = action { return "sun.max.fill" }
        return "power"
    }

    var toolTip: String {
        switch action {
        case .turnOnDisplay(let host): return "Turn on the display of \(host)"
        case .wakeOnLAN(let mac): return "Send Wake-on-LAN to \(mac)"
        }
    }
}

/// One device in the menu: icon, name and address on the left, an action button on the right.
private struct DeviceMenuRow: View {
    let target: WakeTarget
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: target.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(target.name)
                // Menus don't show tooltips, so hovering the button swaps the
                // address line for a hint saying what the button does.
                Text(isHovering ? target.buttonTitle : target.detail)
                    .font(.caption)
                    .foregroundStyle(isHovering ? AnyShapeStyle(target.buttonColor) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 16)
            Button(action: action) {
                Image(systemName: target.buttonSymbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(target.buttonColor.opacity(isHovering ? 1 : 0.85)))
                    .scaleEffect(isHovering ? 1.08 : 1)
                    .animation(.easeOut(duration: 0.12), value: isHovering)
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .accessibilityLabel(target.buttonTitle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(minWidth: 220)
    }
}
