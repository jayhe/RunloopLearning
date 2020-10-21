//
//  HCUncaughtExceptionHandler.m
//  RunloopLearning
//
//  Created by 贺超 on 2019/12/3.
//  Copyright © 2019年 hechao. All rights reserved.
//

#import "HCUncaughtExceptionHandler.h"
#import "HCSignalHandler.h"
#include <libkern/OSAtomic.h>
#include <stdatomic.h>
#import <Bugly/Bugly.h>
#import <fishhook/fishhook.h>

const NSString *HCUncaughtExceptionNameKey = @"exceptionName";
const NSString *HCUncaughtExceptionReasonKey = @"exceptionReason";
const NSString *HCUncaughtExceptionSymbolsKey = @"exceptionSymbols";
const NSString *HCUncaughtExceptionFileKey = @"exceptionFile";
const NSString *HCUncaughtExceptionExitKey = @"exceptionExit";
const NSString *HCUncaughtExceptionAddressesKey = @"exceptionAddresses";
const NSInteger HCUncaughtExceptionMaxinumCount = 2;

atomic_int HCUncaughtExceptionCount = 0;

void HCUncaughtExceptionHandles(NSException *exception);

@interface HCHandler : NSObject {
    @package
    NSUncaughtExceptionHandler *handler;
}

@end

@implementation HCHandler

- (BOOL)isEqual:(HCHandler *)object {
    if (self == object) {
        return YES;
    }
    
    return (self->handler) == (object->handler);
}

- (NSUInteger)hash {
    //NSLog(@"%ld", (NSUInteger)(self->handler));
    return (NSUInteger)(self->handler);
}

@end

@implementation HCUncaughtExceptionHandler

static void (*SystemNSSetUncaughtExceptionHandler)(NSUncaughtExceptionHandler * _Nullable handler);
static NSHashTable *_handlers;

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _handlers = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];
        struct rebinding rebindingHandler = {};
        rebindingHandler.name = "NSSetUncaughtExceptionHandler";
        rebindingHandler.replacement = (void *)MineSetUncaughtExceptionHandler;
        rebindingHandler.replaced = (void **)&SystemNSSetUncaughtExceptionHandler;
        struct rebinding rebindings[] = {rebindingHandler};
        rebind_symbols(rebindings, 1);
    });
}

void MineSetUncaughtExceptionHandler(NSUncaughtExceptionHandler * _Nullable handler) {
    if (handler == HCUncaughtExceptionHandles) { // 如果handler是我们自己的handler就不加入到hashmap中
        SystemNSSetUncaughtExceptionHandler(&HCUncaughtExceptionHandles);
    } else {
        HCHandler *handlerObj = [HCHandler new];
        handlerObj->handler = handler;
        if (![_handlers containsObject:handlerObj]) {
            [_handlers addObject:handlerObj];
            //SystemNSSetUncaughtExceptionHandler(handler);
        }
    }
}

