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

    /// The name of the questionnaire.
    let name: String

    /// A list of the categories of the questionnaire.
    let categories: [Category]

    /// The type of function to be used for scoring.
    /// Implemented options: ['sum'].
    let scoring: Scoring

    /// A string indicating the version of the questionnaire.
    let version: String

    /// The number of randomly sampled questions to be asked to the candidate.
    /// Defaults to the number of categories.
    let subsetSize: Int?

    /// A boolean indicating if the randomly sampled questions should belong to exclusive categories.
    /// Defaults to false.
    let differentCategories: Bool?

    /// A factor to be applied to the final score at the end of the evaluation.
    /// Defaults to 1.0.
    let scoringFactor: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case categories
        case scoring
        case version
        case subsetSize = "subset_size"
        case differentCategories = "different_categories"
        case scoringFactor = "scoring_factor"
    }

    enum Scoring: String, Codable {
        case sum = "sum"
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

    /// Dictionary of questions keyed with IDs based on the ordering of the questionnaire.
    /// Ex. the 3rd question of the 5th category will have ID = '5.3'.
    var allQuestions: [String: Question] {
        var dict = [String: Question]()
        for i in 0..<categories.count {
            let questions = categories[i].questions
            for j in 0..<questions.count {
                let id = "\(i+1).\(j+1)"
                dict[id] = questions[j]
            }
        }
        return dict
    }
}

extension Questionnaire.Question.Option {

    /// Returns the option as a ORKTextChoice object.
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

    /// Returns the question as a ORKFormStep with the given ID.
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

    /// Returns a Questionnaire instance initialized with a given JSON file.
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

    /// Returns a Questionnaire instance initialized with the default JSON file.
    static let main: Questionnaire = {
        let path = Bundle.main.path(forResource: "custom_test", ofType: "json")!
        return Questionnaire.fromFile(path)!
    }()

    /// Evaluates the sum of the values of all choices picked by the candidate, applying the scoring factor.
    private func evaluateSum(_ result: ORKResult) -> QuestionnaireScore {

        var total = 0.0
        let stepResults = (result as! ORKTaskResult).results as! [ORKStepResult]
        for step in stepResults {
            let questionResult = step.firstResult as? ORKChoiceQuestionResult
            let ans = questionResult?.choiceAnswers?.first as? NSNumber
            total += ans?.doubleValue ?? 0.0
        }

        return total * (scoringFactor ?? 1.0)
    }

    /// Evaluates the final score of the questionnaire from a given ORKResult object.
    func evaluate(_ result: ORKResult) -> QuestionnaireScore {

        switch scoring {
        case .sum:
            return evaluateSum(result)
        }
    }

    /// Returns a dictionary of questions (keyed by ID) by sampling randomly the questionnaire.
    /// If differentCategories is true, the questions are chosen from exclusive categories.
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

    /// Returns an ORKOrderedTask object with the subset of questions to be presented to the candidate.
    func generateTask() -> ORKOrderedTask {

        var formSteps = [ORKStep]()

        let intro = ORKInstructionStep(identifier: "intro")
        intro.title = "Welcome"
        formSteps.append(intro)

        let selectedQuestions = sampleQuestions(
            n: (subsetSize ?? categories.count),
            differentCategories: (differentCategories ?? false)
        )

        for (id, question) in selectedQuestions {
            formSteps.append(question.asFormStep(id: id))
        }

        return ORKOrderedTask(identifier: "task", steps: formSteps)
    }
}
