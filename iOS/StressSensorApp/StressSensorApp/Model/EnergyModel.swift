//
//  EnergyModel.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 15/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation
import PromiseKit

typealias EnergyLevel = Double

struct PhysicalEnergy: ExpressibleByFloatLiteral {

    let value: Double
    var percentage: Double { return value * 100.0 }

    init(floatLiteral value: Double) {
        self.value = value
    }

    init(withEnergyLevel level: EnergyLevel) {
        self.value = PhysicalEnergy.fromEnergyLevel(level)
    }

    static func fromEnergyLevel(_ level: EnergyLevel) -> Double {
        return 1.0 - ((level - 0.2) / 0.8)
    }
}

/// Dataset object used by the model
class EnergyModelData: Codable {

    struct Couple: Codable {
        let sample: ModelSample, label: EnergyLevel
    }

    /// All model entries coupled as (sample, label), wrapped in a struct
    var couples: [Couple]

    /// All model entries coupled as (sample, label), sorted by recording time (oldest first)
    var sortedCouples: [Couple] {
        return couples.sorted { $0.sample.timestampEnd < $1.sample.timestampEnd }
    }

    /// Total number of entries
    var count: Int {
        return couples.count
    }

    /// The entry that was recorded last
    var latestCouple: Couple? {
        return sortedCouples.last
    }

    /// Returns an SVR-friendly object to be used for training
    var svrTrainingData: TrainingData {

        var samples = [[NSNumber]]()
        var labels = [NSNumber]()

        couples.forEach { c in
            samples.append(c.sample.values)
            labels.append(c.label as NSNumber)
        }

        return TrainingData(samples: samples, labels: labels, layout: .row)
    }

    /// Inits the object with an empty dataset
    init() {
        self.couples = []
    }

    /// Inits the object with a given dataset
    private init(with couples: [Couple]) {
        self.couples = couples
    }

    /// Inits the object from a file at the specified path
    init?(from filepath: String) {
        let url = URL(fileURLWithPath: filepath)
        guard FileManager().fileExists(atPath: filepath),
        let data = try? Data(contentsOf: url),
        let decoded = try? JSONDecoder().decode(EnergyModelData.self, from: data)
        else { return nil }

        self.couples = decoded.couples
    }

    /// Writes the encoded data into a file at the specified path
    func write(to filepath: String) {
        let url = URL(fileURLWithPath: filepath)
        let encoded = try? JSONEncoder().encode(self)
        try? encoded?.write(to: url, options: .atomic)
    }

    /// Appends the given (sample, label) couple to the current dataset
    func append(_ sample: ModelSample, _ energyLevel: EnergyLevel) {
        couples.append(Couple(sample: sample, label: energyLevel))
    }

    /// Keys to be used for serialization
    enum CodingKeys: String, CodingKey {
        case couples
    }

    /// Inits the object from a serialized form
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        couples = try values.decode(Array.self, forKey: .couples)
    }

    /// Returns a serialized copy of the object
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(couples, forKey: .couples)
    }
}

/// Class to train the model and predict energy levels
class EnergyModel {

    /// Singleton of the model, to be used for all operations
    private(set) static var main = EnergyModel()

    /// Dataset of the model
    private(set) var data = EnergyModelData()

    /// SVR wrapper object
    private var svr = initSVR()

    /// UserDefaults key for the date of latest training
    private let latestTrainingDateKey = "energyModel.latestTraining"

    /// Full path to the JSON file of the dataset
    private let dataPath: String = {
        return "\(Constants.documentsPath)/dataset_energy.json"
    }()

    /// Full path to the YAML file of the SVR model
    private let svrPath: String = {
        return "\(Constants.documentsPath)/svr_energy.yml"
    }()

    private static func initSVR() -> SVM {
        let svr = SVM()
        svr.type = .epsSVR
        // TODO: Are these good parameters?
        svr.p = 1.0
        svr.c = 2.0
        return svr
    }

    /// Full path to the JSON file of the dataset, if present on disk
    func dataPathIfAvailable() -> String? {
        return FileManager().fileExists(atPath: dataPath) ? dataPath : nil
    }

    /// Full path to the YAML file of the SVR model, if present on disk
    func svrPathIfAvailable() -> String? {
        return FileManager().fileExists(atPath: svrPath) ? svrPath : nil
    }

