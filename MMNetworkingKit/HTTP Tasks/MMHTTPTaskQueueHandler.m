//
//  MMHTTPTaskQueueHandler.m
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import "MMHTTPTaskQueueHandler.h"
#import "MMHTTPTask.h"
#import "MMHTTPTaskParametersPacker.h"
#import "MMNetworkTaskQueue.h"
#import <objc/runtime.h>

@interface MMHTTPTask (STInternal)

@property (atomic, assign) NSInteger statusCode;
@property (atomic, strong) NSDictionary *responseHeaders;

@end

@class MMHTTPTaskQueueHandlerOperation;

@interface NSURLSessionTask (MMHTTPTaskQueueHandlerOperation)

@property (nonatomic, strong) MMHTTPTaskQueueHandlerOperation *operation;

@end

@implementation NSURLSessionTask (MMHTTPTaskQueueHandlerOperation)

@dynamic operation;

- (void)setOperation:(MMHTTPTaskQueueHandlerOperation *)operation
{
    objc_setAssociatedObject(self, @selector(operation), operation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (MMHTTPTaskQueueHandlerOperation *)operation
{
    return objc_getAssociatedObject(self, @selector(operation));
}

@end

static NSDictionary *MMHTTPTaskMethodMap;
static NSDictionary *MMHTTPTaskContentTypeMap;
static NSString *MMHTTPTaskFormDataBoundary;
static NSMapTable *MMHTTPTaskToSessionTask;

@interface MMHTTPTaskQueueHandlerOperation : NSObject <NSURLSessionDataDelegate>

@property (nonatomic, strong) MMNetworkTaskQueue *queue;
@property (nonatomic, strong) MMHTTPTask *task;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURL *baseURL;

- (void)start;

@end

@implementation MMHTTPTaskQueueHandlerOperation
{
    NSMutableData *_data;
}

+ (void)load
{
    MMHTTPTaskMethodMap = @{ @(MMHTTPTaskGet): @"GET",
                                @(MMHTTPTaskDelete): @"DELETE",
                                @(MMHTTPTaskHead): @"HEAD",
                                @(MMHTTPTaskPatch): @"PATCH",
                                @(MMHTTPTaskPost): @"POST",
                                @(MMHTTPTaskPut): @"PUT" };
    MMHTTPTaskContentTypeMap = @{ @(MMHTTPTaskRequestJSON): @"application/json; charset=utf-8",
                                     @(MMHTTPTaskRequestKeyValueString): @"application/x-www-form-urlencoded",
                                     @(MMHTTPTaskRequestFormData): @"multipart/form-data" };
    MMHTTPTaskFormDataBoundary = [NSString stringWithFormat:@"ST-Boundary-%@", [[NSUUID UUID] UUIDString]];
    MMHTTPTaskToSessionTask = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsWeakMemory capacity:50];
}

- (void)start
{
    _data = [NSMutableData new];
    
    NSDictionary *headers = self.task.headers;
    NSDictionary *parameters = [[[MMHTTPTaskParametersPacker alloc] initWithNetTask:_task] pack];
    
    NSURLSessionTask *sessionTask = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest new];
    request.HTTPMethod = MMHTTPTaskMethodMap[@(_task.method)];
    
    if (_baseURL.user.length || _baseURL.password.length) {
        NSString *credentials = [NSString stringWithFormat:@"%@:%@", _baseURL.user, _baseURL.password];
        credentials = [[credentials dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:kNilOptions];
        [request setValue:[NSString stringWithFormat:@"Basic %@", credentials] forHTTPHeaderField:@"Authorization"];
    }
    
    switch (_task.method) {
        case MMHTTPTaskGet:
        case MMHTTPTaskHead:
        case MMHTTPTaskDelete: {
            NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:[self requestURL]
                                                        resolvingAgainstBaseURL:NO];
            if (parameters.count) {
                urlComponents.query = [self queryStringFromParameters:parameters];
            }
            request.URL = urlComponents.URL;
        }
            break;
        case MMHTTPTaskPost:
        case MMHTTPTaskPut:
        case MMHTTPTaskPatch: {
            request.URL = [self requestURL];
            NSDictionary *datas = _task.datas;
            if (_task.requestType != MMHTTPTaskRequestFormData) {
                request.HTTPBody = [self bodyDataFromParameters:parameters requestType:_task.requestType];
                [request setValue:MMHTTPTaskContentTypeMap[@(_task.requestType)] forHTTPHeaderField:@"Content-Type"];
            }
            else {
                request.HTTPBody = [self formDataFromParameters:parameters datas:datas];
                NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", MMHTTPTaskFormDataBoundary];
                [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
            }
        }
            break;
        default: {
            NSAssert(NO, @"Invalid MMHTTPTaskMethod");
        }
            break;
    }
    
    for (NSString *headerField in headers) {
        [request setValue:headers[headerField] forHTTPHeaderField:headerField];
    }
    sessionTask = [_session dataTaskWithRequest:request];
    
    [MMHTTPTaskToSessionTask setObject:sessionTask forKey:_task];
    
    sessionTask.operation = self;
    [sessionTask resume];
}

- (NSURL *)requestURL
{
    if (_baseURL) {
        return [_baseURL URLByAppendingPathComponent:_task.uri];
    }
    return [NSURL URLWithString:_task.uri];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [_data appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error && error.code == NSURLErrorCancelled) {
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
    NSData *data = [NSData dataWithData:_data];
    
    _task.statusCode = httpResponse.statusCode;
    _task.responseHeaders = httpResponse.allHeaderFields;
    
    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        id responseObj = nil;
        NSError *error = nil;
        switch (_task.responseType) {
            case MMHTTPTaskResponseRawData:
                responseObj = data;
                break;
            case MMHTTPTaskResponseString:
                responseObj = [self stringFromData:data];
                break;
            case MMHTTPTaskResponseJSON:
            default:
                responseObj = [self JSONFromData:data];
                break;
        }
        
        if (!responseObj) {
            error = [NSError errorWithDomain:MMHTTPTaskResponseParsedError
                                        code:0
                                    userInfo:@{ @"url": httpResponse.URL.absoluteString }];
        }
        
        if (error) {
            [_queue task:_task didFailWithError:error];
        }
        else {
            [_queue task:_task didResponse:responseObj];
        }
    }
    else {
        if (!error) { // Response status code is not 20x
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            error = [NSError errorWithDomain:MMHTTPTaskServerError
                                        code:0
                                    userInfo:@{ MMHTTPTaskErrorStatusCodeUserInfoKey: @(httpResponse.statusCode),
                                                MMHTTPTaskErrorResponseDataUserInfoKey: data }];
#pragma GCC diagnostic pop
            [MMNetworkTaskQueueLog log:@"\n%@", _task.description];
        }
        [_queue task:_task didFailWithError:error];
    }
}

#pragma mark - Response data parsing methods

- (NSString *)stringFromData:(NSData *)data
{
    @try {
        NSString *string = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
        return string;
    }
    @catch (NSException *exception) {
        [MMNetworkTaskQueueLog log:@"String parsed error: %@", exception.debugDescription];
        return nil;
    }
}

- (id)JSONFromData:(NSData *)data
{
    NSError *error;
    id JSON = data.length ? [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error] : @{};
    if (error) {
        [MMNetworkTaskQueueLog log:@"JSON parsed error: %@", error.debugDescription];
        return nil;
    }
    return JSON;
}

#pragma mark - Request data constructing methods

- (NSString *)queryStringFromParameters:(NSDictionary *)parameters
{
    if (!parameters.count) {
        return @"";
    }
    
    NSMutableString *queryString = [NSMutableString string];
    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if ([value isKindOfClass:[NSArray class]]) {
            for (id element in value) {
                [self appendKeyValueToString:queryString withKey:key value:[element description] percentEncoding:NO];
            }
        }
        else {
            [self appendKeyValueToString:queryString withKey:key value:[value description] percentEncoding:NO];
        }
    }];
    [queryString deleteCharactersInRange:NSMakeRange(queryString.length - 1, 1)];
    return queryString;
}

