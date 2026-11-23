//
//  ContentView.swift
//  Click2wakeup
//
//  Created by Li Zhipeng on 3/2/25.
//

import SwiftUI
import CoreData

/// Informational window shown from the app's Settings scene.
struct ContentView: View {
    @FetchRequest(fetchRequest: Device.sortedByName()) private var devices: FetchedResults<Device>

    var body: some View {
        VStack(spacing: 20) {
            Text("Click2wakeup")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("This is a status bar application")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Please use the status bar icon to access the application")
                .multilineTextAlignment(.center)
                .padding()

            if devices.isEmpty {
                Text("No devices added yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding()

                Text("Click the status bar icon and select 'Add Device' to add a new device")
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                Text("Configured Devices:")
                    .font(.headline)

                List(devices, id: \.self) { device in
                    HStack {
                        Text(device.displayName)
                        Spacer()
                        Text(device.displayDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 100, maxHeight: 200)
            }

            Spacer()

            Text("This window is for information only")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
