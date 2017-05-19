//
//  MMNetworkTaskQueue.m
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import "MMNetworkTaskQueue.h"
#import "MMNetworkTask.h"

@implementation MMNetworkTaskQueueLog

+ (void)log:(NSString *)content, ...
{
#ifdef DEBUG
    if (!content) {
        return;
    }
    va_list args;
    va_start(args, content);
    NSLogv([NSString stringWithFormat:@"[MMNetworkTaskQueue] %@", content], args);
    va_end(args);
#endif
}

@end



@interface MMNetworkTask (MMInternal)

@property (atomic, assign) BOOL pending;
@property (atomic, assign) BOOL cancelled;
@property (atomic, assign) BOOL finished;
@property (atomic, assign) NSUInteger retryCount;

- (void)notifyState:(MMNetworkTaskState)state;

@end

@interface MMNetworkTaskQueue()

@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, strong) NSMutableDictionary *taskDelegates; // <NSString, NSHashTable<MMNetworkTaskDelegate>>
@property (nonatomic, strong) NSMutableArray *tasks; // <MMNetworkTask>
@property (nonatomic, strong) NSMutableArray *waitingTasks; // <MMNetworkTask>

@end

@implementation MMNetworkTaskQueue

+ (instancetype)sharedQueue
{
    static MMNetworkTaskQueue *sharedQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedQueue = [self new];
    });
    return sharedQueue;
}

- (id)init
{
    if (self = [super init]) {
        self.thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadEntryPoint) object:nil];
        self.thread.name = NSStringFromClass(self.class);
        [self.thread start];
        self.lock = [NSRecursiveLock new];
        self.lock.name = [NSString stringWithFormat:@"%@Lock", NSStringFromClass(self.class)];
        self.taskDelegates = [NSMutableDictionary new];
        self.tasks = [NSMutableArray new];
        self.waitingTasks = [NSMutableArray new];
    }
    return self;
}

- (void)dealloc
{
    [self.handler netTaskQueueDidBecomeInactive:self];
}

- (void)threadEntryPoint
{
    @autoreleasepool {
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [runloop addPort:[NSPort port] forMode:NSDefaultRunLoopMode]; // Just for keeping the runloop
        [runloop run];
    }
}

- (void)performInThread:(NSThread *)thread usingBlock:(void(^)())block
{
    [self performSelector:@selector(performUsingBlock:) onThread:thread withObject:block waitUntilDone:NO];
}

- (void)performUsingBlock:(void(^)())block
{
    block();
}

- (void)addTask:(MMNetworkTask *)task
{
    NSAssert(self.handler, @"MMNetworkTaskQueueHandler is not set.");
    NSAssert(!task.finished && !task.cancelled, @"MMNetworkTask is finished/cancelled, please recreate a net task.");
    
    task.pending = YES;
    [self performInThread:self.thread usingBlock:^{
        [self _addTask:task];
    }];
}

- (void)_addTask:(MMNetworkTask *)task
{
    if (self.maxConcurrentTasksCount > 0 && self.tasks.count >= self.maxConcurrentTasksCount) {
        [self.waitingTasks addObject:task];
        return;
    }
    
    [self.tasks addObject:task];
    [self.handler netTaskQueue:self handleTask:task];
}

- (void)cancelTask:(MMNetworkTask *)task
{
    if (!task) {
        return;
    }
    
    [self performInThread:self.thread usingBlock:^{
        [self _cancelTask:task];
    }];
}

- (void)_cancelTask:(MMNetworkTask *)task
{
    [self.tasks removeObject:task];
    [self.waitingTasks removeObject:task];
    task.pending = NO;
    
    [self.handler netTaskQueue:self didCancelTask:task];
    task.cancelled = YES;
    [task notifyState:MMNetworkTaskStateCancalled];
}

- (BOOL)_retryTask:(MMNetworkTask *)task withError:(NSError *)error
{
    if ([task shouldRetryForError:error] && task.retryCount < task.maxRetryCount) {
        task.retryCount++;
        [self performSelector:@selector(_retryTask:) withObject:task afterDelay:task.retryInterval];
        return YES;
    }
    return NO;
}

- (void)_retryTask:(MMNetworkTask *)task
{
    if (!task.cancelled) {
        [task didRetry];
        [task notifyState:MMNetworkTaskStateRetrying];
        [self addTask:task];
    }
}

- (void)_sendwaitingTasks
{
    if (!self.waitingTasks.count) {
        return;
    }
    MMNetworkTask *task = self.waitingTasks.firstObject;
    [self.waitingTasks removeObjectAtIndex:0];
    [self addTask:task];
}

