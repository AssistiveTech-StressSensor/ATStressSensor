//
//  SVM.mm
//  OpenCV
//
//  Created by Carlo Rapisarda on 12/02/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

#include <opencv2/core/core.hpp>
#include <opencv2/ml/ml.hpp>
#import "SVM.h"

using namespace std;
using namespace cv;

#define fatal(arg) [NSException raise:@"SVM fatal error" format:(arg)];
Mat samplesToMat(NSArray<NSArray<NSNumber *> *> *_Nonnull samples);
cv::String CVStringFromNSString(NSString *str);

SVMSampleType const SVMSampleTypeRow = 0;
SVMSampleType const SVMSampleTypeColumn = 1;

SVMKernelType const SVMKernelTypeCustom = -1;
SVMKernelType const SVMKernelTypeLinear = 0;
SVMKernelType const SVMKernelTypePolynomial = 1;
SVMKernelType const SVMKernelTypeRbf = 2;
SVMKernelType const SVMKernelTypeSigmoid = 3;
SVMKernelType const SVMKernelTypeChi2 = 4;
SVMKernelType const SVMKernelTypeIntersection = 5;

SVMType const SVMTypeCSVC = 100;
SVMType const SVMTypeNuSVC = 101;
SVMType const SVMTypeOneClass = 102;
SVMType const SVMTypeEpsSVR = 103;
SVMType const SVMTypeNuSVR = 104;


#pragma mark - TrainingData

@interface TrainingData()
@property Ptr<ml::TrainData> trainData;
@end

@implementation TrainingData

-(id _Nonnull) initWithSamples:(NSArray<NSArray<NSNumber *> *> *_Nonnull)samples
                        labels:(NSArray<NSNumber *> *_Nonnull)labels
                        layout:(SVMSampleType)layout {
    if (self = [super init]) {
        [self importSamples:samples labels:labels layout:layout];
    }
    return self;
}

-(id _Nonnull) init {
    return [super init];
}

-(void) importSamples:(NSArray<NSArray<NSNumber *> *> *_Nonnull)samples
               labels:(NSArray<NSNumber *> *_Nonnull)labels
               layout:(SVMSampleType)layout {

    int nSamples = (int)samples.count;
    int nLabels = (int)labels.count;
    if (nSamples < 1) {
        // ERROR!
        fatal(@"Number of samples must be > 0");
    }
    if (nLabels != nSamples) {
        // ERROR!
        fatal(@"Number of samples must be equal to number of labels");
    }
    int nFeatures = (int)samples[0].count;
    if (nFeatures < 1) {
        // ERROR!
        fatal(@"Number of features must be > 0");
    }
    Mat samplesMat(nSamples, nFeatures, CV_32FC1);
    vector<int> labelsVec;
    for (int i = 0; i<nSamples; ++i) {
        NSArray<NSNumber *> *sample = samples[i];
        NSNumber *label = labels[i];
        if (label == nil) {
            // ERROR!
            fatal(@"Found nil when reading label value");
        }
        if (sample.count != nFeatures) {
            // ERROR!
            fatal(@"Number of features must be equal for all samples");
        }
        for (int j = 0; j<nFeatures; ++j) {
            NSNumber *val = sample[j];
            if (val == nil) {
                // ERROR!
                fatal(@"Found nil when reading sample value");
            }
            samplesMat.at<float>(i,j) = val.floatValue;
        }
        labelsVec.push_back(label.intValue);
    }
    self.trainData = ml::TrainData::create(samplesMat, layout, labelsVec);
}

-(void) importSamples:(NSArray<NSArray<NSNumber *> *> *_Nonnull)samples
               labels:(NSArray<NSNumber *> *_Nonnull)labels
               layout:(SVMSampleType)layout
           completion:(void (^_Nonnull)())completion {

    NSOperationQueue *prevQueue = [NSOperationQueue currentQueue];
    if (prevQueue == nil) {
        prevQueue = [NSOperationQueue mainQueue];
    }
    __weak TrainingData *weakSelf = self;
    [[NSOperationQueue new] addOperationWithBlock:^{
        [weakSelf importSamples:samples labels:labels layout:layout];
        [prevQueue addOperationWithBlock:completion];
    }];
}

@end


#pragma mark - SVM

@interface SVM()
@property Ptr<ml::SVM> svm;
@property (atomic, readwrite, assign) BOOL isTraining;
@end

@implementation SVM

-(id) init {
    if (self = [super init]) {
        self.svm = ml::SVM::create();
        self.isTraining = false;
    }
    return self;
}

-(id _Nonnull) initFromFile:(NSString *_Nonnull)filepath {
    if (self = [super init]) {
        cv::String cvStr = CVStringFromNSString(filepath);
        self.svm = ml::SVM::load(cvStr);
    }
    return self;
}

-(void) writeToFile:(NSString *_Nonnull)filepath {
    if (self.isTraining) { fatal(@"SVM cannot be written to file during training"); }
    cv::String cvStr = CVStringFromNSString(filepath);
    _svm->save(cvStr);
}

-(unsigned int) getNumberOfFeatures {
    return _svm->getVarCount();
}

-(BOOL) isClassifier {
    return _svm->isClassifier();
}

-(BOOL) isTrained {
    return _svm->isTrained();
}

-(double) getGamma {
    return _svm->getGamma();
}

-(void) setGamma:(double)gamma {
    if (self.isTraining) { fatal(@"SVM parameters must not change during training"); }
    _svm->setGamma(gamma);
}

-(double) getP {
    return _svm->getP();
}

-(void) setP:(double)P {
    if (self.isTraining) { fatal(@"SVM parameters must not change during training"); }
    _svm->setP(P);
}

