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

    let test_type: TestType
    let categories: [Category]

    enum TestType: String, Codable {
        case custom = "custom"
    }

    struct Category: Codable {
        let name: String
        let questions: [Question]
    }

    struct Question: Codable {

        let text: String
        let options: [Option]

        struct Option: Codable {
            let text: String?
            let value: Float
        }
    }

    var allQuestions: [String: Question] {
        var dict = [String: Question]()
        for i in 0..<categories.count {
            let questions = categories[i].questions
            for j in 0..<questions.count {
                let id = "\(i).\(j)"
                dict[id] = questions[j]
            }
        }
        return dict
    }
}

extension Questionnaire.Question.Option {

    var asTextChoice: ORKTextChoice {
        return ORKTextChoice(
            text: "[\(Int(round(value)))]  \(text ?? "")",
            detailText: nil,
            value: value as NSNumber,
            exclusive: true
        )
    }
}

extension Questionnaire.Question {

    func asFormStep(id: String) -> ORKFormStep {
        let step = ORKFormStep(identifier: id)
        step.isOptional = false
        step.formItems = [
            ORKFormItem(
                identifier: "\(id).0",
                text: text,
                answerFormat: ORKTextChoiceAnswerFormat(
                    style: .singleChoice,
                    textChoices: options.map { $0.asTextChoice }
                ),
                optional: false
            )
        ]
        return step
    }
}

extension Questionnaire {

    static func fromFile(_ filepath: String) -> Questionnaire? {

        let url = URL(fileURLWithPath: filepath)
        guard FileManager().fileExists(atPath: filepath),
            let data = try? Data(contentsOf: url)
            else { return nil }

        let decoded: Questionnaire?

        do {
            decoded = try JSONDecoder().decode(Questionnaire.self, from: data)
        } catch {
            print(error)
            decoded = nil
        }

        return decoded
    }

    static let main: Questionnaire = {
        let path = Bundle.main.path(forResource: "custom_test", ofType: "json")!
        return Questionnaire.fromFile(path)!
    }()

    func evaluateForCustomTest(_ result: ORKResult) -> QuestionnaireScore {

        var total = 0.0
        let stepResults = (result as! ORKTaskResult).results as! [ORKStepResult]
        for step in stepResults {
            let questionResult = step.firstResult as? ORKChoiceQuestionResult
            let ans = questionResult?.choiceAnswers?.first as? NSNumber
            total += ans?.doubleValue ?? 0.0
        }
        // Should we multiply this value by a factor?
        return total
    }

    func evaluate(_ result: ORKResult) -> QuestionnaireScore {

        switch test_type {
        case .custom:
            return evaluateForCustomTest(result)
        }
    }

    func sampleQuestions(n: Int, differentCategories: Bool) -> [String: Question] {

        let shuffledKeys = Array(allQuestions.keys).shuffled
        if shuffledKeys.count < n {
            fatalError("Cannot sample \(n) questions out of a questionnaire of \(shuffledKeys.count)")
        }

        if differentCategories {
            var selectedQuestions = [String: Question]()
            var includedCatIDs = [String]()
            for key in shuffledKeys {
                let catID = key.components(separatedBy: ".").first!
                if includedCatIDs.contains(catID) { continue }
                if selectedQuestions.count >= n { break }
                selectedQuestions[key] = allQuestions[key]
                includedCatIDs.append(catID)
            }
            if selectedQuestions.count < n {
                fatalError("Questionnaire does not have enough questions or categories for the given sampling settings")
            }
            return selectedQuestions
        } else {
            let selectedKeys = shuffledKeys[0..<n]
            return allQuestions.filter { selectedKeys.contains($0.key) }
        }
    }

    func generateTask() -> ORKOrderedTask {

        var formSteps = [ORKStep]()

        let intro = ORKInstructionStep(identifier: "intro")
        intro.title = "Welcome"
        formSteps.append(intro)

        let selectedQuestions = sampleQuestions(n: 2, differentCategories: true)

        for (id, question) in selectedQuestions {
            formSteps.append(question.asFormStep(id: id))
        }

        return ORKOrderedTask(identifier: "task", steps: formSteps)
    }
}