+ (void)installUncaughtExceptionHandler {
    /*
     1._objc_init中进行异常初始化，设置为_objc_terminate函数
     exception_init();
     void exception_init(void)
     {
         old_terminate = std::set_terminate(&_objc_terminate);
     }
     2._objc_terminate函数内部会对OC的异常调用foundation的uncaught_handler（如果设置了的话）
     static void _objc_terminate(void)
     {
         if (PrintExceptions) {
             _objc_inform("EXCEPTIONS: terminating");
         }

         if (! __cxa_current_exception_type()) {
             // No current exception.
             (*old_terminate)();
         }
         else {
             // There is a current exception. Check if it's an objc exception.
             @try {
                 __cxa_rethrow();
             } @catch (id e) {
                 // It's an objc object. Call Foundation's handler, if any.
                 (*uncaught_handler)((id)e);
                 (*old_terminate)();
             } @catch (...) {
                 // It's not an objc object. Continue to C++ terminate.
                 (*old_terminate)();
             }
         }
     }
     3.objc-exception中提供了读写uncaught_handler的方法
     static objc_uncaught_exception_handler uncaught_handler = _objc_default_uncaught_exception_handler;
     objc_uncaught_exception_handler
     objc_setUncaughtExceptionHandler(objc_uncaught_exception_handler fn)
     {
         objc_uncaught_exception_handler result = uncaught_handler;
         uncaught_handler = fn;
         return result;
     }
     4.发生一个异常
     void objc_exception_throw(id obj)
     {
         struct objc_exception *exc = (struct objc_exception *)
             __cxa_allocate_exception(sizeof(struct objc_exception));

         obj = (*exception_preprocessor)(obj);

         // Retain the exception object during unwinding
         // because otherwise an autorelease pool pop can cause a crash
         [obj retain];

         exc->obj = obj;
         exc->tinfo.vtable = objc_ehtype_vtable+2;
         exc->tinfo.name = object_getClassName(obj);
         exc->tinfo.cls_unremapped = obj ? obj->getIsa() : Nil;

         if (PrintExceptions) {
             _objc_inform("EXCEPTIONS: throwing %p (object %p, a %s)",
                          exc, (void*)obj, object_getClassName(obj));
         }

         if (PrintExceptionThrow) {
             if (!PrintExceptions)
                 _objc_inform("EXCEPTIONS: throwing %p (object %p, a %s)",
                              exc, (void*)obj, object_getClassName(obj));
             void* callstack[500];
             int frameCount = backtrace(callstack, 500);
             backtrace_symbols_fd(callstack, frameCount, fileno(stderr));
         }
         
         OBJC_RUNTIME_OBJC_EXCEPTION_THROW(obj);  // dtrace probe to log throw activity
         __cxa_throw(exc, &exc->tinfo, &_objc_exception_destructor);
         __builtin_trap();
     }
     
     __cxa_throw --> libc++abi.dylib`std::__terminate: --> _objc_terminate
     
     printing description of old_terminate:
     (void (*)()) old_terminate = 0x00007fff7013ac96 (libc++abi.dylib`demangling_terminate_handler())
     Printing description of uncaught_handler:
     (objc_uncaught_exception_handler) uncaught_handler = 0x00007fff3ba23722 (CoreFoundation`__handleUncaughtException)
     
     */
    // 这里先设置自己的在设置bugly的则没有问题，如果先设置bugly在设置自己的，则bugly会一致尝试去设置handler
    //[Bugly startWithAppId:@"7e8a06bf19"];
    NSSetUncaughtExceptionHandler(&HCUncaughtExceptionHandles);
    // 测试重复加入一个handler，验证去重逻辑
    NSSetUncaughtExceptionHandler(&HCAnotherUncaughtExceptionHandles);
    NSSetUncaughtExceptionHandler(&HCAnotherUncaughtExceptionHandles);
    NSSetUncaughtExceptionHandler(&HCAnotherUncaughtExceptionHandles);
    //[HCSignalHandler installSignalHandler];
    //HCSetSignalExceptionHandler(&HCUncaughtExceptionHandles);
}
/*
   (lldb) bt
   * thread #1, queue = 'com.apple.main-thread', stop reason = signal SIGABRT
       frame #0: 0x00007fff523bc7fa libsystem_kernel.dylib`__pthread_kill + 10
       frame #1: 0x00007fff52466bc1 libsystem_pthread.dylib`pthread_kill + 432
       frame #2: 0x00007fff5234ba5c libsystem_c.dylib`abort + 120
       frame #3: 0x00007fff502497f8 libc++abi.dylib`abort_message + 231
       frame #4: 0x00007fff502499c7 libc++abi.dylib`demangling_terminate_handler() + 262
       frame #5: 0x00007fff513fbd7c libobjc.A.dylib`_objc_terminate() + 96
       frame #6: 0x00007fff50256e97 libc++abi.dylib`std::__terminate(void (*)()) + 8
       frame #7: 0x00007fff50256ae9 libc++abi.dylib`__cxa_rethrow + 99
       frame #8: 0x00007fff513fbcb4 libobjc.A.dylib`objc_exception_rethrow + 37
       frame #9: 0x00007fff23bce0ea CoreFoundation`CFRunLoopRunSpecific + 570
       frame #10: 0x00007fff384c0bb0 GraphicsServices`GSEventRunModal + 65
       frame #11: 0x00007fff48092d4d UIKitCore`UIApplicationMain + 1621
     * frame #12: 0x0000000101f13360 RunloopLearning`main(argc=1, argv=0x00007ffeedcedce8) at main.m:14:16
       frame #13: 0x00007fff5227ec25 libdyld.dylib`start + 1
       frame #14: 0x00007fff5227ec25 libdyld.dylib`start + 1
   (lldb)
*/
static void HCAnotherUncaughtExceptionHandles(NSException *exception) {

}

