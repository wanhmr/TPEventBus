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
}

- (IBAction)testAction:(id)sender {
    TPMediaLikedChangedEvent *event = [[TPMediaLikedChangedEvent alloc] initWithLiked:@(YES)];
//    [[TPEventBus sharedBus] postEvent:event object:self];
    [[TPEventBus sharedBus] postEvent:event];
}

@end
