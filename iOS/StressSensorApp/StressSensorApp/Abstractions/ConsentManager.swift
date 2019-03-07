//
//  ConsentManager.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 03/03/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import UIKit
import ResearchKit

class ConsentManager: NSObject {

    fileprivate var task: ORKOrderedTask!
    fileprivate weak var parentController: UIViewController?
    fileprivate weak var taskController: ORKTaskViewController?

    func present(on parentVC: UIViewController) {

        let (step, review) = ConsentManager.generateConsentStep()
        let task = ORKOrderedTask(identifier: "visualConsent", steps: [step, review])
        let taskVC = ORKTaskViewController(task: task, taskRun: nil)

        taskVC.delegate = self
        self.parentController = parentVC
        self.taskController = taskVC

        parentVC.present(taskVC, animated: true, completion: nil)
    }

    static func generateConsentStep(consentStepID: String = "visualConsentStep",
                                    reviewStepID: String = "consentReviewStep") -> (ORKVisualConsentStep, ORKConsentReviewStep) {

        let overview = ORKConsentSection(type: .overview)
        overview.title = "Welcome"

        overview.summary = """
        Thank you for partecipating in this study!

        We are currently collecting data from people who suffered a traumatic brain injury, in order to develop a product that may help improve their daily lives.

        The following sections will describe what types of data we collect, and what you're asked from us when agreeing to participate.
        """

        overview.content = """
        When dealing with daily tasks, individuals that have suffered from traumatic brain injury (TBI) can experience sudden and important mental and physical fatigue, which has been shown to be connected to a prolonged recovery time. For this reason, in order to speed up the recovery of the patient, it is important to keep their stress and energy levels under control, where for energy level it is meant the quantity of physical and mental strength a person has. In this study, we explore the possibility of employing this iPhone application coupled with a wrist sensor, in order to monitor signals such as heart rate and Galvanic Skin Response, and infer energy and stress levels from the acquired data. The inference is done by means of Statistical Learning techniques, in particular, we use a Support Vector Machine model tailored to each user. Early results show that the method can work with high accuracy for some individuals, while underperform for other patients. By collecting more data through this app, our goal is to improve our models and finally produce a product that may help people with TBI.
        """

        let dataGathering = ORKConsentSection(type: .dataGathering)
        dataGathering.title = "Data Gathering"
        dataGathering.summary = "During the study, the wrist sensor will collect data such as your heart rate, storing the information both locally and in a secure remote database."
        dataGathering.content = """
        During the study, the Empatica E4 wrist sensor will collect data including (1) Heart Rate, (2) Temperature, (3) Blood Volume Pulse, (4) Galvanic Skin Response.

        The data is collected both when the user explicitly initiates the training process, and at regular intervals when the application runs in background.

        All collected data may be stored both locally on the user's device, and remotely, to a secure database.
        """

        let dataUse = ORKConsentSection(type: .dataUse)
        dataUse.title = "Data Use"
        dataUse.summary = "The data we collect will be used for the sole purpose of this study: researching and developing a product that can make a difference for people with TBI."
        dataUse.content = """
        The data we collect will be used for the sole purpose of this study: researching and developing a product that can make a difference for people with TBI.

        In particular, the data stored in your device will be used to build custom statistical models tailored to you. Instead, the data sent to our remote database will be used together with information collected from other participants, in order to build unified models that may work for all users.
        """

        let studyTasks = ORKConsentSection(type: .studyTasks)
        studyTasks.title = "Study Tasks"
        studyTasks.summary = "For the duration of this study, you're asked to wear the wrist sensor, collect data via the app, and occasionally answer questions related to how you feel."
        studyTasks.content = "For the duration of this study, you're asked to wear the wrist sensor, collect data via the app, and occasionally answer questions related to how you feel."

        let timeCommitment = ORKConsentSection(type: .timeCommitment)
        timeCommitment.title = "Time Commitment"
        timeCommitment.summary = "Some of the tasks you will be asked to do may be time-consuming. If - at any point - you think that you don't have time to dedicate to this study, contact the Assistive Technology team as early as possible."
        timeCommitment.content = "Some of the tasks you will be asked to do may be time-consuming. If - at any point - you think that you don't have time to dedicate to this study, contact the Assistive Technology team as early as possible."

        let withdrawing = ORKConsentSection(type: .withdrawing)
        withdrawing.title = "Withdrawing"
        withdrawing.summary = "You may withdraw from this study at all times, although the data collected from you may still be used for the purposes described earlier."
        withdrawing.content = "You may withdraw from this study at all times, although the data collected from you may still be used for the purposes described earlier."

        let document = ORKConsentDocument()
        document.sections = [overview, dataGathering, dataUse, studyTasks, timeCommitment, withdrawing]

        let review = ORKConsentReviewStep(identifier: reviewStepID, signature: nil, in: document)
        review.requiresScrollToBottom = true
        review.reasonForConsent = "By proceeding, you confirm that you have read the document below and that you agree with all its terms."

        let step = ORKVisualConsentStep(identifier: consentStepID, document: document)
        return (step, review)
    }
}

extension ConsentManager: ORKTaskViewControllerDelegate {

    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        taskViewController.dismiss(animated: true, completion: nil)
    }
}
