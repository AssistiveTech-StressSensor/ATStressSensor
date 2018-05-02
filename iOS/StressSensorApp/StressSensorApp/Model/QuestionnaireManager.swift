//
//  QuestionnaireManager.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 23/04/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit
import ResearchKit

class QuestionnaireManager: NSObject {

    fileprivate var task: ORKOrderedTask!
    fileprivate var snapshot: SignalsSnapshot!
    fileprivate var questionnaire: Questionnaire!
    fileprivate var questionnaireCompletion: ((Bool) -> ())!
    fileprivate weak var parentController: UIViewController?
    fileprivate weak var taskController: ORKTaskViewController?

    func present(on parentVC: UIViewController, with snapshot: SignalsSnapshot, completion: @escaping ((Bool) -> ())) {

        self.questionnaire = Questionnaire.main

        let task = questionnaire.generateTask()
        let taskVC = ORKTaskViewController(task: task, taskRun: nil)
        taskVC.delegate = self

        self.task = task
        self.snapshot = snapshot
        self.questionnaireCompletion = completion
        self.parentController = parentVC
        self.taskController = taskVC

        parentVC.present(taskVC, animated: true, completion: nil)
    }

    private func finalize(with results: Questionnaire.Results?) {

        if let results = results {

            let energyLevel = EnergyLevel(results.score)
            let sample = EnergyModel.main.addSample(snapshot: snapshot, for: energyLevel)

            ModelLogger.logEnergy(
                snapshot: snapshot,
                sample: sample,
                energyLevel: energyLevel,
                details: results
            )

            let alert = UIAlertController(
                title: "Awesome!",
                message: "(energy level: \(energyLevel))",
                preferredStyle: .alert
            )

            taskController?.present(alert, animated: true, completion: nil)

            OperationQueue().addOperation { [unowned self] in
                Thread.sleep(forTimeInterval: 1.0)
                OperationQueue.main.addOperation {
                    alert.dismiss(animated: true, completion: nil)
                    self.questionnaireCompletion(true)
                    self.taskController?.dismiss(animated: true, completion: nil)
                }
            }

        } else {
            questionnaireCompletion(false)
            taskController?.dismiss(animated: true, completion: nil)
        }
    }
}

extension QuestionnaireManager: ORKTaskViewControllerDelegate {

    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {

        var results: Questionnaire.Results?

        if reason == .completed {
            let orkResult = taskViewController.result
            results = questionnaire.evaluate(orkResult)
        }

        finalize(with: results)
    }
}
