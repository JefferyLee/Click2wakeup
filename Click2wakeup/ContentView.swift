//
//  ContentView.swift
//  Click2wakeup
//
//  Created by Li Zhipeng on 3/2/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Use manual device fetching instead of FetchRequest
    @State private var devices: [Device] = []
    @State private var errorOccurred: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Click2wakeup")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This is a status bar application")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Please use the status bar icon to access the application")
                .multilineTextAlignment(.center)
                .padding()
            
            if errorOccurred {
                Text("⚠️ Core Data Error: Could not fetch devices")
                    .foregroundColor(.red)
                    .padding()
            } else if devices.isEmpty {
                Text("No devices added yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Text("Click the status bar icon and select 'Add Device' to add a new device")
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                Text("Configured Devices:")
                    .font(.headline)
                
                List {
                    ForEach(devices, id: \.self) { device in
                        HStack {
                            Text(device.name ?? "Unnamed Device")
                            Spacer()
                            Text(device.mac ?? "No MAC address")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(minHeight: 100, maxHeight: 200)
            }
            
            Spacer()
            
            Text("This window is for information only")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
        .padding()
        .frame(width: 400, height: 500)
        .onAppear {
            // Check if view context is correct
            // print("ContentView.onAppear - context: \(viewContext)")
            // Use optional binding to safely unwrap the coordinator
        }
    }
    
    private func fetchDevices() {
        let fetchRequest: NSFetchRequest<Device> = Device.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Device.name, ascending: true)]
        
        do {
            self.devices = try viewContext.fetch(fetchRequest)
            // print("ContentView successfully fetched \(self.devices.count) devices")
            errorOccurred = false
        } catch {
            // print("ContentView failed to fetch devices: \(error)")
            errorOccurred = true
            self.devices = []
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
