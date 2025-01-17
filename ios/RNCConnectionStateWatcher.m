/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "RNCConnectionStateWatcher.h"
#import <SystemConfiguration/SystemConfiguration.h>

@interface RNCConnectionStateWatcher () <NSURLSessionDataDelegate>

@property (nonatomic) SCNetworkReachabilityRef reachabilityRef;
@property (nullable, weak, nonatomic) id<RNCConnectionStateWatcherDelegate> delegate;
@property (nonatomic) SCNetworkReachabilityFlags lastFlags;
@property (nonnull, strong, nonatomic) RNCConnectionState *state;

@end

@implementation RNCConnectionStateWatcher

#pragma mark - Lifecycle

- (instancetype)initWithDelegate:(id<RNCConnectionStateWatcherDelegate>)delegate
{
    self = [self init];
    if (self) {
        _delegate = delegate;
        _state = [[RNCConnectionState alloc] init];
        _reachabilityRef = [self createReachabilityRef];
    }
    return self;
}

- (void)dealloc
{
    self.delegate = nil;

    if (self.reachabilityRef != NULL) {
        SCNetworkReachabilityUnscheduleFromRunLoop(self.reachabilityRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        CFRelease(self.reachabilityRef);
        self.reachabilityRef = nil;
    }
}

#pragma mark - Public methods

- (RNCConnectionState *)currentState
{
    return self.state;
}

#pragma mark - Callback

static void RNCReachabilityCallback(__unused SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    RNCConnectionStateWatcher *self = (__bridge id)info;
    [self update:flags];
    
}

- (void)update:(SCNetworkReachabilityFlags)flags
{
    self.lastFlags = flags;
    self.state = [[RNCConnectionState alloc] initWithReachabilityFlags:flags];
}

#pragma mark - Setters

- (void)setState:(RNCConnectionState *)state
{
    if (![state isEqualToConnectionState:_state]) {
        _state = state;
        
        [self updateDelegate];
    }
}

#pragma mark - Utilities

- (void)updateDelegate
{
    [self.delegate connectionStateWatcher:self didUpdateState:self.state];
}

- (SCNetworkReachabilityRef)createReachabilityRef
{
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "apple.com");
    // Set the callback, setting our "self" as the info so we can get a reference in the callback
    SCNetworkReachabilityContext context = { 0, ( __bridge void *)self, NULL, NULL, NULL };
    SCNetworkReachabilitySetCallback(reachability, RNCReachabilityCallback, &context);
    SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    return reachability;
}

@end
