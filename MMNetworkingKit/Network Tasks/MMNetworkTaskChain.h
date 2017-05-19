//
//  MMNetworkTaskChain.h
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MMNetworkTaskQueue;
@class MMNetworkTask;
@class MMNetworkTaskChain;

DEPRECATED_MSG_ATTRIBUTE("Use MMNetworkTaskGroup instead")
@protocol MMNetworkTaskChainDelegate <NSObject>

- (void)netTaskChainDidEnd:(MMNetworkTaskChain *)netTaskChain;

@end

DEPRECATED_MSG_ATTRIBUTE("Use MMNetworkTaskGroup instead")
@interface MMNetworkTaskChain : NSObject

@property (nullable, nonatomic, weak) id<MMNetworkTaskChainDelegate> delegate;
@property (nullable, nonatomic, strong) MMNetworkTaskQueue *queue;
@property (nullable, nonatomic, strong, readonly) NSError *error;
@property (nonatomic, assign, readonly) BOOL started;

- (void)setTasks:(MMNetworkTask *)task, ...;
// Return NO indicates this task should not be sent.
- (BOOL)onNextRequest:(MMNetworkTask *)task;
- (void)onNextResponse:(MMNetworkTask *)task;
- (void)start;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
