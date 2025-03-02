//
//  Click2wakeupApp.swift
//  Click2wakeup
//
//  Created by Li Zhipeng on 3/2/25.
//

import SwiftUI
import AppKit
import CoreData

// Create an AppDelegate to manage application lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarManager: StatusBarManager?
    
    // Lazily initialize the persistence controller to ensure it's fully set up
    lazy var persistenceController: PersistenceController = {
        // print("Initializing AppDelegate's persistenceController")
        let controller = PersistenceController.shared
        // Validate persistent store is properly loaded
        if !controller.validateViewContext() {
            // print("Warning: Persistent store validation failed, application may not work properly")
        }
        return controller
    }()
    
    // Keep a reference to the viewContext to prevent it from being deallocated
    lazy var viewContext: NSManagedObjectContext = {
        // print("Initializing AppDelegate's viewContext")
        let context = persistenceController.container.viewContext
        
        // Validate view context
        if let coordinator = context.persistentStoreCoordinator {
            // print("View context coordinator: \(coordinator)")
            // print("Persistent stores count: \(coordinator.persistentStores.count)")
        } else {
            // print("Warning: View context has no persistent store coordinator!")
        }
        
        return context
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // print("===== Application Launch =====")
        
        // Configure app to be a pure agent (menu bar only) app
        NSApp.setActivationPolicy(.accessory)
        
        // Ensure Core Data is fully initialized before creating the status bar manager
        // print("Ensuring Core Data is fully initialized...")
        _ = viewContext // Access the context to ensure initialization
        
        // Create the status bar manager
        // print("Creating status bar manager...")
        DispatchQueue.main.async {
            self.statusBarManager = StatusBarManager(viewContext: self.viewContext)
            // print("Status bar manager creation complete")
        }
        
        // Print debugging info
        // print("Core Data container: \(persistenceController.container)")
        // print("View context: \(viewContext)")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // print("Application will terminate")
        
        // Save any pending changes
        if viewContext.hasChanges {
            do {
                // print("Saving context changes...")
                try viewContext.save()
                // print("Context changes saved")
            } catch {
                // print("Failed to save context before termination: \(error)")
            }
        } else {
            // print("Context has no changes to save")
        }
    }
}

@main
struct Click2wakeupApp: App {
    // Use the AppDelegate for lifecycle management
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // print("Click2wakeupApp initialization")
    }
    
    var body: some Scene {
        Settings {
            // Basic info view
            ContentView()
                .environment(\.managedObjectContext, appDelegate.viewContext)
                .onAppear {
                    // Add debug info, verify context in environment
                }
        }
    }
}
