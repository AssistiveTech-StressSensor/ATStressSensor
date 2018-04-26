//
//  Constants.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 29/11/2017.
//  Copyright © 2017 AssistiveTech KTH. All rights reserved.
//

import Foundation

struct Constants {

    /// The developer API key provided by Empatica
    static let empaticaApiKey = "6d8eb0b6edac40f7a5a510a7754174ec"

    /// Minimum number of samples per class required to train the model
    static let minSamplesPerClass = 5

    static let modelWindowLength: TimeInterval = 2*60.0 // 2 minutes

    static let cooldownLength: TimeInterval = 2*60.0 // 2 minutes

    static let disableCooldown = false

    static let useFakeSnapshots = false

    static let documentsPath: String = {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    }()

    struct Firebase {
        static let dummyEmail = "xxxx" // Secret.firebaseEmail
        static let dummyPassword = "xxxx" // Secret.firebasePassword
    }
}
