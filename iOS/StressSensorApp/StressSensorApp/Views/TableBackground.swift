//
//  TableBackground.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 02/03/2019.
//  Copyright © 2019 AssistiveTech KTH. All rights reserved.
//

import UIKit

class SimpleTableBackgroundView: UIView {

    private let label: UILabel
    private var button: UIButton?

    init(frame: CGRect, title: String, button: UIButton? = nil) {

        label = UILabel()
        self.button = button
        super.init(frame: frame)

        backgroundColor = UIColor.clear

        label.font = UIFont.systemFont(ofSize: 15.0)
        label.textColor = UIColor.lightGray
        label.text = title
        label.sizeToFit()
        addSubview(label)

        if let button = button {
            button.titleLabel?.font = .boldSystemFont(ofSize: 15.0)
            button.setTitleColor(.lightGray, for: .normal)
            button.sizeToFit()
            addSubview(button)
        }
    }

    private override init(frame: CGRect) {
        label = UILabel()
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        label.center = CGPoint(x: frame.width/2.0, y: frame.height/2.0)
        if let button = button {
            let buttonY = label.frame.maxY + 0.0
            button.center = CGPoint(x: frame.width/2.0, y: frame.height/2.0)
            button.frame = CGRect(x: button.frame.origin.x, y: buttonY, width: button.frame.width, height: button.frame.height)
        }
    }
}
