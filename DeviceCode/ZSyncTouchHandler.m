//
//  ZSyncTouchHandler.m
//  SampleTouch
//
//  Created by Marcus S. Zarra on 11/11/09.
//  Copyright 2009 Zarra Studios, LLC. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.

#import "Reachability.h"
#import "ServerBrowser.h"
#import "ZSyncShared.h"
#import "ZSyncTouchHandler.h"

#define zsUUIDStringLength 55

#pragma mark -

@interface ZSyncTouchHandler ()

- (void)requestDeregistration;
- (void)uploadDataToServer;
- (void)startServerSearch;
- (NSString *)syncGUID;
- (NSString *)schemaID;

@property (nonatomic, assign) id delegate;
@property (nonatomic, retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end

#pragma mark -

@implementation ZSyncTouchHandler

#pragma mark -
#pragma mark Class methods

+ (id)shared;
{
  static ZSyncTouchHandler *sharedTouchHandler;
  if (sharedTouchHandler) {
    return sharedTouchHandler;
  }

  @synchronized(sharedTouchHandler)
  {
    sharedTouchHandler = [[ZSyncTouchHandler alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:sharedTouchHandler
                         selector:@selector(applicationWillTerminate:)
                           name:UIApplicationWillTerminateNotification
                           object:nil];
  }

  return sharedTouchHandler;
}

#pragma mark -
#pragma mark Public methods

- (void)registerDelegate:(id<ZSyncDelegate>)zsyncDelegate withPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [self setDelegate:zsyncDelegate];
  [self setPersistentStoreCoordinator:coordinator];
}

- (void)requestSync
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  ZAssert([self serverAction] == ZSyncServerActionNoActivity, @"Attempt to sync while another action is active");

  [self setServerAction:ZSyncServerActionSync];

  if ([self connection]) {
    [self uploadDataToServer];
  } else {
    [self startServerSearch];
  }
}

- (void)stopRequestingSync
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [[self serviceBrowser] setDelegate:nil];
  [[self serviceBrowser] stop];
  [self setServerAction:ZSyncServerActionNoActivity];
}

- (void)requestPairing:(ZSyncService *)server
{
  DLog(@"%s", __PRETTY_FUNCTION__);

  [self setServerAction:ZSyncServerActionSync];

  NSNetService *service = [server service];

  BLIPConnection *conn = [[BLIPConnection alloc] initToNetService:service];
  [conn setDelegate:self];
  [conn open];
  [self setConnection:conn];
  [conn release], conn = nil;
}

// - (void)authenticatePairing:(NSString *)pairingCode;
// {
//  DLog(@"%s", __PRETTY_FUNCTION__);
//  if (![self connection]) {
//    return;
//  }
//
//  // Start a pairing request
//  DLog(@"sending a pairing code");
//  NSString *schemaID = [[[NSBundle mainBundle] infoDictionary] objectForKey:zsSchemaIdentifier];
//
//  NSMutableDictionary *requestPropertiesDictionary = [NSMutableDictionary dictionary];
//  [requestPropertiesDictionary setValue:zsActID(zsActionAuthenticatePairing) forKey:zsAction];
//  [requestPropertiesDictionary setValue:[[UIDevice currentDevice] uniqueIdentifier] forKey:zsDeviceGUID];
//  [requestPropertiesDictionary setValue:schemaID forKey:zsSchemaIdentifier];
//
//  NSData *pairingCodeData = [pairingCode dataUsingEncoding:NSUTF8StringEncoding];
//
//  BLIPRequest *request = [BLIPRequest requestWithBody:pairingCodeData properties:requestPropertiesDictionary];
//  [[self connection] sendRequest:request];
// }

- (void)cancelPairing;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  if (![self connection]) {
    return;
  }

  DLog(@"sending a pairing cancel");
  NSMutableDictionary *requestPropertiesDictionary = [NSMutableDictionary dictionary];
  [requestPropertiesDictionary setValue:zsActID(zsActionCancelPairing) forKey:zsAction];
  [requestPropertiesDictionary setValue:[[UIDevice currentDevice] uniqueIdentifier] forKey:zsDeviceGUID];
  [requestPropertiesDictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];

  BLIPRequest *request = [BLIPRequest requestWithBody:nil properties:requestPropertiesDictionary];
  [[self connection] sendRequest:request];
}

- (void)disconnectPairing;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerName];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerUUID];

  if ([self connection]) {
    [[self connection] close];
    [self setConnection:nil];
  }

  [self setServerAction:ZSyncServerActionNoActivity];
}

