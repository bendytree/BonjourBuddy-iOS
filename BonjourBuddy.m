//
//  BonjourBuddy.m
//
//

#import "BonjourBuddy.h"
#include <arpa/inet.h>

@implementation BonjourBuddy{
    
    NSNetService* announcingService;
    NSNetServiceBrowser* listeningService;
    NSMutableArray* peerServices;
    NSDictionary* meCached;
    
}

@synthesize myId, myIdKey, includeSelfInPeers, netServiceType, netServiceDomain, netServicePort, netServiceName;

- (id)init
{
    self = [super init];
    if (self) {
        peerServices = [NSMutableArray array];
        
        self.myIdKey = @"__id";
        self.resolveTimeout = 60;
        self.netServiceDomain = @"local.";        
        self.includeSelfInPeers = NO;
        self.myId = [BonjourBuddy generateUUID];
        self.me = [NSDictionary dictionary];
        self.netServicePort = 53484;
        self.netServiceName = @"";
        
        NSString* appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        NSCharacterSet* charactersToRemove = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
        NSString* cleanAppName = [[appName componentsSeparatedByCharactersInSet:charactersToRemove] componentsJoinedByString:@""];
        self.netServiceType = [NSString stringWithFormat:@"_%@._tcp.", cleanAppName];
        
        // restart from background
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(start) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
     
    [self stop];
}

- (void) start
{
    NSLog(@"Starting bonjour buddy...");
    
    if(announcingService != nil)
    {
        announcingService.delegate = nil;
        announcingService = nil;
    }
    
    // Announce ourself
    announcingService = [[NSNetService alloc] initWithDomain:self.netServiceDomain
                                                        type:self.netServiceType
                                                        name:self.netServiceName
                                                        port:self.netServicePort];
    [announcingService setDelegate:self];
    [announcingService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:meCached]];
    [announcingService publish];
    
    // Look for friends (who are announcing themself)
    if(listeningService == nil)
    {
        listeningService = [[NSNetServiceBrowser alloc] init];
        [listeningService setDelegate:self];
        [listeningService searchForServicesOfType:self.netServiceType inDomain:self.netServiceDomain];
    }
}

- (void) stop {
    
    if(announcingService == nil)
        return;
    
    [announcingService stop];
    [announcingService stopMonitoring];
    announcingService.delegate = nil;
    announcingService = nil;
    
    [listeningService stop];
    listeningService.delegate = nil;
    listeningService = nil;
    
    [peerServices removeAllObjects];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BonjourBuddyPeersChangedNotification object:nil];
}


#pragma Peers

- (void) setMe:(NSDictionary *)d
{
    NSMutableDictionary* dic = [NSMutableDictionary dictionaryWithDictionary:d];
    [dic setObject:self.myId forKey:self.myIdKey];
    meCached = dic;
    
    if(announcingService){
        [announcingService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:dic]];
    }
}

- (NSDictionary*) me
{
    return meCached;
}

