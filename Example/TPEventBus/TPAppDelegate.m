//
//  TPAppDelegate.m
//  TPEventBus
//
//  Created by wanhmr on 09/18/2019.
//  Copyright (c) 2019 wanhmr. All rights reserved.
//

#import "TPAppDelegate.h"
#import <TPEventBus/TPEventBus.h>
#import "TPTestEvent.h"
#import "TPMediaLikedChangedEvent.h"

@implementation TPAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    [[TPEventBus sharedBus] registerEventType:TPTestEvent.class subscriber:self selector:@selector(onTestEvent:object:) object:nil queue:[NSOperationQueue new]];
    [[TPEventBus sharedBus] registerEventType:TPTestEvent.class subscriber:self selector:@selector(onTestEvent:object:)];
    [[TPEventBus sharedBus] registerEventType:TPTestEvent.class subscriber:self selector:@selector(onTestEvent:)];
    [[TPEventBus sharedBus] registerEventType:TPMediaLikedChangedEvent.class subscriber:self selector:@selector(onMediaLikedChangedEvent:)];
    [[TPEventSubscribe(TPMediaLikedChangedEvent).onQueue([NSOperationQueue new]).forObject(nil) onEvent:^(TPMediaLikedChangedEvent * _Nonnull event, id  _Nullable object) {
        NSLog(@"Block Type >>> liked: %@, object: %@, thread: %@", event.liked, object, [NSThread currentThread]);
    }] disposedByObject:self];
    
//    [[TPEventBus sharedBus] unregisterObserver:self];
//    [[TPEventBus sharedBus] unregisterEventType:TPTestEvent.class observer:self object:nil];
    return YES;
}

#pragma mark - Event Bus

- (void)onTestEvent:(TPTestEvent *)event object:(id)object {
    NSLog(@"event name: %@, object: %@, thread: %@", event.name, object, [NSThread currentThread]);
}

- (void)onTestEvent:(TPTestEvent *)event {
    NSLog(@"event name: %@, thread: %@", event.name, [NSThread currentThread]);
}

- (void)onMediaLikedChangedEvent:(TPMediaLikedChangedEvent *)event {
    NSNumber *liked = event.liked;
    NSLog(@"liked: %@", liked);
}

@end
