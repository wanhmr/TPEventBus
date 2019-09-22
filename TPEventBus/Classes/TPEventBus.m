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

@protocol TPEventSubscription;

@protocol TPEventSubscriptionDelegate <NSObject>

- (void)eventSubscriptionWantsDispose:(id<TPEventSubscription>)subscription;

@end

@protocol TPEventSubscription <TPEventToken>

@property (nonatomic, strong, readonly) Class eventType;
@property (nullable, nonatomic, weak, readonly) id object;

@property (nonatomic, weak, readonly) id<TPEventSubscriptionDelegate> delegate;

- (void)executeWithEvent:(id<TPEvent>)event object:(nullable id)object;

@end

@interface TPEventBus () <TPEventSubscriptionDelegate>

- (void)removeSubscription:(id<TPEventSubscription>)subscription;

- (void)addSubscription:(id<TPEventSubscription>)subscription;

@end

@interface TPEventSubscriptionBag : NSObject

- (NSArray<id<TPEventSubscription>> *)allSubscriptions;

- (void)addSubscription:(id<TPEventSubscription>)subscription;

@end

@interface TPEventSubscriptionBag () {
    NSHashTable *_subscriptions;
    NSLock *_lock;
}

@end

@implementation TPEventSubscriptionBag

- (void)dealloc {
    [self dispose];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _subscriptions = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory capacity:1];
        _lock = [NSLock new];
    }
    return self;
}

- (NSArray<id<TPEventSubscription>> *)allSubscriptions {
    return _subscriptions.allObjects;
}

- (void)addSubscription:(id<TPEventSubscription>)subscription {
    [_lock lock];
    [_subscriptions addObject:subscription];
    [_lock unlock];
}

- (void)dispose {
    NSArray *subscriptions = _subscriptions.allObjects;
    
    [_lock lock];
    [_subscriptions removeAllObjects];
    [_lock unlock];
    
    [subscriptions enumerateObjectsUsingBlock:^(id<TPEventSubscription> obj, NSUInteger idx, BOOL *stop) {
        [obj dispose];
    }];
}

@end

@interface NSObject (TPEventBus)

@property (nonatomic, strong, readonly) TPEventSubscriptionBag *tp_eventSubscriptionBag;

@end

@implementation NSObject (TPEventBus)

