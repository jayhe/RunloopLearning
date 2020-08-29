//
//  HCSignalHandler.h
//  RunloopLearning
//
//  Created by 贺超 on 2019/12/3.
//  Copyright © 2019年 hechao. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern const NSString *HCSignalExceptionSymbolsKey;

extern void HCSetSignalExceptionHandler(NSUncaughtExceptionHandler * _Nullable);
extern NSUncaughtExceptionHandler * _Nullable HCGetSignalExceptionHandler(void);

@interface HCSignalHandler : NSObject

+ (void)installSignalHandler;

@end

NS_ASSUME_NONNULL_END
