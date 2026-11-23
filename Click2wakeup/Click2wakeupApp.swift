//
//  Click2wakeupApp.swift
//  Click2wakeup
//
//  Created by Li Zhipeng on 3/2/25.
//

import SwiftUI
import AppKit
import CoreData
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let persistence = PersistenceController.shared
    var viewContext: NSManagedObjectContext { persistence.container.viewContext }

    private var statusBarManager: StatusBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon.
        NSApp.setActivationPolicy(.accessory)
        statusBarManager = StatusBarManager(viewContext: viewContext)
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            Logger.app.error("Failed to save before termination: \(error, privacy: .public)")
        }
    }
}

@main
struct Click2wakeupApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            ContentView()
                .environment(\.managedObjectContext, appDelegate.viewContext)
        }
    }
}
