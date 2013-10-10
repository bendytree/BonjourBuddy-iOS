//
//  BonjourBuddy.m
//
//

#import "BonjourBuddy.h"


#define dBonjourBuddyDebug                          NO


@implementation BonjourBuddy {
    
    NSNetService* announcingService;
    NSNetServiceBrowser* listeningService;
    NSMutableArray* peerServices;
    NSDictionary* meCached;
    
}

@synthesize myId, myIdKey, includeSelfInPeers, netServiceType, netServiceDomain, netServicePort, netServiceName;

- (void)setupInit {
    peerServices = [NSMutableArray array];
    
    self.myIdKey = @"__id";
    self.resolveTimeout = 60;
    self.netServiceDomain = @"local.";
    self.includeSelfInPeers = NO;
    self.myId = [BonjourBuddy generateUUID];
    self.me = [NSDictionary dictionary];
    self.netServicePort = 53484;
    self.netServiceName = @"";
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setupInit];
        
        NSString* appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        NSCharacterSet* charactersToRemove = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
        NSString* cleanAppName = [[appName componentsSeparatedByCharactersInSet:charactersToRemove] componentsJoinedByString:@""];
        self.netServiceType = [NSString stringWithFormat:@"_%@._tcp.", cleanAppName];
        
        // restart from background
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(start) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

- (id)initWithServiceId:(NSString *)serviceId
{
    self = [super init];
    if (self) {
        [self setupInit];
        
        self.netServiceType = serviceId;
        
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
    if (dBonjourBuddyDebug) NSLog(@"Starting bonjour buddy...");
    
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
    if (dBonjourBuddyDebug) NSLog(@"Bonjour Service Published: domain(%@) type(%@) name(%@) port(%i)", [ns domain], [ns type], [ns name], (int)[ns port]);
}

- (void)netService:(NSNetService *)ns didNotPublish:(NSDictionary *)errorDict
{
	if (dBonjourBuddyDebug) NSLog(@"Failed to Publish Service: domain(%@) type(%@) name(%@) - %@", [ns domain], [ns type], [ns name], errorDict);
}


#pragma Listening

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser
{
	if (dBonjourBuddyDebug) NSLog(@"WillSearch");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender didNotSearch:(NSDictionary *)errorInfo
{
	if (dBonjourBuddyDebug) NSLog(@"DidNotSearch: %@", errorInfo);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)sender
           didFindService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing
{
    if (dBonjourBuddyDebug) NSLog(@"netService didFindService: %@", [netService name]);
    
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
	if (dBonjourBuddyDebug) NSLog(@"DidRemoveService: %@", [netService name]);
    
    [netService stopMonitoring];
    
    [peerServices removeObject:netService];
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BonjourBuddyPeersChangedNotification object:nil];
}

- (void) netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
	if (dBonjourBuddyDebug) NSLog(@"didUpdateTXTRecordData: %@", data);
    
	[[NSNotificationCenter defaultCenter] postNotificationName:BonjourBuddyPeersChangedNotification object:nil];
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)sender
{
	if (dBonjourBuddyDebug) NSLog(@"DidStopSearch");
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
    [peerServices removeObject:sender];
    
	if (dBonjourBuddyDebug) NSLog(@"DidNotResolve: %@", errorDict);
}

- (void) netServiceWillResolve:(NSNetService *)sender
{
    if (dBonjourBuddyDebug) NSLog(@"willresolve");
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
	if (dBonjourBuddyDebug) NSLog(@"DidResolve: %@", [sender addresses]);
    
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
