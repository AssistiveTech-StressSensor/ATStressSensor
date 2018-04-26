//
//  SettingsViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 09/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {

    @IBOutlet weak var batteryLevelLabel: UILabel!
    @IBOutlet weak var userIdentifierLabel: UILabel!
    @IBOutlet weak var loggerLabel: UILabel!
    @IBOutlet weak var loggerEntriesLabel: UILabel!
    @IBOutlet weak var connectDisconnectButton: UIButton!
    @IBOutlet weak var authenticatedLabel: UILabel!
    @IBOutlet weak var authenticateButton: UIButton!

    var isConnectedToDevice: Bool {
        return DeviceManager.main.status == .connected
    }

    var isAuthenticatedWithEmpatica: Bool {
        return DeviceManager.main.isAuthenticatedWithEmpatica
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DeviceManager.main.statusChangeHandler = self.updateViews
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateViews()
    }

    func updateLoggedEntries() {
        ModelLogger.getCurrentLoggedEntries { [weak self] count in
            DispatchQueue.main.async {
                self?.loggerEntriesLabel.text = "\(count)"
            }
        }
    }

    func updateViews(_ status: DeviceManagerStatus) {

        if isConnectedToDevice {
            connectDisconnectButton.setTitle("Disconnect", for: .init(rawValue: 0))
        } else {
            connectDisconnectButton.setTitle("Find & Connect", for: .init(rawValue: 0))
        }

        authenticateButton.isEnabled = !isAuthenticatedWithEmpatica

        switch status {
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

        updateBatteryLevel()
        userIdentifierLabel.text = ModelLogger.userID ?? "-"
        loggerLabel.text = ModelLogger.canLog ? "YES" : "NO"
        authenticatedLabel.text = isAuthenticatedWithEmpatica ? "YES" : "NO"
        updateLoggedEntries()
    }

    func updateViews() {
        let status = DeviceManager.main.status
        updateViews(status)
    }

    func updateBatteryLevel() {
        if let level = DeviceManager.main.batteryLevel {
            batteryLevelLabel.text = "\(Int(level*100))%"
        } else {
            batteryLevelLabel.text = "-"
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

    @IBAction func connectDisconnectPressed(_ sender: Any) {
        if isConnectedToDevice {
            disconnectPressed(sender)
        } else {
            connectPressed(sender)
        }
    }

    @IBAction func authenticatePressed(_ sender: Any) {

        if isAuthenticatedWithEmpatica {
            updateViews()
        } else {

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
