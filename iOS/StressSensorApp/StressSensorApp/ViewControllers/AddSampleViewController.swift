//
//  AddSampleViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 05/03/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit

class AddSampleViewController: UITableViewController {

    private static let identifier = "AddSampleViewControllerID"
    static let navIdentifier = "AddSampleViewControllerNavID"

    @IBOutlet weak var notStressedButton: UIButton!
    @IBOutlet weak var stressedButton: UIButton!
    @IBOutlet weak var sleepQualityControl: UISegmentedControl!
    @IBOutlet weak var foodIntakeControl: UISegmentedControl!
    @IBOutlet weak var additionalNotesView: UITextView!
    @IBOutlet weak var addButton: UIButton!

    private var stressLevel: StressLevel?
    private var snapshot: SignalsSnapshot!
    private var addSampleCompletion: ((Bool) -> ())?

    static func fromStoryboard() -> AddSampleViewController {
        let navID = UIStoryboard.main.instantiateViewController(withIdentifier: navIdentifier) as! UINavigationController
        return navID.topViewController as! AddSampleViewController
    }

    static func present(on parentVC: UIViewController, stressLevel: StressLevel?, snapshot: SignalsSnapshot, completion: ((Bool) -> ())? = nil) {
        let vc = fromStoryboard()
        vc.setup(stressLevel: stressLevel, snapshot: snapshot, completion: completion)
        parentVC.present(vc.navigationController!, animated: true, completion: nil)
    }

    func setup(stressLevel: StressLevel?, snapshot: SignalsSnapshot, completion: ((Bool) -> ())? = nil) {
        self.stressLevel = stressLevel
        self.snapshot = snapshot
        self.addSampleCompletion = completion
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        notStressedButton.layer.borderColor = notStressedButton.tintColor.cgColor
        stressedButton.layer.borderColor = stressedButton.tintColor.cgColor
        setNeedsStressLevelUpdate()
        setNeedsFormValidationUpdate()
    }

    private func isFormFilled() -> Bool {
        return (
            stressLevel != nil &&
            sleepQualityControl.selectedSegmentIndex >= 0 &&
            foodIntakeControl.selectedSegmentIndex >= 0
        )
    }

    private func setNeedsStressLevelUpdate() {
        notStressedButton.layer.borderWidth = (stressLevel == .notStressed ? 5.0 : 0.0)
        stressedButton.layer.borderWidth = (stressLevel == .stressed ? 5.0 : 0.0)
    }

    private func setNeedsFormValidationUpdate() {
        addButton.isEnabled = isFormFilled()
    }

    @IBAction func stressedPressed() {
        stressLevel = .stressed
        setNeedsStressLevelUpdate()
        setNeedsFormValidationUpdate()
    }

    @IBAction func notStressedPressed() {
        stressLevel = .notStressed
        setNeedsStressLevelUpdate()
        setNeedsFormValidationUpdate()
    }

    @IBAction func addPressed() {
        tableView.endEditing(true)
        guard isFormFilled(), let stressLevel = stressLevel else { return }

        let sleepQuality = SleepQuality(sleepQualityControl.selectedSegmentIndex)
        let foodIntake = FoodIntake(foodIntakeControl.selectedSegmentIndex)
        let additionalNotes = additionalNotesView.text

        // Add sample to model
        let sample = StressModel.main.addSample(snapshot: snapshot, for: stressLevel)

        // Log data to remote server
        ModelLogger.logStress(
            snapshot: snapshot,
            sample: sample,
            stressLevel: stressLevel,
            sleepQuality: sleepQuality,
            foodIntake: foodIntake,
            additionalNotes: additionalNotes
        )

        let alert = UIAlertController(
            title: "Awesome!",
            message: nil,
            preferredStyle: .alert
        )

        present(alert, animated: true, completion: nil)

        OperationQueue().addOperation { [unowned self] in
            Thread.sleep(forTimeInterval: 1.0)
            OperationQueue.main.addOperation {
                alert.dismiss(animated: true, completion: nil)
                self.addSampleCompletion?(true)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }

    @IBAction func cancelPressed() {
        tableView.endEditing(true)
        addSampleCompletion?(false)
        dismiss(animated: true, completion: nil)
    }

    @IBAction func formValueChanged() {
        setNeedsFormValidationUpdate()
    }
}
