//
//  RevEmpaLink.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 14/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation

private let EmpaticaAPICore = NSClassFromString("EmpaticaAPICore") as! NSObject.Type
private let EmpaticaDevice = NSClassFromString("EmpaticaDevice") as! NSObject.Type
private let EmpaticaLinkBLE = NSClassFromString("EmpaticaLinkBLE") as! NSObject.Type

class RevEmpaticaLink {

    private let empaticaLink: NSObject

    fileprivate init(empaticaLinkObject: NSObject) {
        self.empaticaLink = empaticaLinkObject
    }
}

class RevEmpaticaAPICore {

    // private let empaticaAPICore: NSObject
    let empaticaAPICore: NSObject

    static var shared: RevEmpaticaAPICore = {
        let obj = EmpaticaAPICore.perform(NSSelectorFromString("sharedInstance"))!.takeRetainedValue() as! NSObject
        return RevEmpaticaAPICore(empaticaAPICoreObject: obj)
    }()

    func debug() {
        print(".")
    }

    private init() {
        self.empaticaAPICore = EmpaticaAPICore.perform(NSSelectorFromString("new")).takeRetainedValue() as! NSObject
    }

    private init(empaticaAPICoreObject: NSObject) {
        self.empaticaAPICore = empaticaAPICoreObject
    }

    var connectedDevices: NSArray {
        // TODO: Determine type of array content, probably EmpaticaDevice
        return empaticaAPICore.value(forKey: "connectedDevices")! as! NSArray
    }

    var status: Int {
        return empaticaAPICore.value(forKey: "status")! as! Int
    }

    var currentSessionStartTime: TimeInterval {
        return empaticaAPICore.value(forKey: "currentSessionStartTime")! as! TimeInterval
    }

    var APIuserKey: String {
        return empaticaAPICore.value(forKey: "APIuserKey")! as! String
    }

    var empaticaLink: RevEmpaticaLink {
        let obj = empaticaAPICore.value(forKey: "empaticaLink")! as! NSObject
        return RevEmpaticaLink(empaticaLinkObject: obj)
    }

    var deviceOnWrist: Bool {
        let res = empaticaAPICore.value(forKey: "deviceOnWrist")! as! NSNumber
        return res.boolValue
    }

    // Not sure if this works
    var stressPeakTime: Double {
        let res = empaticaAPICore.perform(NSSelectorFromString("stressPeakTime"))
        dump(res)
        return 0.0
    }

    var stressCounter: Int {
        let res = empaticaAPICore.value(forKey: "stressCounter")! as! NSNumber
        return res.intValue
    }

    var inStressSituation: Bool {
        let res = empaticaAPICore.value(forKey: "inStressSituation")! as! NSNumber
        return res.boolValue
    }
}

class RevEmpaticaDevice {

    // private let empaticaDevice: NSObject
    let empaticaDevice: NSObject

    fileprivate init() {
        self.empaticaDevice = EmpaticaDevice.perform(NSSelectorFromString("new")).takeRetainedValue() as! NSObject
    }

    fileprivate init(empaticaDeviceObject: NSObject) {
        self.empaticaDevice = empaticaDeviceObject
    }

    var actualSampleRate: Double {
        return empaticaDevice.value(forKey: "actualSampleRate")! as! Double
    }

    var averageSampleRateSum: Double {
        return empaticaDevice.value(forKey: "averageSampleRateSum")! as! Double
    }

    var averageSampleRatePos: Double {
        return empaticaDevice.value(forKey: "averageSampleRatePos")! as! Double
    }

    var currentSessionStartTime: TimeInterval {
        return empaticaDevice.value(forKey: "currentSessionStartTime")! as! TimeInterval
    }
}

extension EmpaticaDeviceManager {

    var revDevice: RevEmpaticaDevice {
        // let obj = self.perform(NSSelectorFromString("device"))!.takeRetainedValue() as! NSObject
        let obj = self.value(forKey: "device") as! NSObject
        return RevEmpaticaDevice(empaticaDeviceObject: obj)
    }
}
