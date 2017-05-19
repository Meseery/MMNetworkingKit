//
//  MMHTTPTask.h
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MMNetworkTask.h>

NS_ASSUME_NONNULL_BEGIN

// Error domains
FOUNDATION_EXPORT NSString *const MMHTTPTaskServerError;
FOUNDATION_EXPORT NSString *const MMHTTPTaskResponseParsedError;

// Error "userInfo" keys
FOUNDATION_EXPORT NSString *const MMHTTPTaskErrorStatusCodeUserInfoKey DEPRECATED_MSG_ATTRIBUTE("Use MMHTTPTask.statusCode instead");
FOUNDATION_EXPORT NSString *const MMHTTPTaskErrorResponseDataUserInfoKey;

FOUNDATION_EXPORT NSString *MMHTTPTaskRequestObjectDefaultSeparator;

#define MMHTTPTaskIgnoreAllProperties @[ @"*" ]

typedef NS_ENUM(NSUInteger, MMHTTPTaskMethod) {
    MMHTTPTaskGet,
    MMHTTPTaskPost,
    MMHTTPTaskPut,
    MMHTTPTaskDelete,
    MMHTTPTaskHead,
    MMHTTPTaskPatch
};

typedef NS_ENUM(NSUInteger, MMHTTPTaskRequestType) {
    MMHTTPTaskRequestJSON,
    MMHTTPTaskRequestKeyValueString,
    MMHTTPTaskRequestFormData
};

typedef NS_ENUM(NSUInteger, MMHTTPTaskResponseType) {
    MMHTTPTaskResponseJSON,
    MMHTTPTaskResponseString,
    MMHTTPTaskResponseRawData
};

/**
 MMIgnore marks a property as "ignore" so that the property will be ignored when packing the request.
 MMHTTPTaskRequestObject-ignoredProperties will do the same.
 
 @see MMHTTPTaskRequestObject
 */
@protocol MMIgnore

@end

/**
 To avoid complier warnings
 */
@interface NSObject (MMHTTPTaskRequestObject) <MMIgnore>

@end

/**
 If a class conforms to this protocol, it means the instance of this class will be converted to a dictionary and passed as parameter in a HTTP request.
 */
@protocol MMHTTPTaskRequestObject <NSObject>

/**
 Properties which should be ignored when packing parameters for reqeust.
 
 @return NSArray<NSString> An array of strings representing the name of properties to be ignored.
 */
- (NSArray<NSString *> *)ignoredProperties;

@optional

/**
 Transform a value to another.
 Use case: NSArray need to be transformed to comma separated string.
 
 @param value id Value to be transformed
 @return id The transformed value. Should return the same value if "value" is not supposed to be transformed.
 */
- (nullable id)transformValue:(id)value;

/**
 Separator string which should be used when packing parameters.
 E.g. property schoolName will be converted to school_name.
 Default: @"_"
 
 @return NSString
 */
- (nullable NSString *)parameterNameSeparator;

@end

/**
 Net task which is designed for HTTP protocol.
 */
@interface MMHTTPTask : MMNetworkTask<MMHTTPTaskRequestObject>

/**
 HTTP status code.
 */
@property (atomic, assign, readonly) NSInteger statusCode;

/**
 HTTP headers of response.
 */
@property (atomic, strong, readonly) NSDictionary *responseHeaders;

/**
 HTTP method which should be used for the HTTP net task.
 
 @return MMHTTPTaskMethod
 */
- (MMHTTPTaskMethod)method;

/**
 Request parameters format. E.g JSON, key-value string(form param).
 
 @return MMHTTPTaskRequestType
 */
- (MMHTTPTaskRequestType)requestType;

/**
 Response data format. E.g JSON, String, Raw data.
 
 @return MMHTTPTaskResponseType
 */
- (MMHTTPTaskResponseType)responseType;

/**
 Custom headers which will be added into HTTP request headers.
 
 @return NSDictionary<NSString, NSString> Custom headers, e.g. @{ @"User-Agent": @"MMNetworkTaskQueue Client" }
 */
- (NSDictionary<NSString *, NSString *> *)headers;

/**
 Additional parameters which will be added as HTTP request parameters.
 
 @return NSDictionary<NSString, id>
 */
- (NSDictionary<NSString *, id> *)parameters;

/**
 NSDatas which will be added into multi-part form data body,
 requestType should be MMHTTPTaskRequestFormData if you are going to return datas.
 
 @return NSDictionary<NSString, NSData>
 */
- (NSDictionary<NSString *, NSData *> *)datas;

/**
 This method will be called if the response object is a dictionary.
 
 @param dictionary NSDictionary
 */
- (void)didResponseDictionary:(NSDictionary *)dictionary;

/**
 This method will be called if the response object is an array.
 
 @param array NSArray
 */
- (void)didResponseArray:(NSArray *)array;

/**
 This method will be called if the response obejct is a string.
 
 @param string NSString
 */
- (void)didResponseString:(NSString *)string;

/**
 This method will be called if the response object is NSData
 
 @param data NSData
 */
- (void)didResponseData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END

