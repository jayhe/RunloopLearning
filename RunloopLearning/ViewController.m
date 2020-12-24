//
//  ViewController.m
//  RunloopLearning
//
//  Created by hechao on 2019/3/5.
//  Copyright © 2019 hechao. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>

@interface ViewController () <NSMachPortDelegate>

@property (strong, nonatomic) dispatch_queue_t aQueue;
@property (strong, nonatomic) NSMachPort *machPort;
@property (strong, nonatomic) NSThread *redisentThread;
@property (strong, nonatomic) NSThread *redisentThread1;
@property (weak, nonatomic) IBOutlet UIScrollView *testScrollView;

@end

@implementation ViewController

+ (void)load {
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.testScrollView.contentSize = CGSizeMake(self.view.frame.size.width, self.view.frame.size.height);
    self.testScrollView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    //[self testRunloopRun];
    //[self testRunloopTimerWhileScroll];
    //[self testRunPerformSelector];
//    [self asyncTestDefaultQueueCallMainThread];
//    [self syncTestDefaultQueueSyncCallDefaultQueue];
//    [self syncTestConcurrentQueueSyncCallConcurrentQueue];
//    [self syncTestConcurrentQueueSyncCallConcurrentQueue1];
//    [self testMulThread];
    [self testDoTaskSyncOnMainThread];
//    [self testDoTaskAsyncOnMainThread];
//    [self testRunloop];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

#pragma mark - Action

- (IBAction)showAlertAction:(UIButton *)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Alert" message:@"Test Alert after crash" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)throwUncaughtException:(UIButton *)sender {
    [self testException];
    //[self performSelector:@selector(testException) withObject:nil afterDelay:2]; 失效
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self testException];
//    });
}

#pragma mark - Private Method

- (void)testRunPerformSelector {
    // 这里考察的就是run的机制，run什么时候退出，没有任务直接退出，有任务就任务完成退出
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"111");
        [[NSRunLoop currentRunLoop] run]; // if run here, log 111 222 444
        NSLog(@"222");
        [self performSelector:@selector(testLog) withObject:nil afterDelay:1];
        //[[NSRunLoop currentRunLoop] run]; // if run here, log 111 222 333 444
        NSLog(@"444");
    });
}

- (void)testLog {
    NSLog(@"333");
}

- (void)testException {
    NSArray *array = [NSArray arrayWithObjects:@"1", @"2", nil];
    __unused NSString *testString = array[2];
}

- (void)testSyncCallMainThread {
    dispatch_sync(dispatch_get_main_queue(), ^{ // deadlock
        // 0x10b0c2a01 <+420>: leaq   0x274f0(%rip), %rcx       ; "BUG IN CLIENT OF LIBDISPATCH: dispatch_sync called on queue already owned by current thread"
        NSLog(@"excute in thread:%@ \nlog2", [NSThread currentThread]);
    });
}

- (void)asyncTestDefaultQueueCallMainThread {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ // 这样会死
        NSLog(@"excute in thread:%@ \nlog1", [NSThread currentThread]);
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"excute in thread:%@ \nlog2", [NSThread currentThread]);
        });
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"excute in thread:%@ \nlog3", [NSThread currentThread]);
        });
    });
    // 这里不会产生死锁；异步
    /*
     2019-09-23 17:36:56.458835+0800 RunloopLearning[15191:5817044] excute in thread:<NSThread: 0x60000360f700>{number = 3, name = (null)}
     log1
     2019-09-23 17:36:56.469565+0800 RunloopLearning[15191:5816976] excute in thread:<NSThread: 0x6000036654c0>{number = 1, name = main}
     log2
     */
}