void HCUncaughtExceptionHandles(NSException *exception) {
    NSArray<HCHandler *> *handlers = _handlers.allObjects;
    [handlers enumerateObjectsUsingBlock:^(HCHandler * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj->handler) {
            obj->handler(exception);
        }
    }];
    // 自己的异常处理逻辑
    HCInnerUncaughtExceptionHandles(exception);
}

void HCInnerUncaughtExceptionHandles(NSException *exception) {
    atomic_fetch_add_explicit(&HCUncaughtExceptionCount, 1, memory_order_relaxed);
    BOOL needExit = NO; // 当闪退超过预定的次数就不开启runloop了，上报了日志就退出
    if (HCUncaughtExceptionCount >= HCUncaughtExceptionMaxinumCount) {
        needExit = YES;
    }
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:exception.userInfo];
    [userInfo setObject:exception.name ?: @"no name" forKey:HCUncaughtExceptionNameKey];
    [userInfo setObject:exception.reason ?: @"no reason" forKey:HCUncaughtExceptionReasonKey];
    if (exception.callStackSymbols) {
        [userInfo setObject:exception.callStackSymbols ?: @[] forKey:HCUncaughtExceptionSymbolsKey];
    } else {
        NSArray *symbols = [userInfo objectForKey:HCSignalExceptionSymbolsKey];
        [userInfo setObject:symbols ?: @[] forKey:HCUncaughtExceptionSymbolsKey];
    }
    [userInfo setObject:exception.callStackReturnAddresses forKey:HCUncaughtExceptionAddressesKey];
    [userInfo setObject:@(needExit) forKey:HCUncaughtExceptionExitKey];
    NSString *fileName = [HCUncaughtExceptionHandler exceptionFileName];
    [userInfo setObject:fileName ?: @"file" forKey:HCUncaughtExceptionFileKey];
    NSException *uploadException = [NSException exceptionWithName:exception.name reason:exception.reason userInfo:userInfo];
    [HCUncaughtExceptionHandler performSelectorOnMainThread:@selector(exceptionHandle:) withObject:uploadException waitUntilDone:YES];
}

+ (void)exceptionHandle:(NSException *)exception {
    BOOL needExit = [[exception.userInfo objectForKey:HCUncaughtExceptionExitKey] boolValue];
    BOOL isCompleted = NO;
    // 缓存到本地
    [self saveCrash:exception completedFlag:&isCompleted];
    if (needExit) {
        isCompleted = YES;
    }
    
    // 开启runloop让日志任务完成
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    CFArrayRef modes = CFRunLoopCopyAllModes(runloop);
    // 开启平行空间来处理，isCompleted标记改为YES之前app仍然可以活着
    while (isCompleted == NO) {
        for (NSString *mode in (__bridge NSArray *)modes) {
            CFRunLoopRunInMode((CFStringRef)mode, NSEC_PER_SEC / 1000, false);
        }
    }
    CFRelease(modes);
}

+ (NSString *)exceptionFileName {
    NSString *dateString = [self stringFromDate:[NSDate date]];
    
    return [NSString stringWithFormat:@"%@_crash.log", dateString];
}

#pragma mark - HCExceptionLogProtocol

+ (void)saveCrash:(NSException *)exception completedFlag:(BOOL *)flag {
    NSString *dirPath = [self crashLogsDirectoryPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dirPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *fileName = [exception.userInfo objectForKey:HCUncaughtExceptionFileKey];
    NSString *fileNamePath = [NSString stringWithFormat:@"%@%@", dirPath, fileName];
    [exception.userInfo writeToFile:fileNamePath atomically:YES];
    //*flag = YES;
}

#pragma mark - Tool

+ (NSString *)crashLogsDirectoryPath {
    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dirPath = [NSString stringWithFormat:@"%@/CrashLogs/", documentPath];
    
    return dirPath;
}

+ (NSString *)stringFromDate:(NSDate *)date {
    static NSDateFormatter *dateFormatter;
    if (dateFormatter == nil) {
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyyMMddHHmmss";
        dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh-Hans_CN"];
    }
    
    return [dateFormatter stringFromDate:date];
}

@end
