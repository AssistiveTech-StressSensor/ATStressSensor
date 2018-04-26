//
//  StressModel.swift
//  StressSensorApp
//
//  Created by Carlo Rapisarda on 15/02/2018.
//  Copyright © 2018 AssistiveTech KTH. All rights reserved.
//

import Foundation

/// Sleep quality 'index' ranging from 0.0 (poor) to 2.0 (good)
typealias SleepQuality = Double

/// Food intake 'index' ranging from 0.0 (poor) to 2.0 (good)
typealias FoodIntake = Double

/// Classes of the stress model. Possible values are 0.0 for no stress, 1.0 for stress
enum StressLevel: Double, Codable {
    case notStressed = 0.0
    case stressed = 1.0

    var description: String {
        switch self {
        case .stressed:
            return "Stressed"
        case .notStressed:
            return "Not stressed"
        }
    }
}

/// Dataset object used by the model
class StressModelData: Codable {

    struct Couple: Codable {
        let sample: ModelSample, label: StressLevel
    }

    /// All model entries coupled as (sample, label), wrapped in a struct
    var couples: [Couple] {
        didSet { invalidateCounters() }
    }

    private var _stressedCount: Int?
    private var _notStressedCount: Int?

    /// Number of samples of the 'stressed' class
    var stressedCount: Int {
        if _stressedCount == nil {
            _stressedCount = couples.filter { $0.label == .stressed }.count
        }
        return _stressedCount!
    }

    /// Number of samples of the 'not stressed' class
    var notStressedCount: Int {
        if _notStressedCount == nil {
            _notStressedCount = couples.filter { $0.label == .notStressed }.count
        }
        return _notStressedCount!
    }

    /// Total number of entries
    var count: Int {
        return couples.count
    }

    /// Returns an SVM-friendly object to be used for training
    var svmTrainingData: TrainingData {

        var samples = [[NSNumber]]()
        var labels = [NSNumber]()

        couples.forEach { c in
            samples.append(c.sample.values)
            labels.append(c.label.rawValue as NSNumber)
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
        let decoded = try? JSONDecoder().decode(StressModelData.self, from: data)
        else { return nil }

        self.couples = decoded.couples
    }

    /// Writes the encoded data into a file at the specified path
    func write(to filepath: String) {
        let url = URL(fileURLWithPath: filepath)
        let encoded = try? JSONEncoder().encode(self)
        try? encoded?.write(to: url, options: .atomic)
    }

    /// Returns a new object with balanced classes
    func balanced() -> StressModelData {

        // Separate the samples
        var couplesCopy = Array(couples)
        let stressedSamples = couplesCopy.filter { $0.label == .stressed }
        let notStressedSamples = couplesCopy.filter { $0.label == .notStressed }

        // Compute the imbalance
        let countDiff = stressedSamples.count - notStressedSamples.count

        if countDiff == 0 {
            // No class imbalance, return copy of the current dataset
            return StressModelData(with: couplesCopy)
        }

        // Decide which of the two classes needs to be enlarged
        let samplesToDuplicate: [Couple] = {
            return (countDiff > 0 ? notStressedSamples : stressedSamples)
        }()

        // Choose samples randomly and append them to the dataset
        for _ in 0..<abs(countDiff) {
            let randomSample = samplesToDuplicate.random()!
            couplesCopy.append(randomSample)
        }

        // Return dataset as a StressModelData object
        return StressModelData(with: couplesCopy)
    }

    /// Appends the given (sample, label) couple to the current dataset
    func append(_ sample: ModelSample, _ stressLevel: StressLevel) {
        couples.append(Couple(sample: sample, label: stressLevel))
    }

    /// Sets the class counters to nil so that they will need to be recomputed
    private func invalidateCounters() {
        _stressedCount = nil
        _notStressedCount = nil
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

/// Class to train the model and predict stress levels
class StressModel {

    /// Singleton of the model, to be used for all operations
    private(set) static var main = StressModel()

    /// Dataset of the model
    private(set) var data = StressModelData()

    /// SVM wrapper object
    private var svm = SVM()

    /// Full path to the JSON file of the dataset
    private let dataPath: String = {
        return "\(Constants.documentsPath)/dataset.json"
    }()

    /// Full path to the YAML file of the SVM model
    private let svmPath: String = {
        return "\(Constants.documentsPath)/svm.yml"
    }()

    /// Full path to the JSON file of the dataset, if present on disk
    func dataPathIfAvailable() -> String? {
        return FileManager().fileExists(atPath: dataPath) ? dataPath : nil
    }

    /// Full path to the YAML file of the SVM model, if present on disk
    func svmPathIfAvailable() -> String? {
        return FileManager().fileExists(atPath: svmPath) ? svmPath : nil
    }

    /// Whether or not the model has been trained so far
    var isTrained: Bool {
        return svm.isTrained
    }

    /// Number of samples of the 'stressed' class
    var stressedCount: Int {
        return data.stressedCount
    }

    /// Number of samples of the 'not stressed' class
    var notStressedCount: Int {
        return data.notStressedCount
    }

    /// Length in seconds of the signal window to be used for the model
    var windowLength: TimeInterval {
        return Constants.modelWindowLength
    }

    /// Must be called before any other instance method of this class
    func setup() {
        importSVM()
        importTrainingData()
    }

    /// Reads and imports the SVM model from a YAML file
    private func importSVM() {
        if FileManager().fileExists(atPath: svmPath) {
            svm = SVM(fromFile: svmPath)
        } else {
            print("Tried to import SVM but no file was found")
        }
    }

    /// Writes the current SVM model to a YAML file
    private func exportSVM() {
        svm.write(toFile: svmPath)
    }

    /// Reads and imports the SVM model samples from a JSON file
    private func importTrainingData() {
        if let data = StressModelData(from: dataPath) {
            self.data = data
        } else {
            print("Tried to import training data but no file was found")
        }
    }

    /// Adds a sample to the model. This will *not* trigger training automatically
    @discardableResult
    func addSample(snapshot: SignalsSnapshot, for stressLevel: StressLevel) -> ModelSample {
        let sample = ModelSample(snapshot: snapshot)
        data.append(sample, stressLevel)
        data.write(to: dataPath)
        return sample
    }

    /// Removes all files of the model from disk, and clears the related instance variables
    func clear() {
        let fm = FileManager()
        try? fm.removeItem(atPath: svmPath)
        try? fm.removeItem(atPath: dataPath)
        data = StressModelData()
        svm = SVM()
    }

    /// Trains async. the model with the provided dataset
    func train(completion: @escaping () -> ()) {
        let trainingData = data.balanced().svmTrainingData
        svm.autoTrain(with: trainingData) { [unowned self] in
            self.exportSVM()
            completion()
        }
    }

    /// Returns a predicted stress level based on the current trained model and the given snapshot
    func predict(on snapshot: SignalsSnapshot) -> StressLevel {
        let sample = ModelSample(snapshot: snapshot)
        print("Trying to predict with sample:")
        print(sample)
        let rawPred = svm.predict(on: sample.values)
        print("Result: \(rawPred)")
        return StressLevel(rawValue: Double(rawPred))!
    }
}
