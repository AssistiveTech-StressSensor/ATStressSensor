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

        let (step, review) = generateConsentStep()
        let task = ORKOrderedTask(identifier: "visualConsent", steps: [step, review])
        let taskVC = ORKTaskViewController(task: task, taskRun: nil)

        taskVC.delegate = self
        self.parentController = parentVC
        self.taskController = taskVC

        parentVC.present(taskVC, animated: true, completion: nil)
    }

    private func generateConsentStep() -> (ORKVisualConsentStep, ORKConsentReviewStep) {

        let signature = ORKConsentSignature(forPersonWithTitle: nil, dateFormatString: nil, identifier: "consentSignature")
        signature.requiresName = true
        signature.requiresSignatureImage = true

        let document = ORKConsentDocument()
        document.addSignature(signature)
        document.signaturePageTitle = "Consent"

        let overview = ORKConsentSection(type: .overview)
        overview.title = "Welcome"
        overview.summary = "The summary about the section goes here ..."
        overview.content = "The content to show in learn more ..."

        let dataGathering = ORKConsentSection(type: .dataGathering)
        dataGathering.title = "Data Gathering"
        dataGathering.summary = "The summary about the section goes here ..."
        dataGathering.content = "The content to show in learn more ..."

        let dataUse = ORKConsentSection(type: .dataUse)
        dataUse.title = "Data Use"
        dataUse.summary = "The summary about the section goes here ..."
        dataUse.content = "The content to show in learn more ..."

        let timeCommitment = ORKConsentSection(type: .timeCommitment)
        timeCommitment.title = "Time Commitment"
        timeCommitment.summary = "The summary about the section goes here ..."
        timeCommitment.content = "The content to show in learn more ..."

        let review = ORKConsentReviewStep(identifier: "consentReview", signature: document.signatures?.first, in: document)
        review.text = "Lorem ipsum .."
        review.reasonForConsent = "Lorem ipsum ..."

        document.sections = [overview, dataGathering, dataUse, timeCommitment]

        let step = ORKVisualConsentStep(identifier: "visualConsent", document: document)
        return (step, review)
    }
}

extension ConsentManager: ORKTaskViewControllerDelegate {

    func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        taskViewController.dismiss(animated: true, completion: nil)
    }
}
