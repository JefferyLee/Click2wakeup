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
            button.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Wake")
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
                let item = menuItem(target.name, #selector(wakeDevice(_:)))
                item.representedObject = target
                item.image = NSImage(systemSymbolName: target.symbolName, accessibilityDescription: nil)
                item.toolTip = target.toolTip
                menu.addItem(item)
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

    // MARK: - Actions

    @objc private func wakeDevice(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? WakeTarget else { return }

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

    var toolTip: String {
        switch action {
        case .turnOnDisplay(let host): return "Turn on the display of \(host)"
        case .wakeOnLAN(let mac): return "Send Wake-on-LAN to \(mac)"
        }
    }
}
