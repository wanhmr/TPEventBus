//
//  TPEventBus.m
//  TPEventBus
//
//  Created by Tpphha on 2019/9/18.
//  Copyright © 2019 Tpphha. All rights reserved.
//

#import "TPEventBus.h"
#import <objc/runtime.h>

@implementation TPEventBusUnregisterableBag

- (void)dealloc {
    [[_unregisterables objectEnumerator].allObjects enumerateObjectsUsingBlock:^(id<TPEventBusUnregisterable> obj, NSUInteger idx, BOOL *stop) {
        [obj unregister];
    }];
    [_unregisterables removeAllObjects];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _unregisterables = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory capacity:1];
    }
    return self;
}

- (void)addUnregisterable:(id<TPEventBusUnregisterable>)unregisterable {
    [self.unregisterables addObject:unregisterable];
}

@end

@implementation NSObject (TPEventBus)

- (TPEventBusUnregisterableBag *)eventBusUnregisterableBag {
    TPEventBusUnregisterableBag *bag = objc_getAssociatedObject(self, _cmd);
    if (!bag) {
        bag = [[TPEventBusUnregisterableBag alloc] init];
        objc_setAssociatedObject(self, _cmd, bag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return bag;
}

@end

@interface TPEventBusToken ()

@property (nonatomic, strong, readonly) Class eventType;
@property (nonatomic, weak, readonly) id observer;
@property (nonatomic, assign, readonly) SEL selector;
@property (nullable, nonatomic, weak, readonly) id object;
@property (nullable, nonatomic, strong, readonly) NSOperationQueue *queue;

#pragma mark - Hash
@property (nonatomic, strong, readonly) NSString *eventTypeID;
/**
 这个是关键，因为 observer 是弱引用，observer 清除 AssociatedObject 的时候，已经是 nil，从而导致 TPEventBusObservingContext 的 hash 值改变。
 因此我们需要保存 observer 的 snapshot 也就是 observerID。
 */
@property (nonatomic, strong, readonly) NSString *observerID;
@property (nonatomic, strong, readonly) NSString *selectorID;
@property (nullable, nonatomic, strong, readonly) NSString *objectID;

@end

@implementation TPEventBusToken

- (instancetype)initWithEventType:(Class)eventType
                         observer:(id)observer
                         selector:(SEL)selector
                           object:(id)object
                            queue:(NSOperationQueue *)queue {
    self = [super init];
    if (self) {
        _eventType = eventType;
        _observer = observer;
        _selector = selector;
        _object = object;
        _queue = queue;
        
        _eventTypeID = NSStringFromClass(eventType);
        _observerID = @((NSUInteger)observer).stringValue;
        _selectorID = NSStringFromSelector(selector);
        if (object) {
            _objectID = @((NSUInteger)object).stringValue;
        }
    }
    return self;
}

- (NSUInteger)hash {
    return
    [self.eventTypeID hash] ^
    [self.observerID hash] ^
    [self.selectorID hash] ^
    [self.objectID hash] ^
    [self.queue hash];
}

- (BOOL)isEqual:(TPEventBusToken *)other {
    if (self == other) {
        return YES;
    }
    
    if (![other isKindOfClass:TPEventBusToken.class]) {
        return NO;
    }
    
    return
    (self.eventTypeID == other.eventTypeID || [self.eventTypeID isEqual:other.eventTypeID]) &&
    (self.observerID == other.observerID || [self.observerID isEqual:other.observerID]) &&
    (self.selectorID == other.selectorID || [self.selectorID isEqual:other.selectorID]) &&
    (self.objectID == other.objectID || [self.objectID isEqual:other.objectID]) &&
    (self.queue == other.queue || [self.queue isEqual:other.queue]);
}

- (void)unregister {
    [[TPEventBus sharedBus] unregisterEventType:self.eventType token:self];
}

@end

@interface TPEventBus ()

@property (nonatomic, strong, readonly) dispatch_queue_t  dispatchQueue;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSMutableSet *> *tokens;

@end

@implementation TPEventBus

- (instancetype)init {
    self = [super init];
    if (self) {
        _dispatchQueue = dispatch_queue_create("com.eventbus.dispatch.queue", DISPATCH_QUEUE_CONCURRENT);
        _tokens = [NSMutableDictionary new];
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
                 observer:(id)observer
                 selector:(SEL)selector
                   object:(id)object
                    queue:(NSOperationQueue *)queue {
    NSParameterAssert([eventType conformsToProtocol:@protocol(TPEvent)]);
    NSParameterAssert(observer);
    NSParameterAssert(selector);
    
    TPEventBusToken *token =
    [[TPEventBusToken alloc] initWithEventType:eventType
                                      observer:observer
                                      selector:selector
                                        object:object
                                         queue:queue];
    [self safeAddToken:token forEventType:eventType];
}

- (void)registerEventType:(Class)eventType observer:(id)observer selector:(SEL)selector {
    [self registerEventType:eventType observer:observer selector:selector object:nil queue:nil];
}

- (void)unregisterEventType:(Class)eventType observer:(id)observer object:(id)object {
    NSArray<TPEventBusToken *> *tokens = [observer eventBusUnregisterableBag].unregisterables.allObjects;
    [tokens enumerateObjectsUsingBlock:^(TPEventBusToken * _Nonnull token, NSUInteger idx, BOOL * _Nonnull stop) {
        if (token.eventType == eventType) {
            if (object) {
                if (token.object == object) {
                    [token unregister];
                }
            } else {
                [token unregister];
            }
        }
    }];
}

- (void)unregisterEventType:(Class)eventType observer:(id)observer {
    [self unregisterEventType:eventType observer:observer object:nil];
}

- (void)unregisterObserver:(id)observer {
    NSArray<TPEventBusToken *> *tokens = [observer eventBusUnregisterableBag].unregisterables.allObjects;
    [tokens enumerateObjectsUsingBlock:^(TPEventBusToken * _Nonnull token, NSUInteger idx, BOOL * _Nonnull stop) {
        [token unregister];
    }];
}

- (void)unregisterEventType:(Class)eventType token:(TPEventBusToken *)token {
    [self safeRemoveToken:token forEventType:eventType];
}

- (void)postEvent:(id<TPEvent>)event object:(id)object {
    NSArray<TPEventBusToken *> *tokens = [self safeTokensForEventType:event.class];
    [tokens enumerateObjectsUsingBlock:^(TPEventBusToken * _Nonnull token, NSUInteger idx, BOOL * _Nonnull stop) {
        id observer = token.observer;
        SEL selector = token.selector;
        NSOperationQueue *queue = token.queue;
        if (token.object) {
            if (token.object == object) {
                [self postEvent:event object:object forObserver:observer selector:selector queue:queue];
            }
        } else {
            [self postEvent:event object:object forObserver:observer selector:selector queue:queue];
        }
    }];
}

- (void)postEvent:(id<TPEvent>)event {
    [self postEvent:event object:nil];
}

#pragma mark - Private

- (void)postEvent:(id<TPEvent>)event object:(id)object forObserver:(id)observer selector:(SEL)selector queue:(NSOperationQueue *)queue {
    NSMethodSignature *methodSignature = [object methodSignatureForSelector:selector];
    NSUInteger numberOfArguments = [methodSignature numberOfArguments];
    NSAssert(numberOfArguments <= 4, @"Too many arguments.");
    void (^block)(void) = ^(){
        if (numberOfArguments == 2) {
            ((void (*)(id, SEL))[observer methodForSelector:selector])(observer, selector);
        } else if (numberOfArguments == 3) {
            ((void (*)(id, SEL, id<TPEvent>))[observer methodForSelector:selector])(observer, selector, event);
        } else {
            ((void (*)(id, SEL, id<TPEvent>, id))[observer methodForSelector:selector])(observer, selector, event, object);
        }
    };
    if (queue) {
        [queue addOperationWithBlock:block];
    } else {
        block();
    }
}

- (NSString *)keyFromEventType:(Class)eventType {
    return NSStringFromClass(eventType);
}

- (NSMutableSet *)hashTableForEventType:(Class)eventType {
    NSString *key = [self keyFromEventType:eventType];
    NSMutableSet *ht = self.tokens[key];
    if (!ht) {
        ht = [[NSMutableSet alloc] initWithCapacity:1];
        self.tokens[key] = ht;
    }
    return ht;
}

- (void)safeAddToken:(TPEventBusToken *)token forEventType:(Class)eventType {
    dispatch_barrier_async(self.dispatchQueue, ^{
        NSMutableSet *ht = [self hashTableForEventType:eventType];
        if (![ht containsObject:token]) {
            [[token.observer eventBusUnregisterableBag] addUnregisterable:token];
            [ht addObject:token];
        }
    });
}

- (void)safeRemoveToken:(TPEventBusToken *)token forEventType:(Class)eventType {
    dispatch_barrier_async(self.dispatchQueue, ^{
        NSMutableSet *ht = [self hashTableForEventType:eventType];
        if ([ht containsObject:token]) {
            [ht removeObject:token];
            if (ht.count == 0) {
                [self safeTokensForEventType:eventType];
            }
        }
    });
}

- (void)safeRemoveTokensForEventType:(Class)eventType {
    dispatch_barrier_async(self.dispatchQueue, ^{
        [self removeTokensForEventType:eventType];
    });
}

- (NSArray *)safeTokensForEventType:(Class)eventType {
    __block NSArray *tokens = nil;
    dispatch_sync(self.dispatchQueue, ^{
        tokens = [[self hashTableForEventType:eventType] allObjects];
    });
    return tokens;
}

- (void)removeTokensForEventType:(Class)eventType {
    NSString *key = [self keyFromEventType:eventType];
    self.tokens[key] = nil;
}

@end