- (NSData *)bodyDataFromParameters:(NSDictionary *)parameters requestType:(MMHTTPTaskRequestType)requestType
{
    if (!parameters.count) {
        return nil;
    }
    
    NSData *bodyData = nil;
    
    switch (requestType) {
        case MMHTTPTaskRequestJSON: {
            NSError *error = nil;
            bodyData = [NSJSONSerialization dataWithJSONObject:parameters options:kNilOptions error:&error];
            NSAssert(!error, @"Request is not in JSON format");
        }
            break;
        case MMHTTPTaskRequestKeyValueString:
        default: {
            NSMutableString *bodyString = [NSMutableString string];
            [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
                if ([value isKindOfClass:[NSArray class]]) {
                    for (id element in value) {
                        [self appendKeyValueToString:bodyString withKey:key value:[element description] percentEncoding:YES];
                    }
                }
                else {
                    [self appendKeyValueToString:bodyString withKey:key value:[value description] percentEncoding:YES];
                }
            }];
            [bodyString deleteCharactersInRange:NSMakeRange(bodyString.length - 1, 1)];
            bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
        }
            break;
    }
    
    return bodyData;
}

- (NSData *)formDataFromParameters:(NSDictionary *)parameters datas:(NSDictionary *)datas
{
    NSMutableData *formData = [NSMutableData data];
    
    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if ([value isKindOfClass:[NSArray class]]) {
            for (id element in value) {
                [self appendToFormData:formData withKey:key value:[element description]];
            }
        }
        else {
            [self appendToFormData:formData withKey:key value:[value description]];
        }
    }];
    
    [datas enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSData *fileData, BOOL *stop) {
        [formData appendData:[[NSString stringWithFormat:@"--%@\r\n", MMHTTPTaskFormDataBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [formData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", key, key] dataUsingEncoding:NSUTF8StringEncoding]];
        [formData appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", @"*/*"] dataUsingEncoding:NSUTF8StringEncoding]];
        [formData appendData:fileData];
        [formData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    
    [formData appendData:[[NSString stringWithFormat:@"--%@--\r\n", MMHTTPTaskFormDataBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return formData;
}

- (void)appendKeyValueToString:(NSMutableString *)string withKey:(NSString *)key value:(NSString *)value percentEncoding:(BOOL)percentEncoding
{
    if (percentEncoding) {
        key = [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
        value = [value stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    }
    [string appendFormat:@"%@=%@&", key, value];
}

- (void)appendToFormData:(NSMutableData *)formData withKey:(NSString *)key value:(NSString *)value
{
    [formData appendData:[[NSString stringWithFormat:@"--%@\r\n", MMHTTPTaskFormDataBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [formData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
    [formData appendData:[[NSString stringWithFormat:@"%@\r\n", value] dataUsingEncoding:NSUTF8StringEncoding]];
}

@end

@interface MMHTTPTaskQueueHandler () <NSURLSessionDataDelegate>

@end

@implementation MMHTTPTaskQueueHandler
{
    NSURL *_baseURL;
    NSURLSession *_urlSession;
}

- (instancetype)initWithBaseURL:(NSURL *)baseURL
{
    return [self initWithBaseURL:baseURL configuration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (instancetype)initWithBaseURL:(NSURL *)baseURL configuration:(NSURLSessionConfiguration *)configuration
{
    if (self = [super init]) {
        _baseURL = baseURL;
        _urlSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    }
    return self;
}

#pragma mark - MMNetworkTaskQueueHandler

- (void)netTaskQueue:(MMNetworkTaskQueue *)netTaskQueue handleTask:(MMNetworkTask *)task
{
    NSAssert([task isKindOfClass:[MMHTTPTask class]], @"Net task should be subclass of MMHTTPTask");
    
    MMHTTPTaskQueueHandlerOperation *operation = [MMHTTPTaskQueueHandlerOperation new];
    operation.queue = netTaskQueue;
    operation.task = (MMHTTPTask *)task;
    operation.baseURL = _baseURL;
    operation.session = _urlSession;
    
    [operation start];
}

- (void)netTaskQueue:(MMNetworkTaskQueue *)netTaskQueue didCancelTask:(MMNetworkTask *)task
{
    NSAssert([task isKindOfClass:[MMHTTPTask class]], @"Net task should be subclass of MMHTTPTask");
    
    NSURLSessionTask *sessionTask = [MMHTTPTaskToSessionTask objectForKey:task];
    [sessionTask cancel];
}

- (void)netTaskQueueDidBecomeInactive:(MMNetworkTaskQueue *)netTaskQueue
{
    [_urlSession invalidateAndCancel];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [dataTask.operation URLSession:session dataTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [task.operation URLSession:session task:task didCompleteWithError:error];
}

@end

