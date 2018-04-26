//
//  SVM.h
//  OpenCV
//
//  Created by Carlo Rapisarda on 12/02/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef int SVMSampleType NS_TYPED_ENUM;
SVMSampleType extern const SVMSampleTypeRow;
SVMSampleType extern const SVMSampleTypeColumn;

typedef int SVMKernelType NS_TYPED_ENUM;
SVMKernelType extern const SVMKernelTypeCustom;
SVMKernelType extern const SVMKernelTypeLinear;
SVMKernelType extern const SVMKernelTypePolynomial;
SVMKernelType extern const SVMKernelTypeRbf;
SVMKernelType extern const SVMKernelTypeSigmoid;
SVMKernelType extern const SVMKernelTypeChi2;
SVMKernelType extern const SVMKernelTypeIntersection;

typedef int SVMType NS_TYPED_ENUM;
SVMType extern const SVMTypeCSVC;
SVMType extern const SVMTypeNuSVC;
SVMType extern const SVMTypeOneClass;
SVMType extern const SVMTypeEpsSVR;
SVMType extern const SVMTypeNuSVR;


@interface TrainingData: NSObject

/// Initializes the object with the given training samples and labels.
-(id _Nonnull) initWithSamples:(NSArray<NSArray<NSNumber *> *> *_Nonnull)samples
                         labels:(NSArray<NSNumber *> *_Nonnull)labels
                         layout:(SVMSampleType)layout;

/// Imports the data into the object. Will overwrite existing data.
-(void) importSamples:(NSArray<NSArray<NSNumber *> *> *_Nonnull)samples
               labels:(NSArray<NSNumber *> *_Nonnull)labels
               layout:(SVMSampleType)layout;

/// Async. imports the data into the object. Will overwrite existing data.
-(void) importSamples:(NSArray<NSArray<NSNumber *> *> *_Nonnull)samples
               labels:(NSArray<NSNumber *> *_Nonnull)labels
               layout:(SVMSampleType)layout
           completion:(void (^_Nonnull)())completion;

@end


@interface SVM: NSObject

@property (nonatomic, getter=getGamma, setter=setGamma:) double gamma;
@property (nonatomic, getter=getP, setter=setP:) double p;
@property (nonatomic, getter=getNu, setter=setNu:) double nu;
@property (nonatomic, getter=getC, setter=setC:) double c;
@property (nonatomic, getter=getKernel, setter=setKernel:) SVMKernelType kernel;
@property (nonatomic, getter=getType, setter=setType:) SVMType type;
@property (nonatomic, readonly, getter=isClassifier) BOOL isClassifier;
@property (nonatomic, readonly, getter=isTrained) BOOL isTrained;
@property (nonatomic, readonly, assign) BOOL isTraining;
@property (nonatomic, readonly, getter=getNumberOfFeatures) unsigned int numberOfFeatures;

/// Initializes a new SVM from a YAML file.
-(id _Nonnull) initFromFile:(NSString *_Nonnull)filepath;

/// Writes the serialized SVM to a YAML file. Will overwrite without warning.
-(void) writeToFile:(NSString *_Nonnull)filepath;

/// Trains the SVM with optimal parameters.
-(void) autoTrainWithTrainingData:(TrainingData *_Nonnull)trainingData;

/// Async. trains the SVM with optimal parameters.
-(void) autoTrainWithTrainingData:(TrainingData *_Nonnull)trainingData
                       completion:(void (^_Nonnull)())completion;

/// Trains the SVM with previously set custom parameters.
-(void) trainWithTrainingData:(TrainingData *_Nonnull)trainingData;

/// Async. trains the SVM with previously set custom parameters.
-(void) trainWithTrainingData:(TrainingData *_Nonnull)trainingData
                   completion:(void (^_Nonnull)())completion;

/// Returns the predicted class of a given sample.
-(float) predictOn:(NSArray<NSNumber *> *_Nonnull)sample;

/// Returns the accuracy of the current model with respect to the ground truth y
-(float) computeClassAccuracy:(NSArray<NSArray<NSNumber *> *>*_Nonnull)X y:(NSArray<NSNumber *> *_Nonnull)y;

/// Returns the Mean Square Error of the current model with respect to the ground truth y
-(double) computeMSE:(NSArray<NSArray<NSNumber *> *>*_Nonnull)X y:(NSArray<NSNumber *> *_Nonnull)y;

@end
