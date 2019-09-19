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

@interface TPEventBusUnregisterableBag : NSObject

@property (nonatomic, strong, readonly) NSHashTable *unregisterables;

- (void)addUnregisterable:(id<TPEventBusUnregisterable>)unregisterable;

@end

@interface NSObject (TPEventBus)

@property (nonatomic, strong, readonly) TPEventBusUnregisterableBag *eventBusUnregisterableBag;

@end

@interface TPEventBusToken : NSObject <TPEventBusUnregisterable>

@end

@interface TPEventBus : NSObject

@property (class, strong, readonly) TPEventBus *sharedBus NS_SWIFT_NAME(shared);

- (void)registerEventType:(Class)eventType
                 observer:(id)observer
                 selector:(SEL)selector
                   object:(nullable id)object
                    queue:(nullable NSOperationQueue *)queue NS_SWIFT_NAME(register(eventType:observer:selector:object:queue:));

- (void)registerEventType:(Class)eventType observer:(id)observer selector:(SEL)selector NS_SWIFT_NAME(register(eventType:observer:selector:));

- (void)unregisterEventType:(Class)eventType observer:(id)observer object:(nullable id)object NS_SWIFT_NAME(unregister(eventType:observer:object:));

- (void)unregisterEventType:(Class)eventType observer:(id)observer NS_SWIFT_NAME(unregister(eventType:observer:));

- (void)unregisterObserver:(id)observer NS_SWIFT_NAME(unregister(observer:));

- (void)unregisterEventType:(Class)eventType token:(TPEventBusToken *)token NS_SWIFT_NAME(unregister(eventType:token:));

- (void)postEvent:(id<TPEvent>)event object:(nullable id)object NS_SWIFT_NAME(post(event:object:));

- (void)postEvent:(id<TPEvent>)event NS_SWIFT_NAME(post(event:));

@end

NS_ASSUME_NONNULL_END
