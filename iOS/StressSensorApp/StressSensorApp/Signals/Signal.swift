//
//  Signal.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 08/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation

struct SignalFrequency: ExpressibleByArrayLiteral {
    typealias ArrayLiteralElement = Double
    let min, avg, max: Double
    let isKnown: Bool

    static var unknown: SignalFrequency {
        return SignalFrequency(known: false)
    }

    init(min: Double = 0.0, avg: Double = 1.0, max: Double = .infinity, known: Bool = true) {
        self.min = min
        self.avg = avg
        self.max = max
        self.isKnown = known
    }

    init(arrayLiteral elements: SignalFrequency.ArrayLiteralElement...) {
        if elements.count != 3 {
            fatalError("Signal frequency must be specified as three values (min, avg, max).")
        }
        self.min = elements[0]
        self.avg = elements[1]
        self.max = elements[2]
        self.isKnown = true
    }
}

enum Signal {
    case gsr
    case bvp
    case temperature
    case accelerationX
    case accelerationY
    case accelerationZ
    case ibi
    case heartRate
    case batteryLevel
    case dummy

    static let all: [Signal] = {
        return [
            .gsr,
            .bvp,
            .temperature,
            .accelerationX,
            .accelerationY,
            .accelerationZ,
            .ibi,
            .heartRate,
            .batteryLevel
        ]
    }()

    var shortName: String {
        switch self {
        case .temperature:
            return "Temp."
        case .accelerationZ:
            return "Z''"
        case .accelerationY:
            return "Y''"
        case .accelerationX:
            return "X''"
        case .batteryLevel:
            return "Bttr."
        case .gsr:
            return "GSR"
        case .bvp:
            return "BVP"
        case .ibi:
            return "IBI"
        case .heartRate:
            return "HR"
        case .dummy:
            return "Fake"
        }
    }

    var frequency: SignalFrequency {
        switch self {
        case .accelerationZ, .accelerationY, .accelerationX:
            return [30.5, 32.0, 33.5]
        case .gsr, .temperature:
            return [3.8, 4.0, 4.2]
        case .bvp:
            return [61.0, 64.0, 67.0]
        case .ibi, .heartRate:
            return [0.083, 0.158, 1.0]
        default:
            return .unknown
        }
    }

    var meanExpValue: Double {
        switch self {
        case .temperature:
            return 28.0
        case .accelerationZ, .accelerationY, .accelerationX:
            return 0.0
        case .batteryLevel:
            return 0.5
        case .gsr:
            return 2.0
        case .bvp:
            return 0.0
        case .ibi:
            return 1.2
        case .heartRate:
            return 70.0
        default:
            return 0.0
        }
    }

    var amplitudeExpValue: Double {
        switch self {
        case .temperature:
            return 2.0
        case .accelerationZ, .accelerationY, .accelerationX:
            return 1.0
        case .batteryLevel:
            return 0.2
        case .gsr:
            return 1.0
        case .bvp:
            return 150.0
        case .ibi:
            return 0.2
        case .heartRate:
            return 20.0
        default:
            return 0.0
        }
    }

    static func computeMean(_ samples: [Double]) -> Double {
        let sum = samples.reduce(0.0, { $0 + $1 })
        return sum / Double(samples.count)
    }

    static func computeDerivative(_ samples: [Double], dt: Double = 1.0) -> [Double] {
        var deriv = [Double]()
        for i in 1..<samples.count {
            let val = (samples[i] - samples[i-1]) * dt
            deriv.append(val)
        }
        return deriv
    }

    static func computeLocalMaxima(_ samples: [Double], minDistance: Int = 0) -> [Int] {
        if samples.count < 2 { return [] }
        var maxima = [Int]()
        var samplesFromLastMaximum = Int.max
        let deriv = computeDerivative(samples)
        var prevSign = deriv[0].sign

        for i in 1..<deriv.count {
            let currSign = deriv[i].sign
            if prevSign == .plus && currSign == .minus && samplesFromLastMaximum >= minDistance {
                // Peak
                samplesFromLastMaximum = 1
                maxima.append(i)
            } else if samplesFromLastMaximum < Int.max {
                samplesFromLastMaximum += 1
            }
            prevSign = currSign
        }

        return maxima
    }
}