    /// Number of samples
    var samplesCount: Int {
        return data.count
    }

    /// Whether or not the model has been trained so far
    var isTrained: Bool {
        return svr.isTrained
    }

    /// Length in seconds of the signal window to be used for the model
    var windowLength: TimeInterval {
        return Constants.modelWindowLength
    }

    /// Date of the sample added last, nil if there are no samples
    var dateOfLatestSample: Date? {
        if let timestamp = data.latestCouple?.sample.timestampEnd {
            return Date(timeIntervalSince1970: timestamp)
        } else {
            return nil
        }
    }

    /// The date of latest training
    var dateOfLatestTraining: Date? {
        return UserDefaults().value(forKey: latestTrainingDateKey) as? Date
    }

    /// Number of samples that have been added since the last time the model was trained
    var numberOfSamplesAhead: Int {
        if let cached = _numberOfSamplesAhead {
            return cached
        } else if let trainingTS = dateOfLatestTraining?.timeIntervalSince1970 {
            let ahead = data.sortedCouples.filter { $0.sample.timestampEnd > trainingTS }
            _numberOfSamplesAhead = ahead.count
        } else {
            _numberOfSamplesAhead = data.count
        }
        return _numberOfSamplesAhead!
    }

    /// Cached value of numberOfSamplesAhead
    private var _numberOfSamplesAhead: Int?

    /// Whether or not the candidate should wait to add a new sample
    var cooldown: Bool {
        let length = Constants.cooldownLength
        if let cooldownDate = dateOfLatestSample?.addingTimeInterval(length) {
            return cooldownDate > Date()
        } else {
            return false
        }
    }

    var canBeTrained: Bool {
        // FIXME: How to determine when we have enough data for regression?
        let minNum = Constants.minSamplesPerClass
        return (samplesCount > minNum && numberOfSamplesAhead > 0)
    }

    /// Must be called before any other instance method of this class
    func setup() {
        importSVR()
        importTrainingData()
    }

    /// Reads and imports the SVR model from a YAML file
    private func importSVR() {
        if FileManager().fileExists(atPath: svrPath) {
            svr = SVM(fromFile: svrPath)
        } else {
            print("Tried to import SVR but no file was found")
        }
    }

    /// Writes the current SVR model to a YAML file
    private func exportSVR() {
        svr.write(toFile: svrPath)
    }

    /// Reads and imports the SVR model samples from a JSON file
    private func importTrainingData() {
        if let data = EnergyModelData(from: dataPath) {
            self.data = data
        } else {
            print("Tried to import training data but no file was found")
        }
    }

    /// Adds a sample to the model. This will *not* trigger training automatically
    @discardableResult
    func addSample(snapshot: SignalsSnapshot, for energyLevel: EnergyLevel) -> ModelSample {
        let sample = ModelSample(snapshot: snapshot)
        data.append(sample, energyLevel)
        data.write(to: dataPath)
        _numberOfSamplesAhead = (_numberOfSamplesAhead ?? 0) + 1
        return sample
    }

    /// Removes all files of the model from disk, and clears the related instance variables
    func clear() {
        let fm = FileManager()
        try? fm.removeItem(atPath: svrPath)
        try? fm.removeItem(atPath: dataPath)
        data = EnergyModelData()
        svr = EnergyModel.initSVR()
        UserDefaults().setValue(nil, forKey: latestTrainingDateKey)
        _numberOfSamplesAhead = nil
    }

    /// Trains async. the model with the provided dataset
    func train() -> Guarantee<Void> {
        let trainingData = data.svrTrainingData
        return Guarantee { [unowned self] seal in
            svr.train(with: trainingData) {
                DispatchQueue.main.async {
                    UserDefaults().setValue(Date(), forKey: self.latestTrainingDateKey)
                }
                self._numberOfSamplesAhead = 0
                self.exportSVR()
                seal(())
            }
        }
    }

    /// Returns a predicted stress level based on the current trained model and the given snapshot
    func predict(on snapshot: SignalsSnapshot) -> EnergyLevel {
        let sample = ModelSample(snapshot: snapshot)
        print("Trying to predict with sample:")
        print(sample)
        let rawPred = svr.predict(on: sample.values)
        print("Result: \(rawPred)")
        return EnergyLevel(rawPred)
    }
}
