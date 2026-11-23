//
//  MacFinder.swift
//  Click2wakeup
//
//  Finds Macs on the local network that have Remote Login (SSH) turned on,
//  using Bonjour — the same mechanism Finder's sidebar uses.
//

import Foundation
import Network
import dnssd
import os

struct FoundMac: Identifiable, Hashable, Sendable {
    /// Bonjour name, e.g. "Ada" or "Ada’s iMac".
    let name: String
    /// Resolved host name, e.g. "Ada.local".
    let host: String
    var id: String { name }
}

enum MacFinder {

    private static let serviceType = "_ssh._tcp"  // must be listed in NSBonjourServices

    /// Browses for `duration`, then returns every Mac found (excluding this one), sorted by name.
    static func discover(for duration: Duration = .seconds(3)) async -> [FoundMac] {
        let queue = DispatchQueue(label: "mac-finder")
        let names = OSAllocatedUnfairLock(initialState: Set<String>())

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: "local."), using: .tcp)
        browser.browseResultsChangedHandler = { results, _ in
            let found = results.compactMap { result -> String? in
                if case let .service(name, _, _, _) = result.endpoint { return name }
                return nil
            }
            names.withLock { $0.formUnion(found) }
        }
        browser.stateUpdateHandler = { state in
            if case let .failed(error) = state {
                Logger.discovery.error("Browse failed: \(error, privacy: .public)")
            }
        }
        browser.start(queue: queue)
        try? await Task.sleep(for: duration)
        browser.cancel()

        let ownName = Host.current().localizedName
        let candidates = names.withLock { $0 }.filter { $0 != ownName }

        let macs = await withTaskGroup(of: FoundMac?.self) { group in
            for name in candidates {
                group.addTask {
                    await Task.detached {
                        resolveHost(service: name, type: serviceType).map { FoundMac(name: name, host: $0) }
                    }.value
                }
            }
            var macs: [FoundMac] = []
            for await mac in group { if let mac { macs.append(mac) } }
            return macs
        }
        Logger.discovery.info("Found \(macs.count) Mac(s) with Remote Login")
        return macs.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Resolves a Bonjour service instance to its target host name ("Ada.local").
    /// Blocks for up to `timeout`.
    static func resolveHost(service name: String, type: String, timeout: TimeInterval = 3) -> String? {
        final class Box { var host: String? }
        let box = Box()

        var ref: DNSServiceRef?
        let status = DNSServiceResolve(
            &ref, 0, 0, name, type, "local.",
            { _, _, _, errorCode, _, hostTarget, _, _, _, context in
                guard errorCode == kDNSServiceErr_NoError, let hostTarget, let context else { return }
                Unmanaged<Box>.fromOpaque(context).takeUnretainedValue().host = String(cString: hostTarget)
            },
            Unmanaged.passUnretained(box).toOpaque()
        )
        guard status == kDNSServiceErr_NoError, let ref else { return nil }
        defer { DNSServiceRefDeallocate(ref) }

        let deadline = Date().addingTimeInterval(timeout)
        var pfd = pollfd(fd: DNSServiceRefSockFD(ref), events: Int16(POLLIN), revents: 0)
        while box.host == nil {
            let remainingMs = Int32(deadline.timeIntervalSinceNow * 1000)
            guard remainingMs > 0, poll(&pfd, 1, remainingMs) > 0,
                  DNSServiceProcessResult(ref) == kDNSServiceErr_NoError else { break }
        }
        return box.host.map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 }
    }
}
