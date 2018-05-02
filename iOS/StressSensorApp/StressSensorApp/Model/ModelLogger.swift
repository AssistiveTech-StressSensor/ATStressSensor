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

class ModelLogger {

    private static let userIDKey = "firebase.userID"

    static var userID: String?

    static var enabled: Bool = true

    static var canLog: Bool {
        return enabled && userID != nil
    }

    private struct StressEntry: Codable {
        let snapshot: SignalsSnapshot
        let sample: ModelSample
        let sleepQuality: SleepQuality?
        let foodIntake: FoodIntake?
        let additionalNotes: String?
        let label: StressLevel
        let user_id: String
        let timestamp: TimeInterval
    }

    private struct EnergyEntry: Codable {
        let snapshot: SignalsSnapshot
        let sample: ModelSample
        let label: EnergyLevel
        let questionnaireResults: Questionnaire.Results
        let userID: String
        let timestamp: TimeInterval

        enum CodingKeys: String, CodingKey {
            case snapshot
            case sample
            case label
            case timestamp
            case userID = "user_id"
            case questionnaireResults = "questionnaire_results"
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

    static func getCurrentLoggedEntries(_ completion: @escaping (Int) -> Void) {

        guard let userID = userID else {
            return completion(-1)
        }

        let ref = Database.database().reference(withPath: "users/\(userID)/data")
        ref.observeSingleEvent(of: .value, with: { s in
            completion(Int(s.childrenCount))
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

        guard canLog, let userID = userID else { return }

        let userRef = Database.database().reference(withPath: "users/\(userID)")
        let now = Date().timeIntervalSince1970

        let entry = StressEntry(
            snapshot: snapshot,
            sample: sample,
            sleepQuality: sleepQuality,
            foodIntake: foodIntake,
            additionalNotes: additionalNotes,
            label: stressLevel,
            user_id: userID,
            timestamp: now
        )

        let dataSampleRef = userRef.child("data").childByAutoId()

        dataSampleRef.updateChildValues([
            "js_data": entry.asJSON()!,
            "timestamp": now
        ])
    }

    static func logEnergy(snapshot: SignalsSnapshot, sample: ModelSample, energyLevel: EnergyLevel, details: Questionnaire.Results) {

        guard canLog, let userID = userID else { return }

        let userRef = Database.database().reference(withPath: "users/\(userID)")
        let now = Date().timeIntervalSince1970

        let entry = EnergyEntry(
            snapshot: snapshot,
            sample: sample,
            label: energyLevel,
            questionnaireResults: details,
            userID: userID,
            timestamp: now
        )

        let dataSampleRef = userRef.child("energy_data").childByAutoId()

        dataSampleRef.updateChildValues([
            "js_data": entry.asJSON()!,
            "timestamp": now
        ])
    }
}
