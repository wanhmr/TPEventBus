# TPEventBus

[![CI Status](https://img.shields.io/travis/wanhmr/TPEventBus.svg?style=flat)](https://travis-ci.org/wanhmr/TPEventBus)
[![Version](https://img.shields.io/cocoapods/v/TPEventBus.svg?style=flat)](https://cocoapods.org/pods/TPEventBus)
[![License](https://img.shields.io/cocoapods/l/TPEventBus.svg?style=flat)](https://cocoapods.org/pods/TPEventBus)
[![Platform](https://img.shields.io/cocoapods/p/TPEventBus.svg?style=flat)](https://cocoapods.org/pods/TPEventBus)

EventBus is a publish/subscribe event bus for iOS, inspired by [EventBus](https://github.com/greenrobot/EventBus) and [QTEventBus](https://github.com/LeoMobileDeveloper/QTEventBus).

![Event Bus](http://i.imgur.com/BNtzhB7.png)
source of the picture: [老司机教你 “飙” EventBus 3](https://segmentfault.com/a/1190000005089229)

## EventBus in 3 steps

### Swift

1. Define events:

    ```Swift
    class TPCountEvent: NSObject, TPEvent {
    	var count: Int
    
	    init(count: Int) {
	        self.count = count
	    }
	}
	```

2. Prepare subscribers:
    
    Subscribers implement event handling methods that will be called when an event is received.
    
    ```Swift
    @objc func onCountEvent(event: TPCountEvent, object: Any?) {
    	// do something
    }
    ```
    Register and unregister your subscriber. 
    
    Notice: **When the observer is released, it will be automatically unregistered.**

   ```Swift
   // Register
	TPEventBus.shared.register(eventType: TPCountEvent.self, observer: self, selector: #selector(onCountEvent(event:object:)))
    
    // Unregister
	TPEventBus.shared.unregister(eventType: TPCountEvent.self, observer: self)
    ```

3. Post events:

   ```Swift
	let event = TPCountEvent.init(count: count)
	TPEventBus.shared.post(event: event, object: self)
    ```

### Objective-C

1. Define events:

    ```Objective-C
	@interface TPCountEvent : NSObject <TPEvent>

	@property (nonatomic, assign, readonly) NSInteger count;

	- (instancetype)initWithCount:(NSInteger)count;

	@end
    ```

2. Prepare subscribers:
    
    Subscribers implement event handling methods that will be called when an event is received.
    
    ```Objective-C
    - (void)onCountEvent:(TPCountEvent *)event object:(id)object {
    	// do something
    }
    
    - (void)onCountEvent:(TPCountEvent *)event {
		// do something
	}
	```
	Register and unregister your subscriber.
    
	Notice: **When the observer is released, it will be automatically unregistered.**

   ```Objective-C
   // Register
    [[TPEventBus sharedBus] registerEventType:TPCountEvent.class observer:self selector:@selector(onCountEvent:object:) object:nil queue:[NSOperationQueue new]];
    [[TPEventBus sharedBus] registerEventType:TPCountEvent.class observer:self selector:@selector(onCountEvent:object:)];
    [[TPEventBus sharedBus] registerEventType:TPCountEvent.class observer:self selector:@selector(onCountEvent:)];
    
    // Unregister
	[[TPEventBus sharedBus] unregisterObserver:self];
	[[TPEventBus sharedBus] unregisterEventType: TPCountEvent.class observer:self object:nil];
	```

3. Post events:

   ```Objective-C
	TPCountEvent *event = [[TPCountEvent alloc] initWithCount:count];
    [[TPEventBus sharedBus] postEvent:event object:self];
    ```
    

### Objective-C

1. Define events:

    ```Objective-C
	@interface TPCountEvent : NSObject <TPEvent>

	@property (nonatomic, assign, readonly) NSInteger count;

	- (instancetype)initWithCount:(NSInteger)count;

	@end
    ```

2. Prepare subscribers:
    
    Subscribers implement event handling methods that will be called when an event is received.
    
    ```Objective-C
    - (void)onCountEvent:(TPCountEvent *)event object:(id)object {
    	// do something
    }
    
    - (void)onCountEvent:(TPCountEvent *)event {
		// do something
	}
    ```
    Register and unregister your subscriber.

   ```Objective-C
   // Register
    [[TPEventBus sharedBus] registerEventType:TPCountEvent.class observer:self selector:@selector(onCountEvent:object:) object:nil queue:[NSOperationQueue new]];
    [[TPEventBus sharedBus] registerEventType:TPCountEvent.class observer:self selector:@selector(onCountEvent:object:)];
    [[TPEventBus sharedBus] registerEventType:TPCountEvent.class observer:self selector:@selector(onCountEvent:)];
    
    // Unregister
	[[TPEventBus sharedBus] unregisterObserver:self];
	[[TPEventBus sharedBus] unregisterEventType: TPCountEvent.class observer:self object:nil];
    ```

3. Post events:

   ```Objective-C
	TPCountEvent *event = [[TPCountEvent alloc] initWithCount:count];
    [[TPEventBus sharedBus] postEvent:event object:self];
	```
    
## Convenience

### Swift

```Swift
TPEventSubscriber<TPCountEvent>.subscribe(eventType: TPCountEvent.self).onNext { [weak self] (event, object) in
        guard let self = self else {
            return
        }
        
        // do something
	}.disposed(by: self)
```
	
### Objective-C

```Objective-C
[[TPEventSubscribe(TPCountEvent).onQueue([NSOperationQueue new]).forObject(nil) onNext:^(TPCountEvent * _Nonnull event, id  _Nullable object) {
	// do something
}] disposedByObject:self];
```

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

TPEventBus is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'TPEventBus'
```

## Author

wanhmr, tpx@meitu.com

## License

TPEventBus is available under the MIT license. See the LICENSE file for more info.
