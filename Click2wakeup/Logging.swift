//
//  Logging.swift
//  Click2wakeup
//

import Foundation
import os

/// Unified logging. View in Console.app by filtering on subsystem "Click2wakeup".
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Click2wakeup"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let wake = Logger(subsystem: subsystem, category: "wake")
}
