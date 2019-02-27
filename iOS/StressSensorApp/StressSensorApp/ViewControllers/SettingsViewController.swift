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
    @IBOutlet weak var loggerNicknameLabel: UILabel!
    @IBOutlet weak var loggerEntriesLabel: UILabel!
    @IBOutlet weak var connectDisconnectButton: UIButton!
    @IBOutlet weak var authenticatedLabel: UILabel!
    @IBOutlet weak var authenticateButton: UIButton!

    var isConnectedToDevice: Bool {
        return mainStore.state.device.linkStatus == .connected
    }

    var isAuthenticatedWithEmpatica: Bool {
        return mainStore.state.device.authenticated
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(changeLoggerNickname))
        loggerNicknameLabel.superview?.addGestureRecognizer(tapGR)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mainStore.subscribe(self)
        updateNickname()
        updateLoggedEntries()
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
    }

    func updateLoggedEntries() {
        ModelLogger.getCurrentLoggedEntries { [weak self] (stressCount, energyCount) in
            DispatchQueue.main.async {
                self?.loggerEntriesLabel.text = "\(stressCount)|\(energyCount)"
            }
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

    func updateNickname() {

        ModelLogger.getNickname { [weak self] nickname in

            DispatchQueue.main.async {
                if nickname == nil {
                    self?.loggerNicknameLabel.text = "Tap to add"
                } else {
                    self?.loggerNicknameLabel.text = nickname
                }
            }
        }
    }

    func performNicknameChange(_ newNickname: String) {

        let alert = UIAlertController(title: "Saving...", message: nil, preferredStyle: .alert)
        present(alert, animated: true, completion: nil)

        ModelLogger.modifyNickname(newNickname) { [weak self] result in
            Thread.sleep(forTimeInterval: 1.0)
            DispatchQueue.main.async {
                alert.dismiss(animated: true, completion: nil)
                self?.updateNickname()
            }
        }
    }

    @objc
    func changeLoggerNickname() {

        let alert = UIAlertController(
            title: "Modify nickname:",
            message: nil,
            preferredStyle: .alert
        )

        alert.addTextField { (textField) in
            textField.placeholder = "New nickname"
        }

        let confirmAction = UIAlertAction(title: "Change", style: .destructive) { [weak self] _ in
            let textField = alert.textFields![0] as UITextField
            if let newNickname = textField.text, !newNickname.isEmpty {
                self?.performNicknameChange(newNickname)
            }
        }

        alert.addAction(confirmAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
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
