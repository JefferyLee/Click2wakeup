//
//  Persistence.swift
//  Click2wakeup
//
//  Created by Li Zhipeng on 3/2/25.
//

import CoreData

struct PersistenceController {
    // Shared singleton instance
    static let shared = PersistenceController()
    
    // Container for Core Data
    let container: NSPersistentContainer
    
    // Preview instance for SwiftUI previews
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for i in 0..<3 {
            let newDevice = Device(context: viewContext)
            newDevice.name = "Sample Device \(i+1)"
            newDevice.mac = "00:11:22:33:44:5\(i)"
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    // Initialize the controller
    init(inMemory: Bool = false) {
        // print("===== Initializing PersistenceController =====")
        container = NSPersistentContainer(name: "Click2wakeup")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Ensure we have a valid store URL
            if let storeURL = container.persistentStoreDescriptions.first?.url {
                // print("Persistent store URL: \(storeURL)")
                
                // Check if store directory exists, if not create it
                if let storeDirectory = storeURL.deletingLastPathComponent().path as String? {
                    do {
                        try FileManager.default.createDirectory(
                            atPath: storeDirectory,
                            withIntermediateDirectories: true,
                            attributes: nil
                        )
                    } catch {
                        // print("Failed to create store directory: \(error)")
                    }
                }
            } else {
                // print("Warning: Persistent store URL not found!")
            }
            
            // Set store options for increased reliability
            let storeDescription = container.persistentStoreDescriptions.first
            storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        }
        
        // Synchronously load persistent stores to ensure they are loaded before initialization completes
        // print("Starting persistent store loading...")
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error? = nil
        
        container.loadPersistentStores { (storeDescription, error) in
            defer { semaphore.signal() }
            
            if let error = error {
                // Store error for later reporting
                loadError = error
                // print("Failed to load persistent store: \(error)")
                
            } else {
                // print("Successfully loaded persistent store: \(storeDescription)")
                // print("Persistent store type: \(storeDescription.type)")
                // print("Persistent store URL: \(String(describing: storeDescription.url))")
                // print("Persistent store options: \(storeDescription.options)")
            }
        }
        
        // Wait for stores to load, timeout after 10 seconds
        let timeoutResult = semaphore.wait(timeout: .now() + 10.0)
        if timeoutResult == .timedOut {
            // print("Persistent store loading timed out!")
            fatalError("Persistent store loading timed out - application cannot continue")
        }
        
        // Report errors now if any
        if let error = loadError as NSError? {
            // print("Persistent store loading failed, detailed error: \(error.userInfo)")
            
            // Only fatal error in debug builds
            #if DEBUG
            fatalError("Unresolved error \(error), \(error.userInfo)")
            #else
            // In production, try to recover or rebuild the store
            // print("Attempting to recover persistent store...")
            do {
                try recreatePersistentStore()
            } catch {
                // print("Store recovery failed: \(error)")
            }
            #endif
        }
        
        // Validate persistent store coordinator
        let coordinator = container.persistentStoreCoordinator
        let stores = coordinator.persistentStores
        if !stores.isEmpty {
            // print("Persistent store coordinator is set up with \(stores.count) stores")
        } else {
            // print("Warning: Persistent store coordinator has no loaded stores!")
        }
        
        // Enable automatic change merging
        // print("Configuring view context...")
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Increase fault tolerance
        // print("Setting up error handling...")
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        // print("PersistenceController initialization complete")
        // print("Coordinator: \(String(describing: container.viewContext.persistentStoreCoordinator))")
    }
    
    // Helper method: Try to rebuild persistent store
    private func recreatePersistentStore() throws {
        // print("Attempting to rebuild persistent store...")
        
        let persistentStoreCoordinator = container.persistentStoreCoordinator
        
        guard let persistentStoreDescription = container.persistentStoreDescriptions.first,
              let persistentStoreURL = persistentStoreDescription.url else {
            throw NSError(domain: "PersistenceControllerError", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Could not get persistent store information"
            ])
        }
        
        // Remove failed stores
        for store in persistentStoreCoordinator.persistentStores {
            try persistentStoreCoordinator.remove(store)
        }
        
        // Try to delete old store files
        do {
            try FileManager.default.removeItem(at: persistentStoreURL)
            
            // Also try to delete related files
            let journalURL = persistentStoreURL.appendingPathExtension("-journal")
            try? FileManager.default.removeItem(at: journalURL)
            
            let shmURL = persistentStoreURL.appendingPathExtension("-shm")
            try? FileManager.default.removeItem(at: shmURL)
            
            let walURL = persistentStoreURL.appendingPathExtension("-wal")
            try? FileManager.default.removeItem(at: walURL)
        } catch {
            // print("Failed to delete old store files: \(error), will continue trying to recreate")
        }
        
        // Try to recreate the store
        // print("Creating new persistent store...")
        try persistentStoreCoordinator.addPersistentStore(
            ofType: persistentStoreDescription.type,
            configurationName: persistentStoreDescription.configuration,
            at: persistentStoreURL,
            options: persistentStoreDescription.options
        )
        
        // print("Successfully rebuilt persistent store")
    }
    
    // Check if view context is properly connected to a persistent store coordinator
    func validateViewContext() -> Bool {
        guard let coordinator = container.viewContext.persistentStoreCoordinator else {
            // print("Error: View context has no persistent store coordinator")
            return false
        }
        
        if coordinator.persistentStores.isEmpty {
            // print("Error: Persistent store coordinator has no loaded stores")
            return false
        }
        
        // print("Validation successful: View context is properly connected to persistent store coordinator")
        return true
    }
}
