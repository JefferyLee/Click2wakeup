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
            if let url = description.url {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                Self.importSandboxedStoreIfNeeded(to: url)
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

    /// Versions ≤1.0 were sandboxed and kept their store inside the app container.
    /// Now that the app isn't sandboxed, copy that store over once so saved devices carry over.
    private static func importSandboxedStoreIfNeeded(to url: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path),
              let bundleID = Bundle.main.bundleIdentifier else { return }

        let oldDirectory = fm.homeDirectoryForCurrentUser
            .appending(path: "Library/Containers/\(bundleID)/Data/Library/Application Support")
        let oldStore = oldDirectory.appending(path: url.lastPathComponent)
        guard fm.fileExists(atPath: oldStore.path) else { return }

        // SQLite keeps recent writes in -wal/-shm side files; copy them together.
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: oldStore.path + suffix)
            let destination = URL(fileURLWithPath: url.path + suffix)
            guard fm.fileExists(atPath: source.path) else { continue }
            do {
                try fm.copyItem(at: source, to: destination)
            } catch {
                Logger.persistence.error("Couldn't import \(source.lastPathComponent, privacy: .public): \(error, privacy: .public)")
                // Don't leave a half-copied store behind.
                for cleanup in ["", "-wal", "-shm"] { try? fm.removeItem(atPath: url.path + cleanup) }
                return
            }
        }
        Logger.persistence.notice("Imported device store from sandbox container")
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

    /// Devices with a host turn on a Mac's display over SSH; the rest use Wake-on-LAN.
    var turnsOnDisplay: Bool { !(host ?? "").isEmpty }

    /// Secondary line for lists: the host or MAC address.
    var displayDetail: String {
        if turnsOnDisplay { return host ?? "" }
        return mac ?? "No MAC address"
    }

    var symbolName: String { turnsOnDisplay ? "display" : "power" }
}
