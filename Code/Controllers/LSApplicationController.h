//
//  LSAppController.h
//  LayerSample
//
//  Created by Kevin Coleman on 6/30/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <LayerKit/LayerKit.h>
#import "LSAPIManager.h"

/**
 @abstract The `LSAppController` class manages mission critical classes to the Layer Sample App
 */

@interface LSApplicationController : NSObject

///--------------------------------
/// @name Initializing a Controller
///--------------------------------

+ (instancetype)controllerWithBaseURL:(NSURL *)baseURL layerClient:(LYRClient *)layerClient persistenceManager:(LSPersistenceManager *)persistenceManager;

/**
 @abstract The following properties service mission critical operations for the Layer Sample App and are managed by the Controller
 */

@property (nonatomic) LYRClient *layerClient;
@property (nonatomic) LSAPIManager *APIManager;
@property (nonatomic) LSPersistenceManager *persistenceManager;
@property (nonatomic) NSData *deviceToken;

@property (nonatomic) BOOL shouldSendPushText;
@property (nonatomic) BOOL shouldSendPushSound;
@property (nonatomic) BOOL debugModeEnabled;

/**
 *  Constructs and returns a version string describing the current version of the application.
 *
 *  @return The version string suitable for display in the app.
 */
+ (NSString *)versionString;

/**
 *  Constructs and returns a build string describing the context in which the app was built.
 *
 *  @return The build string suitable for display in the app.
 */
+ (NSString *)buildInformationString;

+ (NSString *)layerServerHostname;

@end
