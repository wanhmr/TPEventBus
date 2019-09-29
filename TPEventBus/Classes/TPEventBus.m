//
//  TPEventBus.m
//  TPEventBus
//
//  Created by Tpphha on 2019/9/18.
//  Copyright © 2019 Tpphha. All rights reserved.
//

#import "TPEventBus.h"
#import <objc/runtime.h>

static inline NSString *TPIdentityFromObject(id object) {
    return @((NSUInteger)object).stringValue;
}

static inline NSString *TPKeyFromEventType(Class eventType) {
    return NSStringFromClass(eventType);
}

@protocol TPEventSubscription;

@protocol TPEventSubscriptionDelegate <NSObject>

- (void)eventSubscriptionWantsDispose:(id<TPEventSubscription>)subscription subscriberID:(nullable NSString *)subscriberID;

@end

@protocol TPEventSubscription <TPEventToken>

@property (nonatomic, strong, readonly) Class eventType;
@property (nullable, nonatomic, weak, readonly) id object;

@property (nonatomic, weak, readonly) id<TPEventSubscriptionDelegate> delegate;

- (void)invokeWithEvent:(id<TPEvent>)event object:(nullable id)object;

@end

@interface TPEventBus () <TPEventSubscriptionDelegate>

- (void)addSubscription:(id<TPEventSubscription>)subscription subscriberID:(nullable NSString *)subscriberID;

- (void)removeSubscription:(id<TPEventSubscription>)subscription subscriberID:(nullable NSString *)subscriberID;

@end

@interface TPEventTokenBag () {
    NSHashTable *_tokens;
    NSLock *_lock;
}

@end

@implementation TPEventTokenBag

- (void)dealloc {
    [self dispose];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _tokens = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory capacity:1];
        _lock = [NSLock new];
    }
    return self;
}

- (NSArray<id> *)allTokens {
    return _tokens.allObjects;
}

- (void)addToken:(id<TPEventToken>)token {
    [_lock lock];
    [_tokens addObject:token];
    [_lock unlock];
}

- (void)dispose {
    NSArray *tokens = _tokens.allObjects;
    
    [_lock lock];
    [_tokens removeAllObjects];
    [_lock unlock];
    
    [tokens enumerateObjectsUsingBlock:^(id<TPEventSubscription> obj, NSUInteger idx, BOOL *stop) {
        [obj dispose];
    }];
}

@end

@implementation NSObject (TPEventBus)

