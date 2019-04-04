//
//  FirebaseWrapper.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 06/03/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import Firebase
import FirebaseAuth
import PromiseKit

struct Firebase {

    static var isSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }

    static var users: DatabaseReference {
        return Database.database().reference(withPath: "users")
    }

    static func collectedData(forUser userID: String) -> DatabaseReference {
        return users.child("\(userID)/collected_data")
    }

    static func pullCollectedData(for userID: String, dataType: String) -> Promise<[String: Any]> {
        guard isSignedIn else {
            return Promise(error: NSError(domain: "Not logged in", code: 1, userInfo: nil))
        }
        return Promise { seal in
            let ref = collectedData(forUser: userID)
            ref.child(dataType).observeSingleEvent(of: .value, with: { s in
                if s.exists() == false {
                    seal.fulfill([:])
                } else if let value = s.value as? [String: Any] {
                    seal.fulfill(value)
                } else {
                    seal.reject(NSError(domain: "Unknown", code: 1, userInfo: nil))
                }
            })
        }
    }

    static func signIn(email: String, password: String) -> Promise<String> {
        return Promise { seal in
            Auth.auth().signIn(
                withEmail: email,
                password: password
            ) { user, error in
                if let userID = user?.uid {
                    seal.fulfill(userID)
                } else {
                    seal.reject(error ?? NSError(domain: "Unknown", code: 1, userInfo: nil))
                }
            }
        }
    }

    static func signIn(_ credentials: UserCredentials) -> Promise<String> {
        return signIn(email: credentials.email, password: credentials.password)
    }

    static func signUp(email: String, password: String) -> Promise<String> {
        return Promise { seal in
            Auth.auth().createUser(
                withEmail: email,
                password: password
            ) { user, error in
                if let userID = user?.uid {
                    seal.fulfill(userID)
                } else {
                    seal.reject(error ?? NSError(domain: "Unknown", code: 1, userInfo: nil))
                }
            }
        }
    }

    static func signUp(_ credentials: UserCredentials) -> Promise<String> {
        return signUp(email: credentials.email, password: credentials.password)
    }

    static func updateUserInfo(data: [String: Any], userID: String) -> Promise<Void> {
        return Promise { seal in
            users.updateChildValues(["/\(userID)/user_info": data]) { error, ref in
                seal.resolve(error)
            }
        }
    }

    static func getUserInfo(withID userID: String) -> Promise<UserInfo> {
        return Promise { seal in
            let ref = users.child("\(userID)/user_info")
            ref.observeSingleEvent(of: .value, with: { s in
                if let value = s.value as? [String: Any], let info = UserInfo.fromDictionary(value) {
                    seal.fulfill(info)
                } else {
                    seal.reject(NSError(domain: "Unknown", code: 1, userInfo: nil))
                }
            })
        }
    }

    static func initUser(withID userID: String, info: UserInfo) -> Promise<UserInfo> {
        let userDict = info.asDictionary()!
        return updateUserInfo(data: userDict, userID: userID).then { Promise.value(info) }
    }
}