- (void)deregister
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  DLog(@"deregister request received");

  if ([self serverAction] != ZSyncServerActionNoActivity) {
    if ([[self delegate] respondsToSelector:@selector(zSync:errorOccurred:)]) {
      NSString *errorString = [NSString stringWithFormat:@"Another activity in progress: %i", [self serverAction]];
      NSDictionary *dict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
      NSError *error = [NSError errorWithDomain:zsErrorDomain code:zsErrorAnotherActivityInProgress userInfo:dict];
      [[self delegate] zSync:self errorOccurred:error];
      return;
    }
  }

  if (![[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID]) {
    if ([[self delegate] respondsToSelector:@selector(zSync:errorOccurred:)]) {
      NSString *errorString = [NSString stringWithFormat:@"Client is not registered with a server", [self serverAction]];
      NSDictionary *dict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
      NSError *error = [NSError errorWithDomain:zsErrorDomain code:zsErrorNoSyncClientRegistered userInfo:dict];
      [[self delegate] zSync:self errorOccurred:error];
      return;
    }
  }

  [self setServerAction:ZSyncServerActionDeregister];
  if ([self connection]) {
    DLog(@"requesting deregister");
    [self requestDeregistration];
  } else {
    DLog(@"searching for server");
    [self startServerSearch];
  }
}

- (NSString *)serverName
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  return [[NSUserDefaults standardUserDefaults] valueForKey:zsServerName];
}

#pragma mark -
#pragma mark Notification and other callback methods

- (void)applicationWillTerminate:(NSNotification *)notification
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  DLog(@"closing connection");
  if ([self connection]) {
    [[self connection] close];
    [self setConnection:nil];
  }

  if ([self serviceBrowser]) {
    [[self serviceBrowser] setDelegate:nil];
    [[self serviceBrowser] stop];
    [self setServiceBrowser:nil];
  }
}

- (void)networkTimeout:(NSTimer *)timer
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  DLog(@"timeout on local network");

  if ([self serverAction] == ZSyncServerActionDeregister) {
    DLog(@"[self serverAction] == ZSyncServerActionDeregister");
    NSMutableArray *deregisteredServers = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:zsDeregisteredServersKey]];
    if (!deregisteredServers) {
      deregisteredServers = [[NSMutableArray alloc] init];
    }

    NSString *registeredServerUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
    if (registeredServerUUID) {
      [deregisteredServers addObject:registeredServerUUID];
      [[NSUserDefaults standardUserDefaults] setObject:deregisteredServers forKey:zsDeregisteredServersKey];
    }

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerUUID];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerName];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [deregisteredServers release], deregisteredServers = nil;

    networkTimer = nil;
    [self setServerAction:ZSyncServerActionNoActivity];
    if ([[self delegate] respondsToSelector:@selector(zSyncDeregisterComplete:)]) {
      [[self delegate] zSyncDeregisterComplete:self];
    }
    [[timer userInfo] stopNotifer];

    return;
  }

  networkTimer = nil;
  [self setServerAction:ZSyncServerActionNoActivity];
  if ([[self delegate] respondsToSelector:@selector(zSyncServerUnavailable:)]) {
    [[self delegate] zSyncServerUnavailable:self];
  }

  [[timer userInfo] stopNotifer];
}

- (void)reachabilityChanged:(NSNotification *)notification
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  Reachability *reachability = [notification object];
  if ([reachability currentReachabilityStatus] == NotReachable) {
    return;
  }

  DLog(@"local network now available");
  [reachability stopNotifer];
  [networkTimer invalidate], networkTimer = nil;
  NSString *serverUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
  if (serverUUID) {
    networkTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                            target:self
                            selector:@selector(networkTimeout:)
                            userInfo:nil
                             repeats:NO];
  }

  [[self serviceBrowser] start];
}

#pragma mark -
#pragma mark Local methods

- (NSString *)cachePath
{
  DLog(@"%s", __PRETTY_FUNCTION__);

  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  NSString *filePath = [paths objectAtIndex:0];

  return filePath;
}

- (void)startServerSearch
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  if ([self serviceBrowser]) {
    DLog(@"service browser is not nil");
    [[self serviceBrowser] setDelegate:nil];
    [[self serviceBrowser] stop];
    [self setServiceBrowser:nil];
  }

  Reachability *reachability = [Reachability reachabilityForLocalWiFi];
  if ([reachability currentReachabilityStatus] == NotReachable) {
    DLog(@"local network not available");
    // start notifying
    [[NSNotificationCenter defaultCenter] addObserver:self
                         selector:@selector(reachabilityChanged:)
                           name:kReachabilityChangedNotification
                           object:nil];

    [reachability startNotifer];
    networkTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                            target:self
                            selector:@selector(networkTimeout:)
                            userInfo:reachability
                             repeats:NO];

    return;
  } else {
    NSString *serverUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
    if (serverUUID) {
      networkTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                              target:self
                              selector:@selector(networkTimeout:)
                              userInfo:reachability
                               repeats:NO];
    }
    [[self serviceBrowser] start];
  }
}

- (void)beginSyncWithService:(NSNetService *)service
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  BLIPConnection *conn = [[BLIPConnection alloc] initToNetService:service];
  [self setConnection:conn];
  [conn setDelegate:self];
  [conn open];
  [conn release], conn = nil;
}

