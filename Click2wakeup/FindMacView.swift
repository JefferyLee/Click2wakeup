//
//  FindMacView.swift
//  Click2wakeup
//
//  Sheet listing Macs on the network that have Remote Login on.
//

import SwiftUI
import CoreData

struct FindMacView: View {
    @FetchRequest(fetchRequest: Device.sortedByName()) private var savedDevices: FetchedResults<Device>

    @State private var macs: [FoundMac] = []
    @State private var isSearching = false
    @State private var selection: FoundMac.ID?

    var onPick: (FoundMac) -> Void
    var onCancel: () -> Void

    private var savedHosts: Set<String> {
        Set(savedDevices.compactMap { $0.host?.lowercased() })
    }

    private var selectedMac: FoundMac? {
        macs.first { $0.id == selection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macs on Your Network")
                .font(.headline)
            Text("Shows Macs with Remote Login turned on (System Settings → General → Sharing).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button {
                    Task { await search() }
                } label: {
                    Label("Search Again", systemImage: "arrow.clockwise")
                }
                .disabled(isSearching)
                Spacer()
                Button("Choose") {
                    if let mac = selectedMac { onPick(mac) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedMac == nil)
            }
        }
        .padding()
        .frame(width: 420, height: 340)
        .task { await search() }
    }

    @ViewBuilder
    private var content: some View {
        if isSearching && macs.isEmpty {
            VStack(spacing: 8) {
                ProgressView()
                Text("Looking for Macs…")
                    .foregroundStyle(.secondary)
            }
        } else if macs.isEmpty {
            ContentUnavailableView(
                "No Macs Found", systemImage: "desktopcomputer",
                description: Text("Make sure the Mac is on, on the same network, and has Remote Login turned on.")
            )
        } else {
            List(macs, selection: $selection) { mac in
                HStack(spacing: 10) {
                    Image(systemName: "desktopcomputer")
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mac.name)
                        Text(mac.host)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if savedHosts.contains(mac.host.lowercased()) {
                        Text("Added")
                            .font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: Capsule())
                    }
                }
                .padding(.vertical, 2)
                .tag(mac.id)
            }
            .listStyle(.inset)
            .contextMenu(forSelectionType: FoundMac.ID.self) { _ in } primaryAction: { ids in
                if let id = ids.first, let mac = macs.first(where: { $0.id == id }) { onPick(mac) }
            }
        }
    }

    private func search() async {
        isSearching = true
        defer { isSearching = false }
        macs = await MacFinder.discover()
        if let selection, !macs.contains(where: { $0.id == selection }) { self.selection = nil }
    }
}
