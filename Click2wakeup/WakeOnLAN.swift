//
//  WakeOnLAN.swift
//  Click2wakeup
//
//  Created for Click2wakeup.
//

import Foundation
import Network
import Darwin

class WakeOnLAN {
    
    // Default broadcast port for Wake-on-LAN
    private static let wolPort: UInt16 = 9
    
    // Converts MAC address string to bytes
    static func macAddressToBytes(_ macAddress: String) -> [UInt8]? {
        // Remove all separators and spaces
        let cleanMac = macAddress.replacingOccurrences(of: "[-:. ]", with: "", options: .regularExpression)
        
        // Check if MAC address length is correct
        guard cleanMac.count == 12 else {
            // print("Invalid MAC address length: \(cleanMac.count) characters")
            return nil
        }
        
        // Use stride and map for more concise processing
        let byteStrings = stride(from: 0, to: cleanMac.count, by: 2).map {
            let start = cleanMac.index(cleanMac.startIndex, offsetBy: $0)
            let end = cleanMac.index(start, offsetBy: 2)
            return String(cleanMac[start..<end])
        }
        
        // Convert strings to bytes
        let bytes = byteStrings.compactMap { UInt8($0, radix: 16) }
        
        // Ensure we have enough bytes
        guard bytes.count == 6 else {
            // print("Invalid MAC address format - cannot parse some bytes")
            return nil
        }
        
        return bytes
    }
    
    // Wake a device using a MAC address
    static func wakeDevice(macAddress: String, completion: @escaping (Bool, String) -> Void) {
        // Debug output for troubleshooting
        // print("Attempting to wake device with MAC: \(macAddress)")
        
        // Check that we have a valid MAC address
        guard let macBytes = macAddressToBytes(macAddress) else {
            // print("Invalid MAC address format")
            completion(false, "Invalid MAC address format")
            return
        }
        
        // Create magic packet: 6 bytes of 0xFF followed by 16 repetitions of the MAC address
        let magicPacket = [UInt8](repeating: 0xFF, count: 6) + Array(repeating: macBytes, count: 16).flatMap { $0 }
        
        // print("Magic packet created with length: \(magicPacket.count) bytes")
        
        // Use dispatch group to wait for the sendWOLPacket operation to complete
        let group = DispatchGroup()
        group.enter()
        
        var didComplete = false
        // var errorMessage = ""
        
        // Send the packet using UDP
        // print("Sending Wake-on-LAN packet...")
        sendWOLPacket(packet: magicPacket) { success, error in
            didComplete = success
            // errorMessage = error
            group.leave()
        }
        
        // Wait for a maximum of 5 seconds for the packet to be sent
        let result = group.wait(timeout: .now() + 5.0)
        
        if result == .timedOut {
            // print("Sending Wake-on-LAN packet timed out")
            completion(false, "Sending Wake-on-LAN packet timed out")
            return
        }
        
        if !didComplete {
            // print("Failed to send Wake-on-LAN packet: \(errorMessage)")
            
            // Try the alternative socket implementation if Network framework fails
            // print("Trying alternative socket implementation...")
            let socketResult: (success: Bool, message: String) = wakeDeviceWithSocket(macAddress: macAddress)
            completion(socketResult.success, socketResult.message)
        } else {
            // print("Wake-on-LAN packet sent successfully")
            completion(true, "Wake-on-LAN packet sent successfully")
        }
    }
    
    // Simplified version that returns a boolean result
    static func wakeDevice(macAddress: String) -> Bool {
        // print("Starting synchronous wake attempt for MAC: \(macAddress)")
        
        var success = false
        
        // Use a semaphore to wait for the async operation to complete
        let semaphore = DispatchSemaphore(value: 0)
        
        wakeDevice(macAddress: macAddress) { result, message in
            success = result
            // print("Wake operation completed: \(result ? "SUCCESS" : "FAILED") - \(message)")
            semaphore.signal()
        }
        
        // Wait for a maximum of 6 seconds for completion
        let waitResult = semaphore.wait(timeout: .now() + 6.0)
        
        if waitResult == .timedOut {
            // print("WARNING: Wake operation timed out after 6 seconds")
            return false
        }
        
        // print("Synchronous wake attempt finished with result: \(success)")
        return success
    }
    
