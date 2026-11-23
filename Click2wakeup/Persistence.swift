//
//  Persistence.swift
//  Click2wakeup
//
//  Created by Li Zhipeng on 3/2/25.
//

import CoreData
import os

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let context = result.container.viewContext
        for i in 0..<3 {
            let device = Device(context: context)
            device.name = "Sample Device \(i + 1)"
            device.mac = "00:11:22:33:44:5\(i)"
        }
        try! context.save()
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Click2wakeup")
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            if let directory = description.url?.deletingLastPathComponent() {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        }

        // SQLite stores load synchronously by default, so the handler runs before this returns.
        var loadError: NSError?
        container.loadPersistentStores { _, error in
            loadError = error as NSError?
        }

        if let error = loadError {
            Logger.persistence.error("Failed to load store: \(error, privacy: .public)")
            #if DEBUG
            fatalError("Unresolved error \(error), \(error.userInfo)")
            #else
            recreateStore(description)
            #endif
        }

        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.shouldDeleteInaccessibleFaults = true
    }

    /// Last-resort recovery: wipe the on-disk store (including -wal/-shm) and start fresh.
    private func recreateStore(_ description: NSPersistentStoreDescription) {
        guard let url = description.url else { return }
        let coordinator = container.persistentStoreCoordinator
        do {
            try coordinator.destroyPersistentStore(at: url, type: NSPersistentStore.StoreType(rawValue: description.type))
            _ = try coordinator.addPersistentStore(
                type: NSPersistentStore.StoreType(rawValue: description.type),
                configuration: description.configuration,
                at: url,
                options: description.options
            )
            Logger.persistence.notice("Recreated persistent store")
        } catch {
            Logger.persistence.fault("Store recovery failed: \(error, privacy: .public)")
        }
    }
}

extension Device {
    /// All devices, alphabetical by name.
    static func sortedByName() -> NSFetchRequest<Device> {
        let request = Device.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Device.name, ascending: true)]
        return request
    }

    var displayName: String { name ?? "Unnamed Device" }
    var displayMAC: String { mac ?? "No MAC address" }
}