- (void)syncTestDefaultQueueCallMainThread {
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"excute in thread:%@ \nlog1", [NSThread currentThread]);
        dispatch_sync(dispatch_get_main_queue(), ^{ // deadlock
            // 0x10b0c2a01 <+420>: leaq   0x274f0(%rip), %rcx       ; "BUG IN CLIENT OF LIBDISPATCH: dispatch_sync called on queue already owned by current thread"
            NSLog(@"excute in thread:%@ \nlog2", [NSThread currentThread]);
        });
    });
    /*
     2019-09-23 17:37:36.993666+0800 RunloopLearning[15225:5817649] excute in thread:<NSThread: 0x600001506940>{number = 1, name = main}
     log1
     */
}

- (void)syncTestDefaultQueueSyncCallDefaultQueue {
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"excute in thread:%@ \nlog0", [NSThread currentThread]);
    });
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"excute in thread:%@ \nlog1", [NSThread currentThread]);
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSLog(@"excute in thread:%@ \nlog2", [NSThread currentThread]);
        });
        NSLog(@"excute in thread:%@ \nlog3", [NSThread currentThread]);
    });
    // 居然没有切换线程
    /*
     2020-12-23 12:24:16.243429+0800 RunloopLearning[10050:3185765] excute in thread:<NSThread: 0x60000199c1c0>{number = 1, name = main}
     log1
     2020-12-23 12:24:16.243665+0800 RunloopLearning[10050:3185765] excute in thread:<NSThread: 0x60000199c1c0>{number = 1, name = main}
     log2
     2020-12-23 12:24:16.243829+0800 RunloopLearning[10050:3185765] excute in thread:<NSThread: 0x60000199c1c0>{number = 1, name = main}
     log3
     */
    /*
     * As an optimization, dispatch_sync() invokes the workitem on the thread which
     * submitted the workitem, except when the passed queue is the main queue or
     * a queue targetting it (See dispatch_queue_main_t,
     * dispatch_set_target_queue()).
     *
     系统会优化，会直接在提交任务的当前线程执行提交的同步任务，提交任务到主线程除外
     */
}

- (void)syncTestConcurrentQueueSyncCallConcurrentQueue {
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"excute in thread:%@ \nlog00", [NSThread currentThread]);
    });
    dispatch_queue_t queue = dispatch_queue_create("com.test.gcd.concurrent", DISPATCH_QUEUE_CONCURRENT);
    dispatch_sync(queue, ^{
        NSLog(@"excute in thread:%@ \nlog11", [NSThread currentThread]);
        dispatch_sync(queue, ^{
            NSLog(@"excute in thread:%@ \nlog22", [NSThread currentThread]);
        });
        NSLog(@"excute in thread:%@ \nlog33", [NSThread currentThread]);
    });
    // 居然没有切换线程
    /*
     2020-12-23 12:27:23.396859+0800 RunloopLearning[10138:3188531] excute in thread:<NSThread: 0x600002fac500>{number = 1, name = main}
     log11
     2020-12-23 12:27:23.396996+0800 RunloopLearning[10138:3188531] excute in thread:<NSThread: 0x600002fac500>{number = 1, name = main}
     log22
     2020-12-23 12:27:23.397091+0800 RunloopLearning[10138:3188531] excute in thread:<NSThread: 0x600002fac500>{number = 1, name = main}
     log33
     */
}

- (void)syncTestConcurrentQueueSyncCallConcurrentQueue1 {
    dispatch_queue_t queue = dispatch_queue_create("com.test.gcd.concurrent", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue, ^{
        NSLog(@"excute in thread:%@ \nlog111", [NSThread currentThread]);
        dispatch_sync(queue, ^{
            NSLog(@"excute in thread:%@ \nlog222", [NSThread currentThread]);
            dispatch_sync(queue, ^{
                NSLog(@"excute in thread:%@ \nlog333", [NSThread currentThread]);
            });
        });
        NSLog(@"excute in thread:%@ \nlog444", [NSThread currentThread]);
    });
    /*
     2020-12-23 13:45:16.972327+0800 RunloopLearning[10869:3219274] excute in thread:<NSThread: 0x600003676700>{number = 5, name = (null)}
     log111
     2020-12-23 13:45:19.958500+0800 RunloopLearning[10869:3219274] excute in thread:<NSThread: 0x600003676700>{number = 5, name = (null)}
     log222
     2020-12-23 13:45:26.475293+0800 RunloopLearning[10869:3219274] excute in thread:<NSThread: 0x600003676700>{number = 5, name = (null)}
     log333
     2020-12-23 13:45:37.111447+0800 RunloopLearning[10869:3219274] excute in thread:<NSThread: 0x600003676700>{number = 5, name = (null)}
     log444
     */
}