- (TPEventTokenBag<id<TPEventToken>> *)tp_eventTokenBag {
    TPEventTokenBag *bag = objc_getAssociatedObject(self, _cmd);
    if (!bag) {
        bag = [[TPEventTokenBag alloc] init];
        objc_setAssociatedObject(self, _cmd, bag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return bag;
}

@end

@interface TPTargetActionEventSubscription : NSObject <TPEventSubscription>

@property (nonatomic, strong, readonly) Class eventType;
@property (nonatomic, weak, readonly) id subscriber;
@property (nonatomic, assign, readonly) SEL selector;
@property (nullable, nonatomic, weak, readonly) id object;
@property (nullable, nonatomic, strong, readonly) NSOperationQueue *queue;

@property (nonatomic, weak, readonly) id<TPEventSubscriptionDelegate> delegate;

#pragma mark - Hash
@property (nonatomic, strong, readonly) NSString *eventTypeID;
/**
 这个是关键，因为 subscriber 是弱引用，subscriber 清除 AssociatedObject 的时候，已经是 nil，从而导致 TPEventSubscription 的 hash 值改变。
 因此我们需要保存 subscriber 的 snapshot 也就是 subscriberID。
 */
@property (nonatomic, strong, readonly) NSString *subscriberID;
@property (nonatomic, strong, readonly) NSString *selectorID;
@property (nullable, nonatomic, strong, readonly) NSString *objectID;

@end

@implementation TPTargetActionEventSubscription

- (instancetype)initWithEventType:(Class)eventType
                       subscriber:(id)subscriber
                         selector:(SEL)selector
                           object:(id)object
                            queue:(NSOperationQueue *)queue
                         delegate:(id<TPEventSubscriptionDelegate>)delegate {
    self = [super init];
    if (self) {
        _eventType = eventType;
        _subscriber = subscriber;
        _selector = selector;
        _object = object;
        _queue = queue;
        _delegate = delegate;
        
        _eventTypeID = NSStringFromClass(eventType);
        _subscriberID = TPIdentityFromObject(subscriber);
        _selectorID = NSStringFromSelector(selector);
        if (object) {
            _objectID = TPIdentityFromObject(object);
        }
    }
    return self;
}

- (NSUInteger)hash {
    return
    [self.eventTypeID hash] ^
    [self.subscriberID hash] ^
    [self.selectorID hash] ^
    [self.objectID hash] ^
    [self.queue hash];
}

- (BOOL)isEqual:(TPTargetActionEventSubscription *)other {
    if (self == other) {
        return YES;
    }
    
    if (![other isKindOfClass:TPTargetActionEventSubscription.class]) {
        return NO;
    }
    
    return
    (self.eventTypeID == other.eventTypeID || [self.eventTypeID isEqual:other.eventTypeID]) &&
    (self.subscriberID == other.subscriberID || [self.subscriberID isEqual:other.subscriberID]) &&
    (self.selectorID == other.selectorID || [self.selectorID isEqual:other.selectorID]) &&
    (self.objectID == other.objectID || [self.objectID isEqual:other.objectID]) &&
    (self.queue == other.queue || [self.queue isEqual:other.queue]);
}

- (void)invokeWithEvent:(id<TPEvent>)event object:(nullable id)object {
    id subscriber = self.subscriber;
    SEL selector = self.selector;
    NSOperationQueue *queue = self.queue;
    NSMethodSignature *methodSignature = [subscriber methodSignatureForSelector:selector];
    NSUInteger numberOfArguments = [methodSignature numberOfArguments];
    NSAssert(numberOfArguments <= 4, @"Too many arguments.");
    void (^block)(void) = ^(){
        if (numberOfArguments == 2) {
            ((void (*)(id, SEL))[subscriber methodForSelector:selector])(subscriber, selector);
        } else if (numberOfArguments == 3) {
            ((void (*)(id, SEL, id<TPEvent>))[subscriber methodForSelector:selector])(subscriber, selector, event);
        } else {
            ((void (*)(id, SEL, id<TPEvent>, id))[subscriber methodForSelector:selector])(subscriber, selector, event, object);
        }
    };
    if (queue) {
        [queue addOperationWithBlock:block];
    } else {
        block();
    }
}

- (void)dispose {
    [self.delegate eventSubscriptionWantsDispose:self subscriberID:self.subscriberID];
}

- (void)disposedByBag:(TPEventTokenBag *)bag {
    [bag addToken:self];
}

@end

@interface TPAnonymousEventSubscription : NSObject <TPEventSubscription>

@property (nonatomic, strong, readonly) Class eventType;
@property (nullable, nonatomic, strong, readonly) NSOperationQueue *queue;
@property (nullable, nonatomic, weak, readonly) id object;
@property (nonatomic, copy, readonly) TPEventSubscriberBlock block;

@property (nonatomic, weak, readonly) id<TPEventSubscriptionDelegate> delegate;

#pragma mark - Hash
@property (nonatomic, strong, readonly) NSString *eventTypeID;
@property (nullable, nonatomic, strong, readonly) NSString *objectID;

@end

@implementation TPAnonymousEventSubscription

- (instancetype)initWithEventType:(Class)eventType
                            block:(TPEventSubscriberBlock)block
                           object:(id)object
                            queue:(NSOperationQueue *)queue
                         delegate:(id<TPEventSubscriptionDelegate>)delegate {
    self = [super init];
    if (self) {
        _eventType = eventType;
        _block = [block copy];
        _object = object;
        _queue = queue;
        _delegate = delegate;
        
        _eventTypeID = NSStringFromClass(eventType);
        if (object) {
            _objectID = TPIdentityFromObject(object);
        }
    }
    return self;
}

- (NSUInteger)hash {
    return
    [self.eventTypeID hash] ^
    [self.objectID hash] ^
    [self.queue hash] ^
    [self.block hash];
}

- (BOOL)isEqual:(TPAnonymousEventSubscription *)other {
    if (self == other) {
        return YES;
    }
    
    if (![other isKindOfClass:TPAnonymousEventSubscription.class]) {
        return NO;
    }
    
    return
    (self.eventTypeID == other.eventTypeID || [self.eventTypeID isEqual:other.eventTypeID]) &&
    (self.objectID == other.objectID || [self.objectID isEqual:other.objectID]) &&
    (self.queue == other.queue || [self.queue isEqual:other.queue]) &&
    (self.block == other.block || [self.block isEqual:other.block]);
}

- (void)invokeWithEvent:(id<TPEvent>)event object:(nullable id)object {
    NSOperationQueue *queue = self.queue;
    if (queue) {
        [queue addOperationWithBlock:^{
            self.block(event, object);
        }];
    } else {
        self.block(event, object);
    }
}

- (void)dispose {
    [self.delegate eventSubscriptionWantsDispose:self subscriberID:nil];
}

- (void)disposedByBag:(TPEventTokenBag *)bag {
    [bag addToken:self];
}

@end

@interface TPEventSubscriberMaker ()

@property (nonatomic, weak, readonly) TPEventBus *eventBus;
@property (nonatomic, strong, readonly) Class eventType;

@property (nullable, nonatomic, strong) NSOperationQueue *queue;
@property (nullable, nonatomic, weak) id object;

@end

@implementation TPEventSubscriberMaker

- (instancetype)initWithEventBus:(TPEventBus *)eventBus eventType:(Class)eventType {
    self = [super init];
    if (self) {
        _eventBus = eventBus;
        _eventType = eventType;
    }
    return self;
}

- (TPEventSubscriberMaker<id<TPEvent>> *)onQueue:(NSOperationQueue *)queue {
    self.queue = queue;
    return self;
}

- (TPEventSubscriberMaker<id<TPEvent>> *)forObject:(id)object {
    self.object = object;
    return self;
}

- (TPEventSubscriberMaker<id<TPEvent>> * (^)(NSOperationQueue *))onQueue {
    return ^ TPEventSubscriberMaker * (NSOperationQueue *queue) {
        self.queue = queue;
        return self;
    };
}

- (TPEventSubscriberMaker<id<TPEvent>> * (^)(id))forObject {
    return ^ TPEventSubscriberMaker * (id object) {
        return [self forObject:object];
    };
}

- (id<TPEventToken>)onEvent:(TPEventSubscriberBlock)block {
    TPAnonymousEventSubscription *subscription =
    [[TPAnonymousEventSubscription alloc] initWithEventType:self.eventType block:block object:self.object queue:self.queue delegate:self.eventBus];
    [self.eventBus addSubscription:subscription subscriberID:nil];
    return subscription;
}

@end


@interface TPEventBus ()

@property (nonatomic, strong, readonly) NSLock *lock;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSMutableSet<id<TPEventSubscription>> *> *subscriptionsByEventType;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSMutableSet<id<TPEventSubscription>> *> *subscriptionsBySubscriber;

@end

@implementation TPEventBus

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = [NSLock new];
        _subscriptionsByEventType = [NSMutableDictionary new];
        _subscriptionsBySubscriber = [NSMutableDictionary new];
    }
    return self;
}

