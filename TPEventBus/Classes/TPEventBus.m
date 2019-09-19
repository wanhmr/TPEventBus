//
//  TPEventBus.m
//  TPEventBus
//
//  Created by Tpphha on 2019/9/18.
//  Copyright © 2019 Tpphha. All rights reserved.
//

#import "TPEventBus.h"
#import <objc/runtime.h>

@interface TPEventBusUnregisterableBag () {
    NSHashTable *_unregisterables;
}

@end

@implementation TPEventBusUnregisterableBag

- (void)dealloc {
    NSArray<id<TPEventBusUnregisterable>> *allUnregisterables = _unregisterables.allObjects;
    [_unregisterables removeAllObjects];
    
    [allUnregisterables enumerateObjectsUsingBlock:^(id<TPEventBusUnregisterable> obj, NSUInteger idx, BOOL *stop) {
        [obj unregister];
    }];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _unregisterables = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory capacity:1];
    }
    return self;
}

- (NSArray<id<TPEventBusUnregisterable>> *)allUnregisterables {
    return _unregisterables.allObjects;
}

- (void)addUnregisterable:(id<TPEventBusUnregisterable>)unregisterable {
    [_unregisterables addObject:unregisterable];
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

@protocol TPEventBusTokenDelegate <NSObject>

- (void)eventBusTokenWantUnregister:(TPEventBusToken *)token;

@end

@interface TPEventBusToken ()

@property (nonatomic, strong, readonly) Class eventType;
@property (nonatomic, weak, readonly) id observer;
@property (nonatomic, assign, readonly) SEL selector;
@property (nullable, nonatomic, weak, readonly) id object;
@property (nullable, nonatomic, strong, readonly) NSOperationQueue *queue;

@property (nonatomic, weak) id<TPEventBusTokenDelegate> delegate;

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
                            queue:(NSOperationQueue *)queue
                         delegate:(id<TPEventBusTokenDelegate>)delegate {
    self = [super init];
    if (self) {
        _eventType = eventType;
        _observer = observer;
        _selector = selector;
        _object = object;
        _queue = queue;
        _delegate = delegate;
        
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
    [self.delegate eventBusTokenWantUnregister:self];
}

@end

@interface TPEventBus () <TPEventBusTokenDelegate>

@property (nonatomic, strong, readonly) NSLock *lock;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSMutableSet *> *tokens;

@end

@implementation TPEventBus

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = [NSLock new];
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
                                         queue:queue
                                      delegate:self];
    [self safeAddToken:token];
}

- (void)registerEventType:(Class)eventType observer:(id)observer selector:(SEL)selector {
    [self registerEventType:eventType observer:observer selector:selector object:nil queue:nil];
}

- (void)unregisterEventType:(Class)eventType observer:(id)observer object:(id)object {
    NSArray<TPEventBusToken *> *tokens = [observer eventBusUnregisterableBag].allUnregisterables;
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
    NSArray<TPEventBusToken *> *tokens = [observer eventBusUnregisterableBag].allUnregisterables;
    [tokens enumerateObjectsUsingBlock:^(TPEventBusToken * _Nonnull token, NSUInteger idx, BOOL * _Nonnull stop) {
        [token unregister];
    }];
}

- (void)postEvent:(id<TPEvent>)event object:(id)object {
    NSArray<TPEventBusToken *> *tokens = [self tokensForEventType:event.class];
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

#pragma mark - TPEventBusTokenDelegate

- (void)eventBusTokenWantUnregister:(TPEventBusToken *)token {
    [self safeRemoveToken:token];
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

- (NSArray *)tokensForEventType:(Class)eventType {
    return [self hashTableForEventType:eventType].allObjects;
}

- (void)removeToken:(TPEventBusToken *)token {
    NSMutableSet *ht = [self hashTableForEventType:token.eventType];
    if ([ht containsObject:token]) {
        [ht removeObject:token];
    }
}

- (void)addToken:(TPEventBusToken *)token {
    NSMutableSet *ht = [self hashTableForEventType:token.eventType];
    if (![ht containsObject:token]) {
        [[token.observer eventBusUnregisterableBag] addUnregisterable:token];
        [ht addObject:token];
    }
}

- (void)safeAddToken:(TPEventBusToken *)token {
    [self.lock lock];
    [self addToken:token];
    [self.lock unlock];
}

- (void)safeRemoveToken:(TPEventBusToken *)token {
    [self.lock lock];
    [self removeToken:token];
    [self.lock unlock];
}

@end
