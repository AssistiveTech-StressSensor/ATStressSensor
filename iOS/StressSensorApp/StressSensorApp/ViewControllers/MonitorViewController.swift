//
//  MonitorViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 02/03/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import UIKit


struct Prediction: Codable {

    struct Feedback: Codable {
        let date: Date
        let correctness: Float
        let notes: String?
    }

    let date: Date
    var stress: StressLevel?
    var energy: EnergyLevel?
    var feedback: Feedback?

    var physicalEnergy: PhysicalEnergy? {
        guard let level = energy else { return nil }
        return PhysicalEnergy(withEnergyLevel: level)
    }

    var identifier: String {
        let timestamp = date.timeIntervalSince1970.description
        return timestamp.replacingOccurrences(of: ".", with: "_")
    }
}


extension Array where Element == Prediction {

    static func load() -> [Prediction] {
        return fromFile(Constants.predictionsPath) ?? []
    }

    func save() throws {
        try toFile(Constants.predictionsPath)
    }
}

class MonitorViewController: UITableViewController {

    private var predictions = [Prediction].load()

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action:#selector(MonitorViewController.refresh(_:)), for: .valueChanged)

        setNeedsBackgroundUpdate()
        MonitorCell.register(for: tableView)
    }

    fileprivate func setNeedsBackgroundUpdate() {
        if predictions.isEmpty {
            tableView.backgroundView = SimpleTableBackgroundView(frame: view.bounds, title: "Pull to predict!")
            tableView.separatorStyle = .none
        } else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
        }
    }

    fileprivate func getSnapshotIfAllowed() -> SignalsSnapshot? {

        let alertCompletion = { [weak self] () -> Void in
            self?.refreshControl?.endRefreshing()
        }

        let snapshot: SignalsSnapshot
        do {
            snapshot = try SignalAcquisition.generateSnapshot()
        } catch SignalAcquisitionError.snapshotGenerationFailed(let details) {
            var error = "Not enough data from the sensor. Please keep the sensor connected and try again later."
            if mainStore.state.user.userInfo?.clearance == .dev {
                error += "\n\nDetails:\n\(details)"
            }
            presentGenericError(error)
            return nil
        } catch {
            presentGenericError(error.localizedDescription, completion: alertCompletion)
            return nil
        }
        return snapshot
    }

    fileprivate func modifyPrediction(_ newPrediction: Prediction, index: Int) {
        predictions[index] = newPrediction
        try? predictions.save()
        ModelLogger.logPrediction(newPrediction)
        tableView.reloadData()
    }

    fileprivate func addPrediction(_ prediction: Prediction, snapshot: SignalsSnapshot?) {
        predictions.append(prediction)
        try? predictions.save()
        ModelLogger.logPrediction(prediction, snapshot: snapshot)

        refreshControl?.endRefreshing()
        setNeedsBackgroundUpdate()
        tableView.reloadData()
    }

    @objc
    private func refresh(_ sender: Any? = nil) {

        refreshControl?.beginRefreshing()

        if mainStore.state.debug.fakePredictions {
            let snapshot = DummySignalsSnapshot()
            let stress: StressLevel = snapshot.stressed ? .stressed : .notStressed
            let energy: EnergyLevel = Double(20 + arc4random() % 80) / 100.0
            let prediction = Prediction(date: snapshot.dateEnd, stress: stress, energy: energy, feedback: nil)
            addPrediction(prediction, snapshot: snapshot)
            return
        }

        let stressTrained = StressModel.main.isTrained
        let energyTrained = EnergyModel.main.isTrained

        guard stressTrained || energyTrained else {
            presentGenericError("The models are not trained yet!") { [weak self] in
                self?.refreshControl?.endRefreshing()
            }
            return
        }

        if let snapshot = getSnapshotIfAllowed() {

            var prediction = Prediction(date: snapshot.dateEnd, stress: nil, energy: nil, feedback: nil)

            if stressTrained {
                prediction.stress = StressModel.main.predict(on: snapshot)
            }

            if energyTrained {
                prediction.energy = EnergyModel.main.predict(on: snapshot)
            }

            addPrediction(prediction, snapshot: snapshot)
        }
    }
}


extension MonitorViewController {

    fileprivate func predictionIndex(for indexPath: IndexPath) -> Int {
        return predictions.count - 1 - indexPath.row
    }

    fileprivate func prediction(for indexPath: IndexPath) -> Prediction {
        return predictions[predictionIndex(for: indexPath)]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return predictions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return MonitorCell.dequeue(for: tableView, at: indexPath)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        (cell as! MonitorCell).configure(for: prediction(for: indexPath))
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        var pred = prediction(for: indexPath)
        let predIndex = predictionIndex(for: indexPath)

        let vc = FeedbackViewController.instantiate()
        vc.configure(with: pred) { [weak self] confirmed, feedback in
            if confirmed {
                pred.feedback = feedback
                self?.modifyPrediction(pred, index: predIndex)
            }
            vc.dismiss(animated: true, completion: nil)
        }

        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true, completion: nil)
    }
}