- (void)testMulThread {
#define TEST_QUEUE_DEADLOCK 1
#if TEST_QUEUE_DEADLOCK
    NSLog(@"excute in thread:%@ \nlog0", [NSThread currentThread]);
    dispatch_queue_t queue = dispatch_queue_create("com.test.gcd", DISPATCH_QUEUE_SERIAL);
//    dispatch_async(queue, ^{
    dispatch_sync(queue, ^{
        NSLog(@"excute in thread:%@ \nlog1", [NSThread currentThread]);
//        dispatch_sync(queue, ^{ // deadlock
        dispatch_async(dispatch_get_main_queue(), ^{ // no deadlock
            // 0x10b0c2a01 <+420>: leaq   0x274f0(%rip), %rcx       ; "BUG IN CLIENT OF LIBDISPATCH: dispatch_sync called on queue already owned by current thread"
            NSLog(@"excute in thread:%@ \nlog2", [NSThread currentThread]);
        });
    });
#else
    NSLog(@"excute in thread:%@ \nlog0", [NSThread currentThread]);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"excute in thread:%@ \nlog1", [NSThread currentThread]);
    });
    NSLog(@"excute in thread:%@ \nlog2", [NSThread currentThread]);
#endif
    /*
     内部会调用到_dispatch_sync_f_slow，当queue正在do_targetq就进入到_dispatch_sync_wait
     DISPATCH_NOINLINE
     static void
     _dispatch_sync_f_slow(dispatch_queue_t dq, void *ctxt,
     dispatch_function_t func, uintptr_t dc_flags)
     {
     if (unlikely(!dq->do_targetq)) {
     return _dispatch_sync_function_invoke(dq, ctxt, func);
     }
     _dispatch_sync_wait(dq, ctxt, func, dc_flags, dq, dc_flags);
     }
     
     DISPATCH_NOINLINE
     static void
     _dispatch_sync_wait(dispatch_queue_t top_dq, void *ctxt,
     dispatch_function_t func, uintptr_t top_dc_flags,
     dispatch_queue_t dq, uintptr_t dc_flags)
     {
     pthread_priority_t pp = _dispatch_get_priority();
     dispatch_tid tid = _dispatch_tid_self();
     dispatch_qos_t qos;
     uint64_t dq_state;
     
     dq_state = _dispatch_sync_wait_prepare(dq);
     if (unlikely(_dq_state_drain_locked_by(dq_state, tid))) {
     DISPATCH_CLIENT_CRASH((uintptr_t)dq_state,
     "dispatch_sync called on queue "
     "already owned by current thread");
     }
     
     struct dispatch_sync_context_s dsc = {
     .dc_flags    = dc_flags | DISPATCH_OBJ_SYNC_WAITER_BIT,
     .dc_other    = top_dq,
     .dc_priority = pp | _PTHREAD_PRIORITY_ENFORCE_FLAG,
     .dc_voucher  = DISPATCH_NO_VOUCHER,
     .dsc_func    = func,
     .dsc_ctxt    = ctxt,
     .dsc_waiter  = tid,
     };
     if (_dq_state_is_suspended(dq_state) ||
     _dq_state_is_base_anon(dq_state)) {
     dsc.dc_data = DISPATCH_WLH_ANON;
     } else if (_dq_state_is_base_wlh(dq_state)) {
     dsc.dc_data = (dispatch_wlh_t)dq;
     } else {
     _dispatch_sync_waiter_compute_wlh(dq, &dsc);
     }
     #if DISPATCH_COCOA_COMPAT
     // It's preferred to execute synchronous blocks on the current thread
     // due to thread-local side effects, etc. However, blocks submitted
     // to the main thread MUST be run on the main thread
     //
     // Since we don't know whether that will happen, save the frame linkage
     // for the sake of _dispatch_sync_thread_bound_invoke
     _dispatch_thread_frame_save_state(&dsc.dsc_dtf);
     
     // Since the continuation doesn't have the CONSUME bit, the voucher will be
     // retained on adoption on the thread bound queue if it happens so we can
     // borrow this thread's reference
     dsc.dc_voucher = _voucher_get();
     dsc.dc_func = _dispatch_sync_thread_bound_invoke;
     dsc.dc_ctxt = &dsc;
     #endif
     
     if (dsc.dc_data == DISPATCH_WLH_ANON) {
     dsc.dsc_override_qos_floor = dsc.dsc_override_qos =
     _dispatch_get_basepri_override_qos_floor();
     qos = _dispatch_qos_from_pp(pp);
     _dispatch_thread_event_init(&dsc.dsc_event);
     } else {
     qos = 0;
     }
     _dispatch_queue_push_sync_waiter(dq, &dsc, qos);
     if (dsc.dc_data == DISPATCH_WLH_ANON) {
     _dispatch_thread_event_wait(&dsc.dsc_event); // acquire
     _dispatch_thread_event_destroy(&dsc.dsc_event);
     // If _dispatch_sync_waiter_wake() gave this thread an override,
     // ensure that the root queue sees it.
     if (dsc.dsc_override_qos > dsc.dsc_override_qos_floor) {
     _dispatch_set_basepri_override_qos(dsc.dsc_override_qos);
     }
     } else {
     _dispatch_event_loop_wait_for_ownership(&dsc);
     }
     _dispatch_introspection_sync_begin(top_dq);
     #if DISPATCH_COCOA_COMPAT
     if (unlikely(dsc.dsc_func == NULL)) {
     // Queue bound to a non-dispatch thread, the continuation already ran
     // so just unlock all the things, except for the thread bound queue
     dispatch_queue_t bound_dq = dsc.dc_other;
     return _dispatch_sync_complete_recurse(top_dq, bound_dq, top_dc_flags);
     }
     #endif
     _dispatch_sync_invoke_and_complete_recurse(top_dq, ctxt, func,top_dc_flags);
     }
     */
}

