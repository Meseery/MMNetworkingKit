# MMNetworkingKit
Networking framework for iOS and OS X

## Get Started

### Podfile

```ruby
platform :ios, '9.0'
pod 'MMNetworkingKit'
```

### Main Components
#### MMNetworkTask
It provides basic properties and callbacks for subclassing.

#### MMNetworkTaskDelegate
It is the delegate protocol for observing result of ```MMNetworkTask```, mostly it is used in view controller.

#### MMNetworkTaskGroup
A network task group for executing network tasks serially or concurrently.

#### MMHTTPTaskQueueHandler
It is a HTTP based implementation of ```MMNetworkTaskQueueHandler```. It provides different ways to pack request and parse response, e.g. ```MMHTTPTaskRequestJSON``` is for JSON format request body, ```MMHTTPTaskResponseJSON``` is for JSON format response data and `MMHTTPTaskRequestFormData` is for form data format request body which is mostly used for uploading file.

### How to use ?

#### Step 1: Setup `MMNetworkTaskQueue` after your app launch
```objc
NSURL *baseUrl = [NSURL URLWithString:@"http://example.com"];
MMHTTPTaskQueueHandler *httpHandler = [[MMHTTPTaskQueueHandler alloc] initWithBaseURL:baseUrl];
[MMNetworkTaskQueue sharedQueue].handler = httpHandler;
```

#### Step 2: Create your own task
```objc
@interface MMTestTask : MMHTTPTask

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *body;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, assign) int userId;
@property (nonatomic, strong) NSString<MMIgnore> *ignored; // This property is ignored when packing the request.
@property (nonatomic, strong, readonly) NSDictionary *post;

@end
```

```objc
@implementation MMTestTask

- (MMHTTPTaskMethod)method
{
    return MMHTTPTaskPost;
}

- (NSString *)uri
{
    return @"posts";
}

// Optional. Retry 3 times after error occurs.
- (NSUInteger)maxRetryCount
{
    return 3;
}

// Optional. Retry for all types of errors
- (BOOL)shouldRetryForError:(NSError *)error
{
    return YES;
}

// Optional. Retry after 5 seconds.
- (NSTimeInterval)retryInterval
{
    return 5;
}

// Optional. Custom headers.
- (NSDictionary *)headers
{
    return @{ @"custom_header": @"value" };
}

// Optional. Add parameters which are not inclued in requestObject and net task properties.
- (NSDictionary *)parameters
{
    return @{ @"other_parameter": @"value" };
}

// Optional. Transform value to a format you want.
- (id)transformValue:(id)value
{
    if ([value isKindOfClass:[NSDate class]]) {
        return @([value timeIntervalSince1970]);
    }
    return value;
}

- (void)didResponseDictionary:(NSDictionary *)dictionary
{
    _post = dictionary;
}

@end
```

#### Step 3: Create a test task and delegate for the result
```objc
MMTestTask *testTask = [MMTestTask new];
testTask.title = @"Test Task Title";
testTask.body = @"Test Body";
testTask.userId = 1;
testTask.date = [NSDate new];
testTask.ignored = @"test";
[[MMNetworkTaskQueue sharedQueue] addTaskDelegate:self uri:testTask.uri];
[[MMNetworkTaskQueue sharedQueue] addTask:testTask];

// The net task will be sent as described below.
/*
 URI: posts
 Method: POST
 Request Type: Key-Value String
 Response Type: JSON
 Custom Headers:
 {
 "custom_header" = value;
 }
 Parameters:
 {
 body = "Test Body";
 date = "1452239110.829915";
 "other_parameter" = value;
 title = "Test Task Title";
 "user_id" = 1;
 }
 */
```

#### Use subscription block
```objc
[testTask subscribeState:MMNetworkTaskStateFinished usingBlock:^{
    if (testTask.error) {
        // Handle error cases
        return;
    }
    // Access result from net task
}];
```

#### Use MMNetworkTaskDelegate

```objc
- (void)networkTaskDidEnd:(MMNetworkTask *)task
{
    if (task.error) {
        // Handle error cases
        return;
    }
    // Access result from net task
}
```

#### Work with ReactiveCocoa for getting net task result

```objc
[MMNetworkTaskObserve(testTask) subscribeCompleted:^(
                                                     if (testTask.error) {
                                                         // Handle error cases
                                                         return;
                                                     }
// Access result from net task
}];
```
Sometimes we need to set the concurrent image download tasks to avoid too much data coming at the same time.

```objc
MMNetworkTaskQueue *downloadQueue = [MMNetworkTaskQueue new];
downloadQueue.handler = [[MMHTTPTaskQueueHandler alloc] initWithBaseURL:[NSURL URLWithString:@"http://example.com"]];
downloadQueue.maxConcurrentTasksCount = 2;
/*
 [downloadQueue addTask:task1];
 [downloadQueue addTask:task2];
 [downloadQueue addTask:task3]; // task3 will be sent after task1 or task2 is finished.
 */
```
### Execute multiple tasks
`MMNetworkTaskGroup` supports two modes: `MMNetworkTaskGroupModeSerial` and `MMNetworkTaskGroupModeConcurrent`.
`MMNetworkTaskGroupModeSerial` will execute a net task after the previous net task is finished.
`MMNetworkTaskGroupModeConcurrent` will execute all net tasks concurrently.
```objc
MMGetTask *task1 = [MMGetTask new];
task1.id = 1;

MMGetTask *task2 = [MMGetTask new];
task2.id = 2;

MMNetworkTaskGroup *group = [[MMNetworkTaskGroup alloc] initWithTasks:@[ task1, task2 ] mode:MMNetworkTaskGroupModeSerial];
[group subscribeState:MMNetworkTaskGroupStateFinished usingBlock:^(MMNetworkTaskGroup *group, NSError *error) {
    if (error) {
        // One of the net task is failed.
        return;
    }
    // All net tasks are finished without error.
}];
[group start];
```

Or a handy way:
```objc
MMGetTask *task1 = [MMGetTask new];
task1.id = 1;

MMGetTask *task2 = [MMGetTask new];
task2.id = 2;

[[[@[ task1, task2 ] serialNetTaskGroup] subscribeState:MMNetworkTaskGroupStateFinished usingBlock:^(MMNetworkTaskGroup *group, NSError *error) {
    if (error) {
        // One of the net task is failed.
        return;
    }
    // All net tasks are finished without error.
}] start];
```
