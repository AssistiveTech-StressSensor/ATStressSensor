//
//  Utilities.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 16/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit
import PromiseKit

func CFUnixTimeGetCurrent() -> CFTimeInterval {
    return CFAbsoluteTimeGetCurrent() + 978307200.0
}

extension CGRect {
    var bounds: CGRect {
        return CGRect(origin: .zero, size: self.size)
    }
}

extension UIDevice {
    var uuidString: String? {
        return identifierForVendor?.uuidString
    }
}

extension DispatchSourceTimer {
    var isActive: Bool {
        return !isCancelled
    }
}

extension UIStoryboard {
    static var main: UIStoryboard {
        return UIStoryboard(name: "Main", bundle: nil)
    }
}

protocol StoryboardInstantiable where Self: UIViewController {
    associatedtype instantiableType: UIViewController = Self
    static var instantiableID: String { get }
    static func instantiate() -> instantiableType
}

extension StoryboardInstantiable {
    static func instantiate() -> instantiableType {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        return sb.instantiateViewController(withIdentifier: instantiableID) as! instantiableType
    }
}

extension Encodable {

    func asDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)) as? [String: Any]
    }

    func asJSON() -> String? {
        guard let jsonData = try? JSONEncoder().encode(self) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }

    func toFile(_ url: URL) throws {
        let encoded = try JSONEncoder().encode(self)
        try encoded.write(to: url, options: .atomic)
    }

    func toFile(_ path: String) throws {
        try toFile(URL(fileURLWithPath: path))
    }
}

extension Decodable {

    static func fromDictionary(_ dict: [String: Any]) -> Self? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return nil }
        return fromJSON(data)
    }

    static func fromJSON(_ json: Data) -> Self? {
        return try? JSONDecoder().decode(Self.self, from: json)
    }

    static func fromJSON(_ json: String, using encoding: String.Encoding = .utf8) -> Self? {
        guard let data = json.data(using: encoding) else { return nil }
        return fromJSON(data)
    }

    static func fromFile(_ url: URL) -> Self? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return fromJSON(data)
    }

    static func fromFile(_ path: String) -> Self? {
        return fromFile(URL(fileURLWithPath: path))
    }

}

protocol Storable where Self: Codable {
    associatedtype codableType: Codable = Self
    static var storableKey: String { get }
}

extension Storable {
    static func load() -> codableType? {
        assert(Thread.isMainThread)
        guard let json = UserDefaults().value(forKey: storableKey) as? String else { return nil }
        return codableType.fromJSON(json)
    }

    @discardableResult
    func save() -> Bool {
        assert(Thread.isMainThread)
        guard let json = (self as? codableType)?.asJSON() else { return false }
        UserDefaults().set(json, forKey: Self.storableKey)
        return true
    }
}

extension UIViewController {

    func dismiss() -> Guarantee<Void> {
        return Guarantee { dismiss(animated: true, completion: $0) }
    }

    func presentGenericError(_ message: String, dismissHandler: ((UIAlertAction) -> ())? = nil, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(
            title: "Oops!",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: dismissHandler))
        present(alert, animated: true, completion: completion)
    }
}

extension Array {

    func random() -> Element? {
        if isEmpty { return nil }
        return self[Int(arc4random_uniform(UInt32(count)))]
    }

    mutating func shuffle() {
        guard self.count >= 1 else { return }

        for i in (1..<self.count).reversed() {
            let j = Array<Int>(0...i).random()!
            self.swapAt(j, i)
        }
    }

    var shuffled : [Element] {
        var elements = self
        elements.shuffle()
        return elements
    }
}

extension String {

    static func random(length: Int, charactersIn: String) -> String {
        let all = charactersIn.unicodeScalars.map { $0.description }
        return (0..<length).map { _ in all.random()! }.joined()
    }

    static func randomNumeric(length: Int) -> String {
        return random(length: length, charactersIn: "0123456789")
    }

    static func randomHex(length: Int) -> String {
        return random(length: length, charactersIn: "abcdef0123456789")
    }

    static func randomAlphabetic(length: Int) -> String {
        return random(length: length, charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    }

    static func randomAlphanumeric(length: Int) -> String {
        return random(length: length, charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    }
}

extension Int {

    func times(_ closure: () -> Void) {
        guard self > 0 else { return }
        for _ in 0..<self { closure() }
    }
}
