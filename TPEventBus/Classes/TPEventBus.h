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

#define TPEventSubscriber(_EventType_) ((TPEventSubscriberMaker<_EventType_ *> *)[TPEventBus sharedBus].subscribe(_EventType_.class))

NS_ASSUME_NONNULL_BEGIN

@protocol TPEventToken <NSObject>

@property (nonatomic, strong, readonly) Class eventType;
@property (nullable, nonatomic, weak, readonly) id object;

- (void)executeWithEvent:(id<TPEvent>)event object:(nullable id)object;

- (void)dispose;

- (void)disposedByObject:(id)object;

@end

@interface TPEventSubscriberMaker<__covariant EventType> : NSObject

typedef void(^TPEventSubscriptionBlock)(EventType event, _Nullable id object);

- (TPEventSubscriberMaker<EventType> *(^)(NSOperationQueue * _Nullable))onQueue;
- (TPEventSubscriberMaker<EventType> *(^)(_Nullable id))forObject;
- (nullable id<TPEventToken>)onNext:(TPEventSubscriptionBlock)block;

@end

@interface TPEventBus : NSObject

@property (class, strong, readonly) TPEventBus *sharedBus NS_SWIFT_NAME(shared);

@property (nonatomic, strong, readonly) TPEventSubscriberMaker *(^subscribe)(Class eventType);

- (void)registerEventType:(Class)eventType
                 observer:(id)observer
                 selector:(SEL)selector
                   object:(nullable id)object
                    queue:(nullable NSOperationQueue *)queue NS_SWIFT_NAME(register(eventType:observer:selector:object:queue:));

- (void)registerEventType:(Class)eventType observer:(id)observer selector:(SEL)selector NS_SWIFT_NAME(register(eventType:observer:selector:));

- (void)unregisterEventType:(Class)eventType observer:(id)observer object:(nullable id)object NS_SWIFT_NAME(unregister(eventType:observer:object:));

- (void)unregisterEventType:(Class)eventType observer:(id)observer NS_SWIFT_NAME(unregister(eventType:observer:));

- (void)unregisterObserver:(id)observer NS_SWIFT_NAME(unregister(observer:));

- (void)postEvent:(id<TPEvent>)event object:(nullable id)object NS_SWIFT_NAME(post(event:object:));

- (void)postEvent:(id<TPEvent>)event NS_SWIFT_NAME(post(event:));

@end

NS_ASSUME_NONNULL_END
