//
//  TPEventBusTests.m
//  TPEventBusTests
//
//  Created by wanhmr on 09/18/2019.
//  Copyright (c) 2019 wanhmr. All rights reserved.
//

@import XCTest;
#import <TPEventBus/TPEventBus.h>

@interface TPBenchmarkEvent : NSObject <TPEvent>

@end

@implementation TPBenchmarkEvent

@end

@interface Tests : XCTestCase

@end

@implementation Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    {
        TPBenchmarkEvent *event = [TPBenchmarkEvent new];
        CFTimeInterval startTime = CACurrentMediaTime();
        for (NSUInteger i = 0; i < 10000; i++) {
            [[TPEventBus sharedBus] postEvent:event object:nil];
        }
        CFTimeInterval endTime = CACurrentMediaTime();
        CFTimeInterval consumingTime = endTime - startTime;
        NSLog(@"TPEventBus: 耗时：%@", @(consumingTime * 1000));
    }
    {
        CFTimeInterval startTime = CACurrentMediaTime();
        for (NSUInteger i = 0; i < 10000; i++) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"Tpphha" object:nil];
        }
        CFTimeInterval endTime = CACurrentMediaTime();
        CFTimeInterval consumingTime = endTime - startTime;
        NSLog(@"NSNotificationCenter: 耗时：%@", @(consumingTime * 1000));
    }
}

@end

