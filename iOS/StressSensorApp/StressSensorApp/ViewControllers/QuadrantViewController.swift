//
//  QuadrantViewController.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 08/02/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import UIKit

class QuadrantViewController: UITableViewController {

    private static let identifier = "QuadrantViewControllerID"
    static let navIdentifier = "QuadrantViewControllerNavID"

    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var quadrantView: QuadrantView!

    private var snapshot: SignalsSnapshot!
    private var completionHandler: ((Bool) -> ())?

    static func fromStoryboard() -> QuadrantViewController {
        let navID = UIStoryboard.main.instantiateViewController(withIdentifier: navIdentifier) as! UINavigationController
        return navID.topViewController as! QuadrantViewController
    }

    static func present(on parentVC: UIViewController, snapshot: SignalsSnapshot, completion: ((Bool) -> ())? = nil) {
        let vc = fromStoryboard()
        vc.setup(with: snapshot, completion: completion)
        parentVC.present(vc.navigationController!, animated: true, completion: nil)
    }

    func setup(with snapshot: SignalsSnapshot, completion: ((Bool) -> ())? = nil) {
        self.snapshot = snapshot
        self.completionHandler = completion
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let labels = ["Success", "Inner Peace", "Depression", "Anxiety"]
        quadrantView.setTextLabels(labels)
        quadrantView.valueChangeHandler = quadrantValueChanged
    }

    func quadrantValueChanged(_ newValue: QuadrantValue) {
        addButton.isEnabled = true
    }

    @IBAction func addPressed() {

        // Add sample to model
        let value = quadrantView!.value
        let sample = QuadrantModel.main.addSample(snapshot: snapshot, for: value)

        // Log data to remote server
        ModelLogger.logQuadrant(
            snapshot: snapshot,
            sample: sample,
            value: value
        )

        let alert = UIAlertController(
            title: "Awesome!",
            message: nil,
            preferredStyle: .alert
        )

        present(alert, animated: true, completion: nil)

        OperationQueue().addOperation { [unowned self] in
            Thread.sleep(forTimeInterval: 1.0)
            OperationQueue.main.addOperation {
                alert.dismiss(animated: true, completion: nil)
                self.completionHandler?(true)
                self.dismiss(animated: true, completion: nil)
            }
        }
    }

    @IBAction func cancelPressed() {
        completionHandler?(false)
        dismiss(animated: true, completion: nil)
    }
}
