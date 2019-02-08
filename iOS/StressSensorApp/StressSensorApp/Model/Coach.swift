//
//  Coach.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 05/06/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation
import UserNotifications

class Coach {

    private init() {}

    private static var lastCheck: Date = .distantPast
    private static var nextCheck: Date = .distantFuture
    private(set) static var active: Bool = false

    private static let notificationID: String = "device.snapshot.ready"
    private static let maxInterval: TimeInterval = 64.0 * 60.0
    private static let minInterval: TimeInterval = 8.0 * 60.0
    private static var curInterval: TimeInterval = -1.0

    static func activate() {
        print("Coach.activate()")
        active = true
        resetInterval()
    }

    static func deactivate() {
        print("Coach.deactivate()")
        active = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    private static func setInterval(_ interval: TimeInterval) {
        nextCheck = Date().addingTimeInterval(interval)
        curInterval = interval
    }

    private static func resetInterval() {
        setInterval(maxInterval)
    }

    private static func notify(with snapshot: SignalsSnapshot, userRequested: Bool = false) {
        print("Coach.notify()")
        
        let content = UNMutableNotificationContent()
        content.threadIdentifier = notificationID
        content.userInfo = ["snapshot": snapshot.asJSON()!]

        if userRequested {
            content.body = "Sample ready to be added!"
        } else {
            content.body = "Is this a good moment to add a sample?"
        }

        let req = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    static func tagPressed() {
        if let snapshot = try? SignalAcquisition.generateSnapshot() {
            Coach.notify(with: snapshot, userRequested: true)
        }
    }

    static func fireIfNeeded() {

        if active, nextCheck < Date() {

            if let snapshot = try? SignalAcquisition.generateSnapshot() {
                Coach.notify(with: snapshot)
                resetInterval()
            } else {
                let interval = max(minInterval, curInterval * 0.5)
                setInterval(interval)
            }

            lastCheck = Date()
        }
    }
}
