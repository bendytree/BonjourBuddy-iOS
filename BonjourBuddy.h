//
//  BonjourBuddy.h
//

/**
 *
 *  By Josh Wright (@BendyTree) http://bendytree.com
 *
 *
 *  Tested on iOS 5-6.
 *
 *
 *  ################################  HOW IT WORKS  ######################################
 *
 *  Bonjour allows you to find other devices on the same wifi network. If you don't know
 *  what you're doing, it can be tricky to get going. So I made this wrapper to hide all
 *  the details and make it easy. No dependencies, no frameworks. Uses ARC.
 *
 *      // Can be a singleton, or use alloc/init
 *      BonjourBuddy* bonjour = [BonjourBuddy current];
 *
 *      // Share a dictionary of information about yourself
 *      bonjour.me = @{ @"name": @"Josh" };
 *
 *      // Broadcast yourself & look for others
 *      [bonjour start];
 *
 *      // Get notified when the list of peers (or their data) changes
 *      [[NSNotificationCenter defaultCenter] addObserver:self 
 *                                               selector:@selector(peersChanged) 
 *                                  name:BonjourBuddyPeersChangedNotification object:nil];
 *
 *
 *      - (void) peersChanged
 *      {
 *          // Read data from other peers
 *          for(NSDictionary* peer in BonjourBuddy.current.peers){
 *              NSString* name = [peer objectForKey:@"name"];
 *              NSLog(@"%@ is on the network!", name);
 *          }
 *      }
 *
 *
 *  ###################################  LICENSE  ########################################
 *
 *  Use BonjourBuddy however you want. Change it, sell it, burn it, paint butterflies
 *  on its cheeks... just so long as you know I'm not responsible for any problems.
 *
 */

#import <Foundation/Foundation.h>

// Called when a peer is added, removed, or updates their data
#define BonjourBuddyPeersChangedNotification @"BonjourBuddyPeersChangedNotification"


@interface BonjourBuddy : NSObject<NSNetServiceDelegate, NSNetServiceBrowserDelegate>

// Uniquely identifies yourself (so you aren't shown in the list of peers)
// - Defaults to a GUID, but you can override it
@property (retain) NSString* myId;

// A dictionary of data about yourself.
// - Winds up in the bonjour.peers array for others
// - Keys and values must both be NSString
// - LENGTH(key+value) must be 254 characters or less
// - No more than 60,000 bytes of key value pairs
// - Defaults to an empty dictionary
// - Setting this automatically updates peers
@property (nonatomic) NSDictionary* me;

// Whether to include "me" as a peer
// - false by default
@property (assign) BOOL includeSelfInPeers;

// The identifier for the network you are creating
// - @"_YOURBUNDLEIDENTIFIER._tcp." is the default
// - must be set before you start the service
@property (retain) NSString* netServiceType;

// The domain for your service
// - defaults to @"local."
@property (retain) NSString* netServiceDomain;

// The port for your service
// - defaults to 53484
@property (assign) int netServicePort;

// The name for your service
// - defaults to blank, so one is selected for you (like Josh's Phone)
// - may be changed by the network, so don't rely on this
@property (retain) NSString* netServiceName;

// How many seconds until netService resolution times out
// - defaults to 60 seconds
@property (assign) int resolveTimeout;

// The key where your identifier is stored in your NSDictionary
// - defaults to @"__id"
@property (retain) NSString* myIdKey;

// A list of currently available peers on the network
// - Each element in the array is a NSDictionary* which comes from "me"
// - Does not include self by default, use includeSelfInPeers to change this
- (NSArray*) peers;

// Starts announcing yourself on Bonjour & looking for others
// - Is not called automatically (on init), you must call this yourself
// - Do not call this multiple times
// - Automatically called if your app resumes from backround
- (void) start;

// Stops the bonjour services & removes all peers
- (void) stop;

// Singleton instance
// - use this if you only want one instance shared across your app
+ (BonjourBuddy*) current;

// Create your own instance
// - does not return the same instance as `current`
- (id) init;

// Define your own service is, for ex: _mycustomidentifier._tcp.
- (id) initWithServiceId:(NSString *)serviceId;

@end