- (void)task:(MMNetworkTask *)task didResponse:(id)response
{
    [self performInThread:self.thread usingBlock:^{
        [self _task:task didResponse:response];
    }];
}

- (void)_task:(MMNetworkTask *)task didResponse:(id)response
{
    if (![self.tasks containsObject:task]) {
        return;
    }
    [self.tasks removeObject:task];
    
    @try {
        [task didResponse:response];
    }
    @catch (NSException *exception) {
        [MMNetworkTaskQueueLog log:@"Exception in 'didResponse' - %@", exception.debugDescription];
        NSError *error = [NSError errorWithDomain:MMNetworkTaskUnknownError
                                             code:-1
                                         userInfo:@{ @"msg": exception.description ? : @"nil" }];
        
        if ([self _retryTask:task withError:error]) {
            return;
        }
        
        task.error = error;
        [task didFail];
    }
    
    task.pending = NO;
    task.finished = YES;
    [task notifyState:MMNetworkTaskStateFinished];
    
    [self _netTaskDidEnd:task];
    
    [self _sendwaitingTasks];
}

- (void)task:(MMNetworkTask *)task didFailWithError:(NSError *)error
{
    [self performInThread:self.thread usingBlock:^{
        [self _task:task didFailWithError:error];
    }];
}

- (void)_task:(MMNetworkTask *)task didFailWithError:(NSError *)error
{
    if (![self.tasks containsObject:task]) {
        return;
    }
    [self.tasks removeObject:task];
    
    [MMNetworkTaskQueueLog log:error.debugDescription];
    
    if ([self _retryTask:task withError:error]) {
        return;
    }
    
    task.error = error;
    [task didFail];
    task.pending = NO;
    task.finished = YES;
    [task notifyState:MMNetworkTaskStateFinished];
    
    [self _netTaskDidEnd:task];
    
    [self _sendwaitingTasks];
}

- (void)_netTaskDidEnd:(MMNetworkTask *)task
{
    [self.lock lock];
    
    NSHashTable *delegatesForURI = self.taskDelegates[task.uri];
    NSHashTable *delegatesForClass = self.taskDelegates[NSStringFromClass(task.class)];
    NSMutableSet *set = [NSMutableSet new];
    [set addObjectsFromArray:delegatesForURI.allObjects];
    [set addObjectsFromArray:delegatesForClass.allObjects];
    NSArray *delegates = set.allObjects;
    
    [self.lock unlock];
    
    if (delegates.count) {
        dispatch_async(dispatch_get_main_queue(), ^ {
            for (id<MMNetworkTaskDelegate> delegate in delegates) {
                [delegate networkTaskDidEnd:task];
            }
        });
    }
}

- (void)addTaskDelegate:(id<MMNetworkTaskDelegate>)delegate uri:(NSString *)uri
{
    [self.lock lock];
    
    NSHashTable *delegates = self.taskDelegates[uri];
    if (!delegates) {
        delegates = [NSHashTable weakObjectsHashTable];
        self.taskDelegates[uri] = delegates;
    }
    [delegates addObject:delegate];
    
    [self.lock unlock];
}

- (void)addTaskDelegate:(id<MMNetworkTaskDelegate>)delegate class:(Class)clazz
{
    NSString *className = NSStringFromClass(clazz);
    NSAssert([clazz isSubclassOfClass:[MMNetworkTask class]], @"%@ should be a subclass of MMNetworkTask", className);
    
    [self.lock lock];
    
    NSHashTable *delegates = self.taskDelegates[className];
    if (!delegates) {
        delegates = [NSHashTable weakObjectsHashTable];
        self.taskDelegates[className] = delegates;
    }
    [delegates addObject:delegate];
    
    [self.lock unlock];
}

- (void)removeTaskDelegate:(id<MMNetworkTaskDelegate>)delegate
{
    [self.lock lock];
    
    for (NSString *key in self.taskDelegates) {
        [self removeTaskDelegate:delegate key:key];
    }
    
    [self.lock unlock];
}

- (void)removeTaskDelegate:(id<MMNetworkTaskDelegate>)delegate uri:(NSString *)uri
{
    [self removeTaskDelegate:delegate key:uri];
}

- (void)removeTaskDelegate:(id<MMNetworkTaskDelegate>)delegate class:(Class)clazz
{
    [self removeTaskDelegate:delegate key:NSStringFromClass(clazz)];
}

- (void)removeTaskDelegate:(id<MMNetworkTaskDelegate>)delegate key:(NSString *)key
{
    [self.lock lock];
    
    NSHashTable *delegates = self.taskDelegates[key];
    [delegates removeObject:delegate];
    
    [self.lock unlock];
}

@end
