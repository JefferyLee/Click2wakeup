//
//  AddDeviceView.swift
//  Click2wakeup
//
//  Created for Click2wakeup.
//

import SwiftUI
import CoreData

struct AddDeviceView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var deviceName = ""
    @State private var macAddress = ""
    @State private var errorMessage: String?

    /// Called on cancel or after a successful save.
    var onDismiss: () -> Void

    private var trimmedName: String { deviceName.trimmingCharacters(in: .whitespaces) }
    private var trimmedMAC: String { macAddress.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Device")
                .font(.headline)

            TextField("Device Name", text: $deviceName)
                .textFieldStyle(.roundedBorder)

            TextField("MAC Address (e.g., 00:11:22:33:44:55)", text: $macAddress)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add", action: addDevice)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty || trimmedMAC.isEmpty)
            }
            .padding(.top)
        }
        .padding()
        .frame(minWidth: 300, minHeight: 150)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func addDevice() {
        guard let mac = MACAddress(trimmedMAC) else {
            errorMessage = "Invalid MAC address format. Please use format like 00:11:22:33:44:55"
            return
        }

        let duplicate = Device.fetchRequest()
        duplicate.predicate = NSPredicate(format: "name == %@", trimmedName)

        do {
            guard try viewContext.count(for: duplicate) == 0 else {
                errorMessage = "A device with this name already exists."
                return
            }

            let device = Device(context: viewContext)
            device.name = trimmedName
            device.mac = mac.formatted
            try viewContext.save()
            onDismiss()
        } catch {
            viewContext.rollback()
            errorMessage = "Failed to save device: \(error.localizedDescription)"
        }
    }
}

#Preview {
    AddDeviceView {}
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
