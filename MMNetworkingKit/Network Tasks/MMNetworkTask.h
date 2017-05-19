//
//  MMNetworkTask.h
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * _Nonnull const MMNetworkTaskUnknownError;

#ifdef RACObserve

#define MMNetworkTaskObserve(TASK) \
[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) { \
[[[[RACObserve(TASK, finished) skip:1] ignore:@NO] deliverOnMainThread] subscribeNext:^(id x) { \
[subscriber sendNext:TASK];\
[subscriber sendCompleted]; \
}]; \
[[[[RACObserve(TASK, cancelled) skip:1] ignore:@NO] deliverOnMainThread] subscribeNext:^(id x) { \
[subscriber sendError:nil];\
}]; \
return nil; \
}]

#endif

@class MMNetworkTask;

@protocol MMNetworkTaskDelegate <NSObject>

/**
 This delegate method will be called when the net task is finished(no matter it's successful or failed).
 If the net task is failed, task.error will be non-nil.
 
 @param task MMNetworkTask The finished net task.
 */
- (void)networkTaskDidEnd:(__kindof MMNetworkTask *)task;

@end

typedef NS_ENUM(NSUInteger, MMNetworkTaskState) {
    MMNetworkTaskStateCancalled,
    MMNetworkTaskStateFinished,
    MMNetworkTaskStateRetrying
};

typedef void (^MMNetworkTaskSubscriptionBlock)();



@interface MMNetworkTask : NSObject

/**
 Error object which contains error message when net task is failed.
 */
@property (nullable, atomic, strong) NSError *error;

/**
 Indicates if the net task is waiting for executing or executing.
 This value will be set to "YES" immediately after the net task is added to net task queue.
 */
@property (atomic, assign, readonly) BOOL pending;

/**
 Indicates if the net task is cancelled.
 This value would be "NO" by default after net task is created, even the net task is not added to queue.
 */
@property (atomic, assign, readonly) BOOL cancelled;

/**
 Indicates if the net task is finished(no matter it's successful or failed).
 */
@property (atomic, assign, readonly) BOOL finished;

/**
 The current retry time @see maxRetryCount
 */
@property (atomic, assign, readonly) NSUInteger retryCount;

/**
 A unique string represents the net task.
 
 @return NSString The uri string.
 */
- (NSString *_Nullable)uri;

/**
 A callback method which is called when the net task is finished successfully.
 Note: this method will be called in thread of MMNetworkTaskQueue.
 
 @param response id The response object.
 */
- (void)didResponse:(id _Nullable )response;

/**
 A callback method which is called when the net task is failed.
 Note: this method will be called in thread of MMNetworkTaskQueue.
 */
- (void)didFail;

/**
 A callback method which is called when the net task is retried.
 Note: this method will be called in thread of MMNetworkTaskQueue.
 */
- (void)didRetry;

/**
 Indicates how many times the net task should be retried after failed.
 Default 0.
 
 @return NSUInteger
 */
- (NSUInteger)maxRetryCount;

/**
 If you are going to retry the net task only when specific error is returned, return NO in this method.
 Default YES.
 
 @param error NSError Error object.
 @return BOOL Should the net task be retried according to the error object.
 */
- (BOOL)shouldRetryForError:(NSError *_Nullable)error;

/**
 Indicates how many seconds should be delayed before retrying the net task.
 
 @return NSTimeInterval
 */
- (NSTimeInterval)retryInterval;

/**
 Subscribe state of net task by using block
 
 @param state MMNetworkTaskState state of net task
 @param block MMNetworkTaskSubscriptionBlock block is called when net task is in subscribed state.
 NOTE: this block will be called in main thread.
 */
- (void)subscribeState:(MMNetworkTaskState)state usingBlock:(MMNetworkTaskSubscriptionBlock _Nullable )block;

@end

NS_ASSUME_NONNULL_END