+ (instancetype)sharedBus {
    static TPEventBus *eventBus;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        eventBus = [TPEventBus new];
    });
    return eventBus;
}

- (TPEventSubscriberMaker<id<TPEvent>> *)subscribeEventType:(Class)eventType {
    NSParameterAssert([eventType conformsToProtocol:@protocol(TPEvent)]);
    
    return [[TPEventSubscriberMaker alloc] initWithEventBus:self eventType:eventType];
}

- (TPEventSubscriberMaker<id<TPEvent>> * (^)(Class))subscribeEventType {
    return ^ TPEventSubscriberMaker * (Class eventType) {
        return [self subscribeEventType:eventType];
    };
}

- (void)registerEventType:(Class)eventType
               subscriber:(id)subscriber
                 selector:(SEL)selector
                   object:(id)object
                    queue:(NSOperationQueue *)queue {
    NSParameterAssert([eventType conformsToProtocol:@protocol(TPEvent)]);
    NSParameterAssert(subscriber);
    
    TPTargetActionEventSubscription *subscription =
    [[TPTargetActionEventSubscription alloc] initWithEventType:eventType
                                                subscriber:subscriber
                                                  selector:selector
                                                    object:object
                                                     queue:queue
                                                  delegate:self];
    [self addSubscription:subscription subscriberID:subscription.subscriberID];
    [[subscriber tp_eventTokenBag] addToken:subscription];
}

- (void)registerEventType:(Class)eventType subscriber:(id)subscriber selector:(SEL)selector {
    [self registerEventType:eventType subscriber:subscriber selector:selector object:nil queue:nil];
}

- (void)unregisterEventType:(Class)eventType subscriber:(id)subscriber object:(id)object {
    NSArray<id<TPEventSubscription>> *subscriptions = [self subscriptionsBySubscriberID:TPIdentityFromObject(subscriber)];
    [subscriptions enumerateObjectsUsingBlock:^(id<TPEventSubscription> _Nonnull subscription, NSUInteger idx, BOOL * _Nonnull stop) {
        if (subscription.eventType == eventType) {
            if (object) {
                if (subscription.object == object) {
                    [subscription dispose];
                }
            } else {
                [subscription dispose];
            }
        }
    }];
}

- (void)unregisterEventType:(Class)eventType subscriber:(id)subscriber {
    [self unregisterEventType:eventType subscriber:subscriber object:nil];
}