- (void)receiveFile:(BLIPRequest *)request
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  ZAssert([request complete], @"Message is incomplete");

  DLog(@"file received");

  NSString *tempFilename = [[NSProcessInfo processInfo] globallyUniqueString];
  NSString *tempPath = [[self cachePath] stringByAppendingPathComponent:tempFilename];
  DLog(@"file written to \n%@", tempPath);

  DLog(@"request length: %i", [[request body] length]);
  [[request body] writeToFile:tempPath atomically:YES];

  NSMutableDictionary *fileDict = [[NSMutableDictionary alloc] init];
  [fileDict setValue:[request valueOfProperty:zsStoreIdentifier] forKey:zsStoreIdentifier];
  if (![[request valueOfProperty:zsStoreConfiguration] isEqualToString:@"PF_DEFAULT_CONFIGURATION_NAME"]) {
    [fileDict setValue:[request valueOfProperty:zsStoreConfiguration] forKey:zsStoreConfiguration];
  }
  [fileDict setValue:[request valueOfProperty:zsStoreType] forKey:zsStoreType];
  [fileDict setValue:tempPath forKey:zsTempFilePath];

  [[self receivedFileLookupDictionary] setValue:fileDict forKey:[request valueOfProperty:zsStoreIdentifier]];
  [fileDict release], fileDict = nil;

  BLIPResponse *response = [request response];
  [response setValue:zsActID(zsActionFileReceived) ofProperty:zsAction];
  [response setValue:[request valueOfProperty:zsStoreIdentifier] ofProperty:zsStoreIdentifier];
  [response send];
}

- (BOOL)switchStore:(NSPersistentStore *)persistentStore withReplacement:(NSDictionary *)replacement error:(NSError **)error
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSDictionary *storeOptions = [[[persistentStore options] copy] autorelease];
  NSFileManager *fileManager = [NSFileManager defaultManager];
//  NSPersistentStoreCoordinator *psc = [self persistentStoreCoordinator];

  NSString *newFileTempPath = [replacement valueForKey:zsTempFilePath];
  NSString *originalFilePath = [[persistentStore URL] path];
  NSString *originalFileTempPath = [originalFilePath stringByAppendingPathExtension:@"zsync_"];

  if (![[self persistentStoreCoordinator] removePersistentStore:persistentStore error:error]) {
    return NO;
  }

  if ([fileManager fileExistsAtPath:originalFileTempPath]) {
    DLog(@"deleting stored file");
    if (![fileManager removeItemAtPath:originalFileTempPath error:error]) {
      return NO;
    }
  }

  if ([fileManager fileExistsAtPath:originalFilePath]) {
    if (![fileManager moveItemAtPath:originalFilePath toPath:originalFileTempPath error:error]) {
      return NO;
    }
  }

  if (![fileManager moveItemAtPath:newFileTempPath toPath:originalFilePath error:error]) {
    return NO;
  }

  NSURL *fileURL = [NSURL fileURLWithPath:originalFilePath];
  if (![[self persistentStoreCoordinator] addPersistentStoreWithType:[replacement valueForKey:zsStoreType] configuration:[replacement valueForKey:zsStoreConfiguration] URL:fileURL options:storeOptions error:error]) {
    return NO;
  }

  DLog(@"store switched");
  return YES;
}

- (void)completeSync
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [[self persistentStoreCoordinator] lock];

  // First we need to verify that we received every file.  Otherwise we fail
  for (NSPersistentStore *store in [[self persistentStoreCoordinator] persistentStores]) {
    if ([[self receivedFileLookupDictionary] objectForKey:[store identifier]]) {
      continue;
    }

    DLog(@"Store ID: %@\n%@", [store identifier], [[self receivedFileLookupDictionary] allKeys]);
    // Fail
    if ([[self delegate] respondsToSelector:@selector(zSync:errorOccurred:)]) {
      // Flush the temp files
      for (NSDictionary *fileDict in [[self receivedFileLookupDictionary] allValues]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:[fileDict valueForKey:zsTempFilePath] error:&error];

        // We want to explode on this failure in dev but in prod just note it
        ZAssert(error == nil, @"Error deleting temp file: %@", [error localizedDescription]);
      }
      NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[store identifier] forKey:zsStoreIdentifier];
      NSError *error = [NSError errorWithDomain:zsErrorDomain code:zsErrorFailedToReceiveAllFiles userInfo:userInfo];
      [[self delegate] zSync:self errorOccurred:error];
      [self setReceivedFileLookupDictionary:nil];
    }
    [[self persistentStoreCoordinator] unlock];
    return;
  }

  // We have all of the files now we need to swap them out.
  for (NSPersistentStore *persistentStore in [[self persistentStoreCoordinator] persistentStores]) {
    NSDictionary *replacement = [[self receivedFileLookupDictionary] valueForKey:[persistentStore identifier]];

    ZAssert(replacement != nil, @"Missing the replacement file for %@\n%@", [persistentStore identifier], [[self receivedFileLookupDictionary] allKeys]);

    NSError *error = nil;
    if ([self switchStore:persistentStore withReplacement:replacement error:&error]) {
      continue;
    }

    ZAssert(error == nil, @"Error switching stores: %@\n%@", [error localizedDescription], [error userInfo]);

    // TODO: We failed in the migration and need to roll back
  }

  [self setReceivedFileLookupDictionary:nil];

  [[self connection] close];
  [self setConnection:nil];

  if ([[self delegate] respondsToSelector:@selector(zSyncFinished:)]) {
    [[self delegate] zSyncFinished:self];
  }

  [[self persistentStoreCoordinator] unlock];

  [self setServerAction:ZSyncServerActionNoActivity];
}