void dispatch_async_on_main_queue(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

void dispatch_sync_on_main_queue(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

- (void)testDoTaskSyncOnMainThread {
#define TestCase1 0
#define TestCase2 0
#define TestCase3 0
#define TestCase4 1
#if TestCase1
    // case 1
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            dispatch_sync_on_main_queue(^{
                NSLog(@"case 1 %s\n OnThread:%@", __FUNCTION__, [NSThread currentThread]);
            });
            NSLog(@"case 1 do another task OnThread:%@",[NSThread currentThread]);
        });
        NSLog(@"case 1 testDoTaskSyncOnMainThread");
        /*
         2020-12-24 16:12:30.709649+0800 RunloopLearning[22633:521605] case 1 testDoTaskSyncOnMainThread
         2020-12-24 16:12:30.772703+0800 RunloopLearning[22633:521605] case 1 -[ViewController testDoTaskSyncOnMainThread]_block_invoke_2
          OnThread:<NSThread: 0x600002df0a80>{number = 1, name = main}
         2020-12-24 16:12:30.773024+0800 RunloopLearning[22633:521868] case 1 do another task OnThread:<NSThread: 0x600002dbd6c0>{number = 3, name = (null)}
         */
    }
    return;
#endif
#if TestCase2
    // case 2
    {
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            dispatch_sync_on_main_queue(^{
                NSLog(@"case 2 %s\n OnThread:%@", __FUNCTION__, [NSThread currentThread]);
            });
            NSLog(@"case 2 do another task OnThread:%@",[NSThread currentThread]);
        });
        NSLog(@"case 2 testDoTaskSyncOnMainThread");
        /*
         2020-12-24 16:13:03.028826+0800 RunloopLearning[22660:522420] case 2 -[ViewController testDoTaskSyncOnMainThread]_block_invoke_2
          OnThread:<NSThread: 0x600003e888c0>{number = 1, name = main}
         2020-12-24 16:13:03.029261+0800 RunloopLearning[22660:522420] case 2 do another task OnThread:<NSThread: 0x600003e888c0>{number = 1, name = main}
         2020-12-24 16:13:03.029394+0800 RunloopLearning[22660:522420] case 2 testDoTaskSyncOnMainThread
         */
    }
    return;
