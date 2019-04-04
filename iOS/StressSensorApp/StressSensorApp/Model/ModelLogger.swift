//
//  ModelLogger.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 18/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import FirebaseDatabase
import PromiseKit


private protocol LoggerEntry: Codable {
    static var databaseLabel: String { get }
    var snapshot: SignalsSnapshot { get }
    var userID: String { get }
    var timestamp: TimeInterval { get }
}

private protocol CommentableLoggerEntry: LoggerEntry {
    var comments: String? { get }
}

extension CommentableLoggerEntry {
    func asDiaryEntry() -> Diary.Entry? {
        return Diary.Entry(notes: comments, date: Date(timeIntervalSince1970: timestamp))
    }
}


class ModelLogger {

    static var enabled: Bool = true

    static var userID: String? {
        return mainStore.state.user.userID
    }

    static var userClearance: UserClearance {
        return mainStore.state.user.userInfo?.clearance ?? .user
    }

    static var canLog: Bool {
        return enabled && userID != nil && Firebase.isSignedIn
    }

    private static var dataReference: DatabaseReference? {
        guard let userID = userID else { return nil }
        return Firebase.collectedData(forUser: userID)
    }

    private struct StressEntry: CommentableLoggerEntry {
        static let databaseLabel = "stress_data"
        let snapshot: SignalsSnapshot
        let userID: String
        let timestamp: TimeInterval

        let sample: ModelSample
        let label: StressLevel
        let sleepQuality: SleepQuality?
        let foodIntake: FoodIntake?
        let additionalNotes: String?
        var comments: String? { return additionalNotes }

        enum CodingKeys: String, CodingKey {
            case snapshot
            case userID = "user_id"
            case timestamp

            case sample
            case label
            case sleepQuality
            case foodIntake
            case additionalNotes
        }
    }

    private struct EnergyEntry: CommentableLoggerEntry {
        static let databaseLabel = "energy_data"
        let snapshot: SignalsSnapshot
        let userID: String
        let timestamp: TimeInterval

        let sample: ModelSample
        let label: EnergyLevel
        let questionnaireResults: Questionnaire.Results
        var comments: String? { return questionnaireResults.notes }

        enum CodingKeys: String, CodingKey {
            case snapshot
            case userID = "user_id"
            case timestamp

            case sample
            case label
            case questionnaireResults = "questionnaire_results"
        }
    }

    private struct QuadrantEntry: CommentableLoggerEntry {
        static let databaseLabel = "quadrant_data"
        let snapshot: SignalsSnapshot
        let userID: String
        let timestamp: TimeInterval

        let sample: ModelSample
        let label: QuadrantValue
        let notes: String?
        var comments: String? { return notes }

        enum CodingKeys: String, CodingKey {
            case snapshot
            case userID = "user_id"
            case timestamp

            case sample
            case label
            case notes
        }
    }

    private struct UnlabeledEntry: LoggerEntry {
        static let databaseLabel = "unlabeled_data"
        let snapshot: SignalsSnapshot
        let userID: String
        let timestamp: TimeInterval

        enum CodingKeys: String, CodingKey {
            case snapshot
            case userID = "user_id"
            case timestamp
        }
    }

    private static func pullData<T: LoggerEntry>(ofType type: T.Type) -> Promise<[T]> {
        return Promise().compactMap {
            self.userID
        }.then {
            Firebase.pullCollectedData(for: $0, dataType: T.databaseLabel)
        }.compactMap {
            Array($0.values) as? [[String: Any]]
        }.map { rawEntries in
            rawEntries.compactMap { $0["js_data"] as? String }
        }.map { jsonEntries in
            jsonEntries.compactMap { T.fromJSON($0) }
        }
    }

    private static func pullCommentables<T: CommentableLoggerEntry>(ofType type: T.Type) -> Promise<[CommentableLoggerEntry]> {
        return pullData(ofType: type).map { $0 as [CommentableLoggerEntry] }
    }

    static func pullDiary() -> Promise<[Diary.Entry]> {
        return when(fulfilled: [
            pullCommentables(ofType: StressEntry.self),
            pullCommentables(ofType: QuadrantEntry.self),
            pullCommentables(ofType: EnergyEntry.self),
        ]).map {
            $0.reduce([], +)
        }.map {
            $0.compactMap { $0.asDiaryEntry() }
        }
    }

    static func logStress(snapshot: SignalsSnapshot, sample: ModelSample, stressLevel: StressLevel,
                    sleepQuality: SleepQuality? = nil, foodIntake: FoodIntake? = nil, additionalNotes: String? = nil) {
        guard let userID = userID else { return }
        logEntry(StressEntry(
            snapshot: snapshot,
            userID: userID,
            timestamp: Date().timeIntervalSince1970,
            sample: sample,
            label: stressLevel,
            sleepQuality: sleepQuality,
            foodIntake: foodIntake,
            additionalNotes: additionalNotes
        ))
    }

    static func logEnergy(snapshot: SignalsSnapshot, sample: ModelSample, energyLevel: EnergyLevel, details: Questionnaire.Results) {
        guard let userID = userID else { return }
        logEntry(EnergyEntry(
            snapshot: snapshot,
            userID: userID,
            timestamp: Date().timeIntervalSince1970,
            sample: sample,
            label: energyLevel,
            questionnaireResults: details
        ))
    }

    static func logQuadrant(snapshot: SignalsSnapshot, sample: ModelSample, value: QuadrantValue, notes: String?) {
        guard let userID = userID else { return }
        logEntry(QuadrantEntry(
            snapshot: snapshot,
            userID: userID,
            timestamp: Date().timeIntervalSince1970,
            sample: sample,
            label: value,
            notes: notes
        ))
    }

    static func logUnlabeled(snapshot: SignalsSnapshot) {
        guard let userID = userID else { return }
        logEntry(UnlabeledEntry(
            snapshot: snapshot,
            userID: userID,
            timestamp: Date().timeIntervalSince1970
        ))
    }

    static func logPrediction(_ prediction: Prediction, snapshot: SignalsSnapshot? = nil) {
        guard canLog, let dataReference = dataReference else { return }

        let predictionRef = dataReference.child("predictions").child(prediction.identifier)

        var updates: [String: Any] = [
            "prediction": prediction.asDictionary()!
        ]

        if let snapshot = snapshot {
            updates["snapshot_json"] = snapshot.asJSON()!
        }

        predictionRef.updateChildValues(updates)
    }

    private static func logEntry(_ entry: LoggerEntry) {
        guard canLog, let dataReference = dataReference else { return }
        if let diaryEntry = (entry as? CommentableLoggerEntry)?.asDiaryEntry() {
            try? Diary.log(diaryEntry)
        }
        let dbLabel = type(of: entry).databaseLabel
        let entryRef = dataReference.child(dbLabel).childByAutoId()
        entryRef.updateChildValues([
            "js_data": entry.asJSON()!,
            "timestamp": entry.timestamp
        ])
    }
}
