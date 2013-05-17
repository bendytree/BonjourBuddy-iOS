//
//  Bonjour.h
//  Speaky
//
//  Created by Joshua Wright on 5/14/13.
//  Copyright (c) 2013 Joshua Wright. All rights reserved.
//

#import <Foundation/Foundation.h>

#define BonjourBuddyPeersChangedNotification @"BonjourBuddyPeersChangedNotification"

@interface BonjourBuddy : NSObject<NSNetServiceDelegate, NSNetServiceBrowserDelegate>

@property (retain) NSString* myId;
@property (nonatomic) NSDictionary* me;
@property (assign) BOOL includeSelfInPeers;
@property (retain) NSString* netServiceType;
@property (retain) NSString* netServiceDomain;
@property (assign) int netServicePort;
@property (retain) NSString* netServiceName;
@property (assign) int resolveTimeout;
@property (retain) NSString* myIdKey;

- (NSArray*) peers;
- (void) start;
- (void) stop;

+ (BonjourBuddy*) current;

@end

