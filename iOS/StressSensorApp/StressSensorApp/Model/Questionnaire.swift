//
//  Questionnaire.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 17/04/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation
import ResearchKit

typealias QuestionnaireScore = Double

struct Questionnaire: Codable {

    static let main: Questionnaire = {
        // TODO: Read from json file
        return Questionnaire()
    }()
}

extension Questionnaire {

    func evaluate(_ result: ORKResult) -> QuestionnaireScore {

        // TODO: Return actual score
        return 0.0
    }

    func generateTask() -> ORKOrderedTask {

        let myStep = ORKInstructionStep(identifier: "intro")
        myStep.title = "Welcome to ResearchKit"

        let q1 = ORKFormStep(identifier: "q1")
        q1.formItems = [
            ORKFormItem(
                identifier: "i1",
                text: "First question?",
                answerFormat: ORKTextChoiceAnswerFormat(
                    style: .singleChoice,
                    textChoices: [
                        ORKTextChoice(text: "text1", detailText: "detail1", value: 1 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text2", detailText: "detail2", value: 2 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text3", detailText: "detail3", value: 3 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text4", detailText: "detail4", value: 4 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text5", detailText: "detail5", value: 5 as NSNumber, exclusive: true)
                    ]
                ),
                optional: false
            ),
            ORKFormItem(
                identifier: "i2",
                text: "Second question? Additional text, additional text, additional text, additional text, additional text, additional text, additional text, additional text, additional text, additional text, additional text, additional text",
                answerFormat: ORKTextChoiceAnswerFormat(
                    style: .singleChoice,
                    textChoices: [
                        ORKTextChoice(text: "text1", detailText: "detail1", value: 1 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text2", detailText: "detail2", value: 2 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text3", detailText: "detail3", value: 3 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text4", detailText: "detail4", value: 4 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text5", detailText: "detail5", value: 5 as NSNumber, exclusive: true)
                    ]
                ),
                optional: false
            )
        ]
        q1.isOptional = false


        let q2 = ORKFormStep(identifier: "q2")
        q2.formItems = [
            ORKFormItem(
                identifier: "i3",
                text: "Third question?",
                answerFormat: ORKTextChoiceAnswerFormat(
                    style: .singleChoice,
                    textChoices: [
                        ORKTextChoice(text: "text1", detailText: "detail1", value: 1 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text2", detailText: "detail2", value: 2 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text3", detailText: "detail3", value: 3 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text4", detailText: "detail4", value: 4 as NSNumber, exclusive: true),
                        ORKTextChoice(text: "text5", detailText: "detail5", value: 5 as NSNumber, exclusive: true)
                    ]
                ),
                optional: false
            )
        ]
        q2.isOptional = false

        let task = ORKOrderedTask(identifier: "task", steps: [myStep, q1, q2])

        return task
    }
}