#endif
#if TestCase3
    {
        dispatch_queue_t queue = dispatch_queue_create("com.test.gcd", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(queue, ^{
            NSLog(@"case 3 testDoTaskSyncOnMainThread begin and OnThread:%@", [NSThread currentThread]);
            dispatch_sync_on_main_queue(^{
                NSLog(@"case 3 %s\n OnThread:%@", __FUNCTION__, [NSThread currentThread]);
            });
            NSLog(@"case 3 do another task OnThread:%@",[NSThread currentThread]);
        });
        NSLog(@"case 3 testDoTaskSyncOnMainThread end and OnThread:%@", [NSThread currentThread]);
        /*
         2020-12-24 16:21:43.384532+0800 RunloopLearning[22881:529011] case 3 testDoTaskSyncOnMainThread begin and OnThread:<NSThread: 0x6000037b0a40>{number = 1, name = main}
         2020-12-24 16:21:43.384799+0800 RunloopLearning[22881:529011] case 3 -[ViewController testDoTaskSyncOnMainThread]_block_invoke_2
          OnThread:<NSThread: 0x6000037b0a40>{number = 1, name = main}
         2020-12-24 16:21:43.384971+0800 RunloopLearning[22881:529011] case 3 do another task OnThread:<NSThread: 0x6000037b0a40>{number = 1, name = main}
         2020-12-24 16:21:43.385111+0800 RunloopLearning[22881:529011] case 3 testDoTaskSyncOnMainThread end and OnThread:<NSThread: 0x6000037b0a40>{number = 1, name = main}
         */
    }
    return;
#endif
#if TestCase4
    {
        dispatch_queue_t queue = dispatch_queue_create("com.test.gcd", DISPATCH_QUEUE_SERIAL);
        dispatch_async(queue, ^{
            NSLog(@"case 4 testDoTaskSyncOnMainThread begin and OnThread:%@", [NSThread currentThread]);
            dispatch_sync_on_main_queue(^{
                NSLog(@"case 4 %s\n OnThread:%@", __FUNCTION__, [NSThread currentThread]);
            });
            NSLog(@"case 4 do another task OnThread:%@",[NSThread currentThread]);
        });
        NSLog(@"case 4 testDoTaskSyncOnMainThread end and OnThread:%@", [NSThread currentThread]);
        /*
         2020-12-24 16:23:41.188313+0800 RunloopLearning[22934:530733] case 4 testDoTaskSyncOnMainThread end and OnThread:<NSThread: 0x600003db82c0>{number = 1, name = main}
         2020-12-24 16:23:41.193065+0800 RunloopLearning[22934:530807] case 4 testDoTaskSyncOnMainThread begin and OnThread:<NSThread: 0x600003df6c40>{number = 5, name = (null)}
         2020-12-24 16:23:41.256800+0800 RunloopLearning[22934:530733] case 4 -[ViewController testDoTaskSyncOnMainThread]_block_invoke_2
          OnThread:<NSThread: 0x600003db82c0>{number = 1, name = main}
         2020-12-24 16:23:41.256959+0800 RunloopLearning[22934:530807] case 4 do another task OnThread:<NSThread: 0x600003df6c40>{number = 5, name = (null)}
         */
    }
    return;
#endif
}

