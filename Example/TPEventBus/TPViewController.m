//
//  TPViewController.m
//  TPEventBus
//
//  Created by wanhmr on 09/18/2019.
//  Copyright (c) 2019 wanhmr. All rights reserved.
//

#import "TPViewController.h"
#import <TPEventBus/TPEventBus.h>
#import "TPTestEvent.h"
#import "TPMediaLikedChangedEvent.h"
#import "TPEventBus_Example-Swift.h"

@interface TPViewController ()

@end

@implementation TPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
//    AViewController *aVC = [AViewController new];
//    aVC.view.frame = CGRectMake(0, 0, self.view.frame.size.width, 100);
//    [self.view addSubview:aVC.view];
//    [self addChildViewController:aVC];
//    [[TPEventBus sharedBus] registerEventType:TPTestEvent.class observer:self selector:@selector(onTestEvent:object:) object:self queue:[NSOperationQueue new]];
    [[TPEventSubscriber(TPMediaLikedChangedEvent).onQueue([NSOperationQueue new]).forObject(nil) onNext:^(TPMediaLikedChangedEvent * _Nonnull event, id  _Nullable object) {
        NSLog(@"event name: %@, object: %@, thread: %@", event.liked, object, [NSThread currentThread]);
    }] disposedByObject:self];
    
    [[TPEventSubscriber(TPTestEvent) onNext:^(TPTestEvent * _Nonnull event, id  _Nullable object) {
        NSLog(@"event name: %@, object: %@, thread: %@", event.name, object, [NSThread currentThread]);
    }] disposedByObject:self];
}

- (IBAction)testAction:(id)sender {
//    {
//        TPTestEvent *event = [TPTestEvent new];
//        event.name = @"Tpphha";
//        CFTimeInterval startTime = CACurrentMediaTime();
//        for (NSUInteger i = 0; i < 10000; i++) {
//            [[TPEventBus sharedBus] postEvent:event object:nil];
//        }
//        CFTimeInterval endTime = CACurrentMediaTime();
//        CFTimeInterval consumingTime = endTime - startTime;
//        NSLog(@"TPEventBus: 耗时：%@", @(consumingTime * 1000));
//    }
//    {
//        CFTimeInterval startTime = CACurrentMediaTime();
//        for (NSUInteger i = 0; i < 10000; i++) {
//            [[NSNotificationCenter defaultCenter] postNotificationName:@"Tpphha" object:nil];
//        }
//        CFTimeInterval endTime = CACurrentMediaTime();
//        CFTimeInterval consumingTime = endTime - startTime;
//        NSLog(@"NSNotificationCenter: 耗时：%@", @(consumingTime * 1000));
//    }
    {
        TPMediaLikedChangedEvent *event = [[TPMediaLikedChangedEvent alloc] initWithLiked:@(YES)];
        [[TPEventBus sharedBus] postEvent:event object:self];
//        [[TPEventBus sharedBus] postEvent:event];
    }
}

- (void)onTestEvent:(TPTestEvent *)event object:(id)object {
    NSLog(@"event name: %@, object: %@, thread: %@", event.name, object, [NSThread currentThread]);
}

@end
