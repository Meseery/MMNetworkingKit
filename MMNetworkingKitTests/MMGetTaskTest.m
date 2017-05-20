//
//  MMGetTaskTest.m
//  MMNetworkingKit
//
//  Created by Mohamed EL Meseery on 5/20/17.
//  Copyright © 2017 Meseery. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MMHTTPTaskQueueHandler.h"
#import "MMHTTPTask.h"

NSString * const baseURLString = @"";

@interface MMGetTaskTest : XCTestCase <MMNetworkTaskDelegate>{
XCTestExpectation *_expectation;
}
@end

@implementation MMGetTaskTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    MMHTTPTaskQueueHandler *httpHandler = [[MMHTTPTaskQueueHandler alloc] initWithBaseURL:[NSURL URLWithString:baseURLString]];
    [MMNetworkTaskQueue sharedQueue].handler = httpHandler;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


- (void)testGetTask {
    _expectation = [self expectationWithDescription:NSStringFromSelector(_cmd)];
    
    MMHTTPTask *testGetTask = [MMHTTPTask new]; // Default is GET task
    
    [[MMNetworkTaskQueue sharedQueue] addTaskDelegate:self uri:testGetTask.uri];
    [[MMNetworkTaskQueue sharedQueue] addTask:testGetTask];
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

-(void)networkTaskDidEnd:(__kindof MMNetworkTask *)task {
    if (!_expectation) {
        return;
    }
        [_expectation fulfill];
    
        if (task.error) {
            XCTFail(@"%@ failed", _expectation.description);
        }
    
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
