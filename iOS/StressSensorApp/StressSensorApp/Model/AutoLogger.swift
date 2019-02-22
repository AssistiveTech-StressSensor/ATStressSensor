//
//  AutoLogger.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 22/02/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import Foundation

class AutoLogger {

    private init() {}

    private static var lastCheck: Date = .distantPast
    private static var nextCheck: Date = .distantFuture
    private(set) static var active: Bool = false

    private static let maxInterval: TimeInterval = 16.0 * 60.0
    private static let minInterval: TimeInterval = 4.0 * 60.0
    private static var curInterval: TimeInterval = -1.0

    static func activate() {
        active = true
        resetInterval()
    }

    static func deactivate() {
        active = false
    }

    private static func setInterval(_ interval: TimeInterval) {
        nextCheck = Date().addingTimeInterval(interval)
        curInterval = interval
    }

    private static func resetInterval() {
        setInterval(maxInterval)
    }

    static func fireIfNeeded() {

        if active, nextCheck < Date() {

            if let snapshot = try? SignalAcquisition.generateSnapshot(), snapshot.hasNoise == false {
                ModelLogger.logUnlabeled(snapshot: snapshot)
                resetInterval()
            } else {
                let interval = max(minInterval, curInterval * 0.5)
                setInterval(interval)
            }

            lastCheck = Date()
        }
    }
}