    // Send the WOL packet using Network framework
    private static func sendWOLPacket(packet: [UInt8], completion: @escaping (Bool, String) -> Void) {
        // Use broadcast address on port 9
        let host = NWEndpoint.Host("255.255.255.255")
        let port = NWEndpoint.Port(integerLiteral: UInt16(wolPort))
        
        // print("Network framework: Creating connection to \(host) on port \(port)...")
        
        // Set UDP parameters for broadcast
        let parameters = NWParameters.udp
        
        // Enable broadcasting
        if let options = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            options.version = .v4
            options.hopLimit = 3
            // print("Network framework: IP options set - version: v4, hop limit: 3")
        }
        
        // Setup UDP options to allow broadcasting
        parameters.allowLocalEndpointReuse = true
        parameters.prohibitExpensivePaths = false
        parameters.requiredInterfaceType = .wifi  // Usually WOL is sent over WiFi or Ethernet
        // print("Network framework: UDP parameters set for broadcasting")
        
        // Create the connection
        let connection = NWConnection(host: host, port: port, using: parameters)
        // print("Network framework: Connection created")
        
        // Set the state change handler
        connection.stateUpdateHandler = { (state) in
            switch state {
            case .ready:
                // print("Network framework: UDP connection is ready to send data")
                
                // Connection is ready, send the packet
                // print("Network framework: Sending \(packet.count) bytes...")
                connection.send(content: Data(packet), completion: .contentProcessed { error in
                    if let error = error {
                        // print("Network framework: Failed to send Wake-on-LAN packet: \(error)")
                        completion(false, "Failed to send packet: \(error.localizedDescription)")
                    } else {
                        // print("Network framework: Wake-on-LAN packet sent successfully")
                        completion(true, "")
                    }
                    
                    // Close the connection after sending
                    connection.cancel()
                })
                
            case .failed(let error):
                // print("Network framework: UDP connection failed: \(error)")
                completion(false, "Connection failed: \(error.localizedDescription)")
                connection.cancel()
                
            case .cancelled:
                // print("Network framework: UDP connection cancelled")
                break
                
            case .preparing:
                // print("Network framework: Connection preparing...")
                break
                
            case .setup:
                // print("Network framework: Connection setup...")
                break
                
            case .waiting(_):
                // print("Network framework: Connection waiting: \(error)")
                break
                
            @unknown default:
                // print("Network framework: Unknown connection state")
                break
            }
        }
        
        // Start the connection
        // print("Network framework: Starting connection...")
        connection.start(queue: .global())
    }
    
    // Alternative implementation using traditional socket API
    static func wakeDeviceWithSocket(macAddress: String) -> (success: Bool, message: String) {
        // print("Using socket API to send Wake-on-LAN packet")
        
        // Validate MAC address
        guard let macBytes = macAddressToBytes(macAddress) else {
            return (false, "Invalid MAC address format")
        }
        
        // Create magic packet
        let magicPacket = [UInt8](repeating: 0xFF, count: 6) + Array(repeating: macBytes, count: 16).flatMap { $0 }
        // print("Magic packet created with \(magicPacket.count) bytes: \(magicPacket.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Create socket
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        if sock < 0 {
            let error = String(cString: strerror(errno))
            // print("Failed to create socket: \(error)")
            return (false, "Failed to create socket: \(error)")
        }
        // print("Socket created successfully: \(sock)")
        
        // Enable broadcasting
        var broadcast: Int32 = 1
        let result = setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
        if result < 0 {
            let error = String(cString: strerror(errno))
            // print("Failed to set socket option: \(error)")
            close(sock)
            return (false, "Failed to set socket option: \(error)")
        }
        // print("Broadcasting enabled on socket")
        
        // Set destination address (broadcast)
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = wolPort.bigEndian // WOL uses port 9
        
        // Use broadcast address (255.255.255.255) - all bits set to 1 in network byte order
        addr.sin_addr.s_addr = UInt32(0xffffffff).bigEndian
        // print("Broadcast address set to 255.255.255.255, port \(wolPort)")
        
        // Convert to sockaddr
        let addrPtr = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        }
        
        // Send the packet
        // print("Sending WOL packet to \(macAddress)...")
        let bytesSent = sendto(sock, magicPacket, magicPacket.count, 0, addrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
        close(sock)
        
        if bytesSent < 0 {
            let error = String(cString: strerror(errno))
            // print("Failed to send packet: \(error)")
            return (false, "Failed to send packet: \(error)")
        }
        
        // print("Successfully sent \(bytesSent) bytes via socket")
        return (true, "Wake-on-LAN packet sent successfully using socket API")
    }
    
    // Simplified version that only returns success status
    static func wakeDeviceWithSocketSimple(macAddress: String) -> Bool {
        let result = wakeDeviceWithSocket(macAddress: macAddress)
        return result.success
    }
} 
