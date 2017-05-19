//
//  MMNetworkTaskGroup.h
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MMNetworkTask;
@class MMNetworkTaskQueue;
@class MMNetworkTaskGroup;

typedef NS_ENUM(NSUInteger, MMNetworkTaskGroupMode) {
    MMNetworkTaskGroupModeSerial,
    MMNetworkTaskGroupModeConcurrent
};

typedef NS_ENUM(NSUInteger, MMNetworkTaskGroupState) {
    MMNetworkTaskGroupStateCancelled,
    MMNetworkTaskGroupStateFinished
};

/**
 @param group MMNetworkTaskGroup
 @param error NSError the first error was encountered in the group.
 */
typedef void (^MMNetworkTaskGroupSubscriptionBlock)(MMNetworkTaskGroup *group, NSError  * _Nullable error);

/**
 MMNetworkTaskGroup is a group to execute MMNetworkTasks in serial or concurrent mode.
 NOTE: MMNetworkTaskGroup is currently not thread safe.
 */
@interface MMNetworkTaskGroup : NSObject

/**
 The executing task in the group when it is in MMNetworkTaskGroupModeSerial.
 It will be always 'nil' when the group is in MMNetworkTaskGroupModeConcurrent.
 */
@property (nullable, nonatomic, strong, readonly) MMNetworkTask *executingTask;

/**
 All tasks in this group.
 */
@property (nonatomic, strong, readonly) NSArray<MMNetworkTask *> *tasks;

/**
 The MMNetworkTaskGroupMode is being used.
 */
@property (nonatomic, assign, readonly) MMNetworkTaskGroupMode mode;

/**
 Indicates if the group is executing tasks.
 */
@property (nonatomic, assign, readonly) BOOL pending;

/**
 Init with an array of net tasks and mode.
 [MMNetworkTaskQueue sharedQueue] will be used for executing tasks in the group.
 
 @param tasks NSArray
 @param mode MMNetworkTaskGroupMode indicates the tasks in this group should be sent serially or concurrently.
 */
- (instancetype)initWithTasks:(NSArray<MMNetworkTask *> *)tasks mode:(MMNetworkTaskGroupMode)mode;

/**
 Init with an array of net tasks, mode and the queue which will be used for executing tasks.
 
 @param tasks NSArray
 @param mode MMNetworkTaskGroupMode indicates the tasks in this group should be sent serially or concurrently.
 @param queue MMNetworkTaskQueue the queue which is used for executing tasks in the group.
 */
- (instancetype)initWithTasks:(NSArray<MMNetworkTask *> *)tasks mode:(MMNetworkTaskGroupMode)mode queue:(MMNetworkTaskQueue *)queue NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/**
 Add a new task to this group.
 
 @param task MMNetworkTask
 */
- (void)addTask:(MMNetworkTask *)task;

/**
 Subscribe state with MMNetworkTaskGroupSubscriptionBlock.
 
 @param state MMNetworkTaskGroupState
 @param block MMNetworkTaskGroupSubscriptionBlock
 */
- (MMNetworkTaskGroup *)subscribeState:(MMNetworkTaskGroupState)state usingBlock:(MMNetworkTaskGroupSubscriptionBlock)block;

/**
 Start executing tasks in this group.
 */
- (void)start;

/**
 Cancel all tasks in this group.
 */
- (void)cancel;

@end

/**
 Handy category for executing tasks in an array.
 */
@interface NSArray (MMNetworkTaskGroup)

- (MMNetworkTaskGroup *)serialNetTaskGroup;
- (MMNetworkTaskGroup *)serialNetTaskGroupInQueue:(MMNetworkTaskQueue *)queue;
- (MMNetworkTaskGroup *)concurrentNetTaskGroup;
- (MMNetworkTaskGroup *)concurrentNetTaskGroupInQueue:(MMNetworkTaskQueue *)queue;

@end

NS_ASSUME_NONNULL_END
