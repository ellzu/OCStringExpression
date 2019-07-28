//
//  SEEngine.m
//  StringExpression
//
//  Created by ellzu on 2019/7/25.
//  Copyright © 2019 ellzu. All rights reserved.
//

#import "SEEngine.h"

NS_ASSUME_NONNULL_BEGIN

#define SEEngineAliasNamePrefix @"`A#"
#define SEEngineAliasNameSuffix @"#N`"

NSErrorDomain const SEEngineErrorDomain = @"SEEngineErrorDomain";

@interface SEEngine ()
@property (nonatomic, assign) NSInteger randomContext;
@end

@implementation SEEngine

/// 根据给定的表达式计算
/// @param expression 表达式 example: "1 + ${currentWeekDay}"
/// @param paremeterHandler 参数获取Handler， 如上面 currentWeekDay 就会调用paremeterHandler获取 currentWeekDays的值
/// @param completion 计算完成回调
- (void)excuteStringExpression:(NSString *)expression
              paremeterHandler:(nullable id _Nullable (^)(NSString *parameterName))paremeterHandler
                    completion:(void(^)(NSError  * _Nullable error,id _Nullable result))completion
{
    [self excuteStringExpression:expression parameters:nil paremeterHandler:paremeterHandler completion:completion];
}


/// 根据给定的表达式计算
/// @param expression 表达式 example: "1 + ${currentWeekDay}"
/// @param parameters 参数集合，如果不想通过paremeterHandler处理参数，可以提前把参数放到parameters来 example: {@"currentWeekDay":5}
/// @param paremeterHandler 参数获取Handler， 如上面 currentWeekDay 就会调用paremeterHandler获取 currentWeekDays的值
/// @param completion 计算完成回调
- (void)excuteStringExpression:(NSString *)expression
                    parameters:(nullable NSDictionary<id,id> *)parameters
              paremeterHandler:(nullable id _Nullable (^)(NSString *parameterName))paremeterHandler
                    completion:(void(^)(NSError  * _Nullable error,id _Nullable result))completion
{
    NSMutableDictionary<id, id> *mParameters = [NSMutableDictionary dictionary];
    if (parameters.count > 0) {
        [mParameters setDictionary:parameters];
    }
    NSMutableString *mExpression = [NSMutableString stringWithString:expression.length == 0 ? @"" : expression];
 
    __block NSError *error = nil;
    id value = nil;
    //字符串提取
    while(mExpression.length > 0) {
        NSString *regex = @"\"[^\"]*?\"|'[^']*?'"; // 'string' or "String"
        NSRange range = [mExpression rangeOfString:regex options:NSRegularExpressionSearch];
        if (range.location == NSNotFound) {
            break;
        }
        NSString *stringValue = [mExpression substringWithRange:NSMakeRange(range.location + 1, range.length - 2)];
        NSString *aliasName = [self randomAliasName];
        [mParameters setObject:stringValue forKey:aliasName];
        [mExpression replaceCharactersInRange:range withString:aliasName];
    }
    
    //变量提取
    while(mExpression.length > 0) {
        NSRange range = NSMakeRange(NSNotFound, 0);
        NSInteger nested = 0;
        for (NSInteger i=0; i < mExpression.length; i++) {
            if ([mExpression characterAtIndex:i] == '$' && mExpression.length > (i + 1) && [mExpression characterAtIndex:i + 1 ] == '{') {
                range.location = i;
                nested = 1;
                i++;
                continue;
            }
            if (range.location == NSNotFound) {
                continue;
            }
            if ([mExpression characterAtIndex:i] == '{') {
                nested++ ;
                continue;
            }
            if ([mExpression characterAtIndex:i] == '}') {
                nested-- ;
            }
            if (nested == 0) {
                range.length = i - range.location + 1;
                break;
            }
        }
        if (range.location == NSNotFound || range.length < 3) {
            break;
        }
        NSString *variateName = [mExpression substringWithRange:NSMakeRange(range.location + 2, range.length - 3)];
        NSString *aliasName = [self randomAliasName];
        id variateValue = [self variateValueWithName:variateName parameters:mParameters paremeterHandler:paremeterHandler];
        if (variateValue != nil) {
            [mParameters setObject:variateValue forKey:aliasName];
        }
        [mExpression replaceCharactersInRange:range withString:aliasName];
    }
    
    //子表达式()
    while (error == nil && mExpression.length > 0) {
        NSString *regex = @"\\([^()]*?\\)"; // ${{name}}
        NSRange range = [mExpression rangeOfString:regex options:NSRegularExpressionSearch];
        if (range.location == NSNotFound) {
            break;
        }
        
        NSString *fragmentConditions = [mExpression substringWithRange:NSMakeRange(range.location + 1, range.length - 2)];
        __block id fragmentValue = nil;
        [self excuteStringExpression:fragmentConditions parameters:mParameters paremeterHandler:paremeterHandler completion:^(NSError * _Nullable e, id  _Nullable result) {
            error = e;
            fragmentValue = result;
        }];
        NSString *aliasName = [self randomAliasName];
        if (fragmentValue) {
            [mParameters setObject:fragmentValue forKey:aliasName];
        }
        [mExpression replaceCharactersInRange:range withString:aliasName];
    }
    
    //运算符 排在后面的优先级高
    NSArray<NSString *> *regexs = @[@"[|][|]|&&",
                                    @"(>=?|<=?|==?|!=)",
                                    @"([+-])",
                                    @"([*/])",
                                    @"[|]|&"
                                    ];
    for (NSInteger i = 0; mExpression.length > 0 && error == nil && i < regexs.count ; i++) {
        NSString *regex = [regexs objectAtIndex:i];
        NSRange range = [mExpression rangeOfString:regex options:NSRegularExpressionSearch];
        if (range.location == NSNotFound) {
            continue;
        }
        NSString *leftFragmentExpression = [self trimmingString:[mExpression substringToIndex:range.location]];
        NSString *operator = [mExpression substringWithRange:range];
        NSString *rightFragmentExpression = [self trimmingString:[mExpression substringFromIndex:range.location + range.length]];
        __block id leftFragmentValue = nil;
        [self excuteStringExpression:leftFragmentExpression parameters:mParameters paremeterHandler:paremeterHandler completion:^(NSError * _Nullable e, id  _Nullable result) {
            error = e;
            leftFragmentValue = result;
        }];
        __block id rightFragmentValue = nil;
        [self excuteStringExpression:rightFragmentExpression parameters:mParameters paremeterHandler:paremeterHandler completion:^(NSError * _Nullable e, id  _Nullable result) {
            error = e;
            rightFragmentValue = result;
        }];
        if (error) {
            break;
        }
        NSObject *fragmentValue = [self operatorResult:leftFragmentValue toObject:rightFragmentValue operator:operator];
        if (fragmentValue == nil) {
            NSDictionary *userInfo = @{@"expression":[NSString stringWithFormat:@"%@ %@ %@",leftFragmentValue, operator, rightFragmentValue]};
            error = [NSError errorWithDomain:SEEngineErrorDomain code:SEEngineExpressionError userInfo:userInfo];
            break;
        }
        mExpression = nil;
        value = fragmentValue;
    }
    
    if (error == nil && value == nil && mExpression.length > 0) {
        value = [self expressionResult:[self trimmingString:mExpression] parameters:mParameters error:&error];
    }
    
    !completion ?: completion(error,value);
}

