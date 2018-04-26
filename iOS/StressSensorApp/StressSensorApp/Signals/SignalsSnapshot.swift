//
//  SignalsSnapshot.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 15/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation

class SignalsSnapshot: Codable {

    let gsrSamples: [Double]
    let hrSamples: [Double]

    let timestampBeg: TimeInterval
    let timestampEnd: TimeInterval

    lazy var length: TimeInterval = {
        return timestampEnd - timestampBeg
    }()

    lazy var dateBeg: Date = {
        return Date(timeIntervalSince1970: timestampBeg)
    }()

    lazy var dateEnd: Date = {
        return Date(timeIntervalSince1970: timestampEnd)
    }()

    var actualGsrSamplingRate: Double {
        return Double(gsrSamples.count) / length
    }

    var actualHrSamplingRate: Double {
        return Double(hrSamples.count) / length
    }

    init(timestampBeg: TimeInterval, timestampEnd: TimeInterval, gsrSamples: [Double], hrSamples: [Double]) {
        self.timestampBeg = timestampBeg
        self.timestampEnd = timestampEnd
        self.gsrSamples = gsrSamples
        self.hrSamples = hrSamples
    }

    func computeGsrMean() -> Double {
        return Signal.computeMean(gsrSamples)
    }

    func computeGsrLocals() -> Double {
        let minTimeApart: TimeInterval = 1 // at least 1 second between each maxima
        let minSamplesApart = Int(ceil(minTimeApart * actualGsrSamplingRate))
        let maxima = Signal.computeLocalMaxima(gsrSamples, minDistance: minSamplesApart)
        return Double(maxima.count)
    }

    func computeHrMean() -> Double {
        return Signal.computeMean(hrSamples)
    }

    func computeHrMeanDerivative() -> Double {
        let deriv = Signal.computeDerivative(hrSamples)
        return Signal.computeMean(deriv)
    }

    enum CodingKeys: String, CodingKey {
        case timestampBeg = "timestamp_beg"
        case timestampEnd = "timestamp_end"
        case gsrSamples = "gsr_samples"
        case hrSamples = "hr_samples"
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        timestampBeg = try values.decode(Double.self, forKey: .timestampBeg)
        timestampEnd = try values.decode(Double.self, forKey: .timestampEnd)
        gsrSamples = try values.decode(Array.self, forKey: .gsrSamples)
        hrSamples = try values.decode(Array.self, forKey: .hrSamples)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestampBeg, forKey: .timestampBeg)
        try container.encode(timestampEnd, forKey: .timestampEnd)
        try container.encode(gsrSamples, forKey: .gsrSamples)
        try container.encode(hrSamples, forKey: .hrSamples)
    }
}




/// DEBUG ONLY
class FakeStressedSS: SignalsSnapshot {

    /// DEBUG ONLY
    static func random() -> FakeStressedSS {
        let now = Date().timeIntervalSince1970
        return FakeStressedSS(
            timestampBeg: now - Constants.modelWindowLength,
            timestampEnd: now,
            gsrSamples: [],
            hrSamples: []
        )
    }

    override func computeGsrMean() -> Double {
        let noise = (Double(arc4random()%100) - 20)*0.01
        return 3.0 + noise
    }

    override func computeGsrLocals() -> Double {
        let noise = (Double(arc4random()%100) - 50)*0.0002
        return (0.1 + noise) * length
    }

    override func computeHrMean() -> Double {
        let noise = (Double(arc4random()%100) - 20)*0.2
        return 110.0 + noise
    }

    override func computeHrMeanDerivative() -> Double {
        let noise = (Double(arc4random()%100) - 50)*0.002
        return 0.5 + noise
    }
}

/// DEBUG ONLY
class FakeNotStressedSS: SignalsSnapshot {

    /// DEBUG ONLY
    static func random() -> FakeNotStressedSS {
        let now = Date().timeIntervalSince1970
        return FakeNotStressedSS(
            timestampBeg: now - Constants.modelWindowLength,
            timestampEnd: now,
            gsrSamples: [],
            hrSamples: []
        )
    }

    override func computeGsrMean() -> Double {
        let noise = (Double(arc4random()%100) - 20)*0.01
        return 1.0 + noise
    }

    override func computeGsrLocals() -> Double {
        let noise = (Double(arc4random()%100) - 50)*0.0002
        return (0.04 + noise) * length
    }

    override func computeHrMean() -> Double {
        let noise = (Double(arc4random()%100) - 50)*0.2
        return 70.0 + noise
    }

    override func computeHrMeanDerivative() -> Double {
        let noise = (Double(arc4random()%100) - 50)*0.002
        return 0.1 + noise
    }
}
