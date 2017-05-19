//
//  MMNetworkTask.m
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import "MMNetworkTask.h"

NSString *const MMNetworkTaskUnknownError = @"MMNetworkTaskUnknownError";

@interface MMNetworkTask ()

@property (atomic, assign) BOOL pending;
@property (atomic, assign) BOOL cancelled;
@property (atomic, assign) BOOL finished;
@property (atomic, assign) NSUInteger retryCount;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<MMNetworkTaskSubscriptionBlock> *> *stateToBlock;

@end

@implementation MMNetworkTask

- (NSString *)uri
{
    return @"";
}

- (void)didResponse:(id)response
{
    
}

- (void)didFail
{
    
}

- (void)didRetry
{
    
}

- (NSUInteger)maxRetryCount
{
    return 0;
}

- (BOOL)shouldRetryForError:(NSError *)error
{
    return YES;
}

- (NSTimeInterval)retryInterval
{
    return 0;
}

- (void)subscribeState:(MMNetworkTaskState)state usingBlock:(MMNetworkTaskSubscriptionBlock)block
{
    if ([NSThread isMainThread]) {
        [self _subscribeState:state usingBlock:block];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _subscribeState:state usingBlock:block];
        });
    }
}

- (void)_subscribeState:(MMNetworkTaskState)state usingBlock:(MMNetworkTaskSubscriptionBlock)block
{
    if (!self.stateToBlock) {
        self.stateToBlock = [NSMutableDictionary new];
    }
    NSMutableArray *blocks = self.stateToBlock[@(state)];
    if (!blocks) {
        blocks = [NSMutableArray new];
        self.stateToBlock[@(state)] = blocks;
    }
    [blocks addObject:[block copy]];
}

- (void)notifyState:(MMNetworkTaskState)state
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *blocks = self.stateToBlock[@(state)];
        for (MMNetworkTaskSubscriptionBlock block in blocks) {
            block();
        }
        switch (state) {
            case MMNetworkTaskStateFinished:
            case MMNetworkTaskStateCancalled: {
                self.stateToBlock = nil;
            }
                break;
            default:
                break;
        }
    });
}

@end

