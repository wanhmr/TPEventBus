//
//  TPEventBus.m
//  TPEventBus
//
//  Created by Tpphha on 2019/9/18.
//  Copyright © 2019 Tpphha. All rights reserved.
//

#import "TPEventBus.h"
#import <objc/runtime.h>

@protocol TPEventToken <NSObject>
    
@property (nonatomic, strong, readonly) Class eventType;
@property (nullable, nonatomic, weak, readonly) id object;
    
- (void)executeWithEvent:(id<TPEvent>)event object:(nullable id)object;
    
- (void)dispose;
    
@end

@interface TPEventBus ()

- (BOOL)removeToken:(id<TPEventToken>)token;

- (BOOL)addToken:(id<TPEventToken>)token;

- (BOOL)safeAddToken:(id<TPEventToken>)token;

- (BOOL)safeRemoveToken:(id<TPEventToken>)token;

@end

@interface TPEventTokenDisposableBag : NSObject

- (NSArray<id<TPEventToken>> *)allTokens;

- (void)addToken:(id<TPEventToken>)token;

@end

@interface TPEventTokenDisposableBag () {
    NSHashTable *_tokens;
    NSLock *_lock;
}

@end

@implementation TPEventTokenDisposableBag

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

- (NSArray<id<TPEventToken>> *)allTokens {
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
    
    [tokens enumerateObjectsUsingBlock:^(id<TPEventToken> obj, NSUInteger idx, BOOL *stop) {
        [obj dispose];
    }];
}

@end

@interface NSObject (TPEventBus)

@property (nonatomic, strong, readonly) TPEventTokenDisposableBag *tp_eventTokenDisposableBag;

@end

@implementation NSObject (TPEventBus)

