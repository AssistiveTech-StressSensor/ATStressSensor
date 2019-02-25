//
//  DayViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 29/11/2017.
//  Copyright © 2017 AssistiveTech KTH. All rights reserved.
//

import UIKit

class DayViewController: UIViewController {

    @IBOutlet var devMenuButton: UIBarButtonItem!

    @IBOutlet weak var chartGSR: LiveChart!
    @IBOutlet weak var chartBVP: LiveChart!
    @IBOutlet weak var chartTemp: LiveChart!
    @IBOutlet weak var chartIBI: LiveChart!
    @IBOutlet weak var chartHR: LiveChart!

    private var charts: [LiveChart]!
    private var pollingTimer: DispatchSourceTimer?

    override func viewDidLoad() {
        super.viewDidLoad()
        charts = [chartGSR, chartBVP, chartTemp, chartIBI, chartHR]
        setChartsAppearance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if ModelLogger.userClearance == .dev {
            navigationItem.rightBarButtonItem = devMenuButton
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    @IBAction
    func displayDebugMenu(_ sender: Any? = nil) {
        DebugMenu.present(on: self) { [weak self] in
            self?.checkForDebugNoise()
        }
    }

    func setChartsAppearance() {

        charts.forEach {
            $0.maxDataPoints = 300
            $0.outOfRangeGuard = true
        }

        chartGSR.signalLabel = "GSR (μS)"
        chartGSR.lineColor = .magenta
        chartGSR.setRangeY(min: 0.0, max: 10.0)

        chartBVP.signalLabel = "BVP (mV)"
        chartBVP.lineColor = .blue
        chartBVP.setRangeY(min: -150.0, max: 150.0)

        chartTemp.signalLabel = "Temperature (°C)"
        chartTemp.lineColor = .green
        chartTemp.setRangeY(min: 20.0, max: 42.0)

        chartIBI.signalLabel = "IBI (s)"
        chartIBI.lineColor = .orange
        chartIBI.setRangeY(min: 0.0, max: 3.0)

        chartHR.signalLabel = "Heart Rate (bpm)"
        chartHR.lineColor = .red
        chartHR.setRangeY(min: 0.0, max: 180.0)
    }

    func startPolling() {
        if pollingTimer?.isActive == true { return }

        charts.forEach { $0.clear() }
        setChartsAppearance()
        let step: TimeInterval = 1.0/24.0
        let timestampBeg = CFAbsoluteTimeGetCurrent()

        pollingTimer = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        pollingTimer?.schedule(deadline: .now(), repeating: step, leeway: .milliseconds(5))
        pollingTimer?.setEventHandler {

            let timestampCurr = CFAbsoluteTimeGetCurrent()
            let timestamp = (timestampCurr - timestampBeg)

            if let sampleGSR = SignalAcquisition.readLastSample(for: .gsr) {
                self.chartGSR.addSample(sampleGSR, sequenceTS: timestamp)
            }
            if let sampleBVP = SignalAcquisition.readLastSample(for: .bvp) {
                self.chartBVP.addSample(sampleBVP, sequenceTS: timestamp)
            }
            if let sampleTemp = SignalAcquisition.readLastSample(for: .temperature) {
                self.chartTemp.addSample(sampleTemp, sequenceTS: timestamp)
            }
            if let sampleIBI = SignalAcquisition.readLastSample(for: .ibi) {
                self.chartIBI.addSample(sampleIBI, sequenceTS: timestamp)
            }
            if let sampleHR = SignalAcquisition.readLastSample(for: .heartRate) {
                self.chartHR.addSample(sampleHR, sequenceTS: timestamp)
            }
        }
        pollingTimer?.resume()
    }

    func stopPolling() {
        pollingTimer?.cancel()
    }

    @IBAction func clearPressed() {
        charts.forEach { $0.clear() }
        setChartsAppearance()
    }

    func checkForDebugNoise() {
        if Constants.addNoiseToSignals {
            SignalAcquisition.startDebugNoise()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            SignalAcquisition.stopDebugNoise()
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
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
