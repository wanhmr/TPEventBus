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
}

- (IBAction)testAction:(id)sender {
    TPMediaLikedChangedEvent *event = [[TPMediaLikedChangedEvent alloc] initWithLiked:@(YES)];
    [[TPEventBus sharedBus] postEvent:event object:self];
//    [[TPEventBus sharedBus] postEvent:event];
}

@end