- (void)unregisterSubscriber:(id)subscriber {
    NSArray<id<TPEventSubscription>> *subscriptions = [self subscriptionsBySubscriberID:TPIdentityFromObject(subscriber)];
    [subscriptions enumerateObjectsUsingBlock:^(id<TPEventSubscription> _Nonnull subscription, NSUInteger idx, BOOL * _Nonnull stop) {
        [subscription dispose];
    }];
}

- (void)postEvent:(id<TPEvent>)event object:(id)object {
    NSArray<id<TPEventSubscription>> *subscriptions = [self subscriptionsByEventType:event.class];
    [subscriptions enumerateObjectsUsingBlock:^(id<TPEventSubscription> _Nonnull subscription, NSUInteger idx, BOOL * _Nonnull stop) {
        if (subscription.object) {
            if (subscription.object == object) {
                [subscription invokeWithEvent:event object:object];
            }
        } else {
            [subscription invokeWithEvent:event object:object];
        }
    }];
}

- (void)postEvent:(id<TPEvent>)event {
    [self postEvent:event object:nil];
}

#pragma mark - TPEventSubscriptionDelegate

- (void)eventSubscriptionWantsDispose:(id<TPEventSubscription>)subscription subscriberID:(nullable NSString *)subscriberID {
    [self removeSubscription:subscription subscriberID:subscriberID];
}

#pragma mark - Private

- (NSMutableSet<id<TPEventSubscription>> *)_hashTableByEventType:(Class)eventType {
    NSString *key = TPKeyFromEventType(eventType);
    NSMutableSet *ht = self.subscriptionsByEventType[key];
    if (!ht) {
        ht = [[NSMutableSet alloc] initWithCapacity:1];
        self.subscriptionsByEventType[key] = ht;
    }
    return ht;
}

- (NSMutableSet<id<TPEventSubscription>> *)_hashTableBySubscriberID:(NSString *)subscriberID {
    NSString *key = subscriberID;
    NSMutableSet *ht = self.subscriptionsBySubscriber[key];
    if (!ht) {
        ht = [[NSMutableSet alloc] initWithCapacity:1];
        self.subscriptionsBySubscriber[key] = ht;
    }
    return ht;
}

- (void)_removeSubscription:(id<TPEventSubscription>)subscription subscriberID:(NSString *)subscriberID {
    NSMutableSet *hashTableByEventType = [self _hashTableByEventType:subscription.eventType];
    if ([hashTableByEventType containsObject:subscription]) {
        [hashTableByEventType removeObject:subscription];
        
        if (subscriberID) {
            NSMutableSet *hashTableBySubscriber = [self _hashTableBySubscriberID:subscriberID];
            [hashTableBySubscriber removeObject:subscription];
        }
    }
}

- (void)_addSubscription:(id<TPEventSubscription>)subscription subscriberID:(NSString *)subscriberID {
    NSMutableSet *hashTableByEventType = [self _hashTableByEventType:subscription.eventType];
    if (![hashTableByEventType containsObject:subscription]) {
        [hashTableByEventType addObject:subscription];
        
        if (subscriberID) {
            NSMutableSet *hashTableBySubscriber = [self _hashTableBySubscriberID:subscriberID];
            [hashTableBySubscriber addObject:subscription];
        }
    }
}

- (NSMutableSet<id<TPEventSubscription>> *)hashTableByEventType:(Class)eventType {
    NSMutableSet *ht = nil;
    [self.lock lock];
    ht = [self _hashTableByEventType:eventType];
    [self.lock unlock];
    return ht;
}

- (NSMutableSet<id<TPEventSubscription>> *)hashTableBySubscriberID:(NSString *)subscriberID {
    NSMutableSet *ht = nil;
    [self.lock lock];
    ht = [self _hashTableBySubscriberID:subscriberID];
    [self.lock unlock];
    return ht;
}

- (NSArray<id<TPEventSubscription>> *)subscriptionsByEventType:(Class)eventType {
    return [self hashTableByEventType:eventType].allObjects;
}

- (NSArray<id<TPEventSubscription>> *)subscriptionsBySubscriberID:(NSString *)subscriberID {
    return [self hashTableBySubscriberID:subscriberID].allObjects;
}

- (void)addSubscription:(id<TPEventSubscription>)subscription subscriberID:(NSString *)subscriberID {
    [self.lock lock];
    [self _addSubscription:subscription subscriberID:subscriberID];
    [self.lock unlock];
}

- (void)removeSubscription:(id<TPEventSubscription>)subscription subscriberID:(NSString *)subscriberID {
    [self.lock lock];
    [self _removeSubscription:subscription subscriberID:subscriberID];
    [self.lock unlock];
}

@end
