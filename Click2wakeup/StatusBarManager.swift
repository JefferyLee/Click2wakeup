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

class StatusBarManager: NSObject, ObservableObject {
    private var statusBar: NSStatusBar!
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var viewContext: NSManagedObjectContext
    
    // Add and manage device window controllers
    private var addDeviceWindowController: NSWindowController?
    private var manageDeviceWindowController: NSWindowController?
    
    init(viewContext: NSManagedObjectContext) {
        // Store the view context
        self.viewContext = viewContext
        
        // Initialize superclass before setting up UI elements
        super.init()
        
        // Setup UI on main thread
        if Thread.isMainThread {
            self.setupStatusBar()
        } else {
            DispatchQueue.main.sync {
                self.setupStatusBar()
            }
        }
        
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in}
    }
    
    private func setupStatusBar() {
        // Create the status bar item
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        
        // Initialize an empty menu
        menu = NSMenu()
        
        // Configure the status bar button
        if let button = statusItem.button {
            // Use fallback text first to ensure something appears
            button.title = "⚡️"
            
            // Then try to use system image if available
            if #available(macOS 11.0, *) {
                if let powerImage = NSImage(systemSymbolName: "power", accessibilityDescription: "Wake") {
                    button.image = powerImage
                    button.image?.size = NSSize(width: 18, height: 18)
                }
            } else {
                // For macOS 10.15 and earlier, use a custom image or keep the text
                // You could add a custom image to Assets.xcassets and use it here
                // print("Using text fallback for earlier macOS versions")
            }
        } else {
            // print("Warning: Could not configure status bar button")
        }
        
        // Set up the menu
        updateMenu()
        
        // Set the menu for our status item
        statusItem.menu = menu
    }
    
    func updateMenu() {
        // Ensure we're on the main thread for UI updates
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.updateMenu()
            }
            return
        }
        
        // Safety check in case the menu isn't initialized yet
        guard menu != nil else {
            // print("Warning: Menu not initialized when updating menu")
            return
        }
        
        // print("Updating status bar menu...")
        
        // Clear the current menu
        menu.removeAllItems()
        
        // Add all devices from Core Data using the safe fetch method
        let devices = fetchDevicesSafely()
        // print("Menu update - fetched \(devices.count) devices")
        
        // Add device items to menu
        if devices.isEmpty {
            let emptyItem = NSMenuItem(title: "No Devices Added", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            // print("Menu showing 'No Devices Added'")
        } else {
            for device in devices {
                if let name = device.name, let mac = device.mac {
                    let item = NSMenuItem(title: name, action: #selector(wakeDevice(_:)), keyEquivalent: "")
                    item.representedObject = mac
                    item.target = self
                    menu.addItem(item)
                    // print("Added device to menu: \(name)")
                }
            }
        }
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add device management options
        let addDeviceItem = NSMenuItem(title: "Add Device", action: #selector(showAddDeviceWindow), keyEquivalent: "")
        addDeviceItem.target = self
        menu.addItem(addDeviceItem)
        
        let manageDevicesItem = NSMenuItem(title: "Manage Devices", action: #selector(showManageDevicesWindow), keyEquivalent: "")
        manageDevicesItem.target = self
        menu.addItem(manageDevicesItem)
        
        // Add quit item
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // print("Status bar menu update complete")
    }
    
    @objc func wakeDevice(_ sender: NSMenuItem) {
        if let macAddress = sender.representedObject as? String {
            // print("Menu item clicked: attempting to wake device \(sender.title) with MAC: \(macAddress)")
            
            DispatchQueue.global(qos: .userInitiated).async {
                // First, try using Network framework
                // print("Attempting primary wake method for MAC: \(macAddress)")
                var success = WakeOnLAN.wakeDevice(macAddress: macAddress)
                var method = "Network framework"
                
                // If that fails, try the socket-based implementation
                if !success {
                    // print("Primary method failed, retrying with Socket implementation...")
                    success = WakeOnLAN.wakeDeviceWithSocketSimple(macAddress: macAddress)
                    method = "Socket API"
                }
                
                let finalResult = success
                let finalMethod = method
                
                // print("Wake attempt completed: \(finalResult ? "SUCCESS" : "FAILED") using \(finalMethod)")
                
                DispatchQueue.main.async {
                    // Show a notification to the user using modern UserNotifications framework
                    let content = UNMutableNotificationContent()
                    content.title = "Wake-on-LAN"
                    
                    if finalResult {
                        content.body = "Successfully sent wake-up packet to \(sender.title) using \(finalMethod)"
                        // print("Notification: Success - Wake packet sent to \(sender.title)")
                    } else {
                        content.body = "Failed to send wake-up packet to \(sender.title). Please check your network settings."
                        // print("Notification: Failed - Could not send wake packet to \(sender.title)")
                    }
                    
                    content.sound = UNNotificationSound.default
                    
                    // Create a request for immediate delivery
                    let request = UNNotificationRequest(
                        identifier: UUID().uuidString, 
                        content: content, 
                        trigger: nil
                    )
                    
                    // Add the request to the notification center
                    UNUserNotificationCenter.current().add(request) { error in}
                }
            }
        } else {
            // print("Error: No MAC address associated with menu item \(sender.title)")
        }
    }
    
    @objc func showAddDeviceWindow() {
        DispatchQueue.main.async {
            if self.addDeviceWindowController == nil {
                let addDeviceView = AddDeviceView(viewContext: self.viewContext) {
                    // This closure will be called when device is added
                    self.updateMenu()
                    self.addDeviceWindowController?.close()
                    self.addDeviceWindowController = nil
                }
                
                let hostingController = NSHostingController(rootView: addDeviceView)
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                    styleMask: [.titled, .closable],
                    backing: .buffered,
                    defer: false
                )
                window.title = "Add Device"
                window.contentView = hostingController.view
                window.center()
                
                self.addDeviceWindowController = NSWindowController(window: window)
            }
            
            self.addDeviceWindowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @objc func showManageDevicesWindow() {
        DispatchQueue.main.async {
            if self.manageDeviceWindowController == nil {
                let manageDevicesView = ManageDevicesView(viewContext: self.viewContext) {
                    // This closure will be called when changes are made
                    self.updateMenu()
                }
                
                let hostingController = NSHostingController(rootView: manageDevicesView)
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered,
                    defer: false
                )
                window.title = "Manage Devices"
                window.contentView = hostingController.view
                window.center()
                
                self.manageDeviceWindowController = NSWindowController(window: window)
            }
            
            self.manageDeviceWindowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // Safely fetch device list, handling potential Core Data errors
    private func fetchDevicesSafely() -> [Device] {
        // Verify that the view context is connected to a persistent store coordinator
        guard let coordinator = viewContext.persistentStoreCoordinator else {
            // print("Error: View context has no persistent store coordinator")
            return []
        }
        
        if coordinator.persistentStores.isEmpty {
            // print("Error: Persistent store coordinator has no loaded stores")
            return []
        }
        
        let fetchRequest: NSFetchRequest<Device> = Device.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Device.name, ascending: true)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            // print("Failed to fetch devices: \(error)")
            return []
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
} 
