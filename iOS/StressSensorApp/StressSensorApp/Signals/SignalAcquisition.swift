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

    private static let windowLength = Constants.modelWindowLength
    private static let trackedSignals: Set<Signal> = [.bvp, .gsr, .heartRate]

    private static var debugNoiseTimers: [Signal: DispatchSourceTimer] = [:]
    private static var lastSamples: [Signal: SignalSample] = [:]
    private static var buffers: [Signal: Circular<SignalSample>]!

    static func setup() {
        buffers = [:]
        for s in trackedSignals {
            let capacity = Int(ceil(s.frequency.max * windowLength))
            buffers[s] = Circular<SignalSample>(capacity: capacity, placeholder: .dummy)
        }
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

        let rawSignals = buffers.mapValues { buffer -> [Double] in
            // Sort samples by timestamp
            let sorted = buffer.toArray().sorted { $0.timestamp < $1.timestamp }
            // Filter out samples that are too old (outside the window)
            let filtered = sorted.filter { $0.timestamp >= timestampBeg }
            // Return the raw values of the signal
            return filtered.map { $0.value }
        }

        let errors = rawSignals.compactMap { (signal, samples) -> String? in
            let minCount = Int(signal.frequency.min * windowLength)
            if samples.count >= minCount { return nil }
            let freq = Double(samples.count) / windowLength
            return "Valid \(signal) samples: \(samples.count)/\(minCount) (\(round(freq)))"
        }

        if errors.count > 0 {
            throw SignalAcquisitionError.snapshotGenerationFailed(errors.joined(separator: "\n"))
        }

        return SignalsSnapshot(
            timestampBeg: timestampBeg,
            timestampEnd: timestampEnd,
            samples: rawSignals
        )
    }

    static func addSample(_ sample: SignalSample) {
        assert(Thread.isMainThread)
        lastSamples[sample.signal] = sample
        buffers[sample.signal]?.push(sample)
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

        for signal in Signal.all {
            if debugNoiseTimers[signal]?.isActive == true { continue }

            let step: TimeInterval = 1.0 / signal.frequency.avg
            let timer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
            timer.schedule(deadline: .now(), repeating: step, leeway: .microseconds(100))
            timer.setEventHandler {
                // Noise between -1.0 and +1.0
                let noise = (Double(arc4random_uniform(2000)) - 1000.0) / 1000.0
                let val = signal.meanExpValue + (signal.amplitudeExpValue * noise)
                addSample(value: val, timestamp: CFUnixTimeGetCurrent(), signal: signal)
            }
            timer.resume()
            debugNoiseTimers[signal] = timer
        }
    }

    static func stopDebugNoise() {
        debugNoiseTimers.forEach { $1.cancel() }
    }
}
