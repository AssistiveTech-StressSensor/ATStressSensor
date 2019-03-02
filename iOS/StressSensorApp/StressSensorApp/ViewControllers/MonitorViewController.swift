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

class MonitorCell: UITableViewCell {
    static let cellID = "MonitorCellID"

    @IBOutlet weak var stressLabel: UILabel!
    @IBOutlet weak var energyLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!

    static func dequeue(for tableView: UITableView, at indexPath: IndexPath) -> MonitorCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        return cell as! MonitorCell
    }

    func configure(for prediction: Prediction) {
        
        var stress = "Unknown"
        if prediction.stress == .stressed {
            stress = "Moderate"
        } else if prediction.stress == .notStressed {
            stress = "Low"
        }
        stressLabel.text = "Stress level: \(stress)"

        var energy = "Unknown"
        if let level = prediction.energy {
            energy = "\(round(level * 100))%"
        }
        energyLabel.text = "Energy level: \(energy)"

        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        f.locale = Locale(identifier: "en")
        dateLabel.text = f.string(from: prediction.date)
    }
}

class MonitorViewController: UITableViewController {

    private var predictions = [Prediction].load()

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action:#selector(MonitorViewController.refresh(_:)), for: .valueChanged)

        setNeedsBackgroundUpdate()
    }

    func setNeedsBackgroundUpdate() {
        if predictions.isEmpty {
            tableView.backgroundView = SimpleTableBackgroundView(frame: view.bounds, title: "Pull to predict!")
            tableView.separatorStyle = .none
        } else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
        }
    }

    func getSnapshotIfAllowed() -> SignalsSnapshot? {

        let alertCompletion = { [weak self] (action: UIAlertAction) -> Void in
            self?.refreshControl?.endRefreshing()
        }

        let snapshot: SignalsSnapshot
        do {
            snapshot = try SignalAcquisition.generateSnapshot()
        } catch SignalAcquisitionError.snapshotGenerationFailed(let details) {
            presentGenericError("Latest data from sensor is corrupted or insufficient. Please try again later.\n\nDetails:\n\(details)", completion: alertCompletion)
            return nil
        } catch {
            presentGenericError(error.localizedDescription, completion: alertCompletion)
            return nil
        }
        return snapshot
    }

    @objc
    private func refresh(_ sender: Any? = nil) {

        func handlePrediction(_ prediction: Prediction, snapshot: SignalsSnapshot?) {
            predictions.append(prediction)
            try? predictions.save()
            ModelLogger.logPrediction(prediction, snapshot: snapshot)

            refreshControl?.endRefreshing()
            setNeedsBackgroundUpdate()
            tableView.reloadData()
        }

        refreshControl?.beginRefreshing()

        if mainStore.state.debug.fakePredictions {
            let snapshot = DummySignalsSnapshot()
            let stress: StressLevel = snapshot.stressed ? .stressed : .notStressed
            let energy: EnergyLevel = Double(arc4random() % 100) / 100.0
            let prediction = Prediction(date: snapshot.dateEnd, stress: stress, energy: energy, feedback: nil)
            handlePrediction(prediction, snapshot: snapshot)
            return
        }

        let stressTrained = StressModel.main.isTrained
        let energyTrained = EnergyModel.main.isTrained

        guard stressTrained || energyTrained else {
            presentGenericError("The models are not trained yet!") { [weak self] _ in
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

            handlePrediction(prediction, snapshot: snapshot)
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
    }
}
