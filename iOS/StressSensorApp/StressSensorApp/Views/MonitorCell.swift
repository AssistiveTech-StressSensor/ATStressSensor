//
//  MonitorCell.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 03/03/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import UIKit
import Eureka

class MonitorCell: Cell<String>, CellType {
    static let cellID = "MonitorCellID"
    static let nibName = "MonitorCell"

    @IBOutlet weak var stressLabel: UILabel!
    @IBOutlet weak var energyLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var feedbackIcon: UIView!

    static func register(for tableView: UITableView) {
        let nib = UINib(nibName: nibName, bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: cellID)
    }

    static func dequeue(for tableView: UITableView, at indexPath: IndexPath) -> MonitorCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        return cell as! MonitorCell
    }

    override func setup() {
        super.setup()
        selectionStyle = .none
        feedbackIcon.isHidden = true
        height = { 72.0 }
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
        if let phEnergy = prediction.physicalEnergy?.percentage {
            energy = "\(round(max(min(phEnergy, 100.0), 0.0)))%"
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

final class MonitorCellRow: Row<MonitorCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
        cellProvider = CellProvider<MonitorCell>(nibName: MonitorCell.nibName)
    }

    convenience init(_ prediction: Prediction) {
        self.init(tag: nil)
        cell.configure(for: prediction)
    }
}
