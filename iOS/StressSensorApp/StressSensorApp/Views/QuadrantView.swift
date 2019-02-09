//
//  QuadrantView.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 08/02/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import UIKit

class QuadrantView: UIView {

    private(set) var labels: [UILabel]?
    private var indicator: UIView?
    private var lines: CAShapeLayer?
    private var selectedLocation: (CGFloat, CGFloat) = (0, 0)
    var valueChangeHandler: ((QuadrantValue) -> ())?

    var value: QuadrantValue {
        return QuadrantValue(Double(selectedLocation.0), Double(selectedLocation.1))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        didLoad()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        didLoad()
    }

    private func didLoad() {

        isExclusiveTouch = true

        func newLabel(_ text: String) -> UILabel {
            let label = UILabel(frame: .zero)
            label.textColor = .black
            label.text = text
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }

        let values = ["1", "2", "3", "4"].map { "---\($0)---" }
        labels = values.map(newLabel)
        labels?.forEach { addSubview($0) }

        let shapeLayer = CAShapeLayer()
        shapeLayer.strokeColor = UIColor.gray.cgColor
        shapeLayer.lineWidth = 1.0
        lines = shapeLayer
        layer.addSublayer(shapeLayer)

        let xMult: [CGFloat] = [2.0/3.0, 2.0/3.0, 2.0, 2.0]
        let yMult: [CGFloat] = [2.0, 2.0/3.0, 2.0/3.0, 2.0]

        for (i, l) in labels!.enumerated() {
            if i >= xMult.count {break}
            self.addConstraints([
                NSLayoutConstraint(
                    item: self,
                    attribute: .centerX,
                    relatedBy: .equal,
                    toItem: l,
                    attribute: .centerX,
                    multiplier: xMult[i],
                    constant: 0.0
                ),
                NSLayoutConstraint(
                    item: self,
                    attribute: .centerY,
                    relatedBy: .equal,
                    toItem: l,
                    attribute: .centerY,
                    multiplier: yMult[i],
                    constant: 0.0
                )
                ])
        }

        indicator = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        indicator?.backgroundColor = .purple
        indicator?.layer.cornerRadius = 5.0
        indicator?.clipsToBounds = false
        indicator?.isUserInteractionEnabled = false
        addSubview(indicator!)
        updateIndicatorLocation()
    }

    func setTextLabels(_ textLabels: [String]) {
        if let labels = labels {
            if textLabels.count != 4 {
                fatalError("Text labels must be exactly 4.")
            }
            textLabels.enumerated().forEach { i, t in labels[i].text = t }
        } else {
            fatalError("Cannot set text labels before view is loaded.")
        }
    }

    private func updateIndicatorLocation() {
        let (x, y) = selectedLocation
        let (w, h) = (bounds.width, bounds.height)
        let xReal = (x + 1.0) * w / 2.0
        let yReal = (y - 1.0) * h / -2.0
        indicator?.center = CGPoint(x: xReal, y: yReal)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard labels != nil, let lines = lines else { return }

        let rect = self.frame
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.width/2, y: 0.0))
        path.addLine(to: CGPoint(x: rect.width/2, y: rect.height))
        path.move(to: CGPoint(x: 0.0, y: rect.height/2))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height/2))

        lines.path = path.cgPath
        updateIndicatorLocation()
    }

    private func handleTouches(_ touches: Set<UITouch>, with event: UIEvent?) {
        let (w, h) = (bounds.width, bounds.height)
        if let touch = touches.first {
            let location = touch.location(in: self)
            if hitTest(location, with: event) == self {
                let x = 2.0 * (location.x / w) - 1.0
                let y = -2.0 * (location.y / h) + 1.0
                selectedLocation = (x, y)
                updateIndicatorLocation()
                valueChangeHandler?(value)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches, with: event)
    }
}
