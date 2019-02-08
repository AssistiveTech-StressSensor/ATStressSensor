//
//  DeviceManager.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 08/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit
import UserNotifications

enum DeviceManagerStatus {
    case disconnected
    case connected
    case connecting
    case disconnecting
    case discovering
}

class DeviceManager: NSObject {

    static let main = DeviceManager()

    private override init() {}

    var statusChangeHandler: ((DeviceManagerStatus) -> Void)?

    var status: DeviceManagerStatus = .disconnected {
        didSet { statusChangeHandler?(status) }
    }
    private(set) var batteryLevel: Float?
    private(set) var isAuthenticatedWithEmpatica: Bool = false
    private var device: EmpaticaDeviceManager?

    func setup(_ completion: ((Bool) -> ())? = nil) {
        EmpaticaAPI.authenticate(withAPIKey: Constants.empaticaApiKey) { [weak self] success, details in
            print("EmpaticaAPI auth: \( success ? "success" : "failure" )")
            self?.isAuthenticatedWithEmpatica = success
            completion?(success)
        }
    }

    func prepareForBackground() {
        EmpaticaAPI.prepareForBackground()
    }

    func prepareForResume() {
        EmpaticaAPI.prepareForResume()
    }

    func scanAndConnect() {
        EmpaticaAPI.discoverDevices(with: self)
    }

    func disconnect() {
        device?.disconnect()
    }

    private func invalidateDeviceInfo() {
        batteryLevel = nil
    }
}

extension DeviceManager {

    private func notifyForDisconnection() {

        let content = UNMutableNotificationContent()
        content.body = "Sensor disconnected!"
        content.threadIdentifier = "device.disconnected"

        let req = UNNotificationRequest(
            identifier: "device.disconnected",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}

extension DeviceManager: EmpaticaDelegate {

    func didUpdate(_ status: BLEStatus) {
        switch status {
        case kBLEStatusNotAvailable:
            print("Bluetooth low energy not available.")
            self.status = .disconnected
        case kBLEStatusReady:
            print("Bluetooth low energy ready.")
        case kBLEStatusScanning:
            print("Bluetooth low energy scanning for devices...")
            self.status = .discovering
        default:
            return
        }
    }

    func didDiscoverDevices(_ array: [Any]!) {
        let devices = array.compactMap { $0 as? EmpaticaDeviceManager }

        if devices.isEmpty {
            print("No devices found in range.")
            self.status = .disconnected
        } else {
            // Connect to first device found that is authorized w/ current API key
            device = devices.first { $0.allowed }
            device?.connect(with: self)
        }
    }
}

extension DeviceManager: EmpaticaDeviceDelegate {

    func didUpdate(_ status: DeviceStatus, forDevice device: EmpaticaDeviceManager!) {
        switch status {
        case kDeviceStatusDisconnected:
            print("Device disconnected.")
            self.status = .disconnected
            self.notifyForDisconnection()
        case kDeviceStatusConnecting:
            print("Device connecting...")
            self.status = .connecting
        case kDeviceStatusConnected:
            print("Device connected.")
            self.status = .connected
        case kDeviceStatusDisconnecting:
            print("Device disconnecting...")
            self.status = .disconnecting
        default:
            return
        }
        invalidateDeviceInfo()
    }

    func didReceiveTag(atTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        DispatchQueue.main.async {
            Coach.tagPressed()
        }
    }

    func didReceiveBatteryLevel(_ level: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        DispatchQueue.main.sync { [weak self] in
            self?.batteryLevel = level
            self?.statusChangeHandler?(status)
        }
    }

    func didReceiveGSR(_ gsr: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        DispatchQueue.main.async {
            SignalAcquisition.addSample(value: Double(gsr), timestamp: timestamp, signal: .gsr)
        }
    }

    func didReceiveBVP(_ bvp: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        DispatchQueue.main.async {
            SignalAcquisition.addSample(value: Double(bvp), timestamp: timestamp, signal: .bvp)
        }
    }

    func didReceiveIBI(_ ibi: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        DispatchQueue.main.async {
            SignalAcquisition.addSample(value: Double(ibi), timestamp: timestamp, signal: .ibi)
            SignalAcquisition.addSample(value: 60.0/Double(ibi), timestamp: timestamp, signal: .heartRate)
            Coach.fireIfNeeded()
        }
    }

    func didReceiveTemperature(_ temp: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        DispatchQueue.main.async {
            SignalAcquisition.addSample(value: Double(temp), timestamp: timestamp, signal: .temperature)
        }
    }

    /*
    func didReceiveAccelerationX(_ x: Int8, y: Int8, z: Int8, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        DispatchQueue.main.async {
            SignalAcquisition.addSample(value: Double(x), timestamp: timestamp, signal: .accelerationX)
            SignalAcquisition.addSample(value: Double(y), timestamp: timestamp, signal: .accelerationY)
            SignalAcquisition.addSample(value: Double(z), timestamp: timestamp, signal: .accelerationZ)
        }
    }
    */
}
