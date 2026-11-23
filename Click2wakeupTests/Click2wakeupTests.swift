//
//  Click2wakeupTests.swift
//  Click2wakeupTests
//
//  Created by Li Zhipeng on 3/2/25.
//

import Testing
@testable import Click2wakeup

struct MACAddressTests {

    @Test(arguments: [
        "00:11:22:aa:bb:cc",
        "00-11-22-AA-BB-CC",
        "0011.22aa.bbcc",
        "001122AABBCC",
    ])
    func parsesCommonFormats(_ input: String) throws {
        let mac = try #require(MACAddress(input))
        #expect(mac.bytes == [0x00, 0x11, 0x22, 0xAA, 0xBB, 0xCC])
        #expect(mac.formatted == "00:11:22:AA:BB:CC")
    }

    @Test(arguments: ["", "00:11:22:33:44", "00:11:22:33:44:55:66", "GG:11:22:33:44:55", "+0:11:22:33:44:55"])
    func rejectsInvalid(_ input: String) {
        #expect(MACAddress(input) == nil)
    }

    @Test func magicPacketLayout() throws {
        let mac = try #require(MACAddress("01:02:03:04:05:06"))
        let packet = mac.magicPacket
        #expect(packet.count == 102)
        #expect(packet.prefix(6).allSatisfy { $0 == 0xFF })
        for i in 0..<16 {
            #expect(Array(packet[(6 + i * 6)..<(12 + i * 6)]) == mac.bytes)
        }
    }

    @Test func wakeRejectsInvalidMAC() {
        guard case .failure = WakeOnLAN.wake(macAddress: "nope") else {
            Issue.record("Expected failure for invalid MAC")
            return
        }
    }
}
