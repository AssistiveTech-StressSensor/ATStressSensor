//
//  StressChart.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 07/03/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import UIKit
import Charts

private class StressChartValueFormatter: NSObject, IAxisValueFormatter {

    private var dayFormatter: DateFormatter!
    private var hourFormatter: DateFormatter!

    static let yAxis = StressChartValueFormatter()

    static let xAxis: StressChartValueFormatter = {
        let scvf = StressChartValueFormatter()

        let hf = DateFormatter()
        // hf.locale = Locale(identifier: "en-US")
        hf.dateStyle = .none
        hf.timeStyle = .medium
        scvf.hourFormatter = hf

        let df = DateFormatter()
        // df.locale = Locale(identifier: "en-US")
        df.dateStyle = .short
        df.timeStyle = .none
        scvf.dayFormatter = df

        return scvf
    }()

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {

        if let axis = axis as? XAxis {

            let date = Date(timeIntervalSince1970: value)
            let actualRange = abs((axis.entries.first ?? 0.0) - (axis.entries.last ?? 0.0))

            if actualRange < 3600*12 {
                // less than one day
                return hourFormatter.string(from: date)
            } else {
                // multiple days
                return dayFormatter.string(from: date)
            }

        } else if (axis as? YAxis)?.axisDependency == .right {
            return " " + (round(value) == 1.0 ? "🤯" : "🤩")
        } else {
            return ""
        }
    }
}

class StressChart: UIView {

    private(set) var dataset: ScatterChartDataSet = {
        let ds = ScatterChartDataSet(values: [ChartDataEntry](), label: nil)
        ds.setScatterShape(.circle)
        ds.drawValuesEnabled = false
        ds.scatterShapeSize = 15.0
        ds.label = "Stress level"
        ds.setColor(.orange)
        // ds.mode = .stepped
        // ds.lineWidth = 2.0
        // ds.drawCirclesEnabled = true
        return ds
    }()

    private(set) var chart: ScatterChartView = {
        let c = ScatterChartView(frame: .zero)
        c.chartDescription?.text = nil
        c.getAxis(.left).valueFormatter = StressChartValueFormatter.yAxis
        c.getAxis(.right).valueFormatter = StressChartValueFormatter.yAxis
        c.xAxis.valueFormatter = StressChartValueFormatter.xAxis
        return c
    }()

    let xMinWhenNoData: Double = 1.0
    let xMaxWhenNoData: Double = 3600.0

    override func draw(_ rect: CGRect) {

        if chart.superview == nil {

            addSubview(chart)

            chart.setViewPortOffsets(left: 20, top: 70, right: 40, bottom: 30)
            chart.autoScaleMinMaxEnabled = false
            chart.scaleYEnabled = false
            chart.dragDecelerationEnabled = true
            chart.highlightPerDragEnabled = false
            chart.highlightPerTapEnabled = false

            let yAxis = chart.getAxis(.right)
            yAxis.granularityEnabled = true
            yAxis.granularity = 1.0
            yAxis.axisMaximum = 1.0
            yAxis.axisMinimum = 0.0
            yAxis.labelFont = .systemFont(ofSize: 18.0)

            let xAxis = chart.xAxis
            xAxis.labelRotationAngle = -90.0
        }

        chart.frame = rect.bounds
    }

    func addSample(_ stressLevel: StressLevel, date: Date) {

        if chart.data == nil {
            chart.data = ScatterChartData(dataSets: [dataset])
        }

        chart.data?.addEntry(ChartDataEntry(
            x: date.timeIntervalSince1970,
            y: stressLevel.rawValue
        ), dataSetIndex: 0)
        chart.notifyDataSetChanged()
    }
}
