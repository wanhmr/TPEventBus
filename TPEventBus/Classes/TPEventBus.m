//
//  TPEventBus.m
//  TPEventBus
//
//  Created by Tpphha on 2019/9/18.
//  Copyright © 2019 Tpphha. All rights reserved.
//

#import "TPEventBus.h"
#import <objc/runtime.h>

@implementation TPEventBusUnregisterBag

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

- (TPEventBusUnregisterBag *)eventBusUnregisterBag {
    TPEventBusUnregisterBag *bag = objc_getAssociatedObject(self, _cmd);
    if (!bag) {
        bag = [[TPEventBusUnregisterBag alloc] init];
        objc_setAssociatedObject(self, _cmd, bag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return bag;
}

@end

@interface TPEventBusObservingContext ()

@property (nonatomic, strong) NSString *eventType;
@property (nonatomic, weak) id observer;
@property (nonatomic, strong) NSString *selector;
@property (nonatomic, weak) id object;
@property (nonatomic, strong) NSOperationQueue *queue;

/**
 这个是关键，因为 observer 是弱引用，observer 清除 AssociatedObject 的时候，已经是 nil，从而导致 TPEventBusObservingContext 的 hash 值改变。
 因此我们需要保存 observer 的 snapshot 也就是 observerID。
 */
@property (nonatomic, strong) NSString *observerID;
@property (nonatomic, strong) NSString *objectID;

@end

@implementation TPEventBusObservingContext

- (NSUInteger)hash {
    return
    [self.eventType hash] ^
    [self.observerID hash] ^
    [self.selector hash] ^
    [self.objectID hash] ^
    [self.queue hash];
}

- (BOOL)isEqual:(TPEventBusObservingContext *)other {
    if (self == other) {
        return YES;
    }
    
    if (![other isKindOfClass:TPEventBusObservingContext.class]) {
        return NO;
    }
    
    return
    (self.eventType == other.eventType || [self.eventType isEqual:other.eventType]) &&
    (self.observerID == other.observerID || [self.observerID isEqual:other.observerID]) &&
    (self.selector == other.selector || [self.selector isEqual:other.selector]) &&
    (self.objectID == other.objectID || [self.objectID isEqual:other.objectID]) &&
    (self.queue == other.queue || [self.queue isEqual:other.queue]);
}

- (void)unregister {
    [[TPEventBus sharedBus] unregisterEventType:NSClassFromString(self.eventType) observingContext:self];
}

@end

@interface TPEventBus ()

@property (nonatomic, strong, readonly) dispatch_queue_t  dispatchQueue;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSHashTable *> *observingContexts;

@end

@implementation TPEventBus

- (instancetype)init {
    self = [super init];
    if (self) {
        _dispatchQueue = dispatch_queue_create("com.eventbus.dispatch.queue", DISPATCH_QUEUE_CONCURRENT);
        _observingContexts = [NSMutableDictionary new];
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
    NSParameterAssert(eventType);
    NSParameterAssert(observer);
    NSParameterAssert(selector);
    NSParameterAssert([eventType conformsToProtocol:@protocol(TPEvent)]);
    
    TPEventBusObservingContext *observingContext = [TPEventBusObservingContext new];
    observingContext.eventType = NSStringFromClass(eventType);
    observingContext.observer = observer;
    observingContext.selector = NSStringFromSelector(selector);
    observingContext.object = object;
    observingContext.queue = queue;
    observingContext.observerID = @((NSUInteger)observer).stringValue;
    if (object) {
        observingContext.objectID = @((NSUInteger)object).stringValue;
    }
    [self safeAddObservingContext:observingContext forEventType:eventType];
}

- (void)registerEventType:(Class)eventType observer:(id)observer selector:(SEL)selector {
    [self registerEventType:eventType observer:observer selector:selector object:nil queue:nil];
}

- (void)unregisterEventType:(Class)eventType observer:(id)observer object:(id)object {
    NSArray<TPEventBusObservingContext *> *observingContexts = [observer eventBusUnregisterBag].unregisterables.allObjects;
    NSString *et = NSStringFromClass(eventType);
    [observingContexts enumerateObjectsUsingBlock:^(TPEventBusObservingContext * _Nonnull observingContext, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([observingContext.eventType isEqualToString:et]) {
            if (object) {
                if (observingContext.object == object) {
                    [observingContext unregister];
                }
            } else {
                [observingContext unregister];
            }
        }
    }];
}

- (void)unregisterEventType:(Class)eventType observer:(id)observer {
    [self unregisterEventType:eventType observer:observer object:nil];
}

- (void)unregisterObserver:(id)observer {
    NSArray<TPEventBusObservingContext *> *observingContexts = [observer eventBusUnregisterBag].unregisterables.allObjects;
    [observingContexts enumerateObjectsUsingBlock:^(TPEventBusObservingContext * _Nonnull observingContext, NSUInteger idx, BOOL * _Nonnull stop) {
        [observingContext unregister];
    }];
}

- (void)unregisterEventType:(Class)eventType observingContext:(TPEventBusObservingContext *)observingContext {
    [self safeRemoveObservingContext:observingContext forEventType:eventType];
}

- (void)postEvent:(id<TPEvent>)event object:(id)object {
    NSArray<TPEventBusObservingContext *> *observingContexts = [self safeObservingContextsForEventType:event.class];
    [observingContexts enumerateObjectsUsingBlock:^(TPEventBusObservingContext * _Nonnull observingContext, NSUInteger idx, BOOL * _Nonnull stop) {
        id observer = observingContext.observer;
        NSString *selector = observingContext.selector;
        NSOperationQueue *queue = observingContext.queue;
        if (observingContext.object) {
            if (observingContext.object == object) {
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

- (void)postEvent:(id<TPEvent>)event object:(id)object forObserver:(id)observer selector:(NSString *)selector queue:(NSOperationQueue *)queue {
    SEL sel = NSSelectorFromString(selector);
    NSMethodSignature *methodSignature = [object methodSignatureForSelector:sel];
    NSUInteger numberOfArguments = [methodSignature numberOfArguments];
    NSAssert(numberOfArguments <= 4, @"Too many arguments.");
    void (^block)(void) = ^(){
        if (numberOfArguments == 2) {
            ((void (*)(id, SEL))[observer methodForSelector:sel])(observer, sel);
        } else if (numberOfArguments == 3) {
            ((void (*)(id, SEL, id<TPEvent>))[observer methodForSelector:sel])(observer, sel, event);
        } else {
            ((void (*)(id, SEL, id<TPEvent>, id))[observer methodForSelector:sel])(observer, sel, event, object);
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

- (NSHashTable *)hashTableFromEventType:(Class)eventType {
    NSString *key = [self keyFromEventType:eventType];
    NSHashTable *ht = self.observingContexts[key];
    if (!ht) {
        ht = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsObjectPersonality capacity:1];
        self.observingContexts[key] = ht;
    }
    return ht;
}

- (void)safeAddObservingContext:(TPEventBusObservingContext *)observingContext forEventType:(Class)eventType {
    dispatch_barrier_async(self.dispatchQueue, ^{
        NSHashTable *ht = [self hashTableFromEventType:eventType];
        if (![ht containsObject:observingContext]) {
            [[observingContext.observer eventBusUnregisterBag] addUnregisterable:observingContext];
            [ht addObject:observingContext];
        }
    });
}

- (void)safeRemoveObservingContext:(TPEventBusObservingContext *)observingContext forEventType:(Class)eventType {
    dispatch_barrier_async(self.dispatchQueue, ^{
        NSHashTable *ht = [self hashTableFromEventType:eventType];
        if ([ht containsObject:observingContext]) {
            [ht removeObject:observingContext];
            if (ht.count == 0) {
                [self safeObservingContextsForEventType:eventType];
            }
        }
    });
}

- (void)safeRemoveObservingContextsForEventType:(Class)eventType {
    dispatch_barrier_async(self.dispatchQueue, ^{
        [self removeObservingContextsForEventType:eventType];
    });
}

- (NSArray *)safeObservingContextsForEventType:(Class)eventType {
    __block NSArray *observingContexts = nil;
    dispatch_sync(self.dispatchQueue, ^{
        observingContexts = [[self hashTableFromEventType:eventType] allObjects];
    });
    return observingContexts;
}

- (void)removeObservingContextsForEventType:(Class)eventType {
    NSString *key = [self keyFromEventType:eventType];
    self.observingContexts[key] = nil;
}


@end
