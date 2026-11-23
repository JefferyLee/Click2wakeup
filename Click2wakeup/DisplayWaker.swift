//
//  DisplayWaker.swift
//  Click2wakeup
//
//  Turns on the display of a Mac that is awake but has its screen off,
//  by running `caffeinate -u` on it over SSH. (`-u` declares user activity,
//  exactly as if someone had touched the mouse.)
//
//  Requirements on the target Mac: Remote Login enabled.
//  Requirements on this Mac: key-based SSH login to it (no password prompt).
//

import Foundation
import os

enum DisplayWaker {

    struct WakeError: Error, LocalizedError, Equatable {
        let message: String
        var errorDescription: String? { message }
    }

    private static let sshPath = "/usr/bin/ssh"
    private static let connectTimeout = 5
    private static let overallTimeout: Duration = .seconds(12)

    /// How long the screen is held on, giving time to move the mouse over.
    /// Once there's real input, the target Mac's normal display-sleep timer takes over.
    static let keepOnSeconds = 60

    /// Runs in the background on the target so ssh returns immediately.
    /// `caffeinate -u` declares user activity (turns the display on) and holds it for `-t` seconds.
    static var remoteCommand: String {
        "nohup caffeinate -u -t \(keepOnSeconds) >/dev/null 2>&1 &"
    }

    /// Blocks for up to ~12s. Call off the main thread.
    static func wake(host: String) -> Result<Void, WakeError> {
        let host = host.trimmingCharacters(in: .whitespaces)
        guard isValidHost(host) else {
            return .failure(WakeError(message: "\"\(host)\" isn't a valid host name."))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: sshPath)
        process.arguments = [
            "-n",                                    // don't read stdin
            "-o", "BatchMode=yes",                   // never prompt for a password
            "-o", "ConnectTimeout=\(connectTimeout)",
            "-o", "StrictHostKeyChecking=accept-new",
            "--", host,
            remoteCommand,
        ]
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return .failure(WakeError(message: "Couldn't start ssh: \(error.localizedDescription)"))
        }

        // Kill ssh if it hangs (e.g. network stalls after connecting).
        let watchdog = Task.detached {
            try? await Task.sleep(for: overallTimeout)
            if process.isRunning { process.terminate() }
        }
        let errorOutput = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        watchdog.cancel()

        if process.terminationStatus == 0 {
            Logger.wake.info("Woke display on \(host, privacy: .public)")
            return .success(())
        }
        if process.terminationReason == .uncaughtSignal {
            return .failure(WakeError(message: "\(host) didn't respond in time."))
        }
        Logger.wake.error("ssh \(host, privacy: .public) exited \(process.terminationStatus): \(errorOutput, privacy: .public)")
        return .failure(explain(stderr: errorOutput, host: host))
    }

    /// Host alias, name, or IP, optionally `user@host`. Rejects anything ssh could read as an option.
    static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, !host.hasPrefix("-") else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_@:[]%"))
        return host.unicodeScalars.allSatisfy(allowed.contains)
    }

    /// Turns ssh's stderr into a message a person can act on.
    static func explain(stderr: String, host: String) -> WakeError {
        let text = stderr.lowercased()
        let message: String
        if text.contains("permission denied") {
            message = "\(host) refused the login. Set up key-based SSH login from this Mac (see README)."
        } else if text.contains("could not resolve hostname") {
            message = "Can't find \(host) on the network."
        } else if text.contains("connection refused") {
            message = "Remote Login is turned off on \(host). Turn it on in System Settings → General → Sharing."
        } else if text.contains("timed out") || text.contains("no route to host") || text.contains("host is down") {
            message = "\(host) didn't respond. Is it on and connected to the same network?"
        } else if text.contains("host key verification failed") || text.contains("remote host identification has changed") {
            message = "\(host)'s identity changed since the last connection. Check ~/.ssh/known_hosts."
        } else if let line = stderr.split(separator: "\n").last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            message = String(line)
        } else {
            message = "Couldn't wake the display on \(host)."
        }
        return WakeError(message: message)
    }
}
