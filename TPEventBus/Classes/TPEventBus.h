//
//  TPEventBus.h
//  TPEventBus
//
//  Created by Tpphha on 2019/9/18.
//  Copyright © 2019 Tpphha. All rights reserved.
//

#if __has_include(<TPEventBus/TPEventBus.h>)
#import <TPEventBus/TPEvent.h>
#else
#import "TPEvent.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@protocol TPEventBusUnregisterable <NSObject>

- (void)unregister;

@end

@interface TPEventBusUnregisterBag : NSObject

@property (nonatomic, strong, readonly) NSHashTable *unregisterables;

- (void)addUnregisterable:(id<TPEventBusUnregisterable>)unregisterable;

@end

@interface NSObject (TPEventBus)

@property (nonatomic, strong, readonly) TPEventBusUnregisterBag *eventBusUnregisterBag;

@end

@interface TPEventBusObservingContext : NSObject <TPEventBusUnregisterable>

@end

@interface TPEventBus : NSObject

+ (instancetype)sharedBus;

- (void)registerEventType:(Class)eventType
                 observer:(id)observer
                 selector:(SEL)selector
                   object:(nullable id)object
                    queue:(nullable NSOperationQueue *)queue;

- (void)registerEventType:(Class)eventType observer:(id)observer selector:(SEL)selector;

- (void)unregisterEventType:(Class)eventType observer:(id)observer object:(nullable id)object;

- (void)unregisterEventType:(Class)eventType observer:(id)observer;

- (void)unregisterObserver:(id)observer;

- (void)unregisterEventType:(Class)eventType observingContext:(TPEventBusObservingContext *)observingContext;

- (void)postEvent:(id<TPEvent>)event object:(nullable id)object;

- (void)postEvent:(id<TPEvent>)event;

@end

NS_ASSUME_NONNULL_END
