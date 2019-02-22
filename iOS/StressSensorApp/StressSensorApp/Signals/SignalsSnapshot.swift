//
//  SignalsSnapshot.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 15/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation

class SignalsSnapshot: Encodable {

    let gsrSamples: [Double]
    let hrSamples: [Double]
    let bvpSamples: [Double]

    let timestampBeg: TimeInterval
    let timestampEnd: TimeInterval
    let hasNoise: Bool

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

    init(timestampBeg: TimeInterval, timestampEnd: TimeInterval, samples: [Signal: [Double]], hasNoise: Bool) {
        self.timestampBeg = timestampBeg
        self.timestampEnd = timestampEnd
        self.gsrSamples = samples[.gsr] ?? []
        self.hrSamples = samples[.heartRate] ?? []
        self.bvpSamples = samples[.bvp] ?? []
        self.hasNoise = hasNoise
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
        case bvpSamples = "bvp_samples"
        case hasNoise = "noise"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestampBeg, forKey: .timestampBeg)
        try container.encode(timestampEnd, forKey: .timestampEnd)
        try container.encode(gsrSamples, forKey: .gsrSamples)
        try container.encode(hrSamples, forKey: .hrSamples)
        try container.encode(bvpSamples, forKey: .bvpSamples)
        try container.encode(hasNoise, forKey: .hasNoise)
    }
}


/// DEBUG ONLY
class DummySignalsSnapshot: SignalsSnapshot {

    var stressed = false

    init() {
        let now = Date().timeIntervalSince1970
        super.init(
            timestampBeg: now - Constants.modelWindowLength,
            timestampEnd: now,
            samples: [:],
            hasNoise: true
        )
        stressed = (arc4random() % 2 == 0)
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    override func computeGsrMean() -> Double {
        let noise = (Double(arc4random()%100) - 20)*0.01
        return (stressed ? 3.0 : 1.0) + noise
    }

    override func computeGsrLocals() -> Double {
        let noise = (Double(arc4random()%100) - 50)*0.0002
        return ((stressed ? 0.1 : 0.04) + noise) * length
    }

    override func computeHrMean() -> Double {
        let noise = (Double(arc4random()%100) - (stressed ? 20 : 50))*0.2
        return (stressed ? 110.0 : 70.0) + noise
    }

    override func computeHrMeanDerivative() -> Double {
        let noise = (Double(arc4random()%100) - 50)*0.002
        return (stressed ? 0.5 : 0.1) + noise
    }
}
