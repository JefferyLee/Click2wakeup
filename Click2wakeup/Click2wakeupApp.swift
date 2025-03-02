//
//  Click2wakeupApp.swift
//  Click2wakeup
//
//  Created by Li Zhipeng on 3/2/25.
//

import SwiftUI

@main
struct Click2wakeupApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
