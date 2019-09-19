//
//  TPMediaLikedChangedEvent.m
//  TPEventBus_Example
//
//  Created by Tpphha on 2019/9/19.
//  Copyright © 2019 wanhmr. All rights reserved.
//

#import "TPMediaLikedChangedEvent.h"

@implementation TPMediaLikedChangedEvent

- (instancetype)initWithLiked:(NSNumber *)liked {
    self = [super init];
    if (self) {
        _liked = [liked copy];
    }
    return self;
}

@end