/*
 * We want to start looking for desktops to sync with here.  Once started
 * We want to maintain a list of computers found and also send out a notification
 * for every server that we discover
 */
- (void)startBrowser;
{
  DLog(@"%s", __PRETTY_FUNCTION__);

  [[self serviceBrowser] start];
}

- (void)sendUploadComplete
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  DLog(@"sending upload complete");

  NSMutableDictionary *requestPropertiesDictionary = [[NSMutableDictionary alloc] init];
  [requestPropertiesDictionary setValue:zsActID(zsActionPerformSync) forKey:zsAction];
  [requestPropertiesDictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];

  BLIPRequest *request = [BLIPRequest requestWithBody:nil properties:requestPropertiesDictionary];
  [request setNoReply:YES];
  [[self connection] sendRequest:request];

  [requestPropertiesDictionary release], requestPropertiesDictionary = nil;
}

- (void)uploadDataToServer
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [[self serviceBrowser] setDelegate:nil];
  [[self serviceBrowser] stop];
  [self setServiceBrowser:nil];

  [[self delegate] zSyncStarted:self];

  NSAssert([self persistentStoreCoordinator] != nil, @"The persistent store coordinator was nil. Make sure you are calling registerDelegate:withPersistentStoreCoordinator: before trying to sync.");

  for (NSPersistentStore *persistentStore in [[self persistentStoreCoordinator] persistentStores]) {
    NSData *persistentStoreData = [[NSData alloc] initWithContentsOfMappedFile:[[persistentStore URL] path]];
    DLog(@"url %@\nIdentifier: %@\nSize: %i", [persistentStore URL], [persistentStore identifier], [persistentStoreData length]);

    NSMutableDictionary *requestPropertiesDictionary = [[NSMutableDictionary alloc] init];
    [requestPropertiesDictionary setValue:zsActID([self majorVersionNumber]) forKey:zsSchemaMajorVersion];
    [requestPropertiesDictionary setValue:zsActID([self minorVersionNumber]) forKey:zsSchemaMinorVersion];
    [requestPropertiesDictionary setValue:[[UIDevice currentDevice] name] forKey:zsDeviceName];
    [requestPropertiesDictionary setValue:[[UIDevice currentDevice] uniqueIdentifier] forKey:zsDeviceGUID];
    [requestPropertiesDictionary setValue:[persistentStore identifier] forKey:zsStoreIdentifier];
    [requestPropertiesDictionary setValue:[self syncGUID] forKey:zsSyncGUID];
    [requestPropertiesDictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];
    if (![[persistentStore configurationName] isEqualToString:@"PF_DEFAULT_CONFIGURATION_NAME"]) {
      [requestPropertiesDictionary setValue:[persistentStore configurationName] forKey:zsStoreConfiguration];
    }
    [requestPropertiesDictionary setValue:[persistentStore type] forKey:zsStoreType];
    [requestPropertiesDictionary setValue:zsActID(zsActionStoreUpload) forKey:zsAction];

    BLIPRequest *request = [BLIPRequest requestWithBody:persistentStoreData properties:requestPropertiesDictionary];
    // TODO: Compression is not working.  Need to find out why
    [request setCompressed:YES];
    [[self connection] sendRequest:request];

    [persistentStoreData release], persistentStoreData = nil;
    [requestPropertiesDictionary release], requestPropertiesDictionary = nil;
    DLog(@"file uploaded");

    [[self storeFileIdentifiers] addObject:[persistentStore identifier]];
  }
  DLog(@"finished");
}

- (NSString *)generatePairingCode
{
  DLog(@"%s", __PRETTY_FUNCTION__);

  NSMutableString *string = [NSMutableString string];
  [string appendFormat:@"%i", (arc4random() % 10)];
  [string appendFormat:@"%i", (arc4random() % 10)];
  [string appendFormat:@"%i", (arc4random() % 10)];
  [string appendFormat:@"%i", (arc4random() % 10)];

  return string;
}

- (void)requestDeregistration;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  DLog(@"issuing deregister command");

  NSMutableDictionary *requestPropertiesDictionary = [NSMutableDictionary dictionary];
  [requestPropertiesDictionary setValue:zsActID(zsActionDeregisterClient) forKey:zsAction];
  [requestPropertiesDictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];

  NSData *body = [[self syncGUID] dataUsingEncoding:NSUTF8StringEncoding];

  BLIPRequest *request = [BLIPRequest requestWithBody:body properties:requestPropertiesDictionary];
  [[self connection] sendRequest:request];
}

- (void)requestLatentDeregistration
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  [dictionary setValue:zsActID(zsActionLatentDeregisterClient) forKey:zsAction];
  [dictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];

  NSData *body = [[self syncGUID] dataUsingEncoding:NSUTF8StringEncoding];

  BLIPRequest *request = [BLIPRequest requestWithBody:body properties:dictionary];
  [[self connection] sendRequest:request];
}

