//
//  TPCountEvent.m
//  TPEventBus_Example
//
//  Created by Tpphha on 2019/9/21.
//  Copyright © 2019 wanhmr. All rights reserved.
//

#import "TPCountEvent.h"

@implementation TPCountEvent

- (instancetype)initWithCount:(NSInteger)count {
    self = [super init];
    if (self) {
        _count = count;
    }
    return self;
}

@end
