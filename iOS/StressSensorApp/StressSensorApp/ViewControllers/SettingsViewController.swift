//
//  SettingsViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 09/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit
import ReSwift

class SettingsViewController: UITableViewController, StoreSubscriber {

    @IBOutlet weak var batteryLevelLabel: UILabel!
    @IBOutlet weak var userIdentifierLabel: UILabel!
    @IBOutlet weak var loggerLabel: UILabel!
    @IBOutlet weak var loggerNameLabel: UILabel!
    @IBOutlet weak var manageAccountButton: UIButton!
    @IBOutlet weak var connectDisconnectButton: UIButton!
    @IBOutlet weak var authenticatedLabel: UILabel!
    @IBOutlet weak var authenticateButton: UIButton!

    var isConnectedToDevice: Bool {
        return mainStore.state.device.linkStatus == .connected
    }

    var isAuthenticatedWithEmpatica: Bool {
        return mainStore.state.device.authenticated
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mainStore.subscribe(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mainStore.unsubscribe(self)
    }

    func newState(state: AppState) {

        if isConnectedToDevice {
            connectDisconnectButton.setTitle("Disconnect", for: .init(rawValue: 0))
        } else {
            connectDisconnectButton.setTitle("Find & Connect", for: .init(rawValue: 0))
        }

        authenticateButton.isEnabled = !isAuthenticatedWithEmpatica

        switch state.device.linkStatus {
        case .connecting:
            authenticateButton.isEnabled = false
            connectDisconnectButton.isEnabled = false
            connectDisconnectButton.setTitle("Connecting...", for: .init(rawValue: 0))
        case .connected, .disconnected:
            connectDisconnectButton.isEnabled = true
        case .disconnecting:
            authenticateButton.isEnabled = false
            connectDisconnectButton.isEnabled = false
            connectDisconnectButton.setTitle("Disconnecting...", for: .init(rawValue: 0))
        case .discovering:
            authenticateButton.isEnabled = false
            connectDisconnectButton.isEnabled = false
            connectDisconnectButton.setTitle("Discovering...", for: .init(rawValue: 0))
        }

        if let level = DeviceManager.main.batteryLevel {
            batteryLevelLabel.text = "\(Int(level*100))%"
        } else {
            batteryLevelLabel.text = "-"
        }

        userIdentifierLabel.text = state.user.userID ?? "-"
        loggerLabel.text = ModelLogger.canLog ? "YES" : "NO"
        authenticatedLabel.text = isAuthenticatedWithEmpatica ? "YES" : "NO"
        loggerNameLabel.text = state.user.userInfo?.fullName ?? "-"

        if state.user.userInfo == nil {
            manageAccountButton.setTitle("Login / Register", for: .init(rawValue: 0))
            manageAccountButton.tintColor = UIButton.appearance().tintColor
        } else {
            manageAccountButton.setTitle("Logout", for: .init(rawValue: 0))
            manageAccountButton.tintColor = .red
        }
    }

    func connectPressed(_ sender: Any) {

        if isAuthenticatedWithEmpatica {
            DeviceManager.main.scanAndConnect()
        } else {
            let alert = UIAlertController(
                title: "Warning",
                message: "This device could not authenticate with the Empatica servers, which may affect the behavior of the app.\n\nDo you wish to proceed anyway?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Connect anyway", style: .destructive, handler: { _ in
                DeviceManager.main.scanAndConnect()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }

    func disconnectPressed(_ sender: Any) {
        DeviceManager.main.disconnect()
    }

    @IBAction func manageAccountPressed(_ sender: Any) {
        AccountManager.shared.presentManageAccountAlert(on: self)
    }

    @IBAction func connectDisconnectPressed(_ sender: Any) {
        if isConnectedToDevice {
            disconnectPressed(sender)
        } else {
            connectPressed(sender)
        }
    }

    @IBAction func authenticatePressed(_ sender: Any) {

        if !isAuthenticatedWithEmpatica {

            let alert = UIAlertController(title: "Authenticating...", message: nil, preferredStyle: .alert)
            present(alert, animated: true, completion: nil)

            DeviceManager.main.setup() { _ in
                DispatchQueue.main.async {
                    alert.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
}
