//
//  WakeOnLAN.swift
//  Click2wakeup
//
//  Created for Click2wakeup.
//

import Foundation
import Network
import os

enum WakeOnLAN {

    enum Method: String {
        case network = "Network framework"
        case socket = "Socket API"
    }

    struct WakeError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static let port: UInt16 = 9
    private static let networkTimeout: TimeInterval = 5

    /// Sends a magic packet to the LAN broadcast address.
    /// Tries the Network framework first, then falls back to a BSD socket.
    /// Blocks the calling thread for up to ~5s — call off the main thread.
    static func wake(macAddress: String) -> Result<Method, WakeError> {
        guard let mac = MACAddress(macAddress) else {
            return .failure(WakeError(message: "Invalid MAC address format"))
        }
        let packet = mac.magicPacket

        switch sendWithNetworkFramework(packet) {
        case .success:
            Logger.wake.info("Sent magic packet to \(mac.formatted, privacy: .public) via Network framework")
            return .success(.network)
        case .failure(let error):
            Logger.wake.notice("Network framework failed (\(error.message, privacy: .public)); falling back to socket")
        }

        switch sendWithSocket(packet) {
        case .success:
            Logger.wake.info("Sent magic packet to \(mac.formatted, privacy: .public) via socket")
            return .success(.socket)
        case .failure(let error):
            Logger.wake.error("Socket send failed: \(error.message, privacy: .public)")
            return .failure(error)
        }
    }

    // MARK: - Network framework

    private static func sendWithNetworkFramework(_ packet: [UInt8]) -> Result<Void, WakeError> {
        let parameters = NWParameters.udp
        if let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
            ip.hopLimit = 3
        }
        parameters.allowLocalEndpointReuse = true

        let connection = NWConnection(
            host: "255.255.255.255",
            port: NWEndpoint.Port(rawValue: port)!,
            using: parameters
        )

        let semaphore = DispatchSemaphore(value: 0)
        let lock = OSAllocatedUnfairLock<Result<Void, WakeError>?>(initialState: nil)
        let finish: (Result<Void, WakeError>) -> Void = { result in
            let isFirst = lock.withLock { state -> Bool in
                guard state == nil else { return false }
                state = result
                return true
            }
            if isFirst {
                connection.cancel()
                semaphore.signal()
            }
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: Data(packet), completion: .contentProcessed { error in
                    finish(error.map { .failure(WakeError(message: $0.localizedDescription)) } ?? .success(()))
                })
            case .failed(let error):
                finish(.failure(WakeError(message: "Connection failed: \(error.localizedDescription)")))
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))

        if semaphore.wait(timeout: .now() + networkTimeout) == .timedOut {
            finish(.failure(WakeError(message: "Timed out")))
        }
        return lock.withLock { $0 } ?? .failure(WakeError(message: "Timed out"))
    }

    // MARK: - BSD socket fallback

    private static func sendWithSocket(_ packet: [UInt8]) -> Result<Void, WakeError> {
        func posixError(_ context: String) -> WakeError {
            WakeError(message: "\(context): \(String(cString: strerror(errno)))")
        }

        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return .failure(posixError("Failed to create socket")) }
        defer { close(sock) }

        var broadcast: Int32 = 1
        guard setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size)) == 0 else {
            return .failure(posixError("Failed to enable broadcast"))
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_BROADCAST

        let sent = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(sock, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard sent >= 0 else { return .failure(posixError("Failed to send packet")) }
        return .success(())
    }
}
