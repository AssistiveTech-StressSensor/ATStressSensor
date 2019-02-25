//
//  DebugMenu.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 25/02/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import UIKit

struct DebugMenu {

    static func present(on controller: UIViewController, completion: (() -> Void)?) {

        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let actions = [
            UIAlertAction(
                title: "Add noise to signals (\(Constants.addNoiseToSignals))",
                style: .default,
                handler: { _ in Constants.addNoiseToSignals = !Constants.addNoiseToSignals; completion?() }
            ),
            UIAlertAction(
                title: "Use fake snapshots (\(Constants.useFakeSnapshots))",
                style: .default,
                handler: { _ in Constants.useFakeSnapshots = !Constants.useFakeSnapshots; completion?() }
            ),
            UIAlertAction(
                title: "Disable cooldown (\(Constants.disableCooldown))",
                style: .default,
                handler: { _ in Constants.disableCooldown = !Constants.disableCooldown; completion?() }
            ),
            UIAlertAction(
                title: "Cancel",
                style: .cancel,
                handler: { _ in completion?() }
            )
        ]
        actions.forEach { actionSheet.addAction($0) }
        controller.present(actionSheet, animated: true, completion: nil)
    }
}