- (void)connectionEstablished
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  switch ([self serverAction]) {
    case ZSyncServerActionLatentDeregistration:
      [self requestLatentDeregistration];
      break;
    case ZSyncServerActionSync:
      if ([[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID]) {
        // Start a sync by pushing the data file to the server
        [self uploadDataToServer];
      } else {
        // We are not paired so we need to request a pairing session
        [self setPasscode:[self generatePairingCode]];

        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setValue:zsActID(zsActionRequestPairing) forKey:zsAction];
        [dict setValue:zsActID([self majorVersionNumber]) forKey:zsSchemaMajorVersion];
        [dict setValue:zsActID([self minorVersionNumber]) forKey:zsSchemaMinorVersion];
        [dict setValue:[[UIDevice currentDevice] name] forKey:zsDeviceName];
        [dict setValue:[[UIDevice currentDevice] uniqueIdentifier] forKey:zsDeviceGUID];
        [dict setValue:[self schemaID] forKey:zsSchemaIdentifier];

        NSData *data = [[self passcode] dataUsingEncoding:NSUTF8StringEncoding];
        BLIPRequest *request = [[self connection] requestWithBody:data properties:dict];
        [request send];

        [dict release], dict = nil;

        [[self delegate] zSyncHandler:self displayPairingCode:[self passcode]];
      }
      break;
    case ZSyncServerActionDeregister:
      [self requestDeregistration];
      break;
    default:
      ALog(@"Unknown server action: %i", serverAction);
  }
}

- (NSString *)syncGUID
{
  NSString *syncGUID = [[NSUserDefaults standardUserDefaults] stringForKey:zsSyncGUID];

  if (!syncGUID) {
    syncGUID = [[NSProcessInfo processInfo] globallyUniqueString];
    [[NSUserDefaults standardUserDefaults] setValue:syncGUID forKey:zsSyncGUID];
  }

  return syncGUID;
}

- (NSString *)schemaID
{
  return [[[NSBundle mainBundle] infoDictionary] objectForKey:zsSchemaIdentifier];
}

#pragma mark -
#pragma mark Overridden getters/setter

- (ServerBrowser *)serviceBrowser
{
  if (!_serviceBrowser) {
    _serviceBrowser = [[ServerBrowser alloc] init];
    _serviceBrowser.delegate = self;
  }

  return _serviceBrowser;
}

- (NSMutableArray *)availableServers
{
  if (!availableServers) {
    availableServers = [[NSMutableArray alloc] init];
  }

  return availableServers;
}

- (NSMutableArray *)discoveredServers
{
  if (!discoveredServers) {
    discoveredServers = [[NSMutableArray alloc] init];
  }

  return discoveredServers;
}

- (NSObject *)lock
{
  if (!lock) {
    lock = [[NSObject alloc] init];
  }

  return lock;
}

- (NSMutableDictionary *)receivedFileLookupDictionary
{
  if (!receivedFileLookupDictionary) {
    receivedFileLookupDictionary = [[NSMutableDictionary alloc] init];
  }

  return receivedFileLookupDictionary;
}

- (NSMutableArray *)storeFileIdentifiers
{
  if (!storeFileIdentifiers) {
    storeFileIdentifiers = [[NSMutableArray alloc] init];
  }

  return storeFileIdentifiers;
}

- (void)setConnection:(BLIPConnection *)conn
{
  if ([conn isEqual:[self connection]]) {
    return;
  }

  if ([self connection]) {
    [[self connection] close];
    [[self connection] setDelegate:nil];
  }

  BLIPConnection *tmp = [conn retain];
  [_connection release], _connection = nil;
  _connection = tmp;
}

#pragma mark -
#pragma mark ServerBrowserDelegate methods

- (void)updateServerList
{
  [lock lock];
  DLog(@"%s", __PRETTY_FUNCTION__);
  [networkTimer invalidate], networkTimer = nil;

  for (NSNetService *service in [self discoveredServers]) {
    [service setDelegate:nil];
    [service stop];
  }

  [[self discoveredServers] removeAllObjects];
  [[self availableServers] removeAllObjects];

  [[self discoveredServers] addObjectsFromArray:[[self serviceBrowser] servers]];
  for (NSNetService *service in [self discoveredServers]) {
    [service setDelegate:self];
    [service resolveWithTimeout:15.0];
  }

  if ([[self discoveredServers] count] == 0) {
    NSString *serverUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
    if (!serverUUID) {
      [[self delegate] zSyncNoServerPaired:[self availableServers]];
    }
  } else {
    NSString *serverUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
    if (serverUUID) {
      networkTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                              target:self
                              selector:@selector(networkTimeout:)
                              userInfo:nil
                               repeats:NO];
    }
  }

  [lock unlock];
}

#pragma mark -
#pragma mark NSNetServiceDelegate methods

/* Sent to the NSNetService instance's delegate prior to resolving a service on the network. If for some reason the resolution cannot occur, the delegate will not receive this message, and an error will be delivered to the delegate via the delegate's -netService:didNotResolve: method.
 */
