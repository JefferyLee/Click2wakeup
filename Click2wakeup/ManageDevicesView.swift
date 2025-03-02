//
//  ManageDevicesView.swift
//  Click2wakeup
//
//  Created for Click2wakeup.
//

import SwiftUI
import CoreData

struct ManageDevicesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDevice: Device?
    
    // Add state variables for UI refresh
    @State private var devices: [Device] = []
    @State private var errorMessage: String = ""
    @State private var showingError: Bool = false
    @State private var isLoading: Bool = false
    
    private var viewContext: NSManagedObjectContext
    var onChange: () -> Void
    
    init(viewContext: NSManagedObjectContext, onChange: @escaping () -> Void) {
        // print("Initializing ManageDevicesView, context: \(viewContext)")
        
        self.viewContext = viewContext
        self.onChange = onChange
        
        // We'll delay loading the device list to onAppear
        self._isLoading = State(initialValue: true)
    }
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if devices.isEmpty {
                Text("No devices added")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(devices, id: \.self, selection: $selectedDevice) { device in
                    DeviceRow(device: device)
                }
                .listStyle(PlainListStyle())
            }
            
            HStack {
                Button("Close") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Refresh") {
                    loadDevices()
                }
                
                Spacer()
                
                Button("Delete Selected") {
                    deleteSelectedDevice()
                }
                .disabled(selectedDevice == nil)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            loadDevices()
        }
        .onDisappear {
            onChange()
        }
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Function to load the device list
    private func loadDevices() {
        // print("Loading device list...")
        isLoading = true
        
        // Manually fetch devices
        let fetchRequest: NSFetchRequest<Device> = Device.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Device.name, ascending: true)]
        
        do {
            self.devices = try viewContext.fetch(fetchRequest)
            // print("Successfully fetched \(self.devices.count) devices")
            isLoading = false
        } catch {
            // print("Failed to fetch devices: \(error)")
            errorMessage = "Failed to fetch devices: \(error.localizedDescription)"
            showingError = true
            self.devices = []
            isLoading = false
        }
    }
    
    private func deleteSelectedDevice() {
        if let deviceToDelete = selectedDevice {
            // print("Deleting device: \(deviceToDelete.name ?? "Unknown")")
            
            withAnimation {
                viewContext.delete(deviceToDelete)
                
                do {
                    try viewContext.save()
                    // print("Device deleted successfully and saved")
                    selectedDevice = nil
                    
                    // Reload the device list to reflect changes
                    loadDevices()
                    
                    // Notify status bar to update
                    onChange()
                } catch {
                    // Error handling
                    errorMessage = "Failed to delete device: \(error.localizedDescription)"
                    showingError = true
                    // print("Failed to delete device: \(error)")
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: Device
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name ?? "Unknown")
                    .font(.headline)
                Text(device.mac ?? "No MAC address")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ManageDevicesView_Previews: PreviewProvider {
    static var previews: some View {
        ManageDevicesView(viewContext: PersistenceController.preview.container.viewContext) {
            // Do nothing in preview
        }
    }
} 
