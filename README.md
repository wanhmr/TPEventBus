# TPEventBus

[![CI Status](https://img.shields.io/travis/wanhmr/TPEventBus.svg?style=flat)](https://travis-ci.org/wanhmr/TPEventBus)
[![Version](https://img.shields.io/cocoapods/v/TPEventBus.svg?style=flat)](https://cocoapods.org/pods/TPEventBus)
[![License](https://img.shields.io/cocoapods/l/TPEventBus.svg?style=flat)](https://cocoapods.org/pods/TPEventBus)
[![Platform](https://img.shields.io/cocoapods/p/TPEventBus.svg?style=flat)](https://cocoapods.org/pods/TPEventBus)

TPEventBus is a publish/subscribe event bus for iOS, inspired by [EventBus](https://github.com/greenrobot/EventBus) and [QTEventBus](https://github.com/LeoMobileDeveloper/QTEventBus).

<img src="Static/EventBus-Publish-Subscribe.png"></img>
Source of the picture: [EventBus](https://github.com/greenrobot/EventBus)

## EventBus in 3 steps

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
    
    Notice: **When the subscriber is released, it will be automatically unregistered.**

   ```Swift
   // Register
	TPEventBus<TPCountEvent>.shared.register(eventType: TPCountEvent.self, subscriber: self, selector: #selector(onCountEvent(event:object:)))
    
    // Unregister
	TPEventBus<TPCountEvent>.shared.unregister(eventType: TPCountEvent.self, subscriber: self)
    ```

3. Post events:

   ```Swift
	let event = TPCountEvent.init(count: count)
	TPEventBus.shared.post(event: event, object: self)
    ```
    
## Convenience


```Swift
TPEventBus<TPCountEvent>.shared.subscribe(eventType: TPCountEvent.self).onQueue(OperationQueue.main).onEvent { [weak self] (event, object) in
    guard let self = self else {
        return
    }
    
    // do something
}.disposed(by: self)
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

tpphha, tpphha@gmail.com

## License

TPEventBus is available under the MIT license. See the LICENSE file for more info.
