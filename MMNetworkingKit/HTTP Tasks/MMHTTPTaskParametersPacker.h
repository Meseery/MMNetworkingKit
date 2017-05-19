//
//  MMHTTPTaskParametersPacker.h
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/19/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MMHTTPTask;

@interface MMHTTPTaskParametersPacker : NSObject

- (instancetype)initWithNetTask:(MMHTTPTask *)netTask;
- (NSDictionary<NSString *, id> *)pack;

@end

NS_ASSUME_NONNULL_END
