//
//  MMNetworkTaskQueue.h
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MMNetworkTask;
@class MMNetworkTaskQueue;
@protocol MMNetworkTaskDelegate;

@protocol MMNetworkTaskQueueHandler <NSObject>

/**
 MMNetworkTaskQueue will call this method when a net task is added to queue and become ready to be excecuted.
 
 @param netTaskQueue MMNetworkTaskQueue The net task queue which is holding the net task.
 @param task MMNetworkTask The net task which is ready to be executed.
 */
- (void)netTaskQueue:(MMNetworkTaskQueue *)netTaskQueue handleTask:(MMNetworkTask *)task;

/**
 MMNetworkTaskQueue will call this method when a net task is cancelled and removed from net task queue.
 Giving a chance to the handler to do a clean up for the cancelled net task.
 
 @param netTaskQueue MMNetworkTaskQueue The net task queue which is holding the cancelled net task.
 @param task MMNetworkTask The net task which is cancelled and removed from net task queue.
 */
- (void)netTaskQueue:(MMNetworkTaskQueue *)netTaskQueue didCancelTask:(MMNetworkTask *)task;

/**
 MMNetworkTaskQueue will call this method when the net task queue is deallocated.
 
 @param netTaskQueue MMNetworkTaskQueue The net task queue which is deallocated.
 */
- (void)netTaskQueueDidBecomeInactive:(MMNetworkTaskQueue *)netTaskQueue;

@end


@interface MMNetworkTaskQueueLog : NSObject

+ (void)log:(NSString *)content, ...;

@end


@interface MMNetworkTaskQueue : NSObject

/**
 The MMNetworkTaskQueueHandler which is used for handling the net tasks in queue.
 */
@property (nullable, nonatomic, strong) id<MMNetworkTaskQueueHandler> handler;

/**
 Count of Max concurrent task in a queue.
 If the number of unfinished tasks in queue hits the max count, upcoming task will be processed till one of the unfinished task is done.
 */
@property (nonatomic, assign) NSUInteger maxConcurrentTasksCount;

/**
 A shared MMNetworkTaskQueue instance.
 */
+ (instancetype)sharedQueue;

/**
 Add a net task into the net task queue.
 The net task may not be executed immediately depends on the "maxConcurrentTasksCount",
 but the net task will be marked as "pending" anyway.
 
 @param task MMNetworkTask The net task to be added into the queue.
 */
- (void)addTask:(MMNetworkTask *)task;

/**
 Cancel and remove the net task from queue.
 If the net task is executing, it will be cancelled and remove from the queue without calling the "netTaskDidEnd" delegate method.
 
 @param task MMNetworkTask The net task to be cancelled and removed from the queue.
 */
- (void)cancelTask:(MMNetworkTask *)task;

/**
 This method should be called when the "handler" finish handling the net task successfully.
 After "handler" called this method, the net task will be marked as "finished", set "pending" as "NO", and removed from the queue.
 
 @param task MMNetworkTask The net task which is handled by "handler".
 @param response id The response object.
 */
- (void)task:(MMNetworkTask *)task didResponse:(id)response;

/**
 This method should be caled when the "handler" finish handling the net task with error.
 After "hadnler" called this method, the net task will be marked as "finished", set "pending" as "NO", and removed from the queue.
 
 @param task MMNetworkTask The net task which is handled by "handler".
 @param error NSError Error object.
 */
- (void)task:(MMNetworkTask *)task didFailWithError:(NSError *)error;

/**
 Add a net task delegate to "MMNetworkTaskQueue" with uri of the net task,
 it's a weak reference and duplicated delegate with same uri will be ignored.
 
 @param delegate id<MMNetworkTaskDelegate>
 @param uri NSString A unique string returned by MMNetworkTask.
 */
- (void)addTaskDelegate:(id<MMNetworkTaskDelegate>)delegate uri:(NSString *)uri;

/**
 Add a net task delegate to "MMNetworkTaskQueue" with class of net task,
 it's a weak reference and duplicated delegate with same class will be ignored.
 
 @param delegate id<MMNetworkTaskDelegate>
 @param clazz Class Class which extends MMNetworkTask.
 */
- (void)addTaskDelegate:(id<MMNetworkTaskDelegate>)delegate class:(Class)clazz;

/**
 Most of the times you don't need to remove net task delegate explicitly,
 because "MMNetworkTaskQueue" holds weak reference of each delegate.
 
 @param delegate id<MMNetworkTaskDelegate>
 @param uri NSString
 */
- (void)removeTaskDelegate:(id<MMNetworkTaskDelegate>)delegate uri:(NSString *)uri;
- (void)removeTaskDelegate:(id<MMNetworkTaskDelegate>)delegate class:(Class)clazz;
- (void)removeTaskDelegate:(id<MMNetworkTaskDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END

