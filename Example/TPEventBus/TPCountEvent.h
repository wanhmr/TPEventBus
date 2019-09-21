//
//  TPCountEvent.h
//  TPEventBus_Example
//
//  Created by Tpphha on 2019/9/21.
//  Copyright © 2019 wanhmr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TPEventBus/TPEventBus.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPCountEvent : NSObject <TPEvent>

@property (nonatomic, assign, readonly) NSInteger count;

- (instancetype)initWithCount:(NSInteger)count;

@end

NS_ASSUME_NONNULL_END
