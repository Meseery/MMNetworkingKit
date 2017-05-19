//
//  MMHTTPTask.m
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import "MMHTTPTask.h"
#import "MMHTTPTaskParametersPacker.h"

NSString *const MMHTTPTaskServerError = @"MMHTTPTaskServerError";
NSString *const MMHTTPTaskResponseParsedError = @"MMHTTPTaskResponseParsedError";
NSString *const MMHTTPTaskErrorStatusCodeUserInfoKey = @"statusCode";
NSString *const MMHTTPTaskErrorResponseDataUserInfoKey = @"responseData";
NSString *MMHTTPTaskRequestObjectDefaultSeparator = @"_";

@interface MMHTTPTask ()

@property (atomic, assign) NSInteger statusCode;
@property (atomic, strong) NSDictionary *responseHeaders;

@end

@implementation MMHTTPTask

- (MMHTTPTaskMethod)method
{
    return MMHTTPTaskGet;
}

- (MMHTTPTaskRequestType)requestType
{
    return MMHTTPTaskRequestKeyValueString;
}

- (MMHTTPTaskResponseType)responseType
{
    return MMHTTPTaskResponseJSON;
}

- (NSDictionary *)headers
{
    return nil;
}

- (NSDictionary *)parameters
{
    return nil;
}

- (NSDictionary *)datas
{
    return nil;
}

- (void)didResponse:(id)response
{
    if ([response isKindOfClass:[NSDictionary class]]) {
        [self didResponseDictionary:response];
    }
    else if ([response isKindOfClass:[NSArray class]]) {
        [self didResponseArray:response];
    }
    else if ([response isKindOfClass:[NSString class]]) {
        [self didResponseString:response];
    }
    else if ([response isKindOfClass:[NSData class]]) {
        [self didResponseData:response];
    }
    else {
        NSAssert(NO, @"Invalid response");
    }
}

- (void)didResponseDictionary:(NSDictionary *)dictionary
{
    
}

- (void)didResponseArray:(NSArray *)array
{
    
}

- (void)didResponseString:(NSString *)string
{
    
}

- (void)didResponseData:(NSData *)data
{
    
}

- (NSArray *)ignoredProperties
{
    return nil;
}

- (NSString *)description
{
    NSDictionary *methodMap = @{ @(MMHTTPTaskGet): @"GET",
                                 @(MMHTTPTaskDelete): @"DELETE",
                                 @(MMHTTPTaskHead): @"HEAD",
                                 @(MMHTTPTaskPatch): @"PATCH",
                                 @(MMHTTPTaskPost): @"POST",
                                 @(MMHTTPTaskPut): @"PUT" };
    NSDictionary *requestTypeMap = @{ @(MMHTTPTaskRequestJSON): @"JSON",
                                      @(MMHTTPTaskRequestKeyValueString): @"Key-Value String",
                                      @(MMHTTPTaskRequestFormData): @"Form Data" };
    NSDictionary *responseTypeMap = @{ @(MMHTTPTaskResponseJSON): @"JSON",
                                       @(MMHTTPTaskResponseString): @"String",
                                       @(MMHTTPTaskResponseRawData): @"Raw Data" };
    
    NSMutableString *desc = [NSMutableString new];
    [desc appendFormat:@"URI: %@\n", self.uri];
    [desc appendFormat:@"Method: %@\n", methodMap[@(self.method)]];
    [desc appendFormat:@"Request Type: %@\n", requestTypeMap[@(self.requestType)]];
    [desc appendFormat:@"Response Type: %@\n", responseTypeMap[@(self.responseType)]];
    
    NSDictionary *headers = self.headers;
    if (headers.count) {
        [desc appendFormat:@"Custom Headers:\n%@\n", headers];
    }
    NSDictionary *datas = self.datas;
    if (datas.count) {
        [desc appendFormat:@"Form Datas:\n"];
        for (NSString *name in datas) {
            NSData *data = datas[name];
            [desc appendFormat:@"%@: %td bytes\n", name, data.length];
        }
    }
    
    [desc appendFormat:@"Parameters:\n%@\n", [[[MMHTTPTaskParametersPacker alloc] initWithNetTask:self] pack]];
    return desc;
}

@end
