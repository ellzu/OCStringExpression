//
//  StringExpressionTests.m
//  StringExpressionTests
//
//  Created by ellzu on 2019/7/25.
//  Copyright © 2019 ellzu. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <StringExpression/StringExpression.h>

@interface StringExpressionTests : XCTestCase

@end

@implementation StringExpressionTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    NSString *expression = @"0/2";
    
    [[[SEEngine alloc] init] excuteStringExpression:expression paremeterHandler:^id _Nullable(NSString * _Nonnull parameterName) {
        NSLog(@"parameterName:%@",parameterName);
        return @"r";
    } completion:^(NSError * _Nullable error, id  _Nullable result) {
        NSLog(@"error:%@",error);
        NSLog(@"result:%@",result);
    }];
    NSLog(@"...");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
