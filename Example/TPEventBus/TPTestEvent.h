//
//  TPTestEvent.h
//  TPEventBus_Example
//
//  Created by Tpphha on 2019/9/18.
//  Copyright © 2019 wanhmr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TPEventBus/TPEvent.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPTestEvent : NSObject <TPEvent>

@property (nonatomic, copy) NSString *name;

@end

NS_ASSUME_NONNULL_END
