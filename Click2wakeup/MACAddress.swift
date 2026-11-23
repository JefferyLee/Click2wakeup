//
//  MACAddress.swift
//  Click2wakeup
//

import Foundation

/// A parsed, validated 6-byte hardware address.
struct MACAddress: Hashable, Sendable {
    let bytes: [UInt8]

    /// Accepts `00:11:22:33:44:55`, `00-11-22-33-44-55`, `0011.2233.4455`, `001122334455`.
    init?(_ string: String) {
        let hex = string.replacingOccurrences(of: "[-:. ]", with: "", options: .regularExpression)
        guard hex.count == 12, hex.allSatisfy(\.isHexDigit) else { return nil }

        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.bytes = bytes
    }

    /// Canonical form, e.g. `00:11:22:AA:BB:CC`.
    var formatted: String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    /// Wake-on-LAN magic packet: 6 × 0xFF followed by the address repeated 16 times.
    var magicPacket: [UInt8] {
        [UInt8](repeating: 0xFF, count: 6) + Array([[UInt8]](repeating: bytes, count: 16).joined())
    }
}
