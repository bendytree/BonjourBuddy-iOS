//
//  BonjourBuddy.h
//
//  Created by Joshua Wright on 5/14/13. http://bendytree.com
//
//  Use BonjourBuddy however you want. Use it, change it, sell it, burn it, paint butterflies
//  on its cheeks... just so long as you know I'm not responsible for any problems.
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

