//
//  FeedbackViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 02/03/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import UIKit
import Eureka

class FeedbackViewController: FormViewController, StoryboardInstantiable {

    static let instantiableID = "FeedbackViewControllerID"
    private var sendButton: UIBarButtonItem!
    private var prediction: Prediction!
    private var completionHandler: ((Bool, Prediction.Feedback?) -> ())!

    var feedback: Prediction.Feedback? {
        let values = form.values()
        if let correctness = values["correctness"] as? Float {
            let notes = values["notes"] as? String
            return Prediction.Feedback(date: Date(), correctness: correctness, notes: notes)
        } else {
            return nil
        }
    }

    func configure(with prediction: Prediction, handler: @escaping ((Bool, Prediction.Feedback?) -> ())) {
        self.prediction = prediction
        completionHandler = handler
    }

    func validateAll() {
        sendButton.isEnabled = form.validate().isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Feedback"

        sendButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(sendFeedback(_:)))
        sendButton.isEnabled = false
        navigationItem.rightBarButtonItem = sendButton

        if navigationController?.viewControllers.first == self {
            let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelFeedback(_:)))
            navigationItem.leftBarButtonItem = cancelButton
        }

        form +++ Section("Prediction")
            <<< MonitorCellRow(prediction)

            +++ Section(header: "Evaluation", footer: "Please evaluate the correctness of the prediction by moving the slider above, where 0% correctness indicates a wrong prediction, while 100% indicates a perfect prediction.\n\nYou may also add some optional notes related to this prediction.")
            <<< SliderRow("correctness") { row in
                row.add(rule: RuleRequired())
                row.validationOptions = .validatesOnChange
                row.shouldHideValue = false
                row.cell.slider.minimumValue = 0.0
                row.cell.slider.maximumValue = 100.0
                row.steps = 100
                row.displayValueFor = { $0 != nil ? "\(Int(round($0!)))%" : "0%" }
                row.title = "Correctness"
                row.value = prediction.feedback?.correctness
                row.cell.detailTextLabel?.widthAnchor.constraint(equalToConstant: 40.0).isActive = true
            }
            .cellUpdate { cell, row in
                if !row.isValid {
                    cell.titleLabel?.textColor = .red
                }
            }
            <<< TextAreaRow("notes") { row in
                row.textAreaHeight = .dynamic(initialTextViewHeight: 64)
                row.placeholder = "Notes"
                row.value = prediction.feedback?.notes
            }

        validateAll()
    }

    override func valueHasBeenChanged(for: BaseRow, oldValue: Any?, newValue: Any?) {
        super.valueHasBeenChanged(for: `for`, oldValue: oldValue, newValue: newValue)
         validateAll()
    }

    @objc
    func sendFeedback(_ sender: Any? = nil) {
        completionHandler(true, feedback)
    }

    @objc
    func cancelFeedback(_ sender: Any? = nil) {
        completionHandler(false, nil)
    }
}