- (void)testDoTaskAsyncOnMainThread {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async_on_main_queue(^{
            NSLog(@"%s\n OnThread:%@", __FUNCTION__, [NSThread currentThread]);
        });
        NSLog(@"do another task");
    });
    NSLog(@"testDoTaskAsyncOnMainThread");
    /*
     2020-12-24 15:52:40.824594+0800 RunloopLearning[22235:508263] testDoTaskAsyncOnMainThread
     2020-12-24 15:52:40.824696+0800 RunloopLearning[22235:508380] do another task
     2020-12-24 15:52:40.880142+0800 RunloopLearning[22235:508263] -[ViewController testDoTaskAsyncOnMainThread]_block_invoke_2
      OnThread:<NSThread: 0x600003a58040>{number = 1, name = main}
     */
}

- (void)testRunloop {
    goto runloop;
runloop:
    {
        // Runloop run and exit(if no source、timer)
        _aQueue = dispatch_queue_create("com.hc.runlooplearning0", DISPATCH_QUEUE_CONCURRENT);
        dispatch_async(self.aQueue, ^{
            NSLog(@"excute task 0 on thread:%@", [NSThread currentThread]);
            [self performSelector:@selector(log) withObject:nil afterDelay:1];
            [self performSelector:@selector(log) withObject:nil afterDelay:2];
            [[NSThread currentThread] setName:@"RunloopLearning"];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            [runLoop runUntilDate:[NSDate distantFuture]]; //If no input sources or timers are attached to the run loop, this method exits immediately
            dispatch_sync(self.aQueue, ^{
                NSLog(@"excute task 1 on thread:%@", [NSThread currentThread]);
                [self performSelector:@selector(log) withObject:nil afterDelay:1];
                [self performSelector:@selector(log) onThread:[NSThread currentThread] withObject:nil waitUntilDone:NO];
            });
        });
        
        goto code_break;
    }
redisent_runloop:
    {
        // redisent runloop
        dispatch_queue_t queue = dispatch_queue_create("com.hc.runlooplearning1", DISPATCH_QUEUE_CONCURRENT);
        dispatch_async(queue, ^{
            [[NSThread currentThread] setName:@"RunloopLearningRedisent"];
            self.redisentThread = [NSThread currentThread];
            NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
            self.machPort = [[NSMachPort alloc] init];
            self.machPort.delegate = self;
//            [self.machPort scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
            [runLoop addPort:self.machPort forMode:NSDefaultRunLoopMode];
            [self performSelector:@selector(log) withObject:nil afterDelay:1];
            [runLoop run];
        });
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSelector:@selector(log) onThread:self.redisentThread withObject:nil waitUntilDone:NO];
            NSString *s1 = @"hello main thread";
            NSData *data = [s1 dataUsingEncoding:NSUTF8StringEncoding];
            [self.machPort sendBeforeDate:[NSDate date] components:@[[NSMachPort port], data].mutableCopy from:nil reserved:0];
        });
        goto code_break;
    }
runloop_timer:
    {
        // runloop timer
        dispatch_queue_t queue = dispatch_queue_create("com.hc.runlooplearning2", DISPATCH_QUEUE_CONCURRENT);
        dispatch_async(queue, ^{
            NSLog(@"runloop_timer start");
            NSTimer *repeatTimer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(loopLog) userInfo:nil repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:repeatTimer forMode:NSDefaultRunLoopMode];
            [[NSRunLoop currentRunLoop] performInModes:@[NSDefaultRunLoopMode] block:^{
                sleep(4);
            }];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:6]];
            NSLog(@"runloop_timer end");
        });
        goto code_break;
    }
code_break:
    {
        
    }
}

- (void)loopLog {
    NSLog(@"excute loopLog");
}

#pragma mark - Runloop Run

