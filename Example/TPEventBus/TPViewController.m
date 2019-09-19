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

@interface TPViewController ()

@end

@implementation TPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [[TPEventBus sharedBus] registerEventType:TPTestEvent.class observer:self selector:@selector(onTestEvent:object:) object:self queue:[NSOperationQueue new]];
}

- (IBAction)testAction:(id)sender {
    {
        TPTestEvent *event = [TPTestEvent new];
        event.name = @"Tpphha";
        [[TPEventBus sharedBus] postEvent:event object:nil];
    }
    {
        TPMediaLikedChangedEvent *event = [[TPMediaLikedChangedEvent alloc] initWithLiked:@(YES)];
        //    [[TPEventBus sharedBus] postEvent:event object:self];
        [[TPEventBus sharedBus] postEvent:event];
    }
}

- (void)onTestEvent:(TPTestEvent *)event object:(id)object {
    NSLog(@"event name: %@, object: %@, thread: %@", event.name, object, [NSThread currentThread]);
}

@end
