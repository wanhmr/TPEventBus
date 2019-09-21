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
#import "TPCountEvent.h"
#import "TPEventBus_Example-Swift.h"

@interface TPViewController ()

@property (weak, nonatomic) IBOutlet UILabel *countLabel;

@end

@implementation TPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    __weak __typeof(self)weakSelf = self;
    [[TPEventSubscribe(TPCountEvent).onQueue([NSOperationQueue mainQueue]) onEvent:^(TPCountEvent * _Nonnull event, id  _Nullable object) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        strongSelf.countLabel.text = @(event.count).stringValue;
    }] disposedByObject:self];
}

- (IBAction)likeAction:(id)sender {
    TPMediaLikedChangedEvent *event = [[TPMediaLikedChangedEvent alloc] initWithLiked:@(YES)];
    [[TPEventBus sharedBus] postEvent:event object:self];
//    [[TPEventBus sharedBus] postEvent:event];
}


@end
