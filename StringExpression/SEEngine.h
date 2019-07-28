//
//  SEEngine.h
//  StringExpression
//
//  Created by ellzu on 2019/7/25.
//  Copyright © 2019 ellzu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const SEEngineErrorDomain;

NS_ERROR_ENUM(SEEngineErrorDomain){
    SEEngineExpressionError = -1
};

@interface SEEngine : NSObject


/// 根据给定的表达式计算
/// @param expression 表达式 example: "1 + ${currentWeekDay}"
/// @param paremeterHandler 参数获取Handler， 如上面 currentWeekDay 就会调用paremeterHandler获取 currentWeekDays的值
/// @param completion 计算完成回调
- (void)excuteStringExpression:(NSString *)expression
              paremeterHandler:(nullable id _Nullable (^)(NSString *parameterName))paremeterHandler
                    completion:(void(^)(NSError  * _Nullable error,id _Nullable result))completion;



@end

NS_ASSUME_NONNULL_END
