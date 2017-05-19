//
//  MMHTTPTaskQueueHandler.h
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//


#import <MMNetworkTaskQueue.h>

NS_ASSUME_NONNULL_BEGIN

@interface MMHTTPTaskQueueHandler : NSObject<MMNetworkTaskQueueHandler>

/**
 Init the handler with base URL, a base URL will be used for constructing the whole url for HTTP net tasks.
 E.g HTTP net task returns uri "user/profile", handled by handler with baseURL "http://example.com", the whole url will be http://example.com/user/profile".
 
 @param baseURL NSURL
 */
- (instancetype)initWithBaseURL:(nullable NSURL *)baseURL;

/**
 Init the handler with baseURL and NSURLSessionConfiguration.
 
 @param baseURL NSURL
 */
- (instancetype)initWithBaseURL:(nullable NSURL *)baseURL configuration:(NSURLSessionConfiguration *)configuration;

@end

NS_ASSUME_NONNULL_END