- (NSString *)trimmingString:(NSString *)str
{
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (NSInteger)randomContext
{
    return ++_randomContext;
}

- (NSString *)randomAliasName
{
    NSString *name = [NSString stringWithFormat:@"%@%ld%@", SEEngineAliasNamePrefix, (long)self.randomContext, SEEngineAliasNameSuffix];
    return name;
}


/// 最小表达式计算 （单个操作符计算)
/// @param obj1 左值
/// @param obj2 右值
/// @param operator 操作符
- (nullable id)operatorResult:(nullable id)obj1 toObject:(id)obj2 operator:(NSString *)operator
{
    id result = nil;
    do {
        if ([@"!=" isEqualToString:operator] || [@"==" isEqualToString:operator] || [@"=" isEqualToString:operator]) {
            BOOL isEqual = NO;
            if (obj1 == nil && obj2 == nil) { //两个都是nil
                isEqual = YES;
            } else if ( (obj1 == nil && obj2 != nil) || (obj1 != nil && obj2 == nil)) { //只有一个为 nil
                isEqual = NO;
            } else if (obj1 == obj2) { //指针相等
                isEqual = YES;
            } else {
                isEqual = [obj1 isEqual:obj2];
            }
            result = [@"!=" isEqualToString:operator] ? @(!isEqual) : @(isEqual);
            break;
        }
        
        if ([@[@">", @">=", @"<", @"<="] containsObject:operator]) {
            if (obj1 == nil || obj2 == nil || ![obj1 isKindOfClass:[obj2 class]]) {
                break;
            }
            if (![obj1 respondsToSelector:@selector(compare:)]) {
                break;
            }
            NSComparisonResult cResult = (NSComparisonResult)[obj1 performSelector:@selector(compare:) withObject:obj2];
            if ([operator characterAtIndex:0] == '>') { //调转大于号的比较结果 令到 compare的结果排列与当前操作符一致
                cResult = cResult == NSOrderedSame ? NSOrderedSame : (cResult == NSOrderedAscending ? NSOrderedDescending : NSOrderedAscending);
            }
            if (operator.length == 2) { //带等于号
                result = cResult == NSOrderedDescending ? @(NO) : @(YES);
            } else {
                result = cResult == NSOrderedAscending ? @(YES) : @(NO);
            }
            break;
        }
        
        if ([@"+" isEqualToString:operator]) {
            if ( (obj1 == nil || [obj1 isKindOfClass:[NSNumber class]]) && [obj2 isKindOfClass:[NSNumber class]]) {
                obj1 = obj1 == nil ? @(0) : obj1;
                result = @([(NSNumber *)obj1 doubleValue] + [(NSNumber *)obj2 doubleValue]);
            } else if ([obj1 isKindOfClass:[NSString class]] || [obj2 isKindOfClass:[NSString class]]) {
                result = [NSString stringWithFormat:@"%@%@", obj1 == nil ? @"" : obj1, obj2 == nil ? @"" : obj2];
            }
            break;
        }
        
        if ([@"-" isEqualToString:operator]) {
            if (obj1 == nil) {
                obj1 = @(0);
            }
            if ([obj1 isKindOfClass:[NSNumber class]] && [obj2 isKindOfClass:[NSNumber class]]) {
                result = @([(NSNumber *)obj1 doubleValue] - [(NSNumber *)obj2 doubleValue]);
            }
            break;
        }
        
        if ([@"*" isEqualToString:operator]) {
            if (obj1 == nil || obj2 == nil) {
                result = @(0);
            } else if ([obj1 isKindOfClass:[NSNumber class]] && [obj2 isKindOfClass:[NSNumber class]]) {
                result = @([(NSNumber *)obj1 doubleValue] * [(NSNumber *)obj2 doubleValue]);
            }
            break;
        }
        
        if ([@"/" isEqualToString:operator]) {
            if (obj1 == nil || obj2 == nil) {
                result = @(0);
            } else if ([obj1 isKindOfClass:[NSNumber class]] && [obj2 isKindOfClass:[NSNumber class]]) {
                if ([(NSNumber *)obj2 doubleValue] != 0) {
                    result = @([(NSNumber *)obj1 doubleValue] / [(NSNumber *)obj2 doubleValue]);
                } else {
                    result = @(0);
                }
            }
            break;
            
        }
        
        BOOL (^boolBlock)(id) = ^(id convertObj){
            BOOL value;
            if (convertObj == nil){
                value = NO;
            } else if ([convertObj respondsToSelector:@selector(boolValue)]) {
                value = [convertObj performSelector:@selector(boolValue)];
            } else {
                value = YES; //其他没有boolValue函数的对象 又不为空 那么就是指针不为空就是YES
            }
            return value;
        };
        
        if ([@"||" isEqualToString:operator]) {
            BOOL bv1 = boolBlock(obj1);
            BOOL bv2 = boolBlock(obj2);
            result = @(bv1 || bv2);
            break;
        }
        
        if ([@"&&" isEqualToString:operator]) {
            BOOL bv1 = boolBlock(obj1);
            BOOL bv2 = boolBlock(obj2);
            result = @(bv1 && bv2);
            break;
        }
        
        if ([@"&" isEqualToString:operator]) {
            if ([obj1 isKindOfClass:[NSNumber class]] && [obj2 isKindOfClass:[NSNumber class]]) {
                result = @( [(NSNumber *)obj1 integerValue] & [(NSNumber *)obj2 integerValue] );
            }
            break;
        }
        
        if ([@"|" isEqualToString:operator]) {
            if ([obj1 isKindOfClass:[NSNumber class]] && [obj2 isKindOfClass:[NSNumber class]]) {
                result = @( [(NSNumber *)obj1 integerValue] | [(NSNumber *)obj2 integerValue] );
            }
            break;
        }
        
        
    } while (false);
    
    return result;
}


/// 变量转换
/// @param expression 变量表达式
/// @param parameters 变量值的集合
/// @param error 转换失败原因
- (nullable id)expressionResult:(NSString *)expression parameters:(nullable NSDictionary<id,id> *)parameters error:(NSError **)error
{
    id result = nil;
    do {
        if (expression.length == 0) {
            result = nil;
            break;
        }
        // 计算中替换的变量
        if (expression.length > (SEEngineAliasNamePrefix.length + SEEngineAliasNameSuffix.length)
            && [expression hasPrefix:SEEngineAliasNamePrefix]
            && [expression hasSuffix:SEEngineAliasNameSuffix]) {
            result = [parameters objectForKey:expression];
            break;
        }
        // 字符串转换
        if (expression.length >= 2 && [expression characterAtIndex:0] == '\"' && [expression characterAtIndex:expression.length - 1] == '\"') {
            result = [expression substringWithRange:NSMakeRange(1, expression.length - 2)];
            break;
        }
        // nil值
        NSRange range =  [expression rangeOfString:@"([Nn][Uu][Ll][Ll])|([Nn][Ii][Ll])" options:NSRegularExpressionSearch];
        if (range.location == 0 && range.length == expression.length) {
            result = nil;
            break;
        }
        
        // YES值
        NSString *lowercaseExpression = expression.lowercaseString;
        if ([lowercaseExpression isEqualToString:@"yes"] || [lowercaseExpression isEqualToString:@"true"]) {
            result = @(YES);
            break;
        }
        // NO值
        if ([lowercaseExpression isEqualToString:@"no"] || [lowercaseExpression isEqualToString:@"false"]) {
            result = @(NO);
            break;
        }
        
        //数字
        range = [expression rangeOfString:@"([-+]?(\\d+\\.\\d+|\\d+))" options:NSRegularExpressionSearch];
        if (range.location == 0 && range.length == expression.length) {
            if ([expression rangeOfString:@"."].location != NSNotFound) {
                result = @([expression doubleValue]);
            } else {
                result = @([expression integerValue]);
            }
            break;
        }
        
        //无法计算的表达式
        if (error) {
            *error = [NSError errorWithDomain:SEEngineErrorDomain code:SEEngineExpressionError userInfo:nil];
        }
        
    }while (NO);
    
    return result;
}


/// 表达式中变量值获取过程
/// @param name 变量名 currentWeekDay
/// @param parameters 变量值集合
/// @param paremeterHandler 变量获取值的Handler
- (nullable id)variateValueWithName:(NSString *)name
                         parameters:(nullable NSDictionary<id, id> *)parameters
                   paremeterHandler:(nullable id _Nullable (^)(NSString *parameterName))paremeterHandler
{
    NSMutableString *mName = nil;
    do {
        NSString *regex = SEEngineAliasNamePrefix @".*?" SEEngineAliasNameSuffix;
        NSRange range = [mName == nil ? name : mName rangeOfString:regex options:NSRegularExpressionSearch];
        if (range.location == NSNotFound) {
            break;
        }
        if (mName.length == 0) {
            mName = [NSMutableString stringWithString:name];
        }
        NSString *subName = [mName substringWithRange:range];
        id subValue = [self expressionResult:subName parameters:parameters error:nil];
        subValue = subValue == nil ? @"" : subValue;
        [mName replaceCharactersInRange:range withString:[NSString stringWithFormat:@"\"%@\"", subValue]];
    } while (mName.length > 0);
    id _Nullable value = nil;
    NSString *useName = mName == nil ? name : mName;
    if(parameters && [[parameters allKeys] containsObject:useName]) {
        value = [parameters objectForKey:useName];
    }
    if (value == nil && paremeterHandler != nil) {
        value = paremeterHandler(useName);
    }
    return value;
}

@end

NS_ASSUME_NONNULL_END
