//
//  StressSensorAppTests.swift
//  StressSensorAppTests
//
//  Created by Carlo Rapisarda on 29/11/2017.
//  Copyright © 2017 AssistiveTech KTH. All rights reserved.
//

import XCTest
@testable import StressSensorApp

class StressSensorAppTests: XCTestCase {
    
    override func setUp() {
        super.setUp()

        // Disable remote logger
        ModelLogger.userID = "test"
        ModelLogger.enabled = false
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testDebugConstants() {
        XCTAssertFalse(Constants.disableCooldown)
        XCTAssertFalse(Constants.useFakeSnapshots)
        XCTAssertFalse(Secret.isValid)
    }

    func testStressModelData() {

        let modelData = StressModelData()
        XCTAssert(modelData.couples.isEmpty)
        XCTAssert(modelData.stressedCount == 0)
        XCTAssert(modelData.notStressedCount == 0)

        let balModelData = modelData.balanced()
        XCTAssert(balModelData.couples.isEmpty)
        XCTAssert(balModelData.stressedCount == 0)
        XCTAssert(balModelData.notStressedCount == 0)

        modelData.append(.empty, .stressed)
        XCTAssertFalse(modelData.couples.isEmpty)
        XCTAssert(modelData.stressedCount == 1)
        XCTAssert(modelData.notStressedCount == 0)

        modelData.append(.empty, .notStressed)
        XCTAssertFalse(modelData.couples.isEmpty)
        XCTAssert(modelData.stressedCount == 1)
        XCTAssert(modelData.notStressedCount == 1)

        modelData.append(.empty, .stressed)
        modelData.append(.empty, .stressed)
        let balModelData2 = modelData.balanced()
        XCTAssertFalse(balModelData2.couples.isEmpty)
        XCTAssert(balModelData2.stressedCount == 3)
        XCTAssert(balModelData2.notStressedCount == 3)

        modelData.append(.empty, .notStressed)
        modelData.append(.empty, .notStressed)
        modelData.append(.empty, .notStressed)
        modelData.append(.empty, .notStressed)
        modelData.append(.empty, .notStressed)
        let balModelData3 = modelData.balanced()
        XCTAssertFalse(balModelData3.couples.isEmpty)
        XCTAssert(balModelData3.stressedCount == 6)
        XCTAssert(balModelData3.notStressedCount == 6)

        XCTAssert(modelData.stressedCount == 3)
        XCTAssert(modelData.notStressedCount == 6)
    }

    func testArrayExtension() {

        var arr = [Int]()
        // Random value must be nil if array is empty
        XCTAssertNil(arr.random())

        arr.append(1)
        // Random value must be 1 since it's the only value
        XCTAssertEqual(arr.random()!, 1)

        arr.append(1)
        arr.append(1)
        arr.append(1)
        // Random value must be 1 since it's the only value
        XCTAssertEqual(arr.random()!, 1)

        arr.append(1)
        arr.append(1)
        arr.append(1)
        arr.append(1)
        arr.append(2)
        arr.append(2)
        var occ = 0
        2000.times {
            if arr.random() == 2 { occ += 1 }
        }
        let prob = Double(occ) / 2000.0
        // Array has 10 '1's and 2 '2's
        // Random fn must be uniform
        // Probability of picking '2' must be approx 2/10
        XCTAssert(1/10.0 < prob && prob < 3/10.0)
    }

    func testStringExtension() {

        XCTAssert(String.random(length: 11, charactersIn: "abc").count == 11)
        XCTAssert(String.randomHex(length: 12).count == 12)
        XCTAssert(String.randomNumeric(length: 13).count == 13)
        XCTAssert(String.randomAlphabetic(length: 14).count == 14)
        XCTAssert(String.randomAlphanumeric(length: 15).count == 15)
        XCTAssert(String.random(length: 5, charactersIn: "aaa") == "aaaaa")

        10.times {
            let str1 = String.random(length: 100, charactersIn: "abc")
            let cs = CharacterSet(charactersIn: "abc")
            let str2 = str1.filter { cs.contains($0.unicodeScalars.first!) }
            XCTAssert(str1 == str2)
        }

        10.times {
            let str1 = String.randomAlphanumeric(length: 100)
            let cs = CharacterSet.alphanumerics
            let str2 = str1.filter { cs.contains($0.unicodeScalars.first!) }
            XCTAssert(str1 == str2)
        }

        10.times {
            let str1 = String.randomNumeric(length: 100)
            let cs = CharacterSet.decimalDigits
            let str2 = str1.filter { cs.contains($0.unicodeScalars.first!) }
            XCTAssert(str1 == str2)
        }

        10.times {
            let str1 = String.randomAlphabetic(length: 100)
            let cs = CharacterSet.letters
            let str2 = str1.filter { cs.contains($0.unicodeScalars.first!) }
            XCTAssert(str1 == str2)
        }
    }

    func testCircular() {

        let circ = Circular<Int>(capacity: 5, placeholder: 0)
        XCTAssert(circ.capacity == 5)
        XCTAssert(circ.count == 0)
        XCTAssert(circ.isEmpty)
        XCTAssertFalse(circ.isFull)
        XCTAssertNil(circ.first)
        XCTAssertNil(circ.last)
        XCTAssert(circ.toArray().count == 0)

        circ.push(34)
        XCTAssert(circ.count == 1)
        XCTAssertFalse(circ.isEmpty)
        XCTAssertFalse(circ.isFull)
        XCTAssert(circ.first == 34)
        XCTAssert(circ.last == 34)
        XCTAssert(circ[0] == 34)
        XCTAssert(circ.toArray().count == 1)
        XCTAssert(circ.toArray()[0] == 34)

        circ.push(57)
        XCTAssert(circ.count == 2)
        XCTAssertFalse(circ.isEmpty)
        XCTAssertFalse(circ.isFull)
        XCTAssert(circ.first == 34)
        XCTAssert(circ.last == 57)
        XCTAssert(circ[0] == 34)
        XCTAssert(circ[1] == 57)
        XCTAssert(circ.toArray().count == 2)
        XCTAssert(circ.toArray()[0] == 34)
        XCTAssert(circ.toArray()[1] == 57)

        circ.push(1001)
        circ.push(1002)
        circ.push(1003)
        XCTAssert(circ.count == 5)
        XCTAssert(circ.isFull)

        circ.push(1004)
        circ.push(1005)
        XCTAssert(circ.toArray() == [1001,1002,1003,1004,1005])
        XCTAssert(circ[0] == circ.first)
        XCTAssert(circ[circ.count-1] == circ.last)
    }

    func testQuestionnaire() {

        continueAfterFailure = false

        let path = Bundle.main.path(forResource: "custom_test", ofType: "json")
        XCTAssertNotNil(path)

        let questFromFile = Questionnaire.fromFile(path!)
        XCTAssertNotNil(questFromFile)

        let quest = Questionnaire.main
        XCTAssertEqual(quest.allQuestions.keys, questFromFile!.allQuestions.keys)
        XCTAssertEqual(quest.name, questFromFile!.name)
        XCTAssertEqual(quest.version, questFromFile!.version)

        XCTAssert(quest.categories.count > 0)
        XCTAssert(quest.allQuestions.count > 0)
    }
}
