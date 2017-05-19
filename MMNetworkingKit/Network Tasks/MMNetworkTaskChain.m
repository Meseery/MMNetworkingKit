//
//  MMNetworkTaskChain.m
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import "MMNetworkTaskChain.h"

#import "MMNetworkTaskChain.h"
#import "MMNetworkTask.h"
#import "MMNetworkTaskQueue.h"

@interface MMNetworkTaskChain()<MMNetworkTaskDelegate>

@property (nonatomic, strong) NSArray *allTasks;
@property (nonatomic, assign) int taskIndex;

@end

@implementation MMNetworkTaskChain

- (void)setTasks:(MMNetworkTask *)task, ...
{
    NSMutableArray *tasks = [NSMutableArray array];
    va_list args;
    va_start(args, task);
    MMNetworkTask *nextTask = nil;
    for (nextTask = task; nextTask != nil; nextTask = va_arg(args, MMNetworkTask *)) {
        [tasks addObject:nextTask];
        [self.queue addTaskDelegate:self uri:nextTask.uri];
    }
    va_end(args);
    self.allTasks = tasks;
}

- (BOOL)onNextRequest:(MMNetworkTask *)task
{
    return YES;
}

- (void)onNextResponse:(MMNetworkTask *)task
{
    
}

- (void)start
{
    if (_started) {
        return;
    }
    _started = YES;
    _error = nil;
    self.taskIndex = 0;
    [self nextRequest];
}

- (void)cancel
{
    if (!_started) {
        return;
    }
    _started = NO;
    for (MMNetworkTask *task in self.allTasks) {
        [self.queue cancelTask:task];
    }
}

- (void)nextRequest
{
    while (_started) {
        if (self.taskIndex >= self.allTasks.count) {
            _started = NO;
            [self.delegate netTaskChainDidEnd:self];
            return;
        }
        MMNetworkTask *task = [self.allTasks objectAtIndex:self.taskIndex];
        self.taskIndex++;
        if ([self onNextRequest:task]) {
            [self.queue addTask:task];
            return;
        }
    }
}

- (void)networkTaskDidEnd:(MMNetworkTask *)task
{
    if (![self.allTasks containsObject:task]) {
        return;
    }
    
    if (task.error) {
        _error = task.error;
        [self.delegate netTaskChainDidEnd:self];
    }
    else {
        [self onNextResponse:task];
        [self nextRequest];
    }
}

@end