- (void)testRunloopRun {
    self.redisentThread1 = [[NSThread alloc] initWithTarget:self selector:@selector(runloopAction) object:nil];
    [self.redisentThread1 setName:@"redisentThread1"];
    [self.redisentThread1 start];
}

- (void)log {
    NSLog(@"excute log");
}

BOOL shouldKeepRunning = YES; // global

- (void)runloopAction {
    NSLog(@"执行方法 %s and mode: %@", __FUNCTION__, [[NSRunLoop currentRunLoop] currentMode]);
    NSInteger testCase = 1;
    switch (testCase) {
        case 0: { // 开启runloop，不保活
            NSLog(@"before run %s", __FUNCTION__);
            [[NSRunLoop currentRunLoop] run];
            NSLog(@"after run %s", __FUNCTION__);
            // 1. 如果没有资源或者timer处理，那么redisentThread1线程的runloop会立马退出(runUntilDate:即使指定distanceFuture也会)；
            //    这时候touch屏幕指定在redisentThread1执行该方法，则该线程的runloop没有开启，此时不会执行该方法。
        }
            break;
        case 1: { // 开启runloop，保活
//            while (1) {
//                NSLog(@"before run %s", __FUNCTION__);
//                [[NSRunLoop currentRunLoop] run];
//                NSLog(@"after run %s", __FUNCTION__);
//            }
            NSLog(@"before run %s", __FUNCTION__);
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                NSRunLoop *theRL = [NSRunLoop currentRunLoop];
                NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate distantFuture] interval:0.0 target:self selector:@selector(step) userInfo:nil repeats:NO];
                [theRL addTimer:timer forMode:NSDefaultRunLoopMode];
                onceToken = ~0l;
                while (shouldKeepRunning && [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
            });
            NSLog(@"after run %s", __FUNCTION__);
        }
            break;
        default:
            break;
    }
}

- (void)step {
    // do nothing
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self performSelector:@selector(runloopAction) onThread:self.redisentThread1 withObject:nil waitUntilDone:NO];
}

#pragma mark - Runloop Timer

- (void)testRunloopTimerWhileScroll {
//    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
//        NSLog(@"timer callback and in mode:%@", [NSRunLoop currentRunLoop].currentMode);
//    }];
    static NSInteger times = 0;
    NSTimer *timer = [NSTimer timerWithTimeInterval:20 * 60 repeats:YES block:^(NSTimer * _Nonnull timer) {
        times++;
        NSLog(@"timer callback and in mode:%@ and times = %ld", [NSRunLoop currentRunLoop].currentMode, (long)times);
    }];
    /*
     You can add a timer to multiple input modes. While running in the designated mode, the receiver causes the timer to fire on or after its scheduled fire date. Upon firing, the timer invokes its associated handler routine, which is a selector on a designated object.
     The receiver retains aTimer. To remove a timer from all run loop modes on which it is installed, send an invalidate message to the timer.
     */
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    // 部分输出
    /*
     RunloopLearning[67890:8587221] timer callback and in mode:UITrackingRunLoopMode
     RunloopLearning[67890:8587221] timer callback and in mode:kCFRunLoopDefaultMode
     */
    // 我们退到后台等待一个周期的时间，再到前台可以看到如下结果；2个时间差不是20min了
    //2020-03-16 11:08:00.883044+0800 RunloopLearning[35657:1085764] timer callback and in mode:kCFRunLoopDefaultMode and times = 3
    //2020-03-16 11:09:58.365953+0800 RunloopLearning[35657:1085764] timer callback and in mode:kCFRunLoopDefaultMode and times = 4
}

#pragma mark - NSMachPortDelegate

- (void)handlePortMessage:(id)msg {
    NSLog(@"%@", [NSThread currentThread]);
    NSArray *components = [msg valueForKey:@"components"];
    NSString *reveived = [[NSString alloc] initWithData:components[1] encoding:NSUTF8StringEncoding];
    NSLog(@"reveived data:%@", reveived);
}

@end