- (TPEventTokenDisposableBag *)tp_eventTokenDisposableBag {
    TPEventTokenDisposableBag *bag = objc_getAssociatedObject(self, _cmd);
    if (!bag) {
        bag = [[TPEventTokenDisposableBag alloc] init];
        objc_setAssociatedObject(self, _cmd, bag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return bag;
}

@end

@protocol TPEventTokenDelegate <NSObject>

- (void)eventTokenWantDispose:(id<TPEventToken>)token;

@end

@interface TPConcreteEventToken : NSObject <TPEventToken>

@property (nonatomic, strong, readonly) Class eventType;
@property (nonatomic, weak, readonly) id observer;
@property (nonatomic, assign, readonly) SEL selector;
@property (nullable, nonatomic, weak, readonly) id object;
@property (nullable, nonatomic, strong, readonly) NSOperationQueue *queue;

@property (nonatomic, weak) id<TPEventTokenDelegate> delegate;

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

@implementation TPConcreteEventToken

- (instancetype)initWithEventType:(Class)eventType
                         observer:(id)observer
                         selector:(SEL)selector
                           object:(id)object
                            queue:(NSOperationQueue *)queue
                         delegate:(id<TPEventTokenDelegate>)delegate {
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

- (BOOL)isEqual:(TPConcreteEventToken *)other {
    if (self == other) {
        return YES;
    }
    
    if (![other isKindOfClass:TPConcreteEventToken.class]) {
        return NO;
    }
    
    return
    (self.eventTypeID == other.eventTypeID || [self.eventTypeID isEqual:other.eventTypeID]) &&
    (self.observerID == other.observerID || [self.observerID isEqual:other.observerID]) &&
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
    id observer = self.observer;
    SEL selector = self.selector;
    NSOperationQueue *queue = self.queue;
    NSMethodSignature *methodSignature = [observer methodSignatureForSelector:selector];
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

- (void)dispose {
    [self.delegate eventTokenWantDispose:self];
}

@end

@interface TPAnonymousEventToken : NSObject <TPEventToken>

@property (nonatomic, strong, readonly) Class eventType;
@property (nullable, nonatomic, strong) NSOperationQueue *queue;
@property (nullable, nonatomic, weak) id object;
@property (nonatomic, copy) TPEventSubscriptionBlock block;
@property (nullable, nonatomic, weak) TPEventTokenDisposableBag *disposableBag;

@property (nonatomic, weak) id<TPEventTokenDelegate> delegate;

#pragma mark - Hash
@property (nonatomic, strong, readonly) NSString *eventTypeID;
@property (nullable, nonatomic, strong) NSString *objectID;

@end

@implementation TPAnonymousEventToken

- (instancetype)initWithEventType:(Class)eventType
                           object:(id)object
                            queue:(NSOperationQueue *)queue
                            block:(TPEventSubscriptionBlock)block {
    self = [super init];
    if (self) {
        _eventType = eventType;
        _block = [block copy];
        _object = object;
        _queue = queue;
        
        _eventTypeID = NSStringFromClass(eventType);
        if (object) {
            _objectID = @((NSUInteger)object).stringValue;
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

- (BOOL)isEqual:(TPAnonymousEventToken *)other {
    if (self == other) {
        return YES;
    }
    
    if (![other isKindOfClass:TPAnonymousEventToken.class]) {
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
    [self.delegate eventTokenWantDispose:self];
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

- (TPEventSubscriberMaker * (^)(NSOperationQueue *))onQueue {
    return ^ TPEventSubscriberMaker * (NSOperationQueue *queue) {
        self.queue = queue;
        return self;
    };
}

- (TPEventSubscriberMaker * (^)(id))forObject {
    return ^ TPEventSubscriberMaker * (id object) {
        self.object = object;
        return self;
    };
}

- (TPEventSubscriberMaker *)onNext:(void (^)(id, id))block {
    TPAnonymousEventToken *token = [[TPAnonymousEventToken alloc] initWithEventType:self.eventType object:self.object queue:self.queue block:block];
    [self.eventBus safeAddToken:token];
    return self;
}

@end

@interface TPEventBus () <TPEventTokenDelegate>

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

- (TPEventSubscriberMaker * (^)(Class))subscribe {
    return ^ TPEventSubscriberMaker * (Class eventType) {
        return [[TPEventSubscriberMaker alloc] initWithEventBus:self eventType:eventType];
    };
}

- (void)registerEventType:(Class)eventType
                 observer:(id)observer
                 selector:(SEL)selector
                   object:(id)object
                    queue:(NSOperationQueue *)queue {
    NSParameterAssert([eventType conformsToProtocol:@protocol(TPEvent)]);
    NSParameterAssert(observer);
    NSParameterAssert(selector);
    
    TPConcreteEventToken *token =
    [[TPConcreteEventToken alloc] initWithEventType:eventType
                                           observer:observer
                                           selector:selector
                                             object:object
                                              queue:queue
                                           delegate:self];
    if ([self safeAddToken:token]) {
        [[observer tp_eventTokenDisposableBag] addToken:token];
    }
}

- (void)registerEventType:(Class)eventType observer:(id)observer selector:(SEL)selector {
    [self registerEventType:eventType observer:observer selector:selector object:nil queue:nil];
}

- (void)unregisterEventType:(Class)eventType observer:(id)observer object:(id)object {
    NSArray<id<TPEventToken>> *tokens = [observer tp_eventTokenDisposableBag].allTokens;
    [tokens enumerateObjectsUsingBlock:^(id<TPEventToken> _Nonnull token, NSUInteger idx, BOOL * _Nonnull stop) {
        if (token.eventType == eventType) {
            if (object) {
                if (token.object == object) {
                    [token dispose];
                }
            } else {
                [token dispose];
            }
        }
    }];
}

- (void)unregisterEventType:(Class)eventType observer:(id)observer {
    [self unregisterEventType:eventType observer:observer object:nil];
}

- (void)unregisterObserver:(id)observer {
    NSArray<id<TPEventToken>> *tokens = [observer tp_eventTokenDisposableBag].allTokens;
    [tokens enumerateObjectsUsingBlock:^(id<TPEventToken> _Nonnull token, NSUInteger idx, BOOL * _Nonnull stop) {
        [token dispose];
    }];
}

- (void)postEvent:(id<TPEvent>)event object:(id)object {
    NSArray<id<TPEventToken>> *tokens = [self tokensForEventType:event.class];
    [tokens enumerateObjectsUsingBlock:^(id<TPEventToken> _Nonnull token, NSUInteger idx, BOOL * _Nonnull stop) {
        [token executeWithEvent:event object:object];
    }];
}

- (void)postEvent:(id<TPEvent>)event {
    [self postEvent:event object:nil];
}

#pragma mark - TPEventTokenDelegate

- (void)eventTokenWantDispose:(id<TPEventToken>)token {
    [self safeRemoveToken:token];
}

#pragma mark - Private

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

- (BOOL)removeToken:(id<TPEventToken>)token {
    NSMutableSet *ht = [self hashTableForEventType:token.eventType];
    if ([ht containsObject:token]) {
        [ht removeObject:token];
        return YES;
    }
    return NO;
}

- (BOOL)addToken:(id<TPEventToken>)token {
    NSMutableSet *ht = [self hashTableForEventType:token.eventType];
    if (![ht containsObject:token]) {
        [ht addObject:token];
        return YES;
    }
    return NO;
}

- (BOOL)safeAddToken:(id<TPEventToken>)token {
    BOOL result = NO;
    [self.lock lock];
    result = [self addToken:token];
    [self.lock unlock];
    return result;
}

- (BOOL)safeRemoveToken:(id<TPEventToken>)token {
    BOOL result = NO;
    [self.lock lock];
    result = [self removeToken:token];
    [self.lock unlock];
    return result;
}

@end
