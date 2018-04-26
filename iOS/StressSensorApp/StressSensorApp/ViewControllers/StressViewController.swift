//
//  StressViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 16/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit

class StressViewController: UIViewController {

    @IBOutlet weak var predictionLabel: UILabel!
    @IBOutlet weak var stressChart: StressChart!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func updatePredictionLabel(_ prediction: StressLevel) {
        predictionLabel.text = "Last prediction: \(prediction.description)"
    }

    @IBAction func predictPressed() {

        guard StressModel.main.isTrained else {
            presentGenericError("You need to train the model first!")
            return
        }

        let snapshot: SignalsSnapshot

        do {
            snapshot = try SignalAcquisition.generateSnapshot()
        } catch SignalAcquisitionError.snapshotGenerationFailed(let details) {
            presentGenericError("Not enough sensor data to predict!\n\nDetails:\n\(details)")
            return
        } catch {
            presentGenericError(error.localizedDescription)
            return
        }

        let prediction = StressModel.main.predict(on: snapshot)

        // TODO: Store prediction
        // ...

        stressChart.addSample(prediction, date: snapshot.dateEnd)
        updatePredictionLabel(prediction)
    }
}
