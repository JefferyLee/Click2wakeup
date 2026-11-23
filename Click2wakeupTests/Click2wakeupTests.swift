//
//  Click2wakeupTests.swift
//  Click2wakeupTests
//
//  Created by Li Zhipeng on 3/2/25.
//

import Testing
import CoreData
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

struct DisplayWakerTests {

    @Test(arguments: ["Ada.local", "Ada", "jeff@Ada.local", "192.168.86.34", "mac-mini_2.lan"])
    func acceptsHosts(_ host: String) {
        #expect(DisplayWaker.isValidHost(host))
    }

    @Test(arguments: ["", "-oProxyCommand=evil", "Ada local", "Ada;rm -rf ~", "$(whoami)", "a`b`"])
    func rejectsUnsafeHosts(_ host: String) {
        #expect(!DisplayWaker.isValidHost(host))
    }

    @Test func invalidHostFailsWithoutRunningSSH() {
        guard case .failure(let error) = DisplayWaker.wake(host: "-oProxyCommand=x") else {
            Issue.record("Expected failure"); return
        }
        #expect(error.message.contains("isn't a valid host name"))
    }

    @Test(arguments: [
        ("jeff@ada.local: Permission denied (publickey,password,keyboard-interactive).", "refused the login"),
        ("ssh: Could not resolve hostname nope.local: nodename nor servname provided, or not known", "Can't find"),
        ("ssh: connect to host ada.local port 22: Connection refused", "Remote Login is turned off"),
        ("ssh: connect to host ada.local port 22: Operation timed out", "didn't respond"),
        ("Host key verification failed.", "identity changed"),
        ("something unexpected\n", "something unexpected"),
    ])
    func explainsSSHErrors(stderr: String, expected: String) {
        #expect(DisplayWaker.explain(stderr: stderr, host: "Ada.local").message.contains(expected))
    }
}

struct MigrationTests {

    /// A store written by the original (v1) model must open with the current model,
    /// keeping existing devices and gaining the new optional `host` attribute.
    @Test func v1StoreMigratesToCurrentModel() throws {
        let momd = try #require(Bundle(for: Device.self).url(forResource: "Click2wakeup", withExtension: "momd"))
        let v1 = try #require(NSManagedObjectModel(contentsOf: momd.appending(path: "Click2wakeup.mom")))
        #expect(v1.entitiesByName["Device"]?.attributesByName["host"] == nil)

        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appending(path: "Click2wakeup.sqlite")

        // Write a v1 store.
        let v1Coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1)
        _ = try v1Coordinator.addPersistentStore(type: .sqlite, at: storeURL)
        let v1Context = NSManagedObjectContext(.mainQueue)
        v1Context.persistentStoreCoordinator = v1Coordinator
        let old = NSManagedObject(entity: v1.entitiesByName["Device"]!, insertInto: v1Context)
        old.setValue("Old PC", forKey: "name")
        old.setValue("00:11:22:33:44:55", forKey: "mac")
        try v1Context.save()
        for store in v1Coordinator.persistentStores { try v1Coordinator.remove(store) }

        // Open it with the current model, as the app does.
        let container = NSPersistentContainer(name: "Click2wakeup")
        container.persistentStoreDescriptions.first!.url = storeURL
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        #expect(loadError == nil)

        let devices = try container.viewContext.fetch(Device.sortedByName())
        #expect(devices.count == 1)
        #expect(devices.first?.name == "Old PC")
        #expect(devices.first?.mac == "00:11:22:33:44:55")
        #expect(devices.first?.host == nil)
        #expect(devices.first?.turnsOnDisplay == false)
    }
}
