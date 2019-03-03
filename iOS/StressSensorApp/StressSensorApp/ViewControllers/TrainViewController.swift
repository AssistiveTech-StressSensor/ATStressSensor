//
//  TrainViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 15/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit
import PromiseKit

class TrainViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!
    private var questionnaireManager: QuestionnaireManager?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateStatusLabel()
    }

    func updateStatusLabel() {

        let aheadEnergy = EnergyModel.main.numberOfSamplesAhead
        let aheadStress = StressModel.main.numberOfSamplesAhead
        let aheadQuadrant = QuadrantModel.main.numberOfSamplesAhead

        var text = "Energy Model: "
        text += (aheadEnergy == 0 ? "up to date" : "\(aheadEnergy) sample\(aheadEnergy > 1 ? "s" : "") behind")
        text += "\n"
        text += "Stress Model: "
        text += (aheadStress == 0 ? "up to date" : "\(aheadStress) sample\(aheadStress > 1 ? "s" : "") behind")
        text += "\n"
        text += "Quadrant Model: "
        text += (aheadQuadrant == 0 ? "up to date" : "\(aheadQuadrant) sample\(aheadQuadrant > 1 ? "s" : "") behind")

        statusLabel.text = text
    }

    func getSnapshotIfAllowed() -> SignalsSnapshot? {
        let snapshot: SignalsSnapshot
        do {
            snapshot = try SignalAcquisition.generateSnapshot()
        } catch SignalAcquisitionError.snapshotGenerationFailed(let details) {
            presentGenericError("Latest data from sensor is corrupted or insufficient. Please try again later.\n\nDetails:\n\(details)")
            return nil
        } catch {
            presentGenericError(error.localizedDescription)
            return nil
        }
        return snapshot
    }

    @IBAction func teachEnergy() {

        if !mainStore.state.debug.disableCooldown && EnergyModel.main.cooldown {
            presentGenericError("An energy sample was added recently. Please try again later.")
        } else if let snapshot = getSnapshotIfAllowed() {
            questionnaireManager = QuestionnaireManager()
            questionnaireManager?.present(on: self, with: snapshot) { [unowned self] completed in
                if completed { self.tryToTrain() }
            }
        }
    }

    @IBAction func teachStress() {

        if !mainStore.state.debug.disableCooldown && StressModel.main.cooldown {
            presentGenericError("A stress sample was added recently. Please try again later.")
        } else if let snapshot = getSnapshotIfAllowed() {
            AddSampleViewController.present(on: self, stressLevel: nil, snapshot: snapshot) { [unowned self] completed in
                if completed { self.tryToTrain() }
            }
        }
    }

    @IBAction func teachQuadrant() {

        if !mainStore.state.debug.disableCooldown && QuadrantModel.main.cooldown {
            presentGenericError("A quadrant sample was added recently. Please try again later.")
        } else if let snapshot = getSnapshotIfAllowed() {
            QuadrantViewController.present(on: self, snapshot: snapshot) { [unowned self] completed in
                if completed { self.tryToTrain() }
            }
        }
    }

    @IBAction func clearPressed() {

        func confirm(_ action: UIAlertAction) {
            StressModel.main.clear()
            EnergyModel.main.clear()
            QuadrantModel.main.clear()
            updateStatusLabel()
        }

        let alert = UIAlertController(
            title: "Are you sure?",
            message: "You're about to delete all collected data. New stress predictions will require training a new model.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: confirm))

        present(alert, animated: true, completion: nil)
    }

    func tryToTrain() {
        var guarantees = [Guarantee<Void>]()

        if StressModel.main.canBeTrained {
            guarantees.append(StressModel.main.train())
        }

        if EnergyModel.main.canBeTrained {
            guarantees.append(EnergyModel.main.train())
        }

        when(guarantees: guarantees).done { [weak self] in
            self?.updateStatusLabel()
        }
    }

    @IBAction func exportPressed() {

        let energyModelPath = EnergyModel.main.svrPathIfAvailable()
        let energyDatasetPath = EnergyModel.main.dataPathIfAvailable()
        let quadrantDatasetPath = QuadrantModel.main.dataPathIfAvailable()

        let stressModelPath = StressModel.main.svmPathIfAvailable()
        let stressDatasetPath = StressModel.main.dataPathIfAvailable()

        let allPaths = [energyModelPath, energyDatasetPath, stressModelPath, stressDatasetPath, quadrantDatasetPath]
        let availablePaths = allPaths.compactMap { $0 }

        if availablePaths.isEmpty {
            presentGenericError("No data to export!")
            return
        }

        func share(_ items: [String]) {
            let urls = items.map { URL(fileURLWithPath: $0) }
            let vc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            present(vc, animated: true, completion: nil)
        }

        let alert = UIAlertController(
            title: "What do you want to export?",
            message: nil,
            preferredStyle: .actionSheet
        )

        if energyModelPath != nil {
            alert.addAction(UIAlertAction(
                title: "Energy model (.yml)",
                style: .default,
                handler: {_ in share([energyModelPath!])}
            ))
        }

        if stressModelPath != nil {
            alert.addAction(UIAlertAction(
                title: "Stress model (.yml)",
                style: .default,
                handler: {_ in share([stressModelPath!])}
            ))
        }

        if energyDatasetPath != nil {
            alert.addAction(UIAlertAction(
                title: "Raw energy dataset (.json)",
                style: .default,
                handler: {_ in share([energyDatasetPath!])}
            ))
        }

        if stressDatasetPath != nil {
            alert.addAction(UIAlertAction(
                title: "Raw stress dataset (.json)",
                style: .default,
                handler: {_ in share([stressDatasetPath!])}
            ))
        }

        if quadrantDatasetPath != nil {
            alert.addAction(UIAlertAction(
                title: "Raw quadrant dataset (.json)",
                style: .default,
                handler: {_ in share([quadrantDatasetPath!])}
            ))
        }

        if availablePaths.count > 1 {
            alert.addAction(UIAlertAction(
                title: "All available data",
                style: .default,
                handler: {_ in share(availablePaths)}
            ))
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