-(double) getNu {
    return _svm->getNu();
}

-(void) setNu:(double)Nu {
    if (self.isTraining) { fatal(@"SVM parameters must not change during training"); }
    _svm->setNu(Nu);
}

-(double) getC {
    return _svm->getC();
}

-(void) setC:(double)c {
    if (self.isTraining) { fatal(@"SVM parameters must not change during training"); }
    _svm->setC(c);
}

-(SVMKernelType) getKernel {
    return _svm->getKernelType();
}

-(void) setKernel:(SVMKernelType)kernel {
    if (self.isTraining) { fatal(@"SVM parameters must not change during training"); }
    _svm->setKernel(kernel);
}

-(SVMType) getType {
    return _svm->getType();
}

-(void) setType:(SVMType)type {
    if (self.isTraining) { fatal(@"SVM parameters must not change during training"); }
    _svm->setType(type);
}

-(void) trainWithTrainingData:(TrainingData *_Nonnull)trainingData {
    if (self.isTraining) { fatal(@"SVM is already being trained"); }
    Ptr<ml::TrainData> trainData = trainingData.trainData;
    self.isTraining = true;
    _svm->train(trainData);
    self.isTraining = false;
}

-(void) trainWithTrainingData:(TrainingData *_Nonnull)trainingData
                   completion:(void (^_Nonnull)())completion {
    if (self.isTraining) { fatal(@"SVM is already being trained"); }
    self.isTraining = true;
    NSOperationQueue *prevQueue = [NSOperationQueue currentQueue];
    if (prevQueue == nil) {
        prevQueue = [NSOperationQueue mainQueue];
    }
    __weak SVM *weakSelf = self;
    [[NSOperationQueue new] addOperationWithBlock:^{
        Ptr<ml::TrainData> trainData = trainingData.trainData;
        weakSelf.svm->train(trainData);
        weakSelf.isTraining = false;
        [prevQueue addOperationWithBlock:completion];
    }];
}

-(void) autoTrainWithTrainingData:(TrainingData *_Nonnull)trainingData {
    if (self.isTraining) { fatal(@"SVM is already being trained"); }
    Ptr<ml::TrainData> trainData = trainingData.trainData;
    self.isTraining = true;
    _svm->trainAuto(trainData);
    self.isTraining = false;
}

-(void) autoTrainWithTrainingData:(TrainingData *_Nonnull)trainingData
                       completion:(void (^_Nonnull)())completion {
    if (self.isTraining) { fatal(@"SVM is already being trained"); }
    self.isTraining = true;
    NSOperationQueue *prevQueue = [NSOperationQueue currentQueue];
    if (prevQueue == nil) {
        prevQueue = [NSOperationQueue mainQueue];
    }
    __weak SVM *weakSelf = self;
    [[NSOperationQueue new] addOperationWithBlock:^{
        Ptr<ml::TrainData> trainData = trainingData.trainData;
        weakSelf.svm->trainAuto(trainData);
        weakSelf.isTraining = false;
        [prevQueue addOperationWithBlock:completion];
    }];
}

-(float) predictOn:(NSArray<NSNumber *> *_Nonnull)sample {
    if (self.isTraining) { fatal(@"SVM cannot predict while being trained"); }
    NSArray *matrix = [NSArray arrayWithObject:sample];
    Mat samplesMat = samplesToMat(matrix);
    return _svm->predict(samplesMat);
}

-(float) computeClassAccuracy:(NSArray<NSArray<NSNumber *> *>*_Nonnull)X y:(NSArray<NSNumber *> *_Nonnull)y {
    if (self.isTraining) { fatal(@"SVM cannot predict while being trained"); }
    double correctPredictions = 0.0;
    for (int i = 0; i<X.count; ++i) {
        float p = [self predictOn: X[i]];
        if (p == y[i].floatValue) {
            correctPredictions += 1.0;
        }
    }
    return correctPredictions / X.count;
}

-(double) computeMSE:(NSArray<NSArray<NSNumber *> *>*_Nonnull)X y:(NSArray<NSNumber *> *_Nonnull)y {
    if (self.isTraining) { fatal(@"SVM cannot predict while being trained"); }
    double sumOfSqErr = 0.0;
    for (int i = 0; i<X.count; ++i) {
        float p = [self predictOn: X[i]];
        double err = abs(p - y[i].floatValue);
        sumOfSqErr += pow(err, 2.0);
    }
    return sumOfSqErr / X.count;
}

@end


#pragma mark - Utilities

Mat samplesToMat(NSArray<NSArray<NSNumber *> *> *_Nonnull samples) {

    int nSamples = (int)samples.count;
    if (nSamples < 1) {
        // ERROR!
        fatal(@"Number of samples must be > 0");
    }
    int nFeatures = (int)samples[0].count;
    if (nFeatures < 1) {
        // ERROR!
        fatal(@"Number of features must be > 0");
    }
    Mat samplesMat(nSamples, nFeatures, CV_32FC1);

    for (int i = 0; i<nSamples; ++i) {
        NSArray<NSNumber *> *sample = samples[i];

        if (sample.count != nFeatures) {
            // ERROR!
            fatal(@"Number of features must be equal for all samples");
        }
        for (int j = 0; j<nFeatures; ++j) {
            NSNumber *val = sample[j];
            if (val == nil) {
                // ERROR!
                fatal(@"Found nil when reading sample value");
            }
            samplesMat.at<float>(i,j) = val.floatValue;
        }
    }

    return samplesMat;
}

cv::String CVStringFromNSString(NSString *str) {
    const char *cStr = [str cStringUsingEncoding:NSUTF8StringEncoding];
    return cv::String(cStr);
}