- (void)netServiceWillResolve:(NSNetService *)bonjourService {}

/* Sent to the NSNetService instance's delegate when one or more addresses have been resolved for an NSNetService instance. Some NSNetService methods will return different results before and after a successful resolution. An NSNetService instance may get resolved more than once; truly robust clients may wish to resolve again after an error, or to resolve more than once.
 */
- (void)netServiceDidResolveAddress:(NSNetService *)bonjourService
{
  DLog(@"%s", __PRETTY_FUNCTION__);

  NSString *incomingServerName = [bonjourService name];

  NSDictionary *txtRecordDictionary = [NSNetService dictionaryFromTXTRecordData:[bonjourService TXTRecordData]];
  if (!txtRecordDictionary) {
    DLog(@"The NSNetService named %@ did not contain a TXT record", incomingServerName);
    return;
  }
  
  NSData *incomingServerUUIDData = [txtRecordDictionary objectForKey:zsServerUUID];
  if (!incomingServerUUIDData) {
    DLog(@"The TXT record did not contain a server UUID.");
    return;
  }
  
  NSString *incomingServerUUID = [[NSString alloc] initWithData:incomingServerUUIDData encoding:NSUTF8StringEncoding];
  if (!incomingServerUUID || [incomingServerUUID length] == 0) {
    DLog(@"The TXT record UUID was zero length.");
    [incomingServerUUID release], incomingServerUUID = nil;
    return;
  }
  
  NSString *registeredServerUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
  NSString *registeredServerName = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerName];

  if (!registeredServerUUID) { // See if the server is in the deregistered list
    NSArray *deregisteredServers = [[NSUserDefaults standardUserDefaults] objectForKey:zsDeregisteredServersKey];
    if (deregisteredServers && [deregisteredServers containsObject:incomingServerUUID]) {
      [self setServerAction:ZSyncServerActionLatentDeregistration];
      BLIPConnection *conn = [[BLIPConnection alloc] initToNetService:bonjourService];
      [self setConnection:conn];
      [conn setDelegate:self];
      [conn open];
      [conn release], conn = nil;
    }

    ZSyncService *zSyncService = [[ZSyncService alloc] init];
    [zSyncService setService:bonjourService];
    [zSyncService setName:incomingServerName];
    [zSyncService setUuid:incomingServerUUID];
    [[self availableServers] addObject:zSyncService];
    [zSyncService release], zSyncService = nil;

    [[self delegate] zSyncNoServerPaired:[self availableServers]];

    [incomingServerUUID release], incomingServerUUID = nil;

    return;
  }

  if (![incomingServerUUID isEqualToString:registeredServerUUID]) {
    NSData *incomingServerNameData = [txtRecordDictionary objectForKey:zsServerName];
    if (!incomingServerNameData) {
      DLog(@"TXT record did not contain server name data");
      [incomingServerUUID release], incomingServerUUID = nil;
      return;
    }

    NSString *incomingServerName = [[NSString alloc] initWithData:incomingServerNameData encoding:NSUTF8StringEncoding];
    if (![incomingServerName isEqualToString:registeredServerName]) {
      DLog(@"Incoming server name did not match registered server name, %@ != %@", incomingServerName, registeredServerName);
      [incomingServerUUID release], incomingServerUUID = nil;
      [incomingServerName release], incomingServerName = nil;
      return;
    }

    if ([incomingServerUUID hasPrefix:registeredServerUUID]) {
      DLog(@"Found an instance of an old UUID that we will upgrade");
      [[NSUserDefaults standardUserDefaults] setValue:incomingServerUUID forKey:zsServerUUID];
      [incomingServerUUID release], incomingServerUUID = nil;
      [incomingServerName release], incomingServerName = nil;
    } else {
      DLog(@"Incoming server UUID did not have a prefix of the registered server UUID, %@ does not start with %@", incomingServerUUID, registeredServerUUID);
      [incomingServerUUID release], incomingServerUUID = nil;
      [incomingServerName release], incomingServerName = nil;

      return;
    }
  }

  [networkTimer invalidate], networkTimer = nil;
  DLog(@"our server found");
  // Found our server, stop looking and start the sync
  [[self serviceBrowser] setDelegate:nil];
  [[self serviceBrowser] stop];

  [self beginSyncWithService:bonjourService];
  
  return;
}

/* Sent to the NSNetService instance's delegate when an error in resolving the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants).
 */
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
  [lock lock];

  DLog(@"%s", __PRETTY_FUNCTION__);
  [[self discoveredServers] removeObject:sender];

  // Did not find our registered server.  Fail
  if ([[self discoveredServers] count] == 0) {
    [[self delegate] zSyncServerUnavailable:self];
    [self setServerAction:ZSyncServerActionNoActivity];
  }

  [lock unlock];
}

/* Sent to the NSNetService instance's delegate when the instance's previously running publication or resolution request has stopped.
 */
- (void)netServiceDidStop:(NSNetService *)sender {}

/* Sent to the NSNetService instance's delegate when the instance is being monitored and the instance's TXT record has been updated. The new record is contained in the data parameter.
 */
- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data {}

#pragma mark -
#pragma mark BLIPConnectionDelegate methods

/* Three possible states at this point: If we have a server UUID
 * then we are ready to start a sync.  If we do not have a server UUID
 * then we need to start a pairing. If we do not have a server UUID but
 * we have a previously deregistered server UUID then we need to tell
 * that server it's been deregistered.
 */
- (void)connectionDidOpen:(BLIPConnection *)conn
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  DLog(@"%s entered", __PRETTY_FUNCTION__);

  // Start by confirming that the server still supports our schema and version
  NSMutableDictionary *requestPropertiesDictionary = [[NSMutableDictionary alloc] init];
  [requestPropertiesDictionary setValue:zsActID(zsActionVerifySchema) forKey:zsAction];
  [requestPropertiesDictionary setValue:zsActID([self majorVersionNumber]) forKey:zsSchemaMajorVersion];
  [requestPropertiesDictionary setValue:zsActID([self minorVersionNumber]) forKey:zsSchemaMinorVersion];
  [requestPropertiesDictionary setValue:[[UIDevice currentDevice] name] forKey:zsDeviceName];
  [requestPropertiesDictionary setValue:[[UIDevice currentDevice] uniqueIdentifier] forKey:zsDeviceGUID];
  [requestPropertiesDictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];

  NSData *syncGUIDData = [[self syncGUID] dataUsingEncoding:NSUTF8StringEncoding];
  BLIPRequest *request = [conn requestWithBody:syncGUIDData properties:requestPropertiesDictionary];
  [request send];

  [requestPropertiesDictionary release], requestPropertiesDictionary = nil;
  DLog(@"%s initial send complete", __PRETTY_FUNCTION__);
}

/* We had an error talking to the server.  Push this error on to our delegate
 * and close the connection
 */
- (void)connection:(TCPConnection *)conn failedToOpen:(NSError *)error
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  [[self connection] close];
  [self setConnection:nil];
  [[self delegate] zSync:self errorOccurred:error];
}

- (void)connection:(BLIPConnection *)conn receivedResponse:(BLIPResponse *)response;
{
  if (![[response properties] valueOfProperty:zsAction]) {
    DLog(@"%s received empty response, ignoring", __PRETTY_FUNCTION__);
    return;
  }

  DLog(@"%s entered\n%@", __PRETTY_FUNCTION__, [[response properties] allProperties]);
  NSInteger action = [[[response properties] valueOfProperty:zsAction] integerValue];
  switch (action) {
    case zsActionLatentDeregisterClient:
      DLog(@"%s zsActionLatentDeregisterClient", __PRETTY_FUNCTION__);

      NSString *registeredServerUUID = [response valueOfProperty:zsServerUUID];
      DLog(@"%s registeredServerUUID %@", __PRETTY_FUNCTION__, registeredServerUUID);
      // TODO: Compare version numbers
      ZAssert(registeredServerUUID != nil, @"Body string is nil in request\n%@", [[response properties] allProperties]);

      NSMutableArray *deregisteredServers = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:zsDeregisteredServersKey]];
      if (!deregisteredServers) {
        return; // Shouldn't really happen...
      }

      if (registeredServerUUID) {
        [deregisteredServers removeObject:registeredServerUUID];
        [[NSUserDefaults standardUserDefaults] setObject:deregisteredServers forKey:zsDeregisteredServersKey];
      }

      [[NSUserDefaults standardUserDefaults] synchronize];

      [deregisteredServers release], deregisteredServers = nil;

      [self setServerAction:ZSyncServerActionNoActivity];
      [[self connection] close];
      [self setConnection:nil];

      return;

    case zsActionDeregisterClient:
      DLog(@"%s zsActionDeregisterClient", __PRETTY_FUNCTION__);
      if ([[self delegate] respondsToSelector:@selector(zSyncDeregisterComplete:)]) {
        [[self delegate] zSyncDeregisterComplete:self];
      }

      [self setServerAction:ZSyncServerActionNoActivity];
      [[self connection] close];
      [self setConnection:nil];

      return;

    case zsActionFileReceived:
      DLog(@"%s zsActionFileReceived", __PRETTY_FUNCTION__);
      ZAssert([self storeFileIdentifiers] != nil, @"zsActionFileReceived with a nil storeFileIdentifiers");
      [[self storeFileIdentifiers] removeObject:[[response properties] valueOfProperty:zsStoreIdentifier]];
      if ([[self storeFileIdentifiers] count] == 0) {
        [self sendUploadComplete];
        [self setStoreFileIdentifiers:nil];
      }
      return;

