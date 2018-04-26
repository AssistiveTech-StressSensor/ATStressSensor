//
//  Signal.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 08/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation

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

    static func computeDerivative(_ samples: [Double]) -> [Double] {
        var deriv = [Double]()
        for i in 1..<samples.count {
            deriv.append(samples[i]-samples[i-1])
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