- (TPEventSubscriptionBag *)tp_eventSubscriptionBag {
    TPEventSubscriptionBag *bag = objc_getAssociatedObject(self, _cmd);
    if (!bag) {
        bag = [[TPEventSubscriptionBag alloc] init];
        objc_setAssociatedObject(self, _cmd, bag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return bag;
}

@end

@interface TPConcreteEventSubscription : NSObject <TPEventSubscription>

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

@implementation TPConcreteEventSubscription

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

- (BOOL)isEqual:(TPConcreteEventSubscription *)other {
    if (self == other) {
        return YES;
    }
    
    if (![other isKindOfClass:TPConcreteEventSubscription.class]) {
        return NO;
    }
    
    return
    (self.eventTypeID == other.eventTypeID || [self.eventTypeID isEqual:other.eventTypeID]) &&
    (self.subscriberID == other.subscriberID || [self.subscriberID isEqual:other.subscriberID]) &&
    (self.selectorID == other.selectorID || [self.selectorID isEqual:other.selectorID]) &&
    (self.objectID == other.objectID || [self.objectID isEqual:other.objectID]) &&
    (self.queue == other.queue || [self.queue isEqual:other.queue]);
}
    
- (void)executeWithEvent:(id<TPEvent>)event object:(nullable id)object {
    if (self.object) {
        if (self.object == object) {
            [self _executeWithEvent:event object:object];
        }
    } else {
        [self _executeWithEvent:event object:object];
    }
}

- (void)_executeWithEvent:(id<TPEvent>)event object:(nullable id)object {
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
    [self.delegate eventSubscriptionWantsDispose:self];
}

- (void)disposedByObject:(id)object {
    [[object tp_eventSubscriptionBag] addSubscription:self];
}

@end

@interface TPAnonymousEventSubscription : NSObject <TPEventSubscription>

@property (nonatomic, strong, readonly) Class eventType;
@property (nullable, nonatomic, strong) NSOperationQueue *queue;
@property (nullable, nonatomic, weak) id object;
@property (nonatomic, copy) TPEventSubscriptionBlock block;
@property (nullable, nonatomic, weak) TPEventSubscriptionBag *disposableBag;

@property (nonatomic, weak, readonly) id<TPEventSubscriptionDelegate> delegate;

#pragma mark - Hash
@property (nonatomic, strong, readonly) NSString *eventTypeID;
@property (nullable, nonatomic, strong) NSString *objectID;

@end

@implementation TPAnonymousEventSubscription

- (instancetype)initWithEventType:(Class)eventType
                            block:(TPEventSubscriptionBlock)block
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
    
- (void)executeWithEvent:(id<TPEvent>)event object:(id)object {
    if (self.object) {
        if (self.object == object) {
            [self _executeWithEvent:event object:object];
        }
    } else {
        [self _executeWithEvent:event object:object];
    }
}

- (void)_executeWithEvent:(id<TPEvent>)event object:(nullable id)object {
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
    [self.delegate eventSubscriptionWantsDispose:self];
}

- (void)disposedByObject:(id)object {
    [[object tp_eventSubscriptionBag] addSubscription:self];
}

@end

@interface TPEventSubscriber ()

@property (nonatomic, weak, readonly) TPEventBus *eventBus;
@property (nonatomic, strong, readonly) Class eventType;

@property (nullable, nonatomic, strong) NSOperationQueue *queue;
@property (nullable, nonatomic, weak) id object;

@end

@implementation TPEventSubscriber

- (instancetype)initWithEventBus:(TPEventBus *)eventBus eventType:(Class)eventType {
    self = [super init];
    if (self) {
        _eventBus = eventBus;
        _eventType = eventType;
    }
    return self;
}

+ (TPEventSubscriber *)subscribeEventType:(Class)eventType {
    return [[TPEventSubscriber alloc] initWithEventBus:[TPEventBus sharedBus] eventType:eventType];
}

- (TPEventSubscriber<id> * (^)(NSOperationQueue *))onQueue {
    return ^ TPEventSubscriber * (NSOperationQueue *queue) {
        self.queue = queue;
        return self;
    };
}

- (TPEventSubscriber<id> * (^)(id))forObject {
    return ^ TPEventSubscriber * (id object) {
        self.object = object;
        return self;
    };
}

- (id<TPEventToken>)onEvent:(TPEventSubscriptionBlock)block {
    TPAnonymousEventSubscription *subscription =
    [[TPAnonymousEventSubscription alloc] initWithEventType:self.eventType block:block object:self.object queue:self.queue delegate:self.eventBus];
    [self.eventBus addSubscription:subscription];
    return subscription;
}

@end


@interface TPEventBus ()

@property (nonatomic, strong, readonly) NSLock *lock;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSMutableSet<id<TPEventSubscription>> *> *subscriptions;

@end

@implementation TPEventBus

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = [NSLock new];
        _subscriptions = [NSMutableDictionary new];
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

- (void)registerEventType:(Class)eventType
               subscriber:(id)subscriber
                 selector:(SEL)selector
                   object:(id)object
                    queue:(NSOperationQueue *)queue {
    NSParameterAssert([eventType conformsToProtocol:@protocol(TPEvent)]);
    NSParameterAssert(subscriber);
    NSParameterAssert(selector);
    
    TPConcreteEventSubscription *subscription =
    [[TPConcreteEventSubscription alloc] initWithEventType:eventType
                                                subscriber:subscriber
                                                  selector:selector
                                                    object:object
                                                     queue:queue
                                                  delegate:self];
    [self addSubscription:subscription];
    [subscription disposedByObject:subscriber];
}

- (void)registerEventType:(Class)eventType subscriber:(id)subscriber selector:(SEL)selector {
    [self registerEventType:eventType subscriber:subscriber selector:selector object:nil queue:nil];
}

- (void)unregisterEventType:(Class)eventType subscriber:(id)subscriber object:(id)object {
    NSArray<id<TPEventSubscription>> *subscriptions = [subscriber tp_eventSubscriptionBag].allSubscriptions;
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
    NSArray<id<TPEventSubscription>> *subscriptions = [subscriber tp_eventSubscriptionBag].allSubscriptions;
    [subscriptions enumerateObjectsUsingBlock:^(id<TPEventSubscription> _Nonnull subscription, NSUInteger idx, BOOL * _Nonnull stop) {
        [subscription dispose];
    }];
}

- (void)postEvent:(id<TPEvent>)event object:(id)object {
    NSArray<id<TPEventSubscription>> *subscriptions = [self subscriptionForEventType:event.class];
    [subscriptions enumerateObjectsUsingBlock:^(id<TPEventSubscription> _Nonnull subscription, NSUInteger idx, BOOL * _Nonnull stop) {
        [subscription executeWithEvent:event object:object];
    }];
}

- (void)postEvent:(id<TPEvent>)event {
    [self postEvent:event object:nil];
}

#pragma mark - TPEventSubscriptionDelegate

- (void)eventSubscriptionWantsDispose:(id<TPEventSubscription>)subscription {
    [self removeSubscription:subscription];
}

#pragma mark - Private

- (NSString *)keyFromEventType:(Class)eventType {
    return NSStringFromClass(eventType);
}

- (NSMutableSet<id<TPEventSubscription>> *)hashTableForEventType:(Class)eventType {
    NSString *key = [self keyFromEventType:eventType];
    NSMutableSet *ht = self.subscriptions[key];
    if (!ht) {
        ht = [[NSMutableSet alloc] initWithCapacity:1];
        self.subscriptions[key] = ht;
    }
    return ht;
}

- (NSArray<id<TPEventSubscription>> *)subscriptionForEventType:(Class)eventType {
    return [self hashTableForEventType:eventType].allObjects;
}

- (void)_removeSubscription:(id<TPEventSubscription>)subscription {
    NSMutableSet *ht = [self hashTableForEventType:subscription.eventType];
    if ([ht containsObject:subscription]) {
        [ht removeObject:subscription];
    }
}

- (void)_addSubscription:(id<TPEventSubscription>)subscription {
    NSMutableSet *ht = [self hashTableForEventType:subscription.eventType];
    if (![ht containsObject:subscription]) {
        [ht addObject:subscription];
    }
}

- (void)addSubscription:(id<TPEventSubscription>)subscription {
    [self.lock lock];
    [self _addSubscription:subscription];
    [self.lock unlock];
}

- (void)removeSubscription:(id<TPEventSubscription>)subscription {
    [self.lock lock];
    [self _removeSubscription:subscription];
    [self.lock unlock];
}

@end
