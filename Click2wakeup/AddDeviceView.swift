//
//  AddDeviceView.swift
//  Click2wakeup
//
//  Created for Click2wakeup.
//

import SwiftUI
import CoreData

struct AddDeviceView: View {
    @State private var deviceName: String = ""
    @State private var macAddress: String = ""
    @State private var errorMessage: String = ""
    @State private var showingError: Bool = false
    
    private var viewContext: NSManagedObjectContext
    var onComplete: () -> Void
    
    init(viewContext: NSManagedObjectContext, onComplete: @escaping () -> Void) {
        // print("Initializing AddDeviceView, context: \(viewContext)")
        self.viewContext = viewContext
        self.onComplete = onComplete
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Device")
                .font(.headline)
            
            TextField("Device Name", text: $deviceName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("MAC Address (e.g., 00:11:22:33:44:55)", text: $macAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Button("Cancel") {
                    onComplete()
                }
                
                Spacer()
                
                Button("Add") {
                    addDevice()
                }
                .disabled(deviceName.isEmpty || macAddress.isEmpty)
            }
            .padding(.top)
        }
        .padding()
        .frame(minWidth: 300, minHeight: 150)
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func addDevice() {
        // Basic MAC address format validation
        let macPattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        let macPredicate = NSPredicate(format: "SELF MATCHES %@", macPattern)
        
        guard macPredicate.evaluate(with: macAddress) else {
            errorMessage = "Invalid MAC address format. Please use format like 00:11:22:33:44:55"
            showingError = true
            return
        }
        
        // Check if device with this name already exists
        let fetchRequest: NSFetchRequest<Device> = Device.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", deviceName)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if !results.isEmpty {
                errorMessage = "A device with this name already exists."
                showingError = true
                return
            }
            
            // Add the new device
            let newDevice = Device(context: viewContext)
            newDevice.name = deviceName
            newDevice.mac = macAddress
            
            try viewContext.save()
            onComplete()
            
        } catch {
            errorMessage = "Failed to save device: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// Preview for the Add Device View
struct AddDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        AddDeviceView(viewContext: PersistenceController.preview.container.viewContext) {
            // Do nothing in preview
        }
    }
} 
