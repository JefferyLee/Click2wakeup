//
//  AddDeviceView.swift
//  Click2wakeup
//
//  Created for Click2wakeup.
//

import SwiftUI
import CoreData

struct AddDeviceView: View {
    enum Method: String, CaseIterable, Identifiable {
        case display = "Turn On Display"
        case wakeOnLAN = "Wake-on-LAN"
        var id: Self { self }
    }

    enum TestState: Equatable {
        case idle, running, succeeded
        case failed(String)
    }

    @Environment(\.managedObjectContext) private var viewContext

    @State private var method: Method = .display
    @State private var deviceName = ""
    @State private var host = ""
    @State private var macAddress = ""
    @State private var errorMessage: String?
    @State private var showingFinder = false
    @State private var testState: TestState = .idle

    /// Called on cancel or after a successful save.
    var onDismiss: () -> Void

    private var trimmedName: String { deviceName.trimmingCharacters(in: .whitespaces) }
    private var trimmedHost: String { host.trimmingCharacters(in: .whitespaces) }
    private var trimmedMAC: String { macAddress.trimmingCharacters(in: .whitespaces) }

    private var canAdd: Bool {
        guard !trimmedName.isEmpty else { return false }
        switch method {
        case .display: return !trimmedHost.isEmpty
        case .wakeOnLAN: return !trimmedMAC.isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add New Device")
                .font(.headline)

            Picker("", selection: $method) {
                ForEach(Method.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(method == .display
                 ? "For a Mac that's awake but has its screen off. Uses SSH (Remote Login) to turn the screen on."
                 : "For a device that's asleep. Sends a Wake-on-LAN packet to its network card.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Device Name", text: $deviceName)
                .textFieldStyle(.roundedBorder)

            switch method {
            case .display: displayFields
            case .wakeOnLAN: wakeOnLANFields
            }

            HStack {
                Button("Cancel", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add", action: addDevice)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: host) { testState = .idle }
        .sheet(isPresented: $showingFinder) {
            FindMacView { mac in
                host = mac.host
                if trimmedName.isEmpty { deviceName = mac.name }
                showingFinder = false
            } onCancel: {
                showingFinder = false
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var displayFields: some View {
        HStack {
            TextField("Host (e.g., Ada.local)", text: $host)
                .textFieldStyle(.roundedBorder)
            Button("Test", action: testConnection)
                .disabled(trimmedHost.isEmpty || testState == .running)
        }
        testStatus
        Button {
            showingFinder = true
        } label: {
            Label("Find Macs on Network…", systemImage: "magnifyingglass")
        }
    }

    @ViewBuilder
    private var testStatus: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Connecting…").foregroundStyle(.secondary)
            }
            .font(.caption)
        case .succeeded:
            Label("Worked — the screen should be on now.", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var wakeOnLANFields: some View {
        TextField("MAC Address (e.g., 00:11:22:33:44:55)", text: $macAddress)
            .textFieldStyle(.roundedBorder)
    }

    private func testConnection() {
        let host = trimmedHost
        testState = .running
        Task {
            let result = await Task.detached { DisplayWaker.wake(host: host) }.value
            guard host == trimmedHost else { return }  // host edited while testing
            switch result {
            case .success: testState = .succeeded
            case .failure(let error): testState = .failed(error.message)
            }
        }
    }

    private func addDevice() {
        var mac: MACAddress?
        switch method {
        case .display:
            guard DisplayWaker.isValidHost(trimmedHost) else {
                errorMessage = "\"\(trimmedHost)\" isn't a valid host name. Use something like Ada.local."
                return
            }
        case .wakeOnLAN:
            mac = MACAddress(trimmedMAC)
            guard mac != nil else {
                errorMessage = "Invalid MAC address format. Please use format like 00:11:22:33:44:55"
                return
            }
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
            device.host = method == .display ? trimmedHost : nil
            device.mac = mac?.formatted
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