//    case zsActionAuthenticatePassed:
//      DLog(@"%s zsActionAuthenticatePassed", __PRETTY_FUNCTION__);
//      ALog(@"%s server UUID accepted: %@", [response valueOfProperty:zsServerUUID]);
//      return;
//
    case zsActionSchemaUnsupported:
      DLog(@"%s zsActionSchemaUnsupported", __PRETTY_FUNCTION__);
      if ([[self delegate] respondsToSelector:@selector(zSync:serverVersionUnsupported:)]) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[response bodyString] forKey:NSLocalizedDescriptionKey];
        NSError *error = [NSError errorWithDomain:zsErrorDomain code:[[response valueOfProperty:zsErrorCode] integerValue] userInfo:userInfo];

        [[self delegate] zSync:self serverVersionUnsupported:error];
      }
      [[self connection] close];
      [self setConnection:nil];
      [self setServerAction:ZSyncServerActionNoActivity];
      return;

    case zsActionSchemaSupported:
      DLog(@"%s zsActionSchemaSupported", __PRETTY_FUNCTION__);
      [self connectionEstablished];
      return;

    default:
      DLog(@"%s default", __PRETTY_FUNCTION__);
      ALog(@"%s unknown action received %i", action);
  }
}

- (BOOL)connection:(BLIPConnection *)conn receivedRequest:(BLIPRequest *)request
{
  NSInteger action = [[[request properties] valueOfProperty:zsAction] integerValue];
  switch (action) {
    case zsActionAuthenticateFailed:
      DLog(@"%s zsActionAuthenticateFailed", __PRETTY_FUNCTION__);
      /*
       * The pairing code was not entered correctly so we reset back to a default state
       * so that the user can start all over again.
       */
      [[self connection] close];
      [self setConnection:nil];
      if ([[self delegate] respondsToSelector:@selector(zSyncPairingCodeRejected:)]) {
        [[self delegate] zSyncPairingCodeRejected:self];
      }
      [self setServerAction:ZSyncServerActionNoActivity];
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerUUID];
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerName];
      return YES;

    case zsActionAuthenticatePairing:
      DLog(@"%s zsActionAuthenticatePairing", __PRETTY_FUNCTION__);
      if ([[request bodyString] isEqualToString:[self passcode]]) {
        [[request response] setValue:zsActID(zsActionAuthenticatePassed) ofProperty:zsAction];
        [[NSUserDefaults standardUserDefaults] setValue:[request valueOfProperty:zsServerUUID] forKey:zsServerUUID];
        [self performSelector:@selector(uploadDataToServer) withObject:nil afterDelay:0.1];
      } else {
        [[request response] setValue:zsActID(zsActionAuthenticateFailed) ofProperty:zsAction];
      }
      [[self delegate] zSyncPairingCodeCompleted:self];
      return YES;

    case zsActionCompleteSync:
      DLog(@"%s zsActionCompleteSync", __PRETTY_FUNCTION__);
      [self performSelector:@selector(completeSync) withObject:nil afterDelay:0.01];
      return YES;

    case zsActionStoreUpload:
      DLog(@"%s zsActionStoreUpload", __PRETTY_FUNCTION__);
      [self receiveFile:request];
      return YES;

    case zsActionCancelPairing:
      DLog(@"%s zsActionCancelPairing", __PRETTY_FUNCTION__);
      [[self connection] close];
      [self setConnection:nil];
      if ([[self delegate] respondsToSelector:@selector(zSyncPairingCodeCancelled:)]) {
        [[self delegate] zSyncPairingCodeCancelled:self];
      }
      [self setServerAction:ZSyncServerActionNoActivity];
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerUUID];
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerName];
      return YES;

    default:
      DLog(@"%s default", __PRETTY_FUNCTION__);
      ALog(@"Unknown action received: %i", action);
      return NO;
  }
}

- (void)connectionDidClose:(TCPConnection *)conn;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  if (![self connection]) {
    return;
  }

  // premature closing
  [self setConnection:nil];
  [self setServerAction:ZSyncServerActionNoActivity];

  if (![[self delegate] respondsToSelector:@selector(zSync:errorOccurred:)]) {
    return;
  }

  NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Server Hung Up", @"Server Hung Up message text") forKey:NSLocalizedDescriptionKey];
  NSError *error = [NSError errorWithDomain:zsErrorDomain code:zsErrorServerHungUp userInfo:userInfo];
  [[self delegate] zSync:self errorOccurred:error];
}

#pragma mark -
#pragma mark Memory management and property declarations

@synthesize delegate = _delegate;

@synthesize serviceBrowser = _serviceBrowser;
@synthesize connection = _connection;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

@synthesize majorVersionNumber;
@synthesize minorVersionNumber;
@synthesize passcode;
@synthesize serverAction;
@synthesize availableServers;
@synthesize discoveredServers;
@synthesize lock;
@synthesize storeFileIdentifiers;
@synthesize receivedFileLookupDictionary;

@end

#pragma mark -

@implementation ZSyncService

@synthesize name;
@synthesize uuid;
@synthesize service;

- (NSString *)description
{
  return [NSString stringWithFormat:@"[%@:%@]", [self name], [self uuid]];
}

- (NSUInteger)hash
{
  return [[self description] hash];
}

- (BOOL)isEqual:(id)object
{
  if (!object || ![object isKindOfClass:[ZSyncService class]]) {
    return NO;
  }

  if (![[object name] isEqualToString:[self name]]) {
    return NO;
  }

  if (![[object uuid] isEqualToString:[self uuid]]) {
    return NO;
  }

  return YES;
}

@end