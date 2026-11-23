//
//  ManageDevicesView.swift
//  Click2wakeup
//
//  Created for Click2wakeup.
//

import SwiftUI
import CoreData

struct ManageDevicesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(fetchRequest: Device.sortedByName()) private var devices: FetchedResults<Device>

    @State private var selectedDevice: Device?
    @State private var errorMessage: String?

    var onClose: () -> Void

    var body: some View {
        VStack {
            if devices.isEmpty {
                Text("No devices added")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(devices, id: \.self, selection: $selectedDevice) { device in
                    DeviceRow(device: device)
                }
                .listStyle(.plain)
            }

            HStack {
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Delete Selected", role: .destructive, action: deleteSelectedDevice)
                    .disabled(selectedDevice == nil)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deleteSelectedDevice() {
        guard let device = selectedDevice else { return }
        withAnimation {
            viewContext.delete(device)
            do {
                try viewContext.save()
                selectedDevice = nil
            } catch {
                viewContext.rollback()
                errorMessage = "Failed to delete device: \(error.localizedDescription)"
            }
        }
    }
}

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading) {
                Text(device.displayName)
                    .font(.headline)
                Text(device.displayDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

#Preview {
    ManageDevicesView {}
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
