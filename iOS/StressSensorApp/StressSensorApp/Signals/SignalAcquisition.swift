//
//  SignalAcquisition.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 08/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation

enum SignalAcquisitionError: Error {

    case snapshotGenerationFailed(String)

    var details: String {
        switch self {
        case .snapshotGenerationFailed(let arg):
            return arg
        }
    }

    var localizedDescription: String {
        switch self {
        case .snapshotGenerationFailed:
            return "Snapshot generation failed"
        }
    }
}

struct SignalSample {
    let value: Double
    let timestamp: Double
    let signal: Signal

    static var dummy: SignalSample {
        return SignalSample(value: 0, timestamp: 0, signal: .dummy)
    }
}

class SignalAcquisition {

    private static var lastSamples: [Signal: SignalSample] = [:]

    private static var debugNoiseTimer: DispatchSourceTimer?
    private static let debugNoiseHz: Double = 4.0

    private static let gsrExpectedHz: Double = 4.0
    private static let gsrMinHz: Double = 3.8
    private static let gsrMaxHz: Double = 4.2

    private static let hrExpectedHz: Double  = 0.158 // 10 samples/min
    private static let hrMinHz: Double  = 0.083 // 5 samples/min
    private static let hrMaxHz: Double  = 1.0 // 60 samples/min

    private static let windowLength = Constants.modelWindowLength

    private static var gsrBufferSize: Int = {
        return Int(ceil(gsrMaxHz * windowLength))
    }()

    private static var hrBufferSize: Int = {
        return Int(ceil(hrMaxHz * windowLength))
    }()

    private static var gsrBuffer: Circular<SignalSample>!
    private static var hrBuffer: Circular<SignalSample>!

    static func setup() {
        gsrBuffer = Circular<SignalSample>(capacity: gsrBufferSize, placeholder: .dummy)
        hrBuffer = Circular<SignalSample>(capacity: hrBufferSize, placeholder: .dummy)
    }

    static func generateSnapshot() throws -> SignalsSnapshot {
        assert(Thread.isMainThread)

        if Constants.useFakeSnapshots {
            // DEBUG ONLY
            let fakeSnapshot = (arc4random()%2 == 0) ? FakeStressedSS.random() : FakeNotStressedSS.random()
            print("Generated fake snapshot of type: \(fakeSnapshot)")
            return fakeSnapshot
        }

        let timestampEnd = Date().timeIntervalSince1970
        let timestampBeg = timestampEnd - windowLength

        var gsrSamples = gsrBuffer.toArray()
        var hrSamples = hrBuffer.toArray()

        gsrSamples.sort { $0.timestamp < $1.timestamp }
        hrSamples.sort { $0.timestamp < $1.timestamp }

        // Filter out samples that are too old (outside the window)
        gsrSamples = gsrSamples.filter { $0.timestamp >= timestampBeg }
        hrSamples = hrSamples.filter { $0.timestamp >= timestampBeg }

        let gsrMinCount = Int(gsrMinHz * windowLength)
        let hrMinCount = Int(hrMinHz * windowLength)

        if gsrSamples.count < gsrMinCount || hrSamples.count < hrMinCount {
            throw SignalAcquisitionError.snapshotGenerationFailed("""
                Valid GSR samples: \(gsrSamples.count)/\(gsrMinCount)
                Valid HR samples: \(hrSamples.count)/\(hrMinCount)
            """)
        }

        // TODO: We might also want to fill 'holes' between samples of HR
        // ...

        let rawGsrSamples = gsrSamples.map { $0.value }
        let rawHrSamples = hrSamples.map { $0.value }

        return SignalsSnapshot(
            timestampBeg: timestampBeg,
            timestampEnd: timestampEnd,
            gsrSamples: rawGsrSamples,
            hrSamples: rawHrSamples
        )
    }

    static func addSample(_ sample: SignalSample) {
        assert(Thread.isMainThread)
        lastSamples[sample.signal] = sample

        if sample.signal == .gsr {
            gsrBuffer.push(sample)
        } else if sample.signal == .heartRate {
            hrBuffer.push(sample)
        }
    }

    static func addSample(value: Double, timestamp: Double, signal: Signal) {
        addSample(SignalSample(value: value, timestamp: timestamp, signal: signal))
    }

    static func readLastSample(for signal: Signal) -> SignalSample? {
        return lastSamples[signal]
    }
}

extension SignalAcquisition {

    static func startDebugNoise() {
        if debugNoiseTimer?.isActive == true { return }

        let step: TimeInterval = (1.0 / debugNoiseHz)

        debugNoiseTimer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        debugNoiseTimer?.schedule(deadline: .now(), repeating: step, leeway: .milliseconds(5))
        debugNoiseTimer?.setEventHandler {

            let timestamp = CFUnixTimeGetCurrent()
            Signal.all.forEach { sig in
                // Noise between -1.0 and +1.0
                let noise = (Double(arc4random_uniform(2000)) - 1000.0) / 1000.0
                let val = sig.meanExpValue + (sig.amplitudeExpValue * noise)
                addSample(value: val, timestamp: timestamp, signal: sig)
            }
        }
        debugNoiseTimer?.resume()
    }

    static func stopDebugNoise() {
        debugNoiseTimer?.cancel()
    }
}
