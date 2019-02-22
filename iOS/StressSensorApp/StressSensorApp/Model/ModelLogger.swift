//
//  ModelLogger.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 18/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit
import Firebase
import FirebaseAuth
import FirebaseDatabase


private protocol LoggerEntry: Encodable {
    var snapshot: SignalsSnapshot { get }
    var userID: String { get }
    var timestamp: TimeInterval { get }
}


private enum LoggerDataType: String {
    case energy = "energy_data"
    case stress = "data"
    case quadrant = "quadrant_data"
}


class ModelLogger {

    private static let userIDKey = "firebase.userID"

    static var userID: String?

    static var enabled: Bool = true

    static var canLog: Bool {
        return enabled && userID != nil
    }

    private struct StressEntry: LoggerEntry {
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

    static func setup() {

        if Secret.isValid {

            FirebaseApp.configure()

            Auth.auth().signIn(
                withEmail: Constants.Firebase.dummyEmail,
                password: Constants.Firebase.dummyPassword,
                completion: { user, error in

                    if let error = error {
                        print("Firebase auth: failure (\(error.localizedDescription))")
                    } else {
                        print("Firebase auth: success")
                        ModelLogger.createUserIfNeeded()
                    }
                }
            )

        } else {
            print("Firebase auth: skipped (credentials not found)")
        }
    }

    static func getNickname(_ completion: @escaping (String?) -> Void) {

        guard let userID = userID else {
            return completion(nil)
        }

        let ref = Database.database().reference(withPath: "users/\(userID)/first_name")
        ref.observeSingleEvent(of: .value, with: { s in
            completion(s.value as? String)
        })
    }

    static func modifyNickname(_ newNickname: String, completion: @escaping (Bool) -> Void) {

        guard let userID = userID else {
            return completion(false)
        }

        let userRef = Database.database().reference(withPath: "users/\(userID)")
        userRef.updateChildValues(["first_name": newNickname]) { error, ref in
            completion(error == nil)
        }
    }

    static func getCurrentLoggedEntries(_ completion: @escaping (Int, Int) -> Void) {

        guard let userID = userID else {
            return completion(-1, -1)
        }

        let stressDataRef = Database.database().reference(withPath: "users/\(userID)/data")
        let energyDataRef = Database.database().reference(withPath: "users/\(userID)/energy_data")

        stressDataRef.observeSingleEvent(of: .value, with: { stressData in
            energyDataRef.observeSingleEvent(of: .value, with: { energyData in
                let stressDataCount = Int(stressData.childrenCount)
                let energyDataCount = Int(energyData.childrenCount)
                completion(stressDataCount, energyDataCount)
            })
        })
    }

    static func createUserIfNeeded(force: Bool = false) {

        guard userID == nil else { return }
        let existingUserID = UserDefaults().value(forKey: userIDKey) as? String

        if !force && existingUserID != nil {
            self.userID = existingUserID
        } else {

            let usersRef = Database.database().reference(withPath: "users")
            let userRef = usersRef.childByAutoId()
            let userID = userRef.key

            usersRef.updateChildValues(["/\(userID)": [
                "first_name": "Mario"
            ]]) { error, ref in

                if error == nil {
                    UserDefaults().set(userID, forKey: userIDKey)
                    self.userID = userID
                }
            }
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
        ), dataType: .stress)
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
        ), dataType: .energy)
    }

    static func logQuadrant(snapshot: SignalsSnapshot, sample: ModelSample, value: QuadrantValue) {
        guard let userID = userID else { return }
        logEntry(QuadrantEntry(
            snapshot: snapshot,
            userID: userID,
            timestamp: Date().timeIntervalSince1970,
            sample: sample,
            label: value
        ), dataType: .quadrant)
    }

    private static func logEntry(_ entry: LoggerEntry, dataType: LoggerDataType) {
        guard canLog else { return }
        let userRef = Database.database().reference(withPath: "users/\(entry.userID)")
        let dataSampleRef = userRef.child(dataType.rawValue).childByAutoId()
        dataSampleRef.updateChildValues([
            "js_data": entry.asJSON()!,
            "timestamp": entry.timestamp
        ])
    }
}
