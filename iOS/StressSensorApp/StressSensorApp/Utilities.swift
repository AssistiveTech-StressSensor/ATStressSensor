//
//  Utilities.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 16/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit

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

extension UIViewController {

    func presentGenericError(_ message: String) {
        let alert = UIAlertController(
            title: "Oops!",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
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
