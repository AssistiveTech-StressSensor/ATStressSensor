//
//  ModelSample.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 23/04/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation

/// Single sample of the model
struct ModelSample: Codable {

    let gsrMean: Double
    let gsrLocals: Double
    let hrMean: Double
    let hrMeanDerivative: Double

    let timestampBeg: TimeInterval
    let timestampEnd: TimeInterval

    /// Inits an empty sample. For test purposes only!
    private init() {
        self.gsrMean = 0.0
        self.gsrLocals = 0.0
        self.hrMean = 0.0
        self.hrMeanDerivative = 0.0
        self.timestampBeg = 0.0
        self.timestampEnd = 0.0
    }

    /// Inits a sample with the data computed from the given snapshot
    init(snapshot: SignalsSnapshot) {
        self.gsrMean = snapshot.computeGsrMean()
        self.gsrLocals = snapshot.computeGsrLocals()
        self.hrMean = snapshot.computeHrMean()
        self.hrMeanDerivative = snapshot.computeHrMeanDerivative()
        self.timestampBeg = snapshot.timestampBeg
        self.timestampEnd = snapshot.timestampEnd
    }

    /// Array of feature values to be used for training
    var values: [NSNumber] {
        return [
            gsrMean,
            gsrLocals,
            hrMean,
            hrMeanDerivative
            ] as [NSNumber]
    }

    /// The length of the window of signals taken into consideration
    var length: TimeInterval {
        return timestampEnd - timestampBeg
    }

    /// Returns an empty sample. For test purposes only!
    static var empty: ModelSample {
        return ModelSample()
    }
}
