//
//  TPMediaLikedChangedEvent.h
//  TPEventBus_Example
//
//  Created by Tpphha on 2019/9/19.
//  Copyright © 2019 wanhmr. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TPEventBus/TPEvent.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPMediaLikedChangedEvent : NSObject <TPEvent>

@property (nonatomic, copy, readonly) NSNumber *liked;

- (instancetype)initWithLiked:(NSNumber *)liked;

@end

NS_ASSUME_NONNULL_END
