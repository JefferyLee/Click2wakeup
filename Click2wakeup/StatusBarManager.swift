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
        let wakeable = devices.filter { $0.name != nil && $0.mac != nil }

        if wakeable.isEmpty {
            let empty = NSMenuItem(title: "No Devices Added", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for device in wakeable {
                let item = menuItem(device.displayName, #selector(wakeDevice(_:)))
                item.representedObject = device.mac
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
        guard let mac = sender.representedObject as? String else { return }
        let name = sender.title

        Task.detached(priority: .userInitiated) {
            let result = WakeOnLAN.wake(macAddress: mac)
            let body: String
            switch result {
            case .success(let method):
                body = "Successfully sent wake-up packet to \(name) using \(method.rawValue)"
            case .failure:
                body = "Failed to send wake-up packet to \(name). Please check your network settings."
            }
            Self.postNotification(body: body)
        }
    }

    nonisolated private static func postNotification(body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Wake-on-LAN"
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
