//
//  TrainViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 15/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit

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

    func canTrainStressModel() -> Bool {
        let minNum = Constants.minSamplesPerClass
        let class0 = StressModel.main.notStressedCount
        let class1 = StressModel.main.stressedCount
        return (class0 >= minNum && class1 >= minNum)
    }

    func canTrainEnergyModel() -> Bool {
        // FIXME: How to determine when we have enough data for regression?
        let minNum = Constants.minSamplesPerClass
        let count = EnergyModel.main.samplesCount
        return count > minNum
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

        if !Constants.disableCooldown && EnergyModel.main.cooldown {
            presentGenericError("An energy sample was added recently. Please try again later.")
        } else if let snapshot = getSnapshotIfAllowed() {
            questionnaireManager = QuestionnaireManager()
            questionnaireManager?.present(on: self, with: snapshot) {
                [unowned self] completed in
                if completed {
                    self.updateStatusLabel()
                }
            }
        }
    }

    @IBAction func teachStress() {

        if !Constants.disableCooldown && StressModel.main.cooldown {
            presentGenericError("A stress sample was added recently. Please try again later.")
        } else if let snapshot = getSnapshotIfAllowed() {
            AddSampleViewController.present(on: self, stressLevel: nil, snapshot: snapshot) { [unowned self] completed in
                if completed {
                    self.updateStatusLabel()
                }
            }
        }
    }

    @IBAction func teachQuadrant() {

        if !Constants.disableCooldown && QuadrantModel.main.cooldown {
            presentGenericError("A quadrant sample was added recently. Please try again later.")
        } else if let snapshot = getSnapshotIfAllowed() {
            QuadrantViewController.present(on: self, snapshot: snapshot) { [unowned self] completed in
                if completed {
                    self.updateStatusLabel()
                }
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

    func trainStressModel(_ sender: Any? = nil) {

        guard canTrainStressModel() else {
            let minNum = Constants.minSamplesPerClass
            presentGenericError("Not enough data to train the model! You need at least \(minNum) samples for each class before you can proceed.")
            return
        }

        let alert = UIAlertController(
            title: "Training SVM...",
            message: "Please don't leave the app during the training.",
            preferredStyle: .alert
        )

        present(alert, animated: true, completion: nil)

        OperationQueue().addOperation {
            // Fake delay for show
            Thread.sleep(forTimeInterval: 2.0)
            NSLog("Actually training...")
            StressModel.main.train {
                NSLog("Done training.")
                OperationQueue.main.addOperation { [weak self] in
                    self?.updateStatusLabel()
                    alert.dismiss(animated: true, completion: nil)
                }
            }
        }
    }

    func trainEnergyModel(_ sender: Any? = nil) {

        guard canTrainEnergyModel() else {
            presentGenericError("Not enough data to train the model!")
            return
        }

        let alert = UIAlertController(
            title: "Training SVR...",
            message: "Please don't leave the app during the training.",
            preferredStyle: .alert
        )

        present(alert, animated: true, completion: nil)

        OperationQueue().addOperation {
            // Fake delay for show
            Thread.sleep(forTimeInterval: 2.0)
            NSLog("Actually training...")
            EnergyModel.main.train {
                NSLog("Done training.")
                OperationQueue.main.addOperation { [weak self] in
                    self?.updateStatusLabel()
                    alert.dismiss(animated: true, completion: nil)
                }
            }
        }
    }

    @IBAction func trainPressed() {

        let alert = UIAlertController(
            title: "Select model to train:",
            message: nil,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(
            title: "Energy model (SVR)",
            style: .default,
            handler: trainEnergyModel
        ))

        alert.addAction(UIAlertAction(
            title: "Stress model (SVM)",
            style: .default,
            handler: trainStressModel
        ))

        let qModelButton = UIAlertAction(
            title: "Quadrant model",
            style: .default,
            handler: nil
        )
        qModelButton.isEnabled = false
        alert.addAction(qModelButton)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
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
