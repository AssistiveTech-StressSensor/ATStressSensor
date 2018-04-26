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

    private let cooldownDateKey = "cooldown.date"
    private var questionnaireManager: QuestionnaireManager?

    var cooldownDate: Date? {
        didSet { updateStatusLabel() }
    }

    var cooldown: Bool {
        if let cdd = cooldownDate {
            return cdd > Date()
        } else {
            return false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        readCooldownDate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateStatusLabel()
    }

    func updateStatusLabel() {
        if cooldown {
            statusLabel.text = "You'll be able to a new sample later"
        } else {
            statusLabel.text = "Ready"
        }
    }

    func readCooldownDate() {
        if Constants.disableCooldown { return }
        cooldownDate = UserDefaults().value(forKey: cooldownDateKey) as? Date
    }

    func clearCooldown() {
        UserDefaults().set(nil, forKey: cooldownDateKey)
        cooldownDate = nil
    }

    func triggerCooldown() {
        if Constants.disableCooldown { return }
        let cddate = Date().addingTimeInterval(Constants.cooldownLength)
        UserDefaults().set(cddate, forKey: cooldownDateKey)
        cooldownDate = cddate
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
        if cooldown { return nil }

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

        guard let snapshot = getSnapshotIfAllowed() else { return }

        questionnaireManager = QuestionnaireManager()
        questionnaireManager?.present(on: self, with: snapshot) {
            [unowned self] completed in
            if completed {
                self.triggerCooldown()
                self.updateStatusLabel()
            }
        }
    }

    @IBAction func teachStress() {

        guard let snapshot = getSnapshotIfAllowed() else { return }

        AddSampleViewController.present(
            on: self,
            with: nil,
            and: snapshot
        ) { [unowned self] completed in
            if completed {
                self.triggerCooldown()
                self.updateStatusLabel()
            }
        }
    }

    @IBAction func clearPressed() {

        func confirm(_ action: UIAlertAction) {
            StressModel.main.clear()
            EnergyModel.main.clear()
            clearCooldown()
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
                OperationQueue.main.addOperation {
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
                OperationQueue.main.addOperation {
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
            title: "Stress model (SVM)",
            style: .default,
            handler: trainStressModel
        ))

        alert.addAction(UIAlertAction(
            title: "Energy model (SVR)",
            style: .default,
            handler: trainEnergyModel
        ))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }

    @IBAction func exportPressed() {

        let energyModelPath = EnergyModel.main.svrPathIfAvailable()
        let energyDatasetPath = EnergyModel.main.dataPathIfAvailable()

        let stressModelPath = StressModel.main.svmPathIfAvailable()
        let stressDatasetPath = StressModel.main.dataPathIfAvailable()

        let allPaths = [energyModelPath, energyDatasetPath, stressModelPath, stressDatasetPath]
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
