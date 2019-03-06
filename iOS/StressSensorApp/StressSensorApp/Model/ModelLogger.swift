//
//  ModelLogger.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 18/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import FirebaseDatabase


private protocol LoggerEntry: Encodable {
    static var databaseLabel: String { get }
    var snapshot: SignalsSnapshot { get }
    var userID: String { get }
    var timestamp: TimeInterval { get }
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

    private struct StressEntry: LoggerEntry {
        static let databaseLabel = "stress_data"
        let snapshot: SignalsSnapshot
        let userID: String
        let timestamp: TimeInterval

        let sample: ModelSample
        let label: StressLevel
        let sleepQuality: SleepQuality?
        let foodIntake: FoodIntake?
        let additionalNotes: String?

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

    private struct EnergyEntry: LoggerEntry {
        static let databaseLabel = "energy_data"
        let snapshot: SignalsSnapshot
        let userID: String
        let timestamp: TimeInterval

        let sample: ModelSample
        let label: EnergyLevel
        let questionnaireResults: Questionnaire.Results

        enum CodingKeys: String, CodingKey {
            case snapshot
            case userID = "user_id"
            case timestamp

            case sample
            case label
            case questionnaireResults = "questionnaire_results"
        }
    }

    private struct QuadrantEntry: LoggerEntry {
        static let databaseLabel = "quadrant_data"
        let snapshot: SignalsSnapshot
        let userID: String
        let timestamp: TimeInterval

        let sample: ModelSample
        let label: QuadrantValue

        enum CodingKeys: String, CodingKey {
            case snapshot
            case userID = "user_id"
            case timestamp

            case sample
            case label
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

    static func logQuadrant(snapshot: SignalsSnapshot, sample: ModelSample, value: QuadrantValue) {
        guard let userID = userID else { return }
        logEntry(QuadrantEntry(
            snapshot: snapshot,
            userID: userID,
            timestamp: Date().timeIntervalSince1970,
            sample: sample,
            label: value
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
        let dbLabel = type(of: entry).databaseLabel
        let entryRef = dataReference.child(dbLabel).childByAutoId()
        entryRef.updateChildValues([
            "js_data": entry.asJSON()!,
            "timestamp": entry.timestamp
        ])
    }
}
