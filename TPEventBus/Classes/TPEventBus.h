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

#define TPEventBusSubscribeEventType(_EventType_) ((TPEventSubscriberMaker<_EventType_ *> *)TPEventBus.sharedBus.subscribeEventType(_EventType_.class))

NS_ASSUME_NONNULL_BEGIN

@class TPEventTokenBag;

@protocol TPEventToken <NSObject>

- (void)dispose;

- (void)disposedByBag:(TPEventTokenBag *)bag NS_SWIFT_NAME(disposed(by:));

@end

@interface TPEventTokenBag<EventToken: id<TPEventToken>> : NSObject

- (NSArray<EventToken> *)allTokens;

- (void)addToken:(EventToken)token;

@end

@interface NSObject (TPEventBus)

@property (nonatomic, strong, readonly) TPEventTokenBag<id<TPEventToken>> *tp_eventTokenBag;

@end

@interface TPEventSubscriberMaker<EventType: id<TPEvent>> : NSObject

typedef void(^TPEventSubscriberBlock)(EventType event, _Nullable id object);

- (TPEventSubscriberMaker<EventType> *)onQueue:(nullable NSOperationQueue *)queue;
- (TPEventSubscriberMaker<EventType> *)forObject:(nullable id)object;

- (TPEventSubscriberMaker<EventType> *(^)(NSOperationQueue * _Nullable))onQueue;
- (TPEventSubscriberMaker<EventType> *(^)(_Nullable id))forObject;

- (id<TPEventToken>)onEvent:(TPEventSubscriberBlock)block;

@end

@interface TPEventBus<EventType: id<TPEvent>> : NSObject

@property (class, strong, readonly) TPEventBus<EventType> *sharedBus NS_SWIFT_NAME(shared);

- (TPEventSubscriberMaker<EventType> *)subscribeEventType:(Class)eventType NS_SWIFT_NAME(subscribe(eventType:));

- (TPEventSubscriberMaker<EventType> *(^)(Class eventType))subscribeEventType;

- (void)registerEventType:(Class)eventType
               subscriber:(id)subscriber
                 selector:(SEL)selector
                   object:(nullable id)object
                    queue:(nullable NSOperationQueue *)queue NS_SWIFT_NAME(register(eventType:subscriber:selector:object:queue:));

- (void)registerEventType:(Class)eventType subscriber:(id)subscriber selector:(SEL)selector NS_SWIFT_NAME(register(eventType:subscriber:selector:));

- (void)unregisterEventType:(Class)eventType subscriber:(id)subscriber object:(nullable id)object NS_SWIFT_NAME(unregister(eventType:subscriber:object:));

- (void)unregisterEventType:(Class)eventType subscriber:(id)subscriber NS_SWIFT_NAME(unregister(eventType:subscriber:));

- (void)unregisterSubscriber:(id)subscriber NS_SWIFT_NAME(unregister(subscriber:));

- (void)postEvent:(EventType)event object:(nullable id)object NS_SWIFT_NAME(post(event:object:));

- (void)postEvent:(EventType)event NS_SWIFT_NAME(post(event:));

@end

NS_ASSUME_NONNULL_END
