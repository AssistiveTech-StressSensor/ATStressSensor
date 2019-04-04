//
//  MonitorViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 02/03/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import UIKit
import PromiseKit


class DiaryCell: UITableViewCell {
    static let cellID = "DiaryCellID"

    @IBOutlet private weak var commentsLabel: UILabel!
    @IBOutlet private weak var dateLabel: UILabel!

    static func dequeue(for tableView: UITableView, at indexPath: IndexPath) -> DiaryCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        return cell as! DiaryCell
    }

    func configure(for entry: Diary.Entry) {
        selectionStyle = .none

        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        f.locale = Locale(identifier: "en")
        dateLabel.text = f.string(from: entry.date)

        commentsLabel.text = entry.notes
    }
}


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

protocol DateSortable {
    var date: Date { get }
}

extension Prediction: DateSortable {}
extension Diary.Entry: DateSortable {}


extension Array where Element == Prediction {

    static func load() -> [Prediction] {
        return fromFile(Constants.predictionsPath) ?? []
    }

    func save() throws {
        try toFile(Constants.predictionsPath)
    }
}

class MonitorViewController: UITableViewController {

    private var tableEntries: [DateSortable] = []
    private var predictions = [Prediction].load()
    private var diaryEntries: [Diary.Entry] { return Diary.content.entries }
    private var diaryPromise: Promise<Void>?

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action:#selector(MonitorViewController.refresh(_:)), for: .valueChanged)

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44

        MonitorCell.register(for: tableView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updateTable()
        if diaryPromise == nil || diaryPromise!.isRejected {
            diaryPromise = Diary.load()
            diaryPromise?.ensure {
                self.updateTable()
            }.cauterize()
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
            presentGenericError(error, completion: alertCompletion)
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
        updateTable()
    }

    fileprivate func addPrediction(_ prediction: Prediction, snapshot: SignalsSnapshot?) {
        predictions.append(prediction)
        try? predictions.save()
        ModelLogger.logPrediction(prediction, snapshot: snapshot)
        refreshControl?.endRefreshing()
        updateTable()
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

    fileprivate func updateTable() {
        let a = predictions as [DateSortable]
        let b = diaryEntries as [DateSortable]
        tableEntries = (a + b).sorted { $0.date > $1.date }
        tableView.reloadData()
        setNeedsBackgroundUpdate()
    }

    private func setNeedsBackgroundUpdate() {
        if tableEntries.isEmpty {
            tableView.backgroundView = SimpleTableBackgroundView(frame: view.bounds, title: "Pull to predict!")
            tableView.separatorStyle = .none
        } else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableEntries.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let entry = tableEntries[indexPath.row]
        if let prediction = entry as? Prediction {
            let cell = MonitorCell.dequeue(for: tableView, at: indexPath)
            cell.configure(for: prediction)
            return cell
        } else if let diaryEntry = entry as? Diary.Entry {
            let cell = DiaryCell.dequeue(for: tableView, at: indexPath)
            cell.configure(for: diaryEntry)
            return cell
        } else {
            fatalError("Not implemented!")
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if var prediction = tableEntries[indexPath.row] as? Prediction {

            let allPredictions = predictions
            let vc = FeedbackViewController.instantiate()
            vc.configure(with: prediction) { [weak self] confirmed, feedback in
                if confirmed {
                    prediction.feedback = feedback

                    OperationQueue().addOperation {
                        let index = allPredictions.firstIndex { $0.identifier == prediction.identifier }
                        OperationQueue.main.addOperation {
                            if index != nil {
                                self?.modifyPrediction(prediction, index: index!)
                            }
                            vc.dismiss(animated: true, completion: nil)
                        }
                    }
                } else {
                    vc.dismiss(animated: true, completion: nil)
                }
            }

            let nav = UINavigationController(rootViewController: vc)
            present(nav, animated: true, completion: nil)
        }
    }
}
