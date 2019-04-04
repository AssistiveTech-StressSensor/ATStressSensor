//
//  DayViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 29/11/2017.
//  Copyright © 2017 AssistiveTech KTH. All rights reserved.
//

import UIKit
import ReSwift

class DayViewController: UIViewController, StoreSubscriber {

    @IBOutlet var devMenuButton: UIBarButtonItem!

    @IBOutlet weak var chart0: LiveChart!
    @IBOutlet weak var chart1: LiveChart!
    @IBOutlet weak var chart2: LiveChart!
    @IBOutlet weak var chart3: LiveChart!
    // @IBOutlet weak var chart4: LiveChart!

    private var charts: [Signal: LiveChart]!
    private var pollingTimer: DispatchSourceTimer?
    var consentManager: ConsentManager?

    override func viewDidLoad() {
        super.viewDidLoad()
        charts = [
            .gsr: chart0,
            .bvp: chart1,
            .heartRate: chart2,
            .temperature: chart3,
            // .ibi: chart4,
        ]
        setChartsAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mainStore.subscribe(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mainStore.unsubscribe(self)
    }

    func newState(state: AppState) {

        if state.user.userInfo?.clearance == .dev {
            navigationItem.rightBarButtonItem = devMenuButton
        } else {
            navigationItem.rightBarButtonItem = nil
        }

        if state.debug.addNoiseToSignals {
            SignalAcquisition.startDebugNoise()
        } else {
            SignalAcquisition.stopDebugNoise()
        }
    }

    @IBAction
    func displayDebugMenu(_ sender: Any? = nil) {
        DebugMenu.present(on: self)
    }

    func setChartsAppearance() {

        charts.values.forEach {
            $0.maxDataPoints = 300
            $0.outOfRangeGuard = true
        }

        charts[.gsr]?.signalLabel = "Perspiration - GSR (μS)"
        charts[.gsr]?.lineColor = .magenta
        charts[.gsr]?.setRangeY(min: 0.0, max: 10.0)

        charts[.bvp]?.signalLabel = "Blood Pulse - BVP (mV)"
        charts[.bvp]?.lineColor = .blue
        charts[.bvp]?.setRangeY(min: -150.0, max: 150.0)

        charts[.temperature]?.signalLabel = "Skin Temperature (°C)"
        charts[.temperature]?.lineColor = .green
        charts[.temperature]?.setRangeY(min: 20.0, max: 42.0)

        charts[.ibi]?.signalLabel = "IBI (s)"
        charts[.ibi]?.lineColor = .orange
        charts[.ibi]?.setRangeY(min: 0.0, max: 3.0)

        charts[.heartRate]?.signalLabel = "Heart Rate (bpm)"
        charts[.heartRate]?.lineColor = .red
        charts[.heartRate]?.setRangeY(min: 0.0, max: 180.0)
    }

    func startPolling() {
        if pollingTimer?.isActive == true { return }

        charts.values.forEach { $0.clear() }
        setChartsAppearance()
        let step: TimeInterval = 1.0/24.0
        let timestampBeg = CFAbsoluteTimeGetCurrent()

        pollingTimer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        pollingTimer?.schedule(deadline: .now(), repeating: step, leeway: .milliseconds(5))
        pollingTimer?.setEventHandler {

            let timestampCurr = CFAbsoluteTimeGetCurrent()
            let timestamp = (timestampCurr - timestampBeg)

            self.charts.forEach { signal, chart in
                if let samples = SignalAcquisition.readLastSample(for: signal) {
                    chart.addSample(samples, sequenceTS: timestamp)
                }
            }
        }
        pollingTimer?.resume()
    }

    func stopPolling() {
        pollingTimer?.cancel()
    }

    @IBAction func clearPressed() {
        charts.values.forEach { $0.clear() }
        setChartsAppearance()
    }

    @IBAction func toggleAcquisitionPressed(_ uiSwitch: UISwitch) {
        if uiSwitch.isOn {
            startPolling()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            stopPolling()
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}
