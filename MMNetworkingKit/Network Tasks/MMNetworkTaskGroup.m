//
//  MMNetworkTaskGroup.m
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import "MMNetworkTaskGroup.h"
#import "MMNetworkTaskQueue.h"
#import "MMNetworkTask.h"

static NSMutableSet<MMNetworkTaskGroup *> *_retainedGroups; // Retain group to make sure it won't be autoreleased.

@interface MMNetworkTaskGroup ()

@property (nonatomic, strong) MMNetworkTask *executingTask;
@property (nonatomic, strong) NSArray<MMNetworkTask *> *tasks;
@property (nonatomic, assign) BOOL pending;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<MMNetworkTaskGroupSubscriptionBlock> *> *stateToBlock;
@property (nonatomic, strong) MMNetworkTaskSubscriptionBlock taskSubscriptionBlock; // For serial mode
@property (nonatomic, strong, readonly) MMNetworkTaskQueue *queue;

@end

@implementation MMNetworkTaskGroup

- (instancetype)initWithTasks:(NSArray<MMNetworkTask *> *)tasks mode:(MMNetworkTaskGroupMode)mode
{
    return [self initWithTasks:tasks mode:mode queue:[MMNetworkTaskQueue sharedQueue]];
}

- (instancetype)initWithTasks:(NSArray<MMNetworkTask *> *)tasks mode:(MMNetworkTaskGroupMode)mode queue:(MMNetworkTaskQueue *)queue
{
    if (self = [super init]) {
        self.tasks = [NSArray arrayWithArray:tasks];
        _mode = mode;
        _queue = queue;
    }
    return self;
}

- (void)addTask:(MMNetworkTask *)task
{
    NSMutableArray *tasks = [_tasks mutableCopy];
    [tasks addObject:task];
    self.tasks = [NSArray arrayWithArray:tasks];
}

- (MMNetworkTaskGroup *)subscribeState:(MMNetworkTaskGroupState)state usingBlock:(MMNetworkTaskGroupSubscriptionBlock)block
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
    return self;
}

- (void)notifyState:(MMNetworkTaskGroupState)state withError:(NSError *)error
{
    NSMutableArray<MMNetworkTaskGroupSubscriptionBlock> *blocks = self.stateToBlock[@(state)];
    for (MMNetworkTaskGroupSubscriptionBlock block in blocks) {
        block(self, error);
    }
    self.stateToBlock = nil;
    self.taskSubscriptionBlock = nil;
    [_retainedGroups removeObject:self];
}

- (void)start
{
    NSAssert(!self.started, @"MMNetworkTaskGroup can not be reused, please create a new instance.");
    if (self.pending) {
        return;
    }
    self.pending = YES;
    self.started = YES;
    if (!_retainedGroups) {
        _retainedGroups = [NSMutableSet new];
    }
    [_retainedGroups addObject:self];
    
    switch (self.mode) {
        case MMNetworkTaskGroupModeSerial: {
            __block NSUInteger executingTaskIndex = 0;
            __weak MMNetworkTaskGroup *weakSelf = self;
            self.taskSubscriptionBlock = ^{
                if (weakSelf.executingTask.error) {
                    [weakSelf notifyState:MMNetworkTaskGroupStateFinished withError:weakSelf.executingTask.error];
                    return;
                }
                executingTaskIndex++;
                if (executingTaskIndex == weakSelf.tasks.count) {
                    [weakSelf notifyState:MMNetworkTaskGroupStateFinished withError:nil];
                }
                else {
                    weakSelf.executingTask = weakSelf.tasks[executingTaskIndex];
                    [weakSelf.queue addTask:weakSelf.executingTask];
                    [weakSelf.executingTask subscribeState:MMNetworkTaskStateFinished usingBlock:weakSelf.taskSubscriptionBlock];
                }
            };
            self.executingTask = self.tasks[executingTaskIndex];
            [self.queue addTask:self.executingTask];
            [self.executingTask subscribeState:MMNetworkTaskStateFinished usingBlock:self.taskSubscriptionBlock];
        }
            break;
        case MMNetworkTaskGroupModeConcurrent: {
            __block NSUInteger finishedTasksCount = 0;
            for (MMNetworkTask *task in self.tasks) {
                [self.queue addTask:task];
                [task subscribeState:MMNetworkTaskStateFinished usingBlock:^{
                    if (task.error) {
                        [self cancelTasks];
                        [self notifyState:MMNetworkTaskGroupStateFinished withError:task.error];
                        return;
                    }
                    finishedTasksCount++;
                    if (finishedTasksCount == self.tasks.count) {
                        [self notifyState:MMNetworkTaskGroupStateFinished withError:nil];
                    }
                }];
            }
        }
            break;
        default:
            break;
    }
}

- (void)cancel
{
    if (!self.pending) {
        return;
    }
    
    switch (self.mode) {
        case MMNetworkTaskGroupModeSerial: {
            [self.queue cancelTask:self.executingTask];
            self.executingTask = nil;
        }
            break;
        case MMNetworkTaskGroupModeConcurrent: {
            [self cancelTasks];
        }
            break;
        default:
            break;
    }
    [self notifyState:MMNetworkTaskGroupStateCancelled withError:nil];
}

- (void)cancelTasks
{
    for (MMNetworkTask *task in self.tasks) {
        if (task.pending) {
            [self.queue cancelTask:task];
        }
    }
}

@end

@implementation NSArray (MMNetworkTaskGroup)

- (MMNetworkTaskGroup *)serialNetTaskGroup
{
    return [[MMNetworkTaskGroup alloc] initWithTasks:self mode:MMNetworkTaskGroupModeSerial];
}

- (MMNetworkTaskGroup *)serialNetTaskGroupInQueue:(MMNetworkTaskQueue *)queue
{
    return [[MMNetworkTaskGroup alloc] initWithTasks:self mode:MMNetworkTaskGroupModeSerial queue:queue];
}

- (MMNetworkTaskGroup *)concurrentNetTaskGroup
{
    return [[MMNetworkTaskGroup alloc] initWithTasks:self mode:MMNetworkTaskGroupModeConcurrent];
}

- (MMNetworkTaskGroup *)concurrentNetTaskGroupInQueue:(MMNetworkTaskQueue *)queue
{
    return [[MMNetworkTaskGroup alloc] initWithTasks:self mode:MMNetworkTaskGroupModeConcurrent queue:queue];
}

@end

