//
//  HCUncaughtExceptionHandler.h
//  RunloopLearning
//
//  Created by 贺超 on 2019/12/3.
//  Copyright © 2019年 hechao. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const NSString *HCUncaughtExceptionNameKey;
extern const NSString *HCUncaughtExceptionReasonKey;
extern const NSString *HCUncaughtExceptionAddressesKey;
extern const NSString *HCUncaughtExceptionSymbolsKey;
extern const NSString *HCUncaughtExceptionFileKey;

@interface HCUncaughtExceptionHandler : NSObject

+ (void)installUncaughtExceptionHandler;

@end

NS_ASSUME_NONNULL_END
