//
//  LiveChart.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 08/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit
import Charts

private class LiveChartValueFormatter: NSObject, IAxisValueFormatter {

    private var numberFormatter: NumberFormatter!

    static let yAxis: LiveChartValueFormatter = {
        let lcvf = LiveChartValueFormatter()
        let f = NumberFormatter()
        f.decimalSeparator = "."
        f.groupingSeparator = ""
        f.allowsFloats = true
        f.minimumFractionDigits = 1
        f.minimumIntegerDigits = 1
        f.maximumFractionDigits = 3
        lcvf.numberFormatter = f
        return lcvf
    }()

    static let xAxis: LiveChartValueFormatter = {
        let lcvf = LiveChartValueFormatter()
        let f = NumberFormatter()
        f.decimalSeparator = "."
        f.groupingSeparator = ""
        f.allowsFloats = true
        f.minimumFractionDigits = 1
        f.minimumIntegerDigits = 1
        f.maximumFractionDigits = 2
        lcvf.numberFormatter = f
        return lcvf
    }()

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        return numberFormatter.string(from: (value as NSNumber)) ?? "\(value)"
    }
}

class LiveChart: UIView {

    private(set) var dataset: LineChartDataSet = {
        let ds = LineChartDataSet(values: [ChartDataEntry](), label: nil)
        ds.drawCirclesEnabled = false
        ds.drawValuesEnabled = false
        ds.mode = .linear
        ds.lineWidth = 2.0
        ds.setColor(.red)
        return ds
    }()

    private(set) var lineChart: LineChartView = {
        let c = LineChartView(frame: .zero)
        c.chartDescription?.text = nil
        c.getAxis(.left).valueFormatter = LiveChartValueFormatter.yAxis
        c.getAxis(.right).valueFormatter = LiveChartValueFormatter.yAxis
        c.xAxis.valueFormatter = LiveChartValueFormatter.xAxis
        return c
    }()

    var maxDataPoints: Int = 100
    var useSensorTimestamp: Bool = false
    var outOfRangeGuard: Bool = false

    let xMinWhenNoData: Double = 0.0
    let xMaxWhenNoData: Double = 0.01

    var title: String? {
        get { return lineChart.chartDescription?.text }
        set { lineChart.chartDescription?.text = newValue }
    }

    var signalLabel: String? {
        get { return dataset.label }
        set { dataset.label = newValue }
    }

    var lineColor: UIColor? {
        get { return dataset.colors.first }
        set { dataset.setColor(newValue ?? .clear) }
    }

    private var maxExpYvalue: Double?
    private var minExpYvalue: Double?

    func setup() {

        if lineChart.superview == nil {
            lineChart.translatesAutoresizingMaskIntoConstraints = false
            addSubview(lineChart)
            self.addConstraints([
                NSLayoutConstraint(item: lineChart, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: lineChart, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: lineChart, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: lineChart, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0.0)
            ])
            lineChart.xAxis.axisMinimum = xMinWhenNoData
            lineChart.xAxis.axisMaximum = xMaxWhenNoData
            lineChart.data = LineChartData(dataSets: [dataset])
            lineChart.setVisibleXRange(minXRange: 0.0, maxXRange: 50.0)
        }
    }

    func resetMinY(axis: YAxis.AxisDependency? = nil) {
        if let axis = axis {
            lineChart.getAxis(axis).resetCustomAxisMin()
        } else {
            lineChart.getAxis(.left).resetCustomAxisMin()
            lineChart.getAxis(.right).resetCustomAxisMin()
        }
        minExpYvalue = nil
    }

    func resetMaxY(axis: YAxis.AxisDependency? = nil) {
        if let axis = axis {
            lineChart.getAxis(axis).resetCustomAxisMax()
        } else {
            lineChart.getAxis(.left).resetCustomAxisMax()
            lineChart.getAxis(.right).resetCustomAxisMax()
        }
        maxExpYvalue = nil
    }

    func resetRangeY(axis: YAxis.AxisDependency? = nil) {
        resetMinY(axis: axis)
        resetMaxY(axis: axis)
    }

    func setMinY(_ minY: Double, axis: YAxis.AxisDependency? = nil) {
        lineChart.autoScaleMinMaxEnabled = false
        if let axis = axis {
            lineChart.getAxis(axis).axisMinimum = minY
        } else {
            lineChart.getAxis(.left).axisMinimum = minY
            lineChart.getAxis(.right).axisMinimum = minY
        }
        minExpYvalue = minY
    }

    func setMaxY(_ maxY: Double, axis: YAxis.AxisDependency? = nil) {
        lineChart.autoScaleMinMaxEnabled = false
        if let axis = axis {
            lineChart.getAxis(axis).axisMaximum = maxY
        } else {
            lineChart.getAxis(.left).axisMaximum = maxY
            lineChart.getAxis(.right).axisMaximum = maxY
        }
        maxExpYvalue = maxY
    }

    func setRangeY(min: Double, max: Double, axis: YAxis.AxisDependency? = nil) {
        setMinY(min, axis: axis)
        setMaxY(max, axis: axis)
    }

    func clear() {
        dataset.clear()
        lineChart.xAxis.axisMinimum = xMinWhenNoData
        lineChart.xAxis.axisMaximum = xMaxWhenNoData
        lineChart.data?.notifyDataChanged()
        lineChart.notifyDataSetChanged()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        setup()
    }

    func addDataPoint(value: Double, timestamp: Double) {

        if dataset.entryCount == 0 {
            lineChart.xAxis.resetCustomAxisMin()
            lineChart.xAxis.resetCustomAxisMax()
        }

        if outOfRangeGuard, let min = minExpYvalue, let max = maxExpYvalue {
            if value > max || value < min {
                title = "Out of range"
            } else {
                title = nil
            }
        }

        let newEntry = ChartDataEntry(x: timestamp, y: value)
        lineChart.data?.addEntry(newEntry, dataSetIndex: 0)

        if dataset.entryCount > maxDataPoints {
            let oldEntry = dataset.entryForIndex(0)!
            lineChart.data?.removeEntry(oldEntry, dataSetIndex: 0)
        }

        lineChart.notifyDataSetChanged()
    }

    func addSample(_ sample: SignalSample, sequenceTS: Double) {
        if useSensorTimestamp {
            addDataPoint(value: sample.value, timestamp: sample.timestamp)
        } else {
            addDataPoint(value: sample.value, timestamp: sequenceTS)
        }
    }
}