- (NSArray*) peers
{
    //addresses: http://stackoverflow.com/a/4976808/193896
    
    NSMutableArray* peers = [NSMutableArray array];
    for(NSNetService* peerService in peerServices)
    {
        NSData* data = peerService.TXTRecordData;
        NSDictionary* txtDic = [NSNetService dictionaryFromTXTRecordData:data];
        if(txtDic == nil)
            continue;
        
        //clean the values (NSData >> NSString)
        NSMutableDictionary* cleanDic = [NSMutableDictionary dictionary];
        for(NSString* key in txtDic.allKeys)
        {
            NSString* val = [NSString stringWithUTF8String:[[txtDic objectForKey:key] bytes]];
            [cleanDic setObject:val forKey:key];
        }
        
        //ip addresses: http://stackoverflow.com/a/4976808/193896
        if ([cleanDic count] > 0)
        {
            char addressBuffer[INET6_ADDRSTRLEN];
            for (NSData *data in [peerService addresses])
            {
                memset(addressBuffer, 0, INET6_ADDRSTRLEN);
                typedef union {
                    struct sockaddr sa;
                    struct sockaddr_in ipv4;
                    struct sockaddr_in6 ipv6;
                } ip_socket_address;
                ip_socket_address *socketAddress = (ip_socket_address *)[data bytes];
                if (socketAddress && (socketAddress->sa.sa_family == AF_INET || socketAddress->sa.sa_family == AF_INET6))
                {
                    const char *addressStr = inet_ntop(
                                                       socketAddress->sa.sa_family,
                                                       (socketAddress->sa.sa_family == AF_INET ? (void *)&(socketAddress->ipv4.sin_addr) : (void *)&(socketAddress->ipv6.sin6_addr)),
                                                       addressBuffer,
                                                       sizeof(addressBuffer));
                    int port = ntohs(socketAddress->sa.sa_family == AF_INET ? socketAddress->ipv4.sin_port : socketAddress->ipv6.sin6_port);
                    if (addressStr && port)
                    {
                        if (socketAddress->sa.sa_family == AF_INET)
                        {
                            [cleanDic setObject:[NSString stringWithFormat:@"%s", addressStr] forKey:BonjourBuddyIPv4];
                        }
                        else
                        {
                            [cleanDic setObject:[NSString stringWithFormat:@"%s", addressStr] forKey:BonjourBuddyIPv6];
                        }
                    }
                }
            }
        }        
        
        NSString* peerId = [cleanDic objectForKey:self.myIdKey];
        if(self.includeSelfInPeers == NO){
            if([peerId isEqualToString:self.myId]){
                continue;
            }
        }
        
        [cleanDic setObject:peerService forKey:@"service"];
        
        [peers addObject:cleanDic];
    }
    return peers;
}


#pragma Announcing

- (void)netServiceDidPublish:(NSNetService *)ns
{
    NSLog(@"Bonjour Service Published: domain(%@) type(%@) name(%@) port(%i)", [ns domain], [ns type], [ns name], (int)[ns port]);
}

- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
	NSLog(@"Failed to Publish Service: domain(%@) type(%@) name(%@) - %@", [ns domain], [ns type], [ns name], errorDict);
}


#pragma Listening

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser
{
	NSLog(@"WillSearch");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender didNotSearch:(NSDictionary *)errorInfo
{
	NSLog(@"DidNotSearch: %@", errorInfo);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender
           didFindService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing
{
    NSLog(@"netService didFindService: %@", [netService name]);
    
    //we must retain netService or it doesn't resolve
    [peerServices addObject:netService];
    
    //must resolve since TXTRecordData isn't available til we resolve
    [netService setDelegate:self];
    [netService resolveWithTimeout:self.resolveTimeout];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender
         didRemoveService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing
{
	NSLog(@"DidRemoveService: %@", [netService name]);
    
    [netService stopMonitoring];
    
    [peerServices removeObject:netService];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BonjourBuddyPeersChangedNotification object:nil];
}

- (void) netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
	NSLog(@"didUpdateTXTRecordData: %@", data);
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BonjourBuddyPeersChangedNotification object:nil];
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)sender
{
	NSLog(@"DidStopSearch");
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
    [peerServices removeObject:sender];
    
	NSLog(@"DidNotResolve: %@", errorDict);
}

- (void) netServiceWillResolve:(NSNetService *)sender
{
    NSLog(@"willresolve");
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
	NSLog(@"DidResolve: %@", [sender addresses]);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BonjourBuddyPeersChangedNotification object:nil];
}


#pragma Helpers

+ (NSString*) generateUUID {
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (__bridge NSString*)string;
}


#pragma Singleton

static BonjourBuddy* _current = NULL;
+ (BonjourBuddy*) current
{
    @synchronized(self){
        if(_current == NULL){
            _current = [[BonjourBuddy alloc] init];
        }
    }
    return _current;
}


@end