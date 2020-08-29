//
//  HCSignalHandler.m
//  RunloopLearning
//
//  Created by 贺超 on 2019/12/3.
//  Copyright © 2019年 hechao. All rights reserved.
//

#import "HCSignalHandler.h"
#include <sys/signal.h>
#include <execinfo.h>

const NSString *HCSignalExceptionSymbolsKey = @"signalSymbols";
const NSInteger HCUncaughtExceptionSkipAddressCount = 0;
const NSInteger HCUncaughtExceptionReportAddressCount = 128;
static NSUncaughtExceptionHandler *HCSingalHandler;

void HCSetSignalExceptionHandler(NSUncaughtExceptionHandler *handler) {
    HCSingalHandler = handler;
}

NSUncaughtExceptionHandler *HCGetSignalExceptionHandler(void) {
    return HCSingalHandler;
}

@implementation HCSignalHandler

void SignalExceptionHandler(int signal) {
    if (HCGetSignalExceptionHandler() != NULL) {
        NSArray *symbols = [HCSignalHandler backtraceInfo];
        NSDictionary *userInfo = @{
                                   HCSignalExceptionSymbolsKey : symbols
                                   };
        NSException *exception = [NSException exceptionWithName:@"signal" reason:@(signal).stringValue userInfo:userInfo];
        NSUncaughtExceptionHandler *handler = HCGetSignalExceptionHandler();
        if (handler) {
            handler(exception);
        } else {
            
        }
    }
}

+ (void)installSignalHandler {
    signal(SIGHUP, SignalExceptionHandler);
    signal(SIGINT, SignalExceptionHandler);
    signal(SIGQUIT, SignalExceptionHandler);
    signal(SIGABRT, SignalExceptionHandler);
    signal(SIGILL, SignalExceptionHandler);
    signal(SIGSEGV, SignalExceptionHandler);
    signal(SIGFPE, SignalExceptionHandler);
    signal(SIGBUS, SignalExceptionHandler);
    signal(SIGPIPE, SignalExceptionHandler);
}

+ (NSArray *)backtraceInfo {
    void *callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    NSMutableArray *backtraceArray = [NSMutableArray arrayWithCapacity:0];
    long maxIndex = MIN(HCUncaughtExceptionSkipAddressCount + HCUncaughtExceptionReportAddressCount, frames);
    for (NSInteger i = HCUncaughtExceptionSkipAddressCount; i < maxIndex; i ++) {
        NSString *backtraceString = [NSString stringWithUTF8String:strs[i]];
        if (backtraceString.length) {
            [backtraceArray addObject:backtraceString];
        }
    }
    free(strs);
    
    return backtraceArray;
}

@end
