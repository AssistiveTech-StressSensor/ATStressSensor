//
//  User.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 06/03/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import KeychainSwift


enum UserClearance: String, Codable {
    case dev
    case user
}


struct UserCredentials {
    let email: String
    let password: String

    static func load(withEmail email: String) -> UserCredentials? {
        guard let password = KeychainSwift().get(email) else { return nil }
        return UserCredentials(email: email, password: password)
    }

    func save() {
        KeychainSwift().set(password, forKey: email)
    }
}


struct UserInfo: Codable {
    private static let userDefaultsKey = "userInfo"

    let clearance: UserClearance
    let email: String
    let firstName: String
    let lastName: String
    let gender: String
    let dateOfBirth: String

    var fullName: String { return "\(firstName) \(lastName)" }

    enum CodingKeys: String, CodingKey {
        case clearance
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case gender
        case dateOfBirth = "dob"
    }
}
