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

- (void)beginSyncWithService:(NSNetService *)service;
- (void)beginDeregistrationWithService:(NSNetService *)service;
- (void)beginLatentDeregistrationWithService:(NSNetService *)service;
- (void)requestDeregistrationUsingConnection:(BLIPConnection *)conn;
- (void)requestLatentDeregistrationUsingConnection:(BLIPConnection *)conn;
- (void)uploadDataToServerUsingConnection:(BLIPConnection *)conn;
- (void)sendPairingRequestToServerUsingConnection:(BLIPConnection *)conn;
- (void)completeSyncFromConnection:(BLIPConnection *)conn;
- (void)startServerSearch;
- (void)handleServerActionWithService:(NSNetService *)service;
- (NSString *)generatePairingCode;
- (NSString *)syncGUID;
- (NSString *)schemaID;
- (void)processLatentDeregisterResponse:(BLIPResponse *)response fromConnection:(BLIPConnection *)conn;
- (void)processDeregisterResponse:(BLIPResponse *)response fromConnection:(BLIPConnection *)conn;
- (void)processFileReceivedResponse:(BLIPResponse *)response fromConnection:(BLIPConnection *)conn;
- (void)processSchemaUnsupportedResponse:(BLIPResponse *)response fromConnection:(BLIPConnection *)conn;
- (void)processSchemaSupportedResponse:(BLIPResponse *)response fromConnection:(BLIPConnection *)conn;
- (void)processAuthenticationFailedRequest:(BLIPRequest *)request fromConnection:(BLIPConnection *)conn;
- (void)processAuthenticatePairingRequest:(BLIPRequest *)request fromConnection:(BLIPConnection *)conn;
- (void)processCompleteSyncRequest:(BLIPRequest *)request fromConnection:(BLIPConnection *)conn;
- (void)processStoreUploadRequest:(BLIPRequest *)request fromConnection:(BLIPConnection *)conn;
- (void)processCancelPairingRequest:(BLIPRequest *)request fromConnection:(BLIPConnection *)conn;

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

    // Initialize our lock objects
    [sharedTouchHandler lock];
    [sharedTouchHandler serviceResolutionLock];
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
  if ([self serverAction] != ZSyncServerActionNoActivity) {
    if ([[self delegate] respondsToSelector:@selector(zSync:errorOccurred:)]) {
      NSString *errorString = [NSString stringWithFormat:@"Another activity in progress: %i", [self serverAction]];
      NSDictionary *dict = [NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey];
      NSError *error = [NSError errorWithDomain:zsErrorDomain code:zsErrorAnotherActivityInProgress userInfo:dict];
      [[self delegate] zSync:self errorOccurred:error];
      return;
    }
  }

  [self setServerAction:ZSyncServerActionSync];
  [self startServerSearch];
}

- (void)stopRequestingSync
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [[self serviceBrowser] setDelegate:nil];
  [[self serviceBrowser] stop];
  [[self resolvedServices] removeAllObjects];
  [self setRegisteredService:nil];
  [self setServerAction:ZSyncServerActionNoActivity];
}

- (void)requestPairing:(ZSyncService *)server
{
  DLog(@"%s", __PRETTY_FUNCTION__);

  [self setServerAction:ZSyncServerActionSync];

  NSNetService *service = [server service];

  BLIPConnection *conn = [[BLIPConnection alloc] initToNetService:service];
  [[self openConnections] addObject:conn];
  //  [self setConnection:conn];
  [conn setDelegate:self];
  [conn open];
  [conn release], conn = nil;
}

- (void)cancelPairing;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  if ([[self openConnections] count] == 0) {
//    if (![self connection]) {
    return;
  }

  BLIPConnection *openConnection = nil;
  for (BLIPConnection *conn in [self openConnections]) {
    if ([conn status] == kTCP_Open) {
      openConnection = conn;
      break;
    }
  }

  if (!openConnection) {
    return;
  }

  DLog(@"sending a pairing cancel");
  NSMutableDictionary *requestPropertiesDictionary = [NSMutableDictionary dictionary];
  [requestPropertiesDictionary setValue:zsActID(zsActionCancelPairing) forKey:zsAction];
  [requestPropertiesDictionary setValue:[[UIDevice currentDevice] uniqueIdentifier] forKey:zsDeviceGUID];
  [requestPropertiesDictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];

  BLIPRequest *request = [BLIPRequest requestWithBody:nil properties:requestPropertiesDictionary];
  [openConnection sendRequest:request];
}

- (void)disconnectPairing;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerName];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerUUID];

  for (BLIPConnection *conn in [self openConnections]) {
    [conn setDelegate:nil];
    [conn close];
  }

  [[self openConnections] removeAllObjects];

  [self setRegisteredService:nil];
//  if ([self connection]) {
//    [[self connection] close];
//    [[self openConnections] removeObject:conn];
//    //  [self setConnection:nil];
//  }

  [self setServerAction:ZSyncServerActionNoActivity];
}

- (void)deregister
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  DLog(@"deregister request received");

  ZAssert([self serverAction] == ZSyncServerActionNoActivity, @"Attempt to sync while another action is active");

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
  DLog(@"searching for server");
  [self startServerSearch];
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
  for (BLIPConnection *conn in [self openConnections]) {
    [conn setDelegate:nil];
    [conn close];
  }

  [[self openConnections] removeAllObjects];
//  if ([self connection]) {
//    [[self connection] close];
//    [[self openConnections] removeObject:conn];
//    //  [self setConnection:nil];
//  }

  if ([self serviceBrowser]) {
    [[self serviceBrowser] setDelegate:nil];
    [[self serviceBrowser] stop];
    [self setServiceBrowser:nil];
  }

  if ([self registeredService]) {
    [[self registeredService] stopMonitoring];
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

  NSString *serverUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
  if (serverUUID) {
    [[self serviceBrowser] setDelegate:nil];
    [[self serviceBrowser] stop];
    [self setServiceBrowser:nil];
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

  if ([self registeredService]) {
    [self handleServerActionWithService:[self registeredService]];
  } else {
    NSString *serverUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
    if (serverUUID) {
      networkTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(networkTimeout:) userInfo:reachability repeats:NO];
    }

    [[self serviceBrowser] start];
  }
}

#pragma mark -
#pragma mark Local methods

- (void)handleServerActionWithService:(NSNetService *)service
{
  if ([self serverAction] == ZSyncServerActionSync) {
    [self beginSyncWithService:service];
  } else if ([self serverAction] == ZSyncServerActionDeregister) {
    [self beginDeregistrationWithService:service];
  }
}

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
  DLog(@"Resetting the service browser");
  [[self serviceBrowser] setDelegate:nil];
  [[self serviceBrowser] stop];
  [self setServiceBrowser:nil];

  Reachability *reachability = [Reachability reachabilityForLocalWiFi];
  if ([reachability currentReachabilityStatus] == NotReachable) {
    DLog(@"local network not available");
    // Subscribe to changes in reachability
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    [reachability startNotifer];
    networkTimer = [NSTimer scheduledTimerWithTimeInterval:15.0     target:self selector:@selector(networkTimeout:) userInfo:reachability repeats:NO];

    return;
  } else if ([self registeredService]) {
    [self handleServerActionWithService:[self registeredService]];
  } else {
    NSString *serverUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
    if (serverUUID) {
      networkTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(networkTimeout:) userInfo:reachability repeats:NO];
    }

    [[self serviceBrowser] start];
  }
}

- (void)beginSyncWithService:(NSNetService *)service
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  BLIPConnection *conn = [[BLIPConnection alloc] initToNetService:service];
  [[self openConnections] addObject:conn];
  //  [self setConnection:conn];
  [conn setDelegate:self];
  [conn open];
  [conn release], conn = nil;
}

- (void)beginDeregistrationWithService:(NSNetService *)service
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  BLIPConnection *conn = [[BLIPConnection alloc] initToNetService:service];
  [[self openConnections] addObject:conn];
  //  [self setConnection:conn];
  [conn setDelegate:self];
  [conn open];
  [conn release], conn = nil;
}

- (void)beginLatentDeregistrationWithService:(NSNetService *)service
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  BLIPConnection *conn = [[BLIPConnection alloc] initToNetService:service];
  [[self openConnections] addObject:conn];
  //  [self setConnection:conn];
  [conn setDelegate:self];
  [conn open];
  [conn release], conn = nil;
}

- (BOOL)switchStore:(NSPersistentStore *)persistentStore withReplacement:(NSDictionary *)replacement error:(NSError **)error
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSDictionary *storeOptions = [[[persistentStore options] copy] autorelease];
  NSFileManager *fileManager = [NSFileManager defaultManager];

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

- (void)completeSyncFromConnection:(BLIPConnection *)conn
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

  [conn setDelegate:nil];
  [conn close];
//  [[self connection] close];
  [[self openConnections] removeObject:conn];
  //  [self setConnection:nil];

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
}

- (void)uploadDataToServerUsingConnection:(BLIPConnection *)conn
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
    [conn sendRequest:request];

    [persistentStoreData release], persistentStoreData = nil;
    [requestPropertiesDictionary release], requestPropertiesDictionary = nil;
    DLog(@"file uploaded");

    [[self storeFileIdentifiers] addObject:[persistentStore identifier]];
  }
  DLog(@"finished");
}

- (void)sendPairingRequestToServerUsingConnection:(BLIPConnection *)conn
{
  [self setPasscode:[self generatePairingCode]];

  NSMutableDictionary *requestPropertiesDictionary = [[NSMutableDictionary alloc] init];
  [requestPropertiesDictionary setValue:zsActID(zsActionRequestPairing) forKey:zsAction];
  [requestPropertiesDictionary setValue:zsActID([self majorVersionNumber]) forKey:zsSchemaMajorVersion];
  [requestPropertiesDictionary setValue:zsActID([self minorVersionNumber]) forKey:zsSchemaMinorVersion];
  [requestPropertiesDictionary setValue:[[UIDevice currentDevice] name] forKey:zsDeviceName];
  [requestPropertiesDictionary setValue:[[UIDevice currentDevice] uniqueIdentifier] forKey:zsDeviceGUID];
  [requestPropertiesDictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];

  NSData *data = [[self passcode] dataUsingEncoding:NSUTF8StringEncoding];
  BLIPRequest *request = [conn requestWithBody:data properties:requestPropertiesDictionary];
  [request send];

  [requestPropertiesDictionary release], requestPropertiesDictionary = nil;

  [[self delegate] zSyncHandler:self displayPairingCode:[self passcode]];
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

- (void)requestDeregistrationUsingConnection:(BLIPConnection *)conn
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  DLog(@"issuing deregister command");

  NSMutableDictionary *requestPropertiesDictionary = [NSMutableDictionary dictionary];
  [requestPropertiesDictionary setValue:zsActID(zsActionDeregisterClient) forKey:zsAction];
  [requestPropertiesDictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];

  NSData *body = [[self syncGUID] dataUsingEncoding:NSUTF8StringEncoding];

  BLIPRequest *request = [BLIPRequest requestWithBody:body properties:requestPropertiesDictionary];
  [conn sendRequest:request];
}

- (void)requestLatentDeregistrationUsingConnection:(BLIPConnection *)conn
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  [dictionary setValue:zsActID(zsActionLatentDeregisterClient) forKey:zsAction];
  [dictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];

  NSData *body = [[self syncGUID] dataUsingEncoding:NSUTF8StringEncoding];

  BLIPRequest *request = [BLIPRequest requestWithBody:body properties:dictionary];
  [conn sendRequest:request];
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

- (void)processLatentDeregisterResponse:(BLIPResponse *)response fromConnection:(BLIPConnection *)conn
{
  DLog(@"%s", __PRETTY_FUNCTION__);

  NSString *registeredServerUUID = [response valueOfProperty:zsServerUUID];
  DLog(@"%s registeredServerUUID %@", __PRETTY_FUNCTION__, registeredServerUUID);

  // TODO: Compare version numbers
  ZAssert(registeredServerUUID != nil, @"Body string is nil in request\n%@", [[response properties] allProperties]);

  NSMutableArray *deregisteredServers = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:zsDeregisteredServersKey]];

  if (registeredServerUUID) {
    [deregisteredServers removeObject:registeredServerUUID];
    [[NSUserDefaults standardUserDefaults] setObject:deregisteredServers forKey:zsDeregisteredServersKey];
  }

  [[NSUserDefaults standardUserDefaults] synchronize];

  [deregisteredServers release], deregisteredServers = nil;

  [self setServerAction:ZSyncServerActionNoActivity];
  [conn setDelegate:nil];
  [conn close];
//  [[self connection] close];
  [[self openConnections] removeObject:conn];
  //  [self setConnection:nil];
}

- (void)processDeregisterResponse:(BLIPResponse *)response fromConnection:(BLIPConnection *)conn
{
  NSLog(@"%s", __PRETTY_FUNCTION__);

  if ([[self delegate] respondsToSelector:@selector(zSyncDeregisterComplete:)]) {
    [[self delegate] zSyncDeregisterComplete:self];
  }

  [self setServerAction:ZSyncServerActionNoActivity];
  [conn setDelegate:nil];
  [conn close];
  //  [[self connection] close];
  [[self openConnections] removeObject:conn];
  //  [self setConnection:nil];

  [self setRegisteredService:nil];
}

- (void)processFileReceivedResponse:(BLIPResponse *)response fromConnection:(BLIPConnection *)conn
{
  NSLog(@"%s", __PRETTY_FUNCTION__);

  ZAssert([self storeFileIdentifiers] != nil, @"zsActionFileReceived with a nil storeFileIdentifiers");

  [[self storeFileIdentifiers] removeObject:[[response properties] valueOfProperty:zsStoreIdentifier]];

  if ([[self storeFileIdentifiers] count] == 0) {
//    [self sendUploadComplete];
    DLog(@"sending upload complete");

    NSMutableDictionary *requestPropertiesDictionary = [[NSMutableDictionary alloc] init];
    [requestPropertiesDictionary setValue:zsActID(zsActionPerformSync) forKey:zsAction];
    [requestPropertiesDictionary setValue:[self schemaID] forKey:zsSchemaIdentifier];

    BLIPRequest *request = [BLIPRequest requestWithBody:nil properties:requestPropertiesDictionary];
    [request setNoReply:YES];
    [conn sendRequest:request];

    [requestPropertiesDictionary release], requestPropertiesDictionary = nil;

    [self setStoreFileIdentifiers:nil];
  }
}

- (void)processSchemaUnsupportedResponse:(BLIPResponse *)response fromConnection:(BLIPConnection *)conn
{
  NSLog(@"%s", __PRETTY_FUNCTION__);

  if ([[self delegate] respondsToSelector:@selector(zSync:serverVersionUnsupported:)]) {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[response bodyString] forKey:NSLocalizedDescriptionKey];
    NSError *error = [NSError errorWithDomain:zsErrorDomain code:[[response valueOfProperty:zsErrorCode] integerValue] userInfo:userInfo];

    [[self delegate] zSync:self serverVersionUnsupported:error];
  }

  [self setServerAction:ZSyncServerActionNoActivity];
  [conn setDelegate:nil];
  [conn close];
  //  [[self connection] close];
  [[self openConnections] removeObject:conn];
  //  [self setConnection:nil];
  [self setRegisteredService:nil];
}

- (void)processSchemaSupportedResponse:(BLIPResponse *)response fromConnection:(BLIPConnection *)conn
{
  DLog(@"%s", __PRETTY_FUNCTION__);

  switch ([self serverAction]) {
    case ZSyncServerActionSync:
      if ([[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID]) {
        // Start a sync by pushing the data file to the server
        [self uploadDataToServerUsingConnection:conn];
      } else {
        // We are not paired so we need to request a pairing session
        [self sendPairingRequestToServerUsingConnection:conn];
      }
      break;
    case ZSyncServerActionDeregister:
      [self requestDeregistrationUsingConnection:conn];
      break;
    case ZSyncServerActionLatentDeregistration:
      [self requestLatentDeregistrationUsingConnection:conn];
      break;
    default:
      ALog(@"Unknown server action: %i", [self serverAction]);
  }
}

- (void)processAuthenticationFailedRequest:(BLIPRequest *)request fromConnection:(BLIPConnection *)conn
{
  NSLog(@"%s", __PRETTY_FUNCTION__);

  /*
   * The pairing code was not entered correctly so we reset back to a default state
   * so that the user can start all over again.
   */
  [conn setDelegate:nil];
  [conn close];
  [[self openConnections] removeObject:conn];
  //  [self setConnection:nil];
  if ([[self delegate] respondsToSelector:@selector(zSyncPairingCodeRejected:)]) {
    [[self delegate] zSyncPairingCodeRejected:self];
  }
  [self setServerAction:ZSyncServerActionNoActivity];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerUUID];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerName];
}

- (void)processAuthenticatePairingRequest:(BLIPRequest *)request fromConnection:(BLIPConnection *)conn
{
  NSLog(@"%s", __PRETTY_FUNCTION__);

  if ([[request bodyString] isEqualToString:[self passcode]]) {
    [[NSUserDefaults standardUserDefaults] setValue:[request valueOfProperty:zsServerUUID] forKey:zsServerUUID];
    [self performSelector:@selector(uploadDataToServerUsingConnection:) withObject:conn afterDelay:0.1];
  }

  [[self delegate] zSyncPairingCodeCompleted:self];
}

- (void)processCompleteSyncRequest:(BLIPRequest *)request fromConnection:(BLIPConnection *)conn
{
  NSLog(@"%s", __PRETTY_FUNCTION__);

  [self performSelector:@selector(completeSyncFromConnection:) withObject:conn afterDelay:0.01];
}

- (void)processStoreUploadRequest:(BLIPRequest *)request fromConnection:(BLIPConnection *)conn
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

- (void)processCancelPairingRequest:(BLIPRequest *)request fromConnection:(BLIPConnection *)conn
{
  DLog(@"%s zsActionCancelPairing", __PRETTY_FUNCTION__);
  [conn setDelegate:nil];
  [conn close];
  [[self openConnections] removeObject:conn];
  //  [self setConnection:nil];
  if ([[self delegate] respondsToSelector:@selector(zSyncPairingCodeCancelled:)]) {
    [[self delegate] zSyncPairingCodeCancelled:self];
  }

  [self setServerAction:ZSyncServerActionNoActivity];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerUUID];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:zsServerName];

  [self setRegisteredService:nil];
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

- (NSMutableArray *)openConnections
{
  if (!openConnections) {
    openConnections = [[NSMutableArray alloc] init];
  }

  return openConnections;
}

- (NSLock *)lock
{
  if (!lock) {
    lock = [[NSLock alloc] init];
  }

  return lock;
}

- (NSLock *)serviceResolutionLock
{
  if (!serviceResolutionLock) {
    serviceResolutionLock = [[NSLock alloc] init];
  }

  return serviceResolutionLock;
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

// - (void)setConnection:(BLIPConnection *)conn
// {
//  if ([conn isEqual:[self connection]]) {
//    return;
//  }
//
//  if ([self connection]) {
//    [[self connection] close];
//    [[self connection] setDelegate:nil];
//  }
//
//  BLIPConnection *tmp = [conn retain];
//  [_connection release], _connection = nil;
//  _connection = tmp;
// }

#pragma mark -
#pragma mark ServerBrowserDelegate methods

- (void)updateServerList
{
  [serviceResolutionLock lock];
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

  [serviceResolutionLock unlock];
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
  [serviceResolutionLock lock];

  NSString *incomingServerName = [bonjourService name];

  if ([bonjourService isEqual:[self registeredService]]) {
//  if ([[self resolvedServices] containsObject:bonjourService]) {
    NSLog(@"%s We've already resolved our service, bailing out before we start a sync. Service Name:%@", __PRETTY_FUNCTION__, incomingServerName);
    [serviceResolutionLock unlock];
    return;
  }

  DLog(@"%s", __PRETTY_FUNCTION__);

  NSDictionary *txtRecordDictionary = [NSNetService dictionaryFromTXTRecordData:[bonjourService TXTRecordData]];
  if (!txtRecordDictionary) {
    DLog(@"The NSNetService named %@ did not contain a TXT record", incomingServerName);
    [serviceResolutionLock unlock];
    return;
  }

  NSData *incomingServerUUIDData = [txtRecordDictionary objectForKey:zsServerUUID];
  if (!incomingServerUUIDData) {
    DLog(@"The TXT record did not contain a server UUID.");
    [serviceResolutionLock unlock];
    return;
  }

  NSString *incomingServerUUID = [[NSString alloc] initWithData:incomingServerUUIDData encoding:NSUTF8StringEncoding];
  if (!incomingServerUUID || [incomingServerUUID length] == 0) {
    DLog(@"The TXT record UUID was zero length.");
    [incomingServerUUID release], incomingServerUUID = nil;
    [serviceResolutionLock unlock];
    return;
  }

  NSArray *deregisteredServers = [[NSUserDefaults standardUserDefaults] objectForKey:zsDeregisteredServersKey];
  if (deregisteredServers && [deregisteredServers containsObject:incomingServerUUID]) {
    [self setServerAction:ZSyncServerActionLatentDeregistration];
    [self beginLatentDeregistrationWithService:bonjourService];
  }

  NSString *registeredServerUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
  NSString *registeredServerName = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerName];

  if (!registeredServerUUID) {     // See if the server is in the deregistered list
    ZSyncService *zSyncService = [[ZSyncService alloc] init];
    [zSyncService setService:bonjourService];
    [zSyncService setName:incomingServerName];
    [zSyncService setUuid:incomingServerUUID];
    [[self availableServers] addObject:zSyncService];
    [zSyncService release], zSyncService = nil;

    [[self delegate] zSyncNoServerPaired:[self availableServers]];

    [incomingServerUUID release], incomingServerUUID = nil;

    [serviceResolutionLock unlock];
    return;
  }

  if (![incomingServerUUID isEqualToString:registeredServerUUID]) {
    NSData *incomingServerNameData = [txtRecordDictionary objectForKey:zsServerName];
    if (!incomingServerNameData) {
      DLog(@"TXT record did not contain server name data");
      [incomingServerUUID release], incomingServerUUID = nil;
      [serviceResolutionLock unlock];
      return;
    }

    NSString *incomingServerName = [[NSString alloc] initWithData:incomingServerNameData encoding:NSUTF8StringEncoding];
    if (![incomingServerName isEqualToString:registeredServerName]) {
      DLog(@"Incoming server name did not match registered server name, %@ != %@", incomingServerName, registeredServerName);
      [incomingServerUUID release], incomingServerUUID = nil;
      [incomingServerName release], incomingServerName = nil;
      [serviceResolutionLock unlock];
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

      [serviceResolutionLock unlock];
      return;
    }
  }

  [incomingServerUUID release], incomingServerUUID = nil;

  [networkTimer invalidate], networkTimer = nil;
  DLog(@"our server found");
  // Found our server, stop looking and start the sync
  [[self serviceBrowser] setDelegate:nil];
  [[self serviceBrowser] stop];

  [self setRegisteredService:bonjourService];

  [self handleServerActionWithService:bonjourService];

  [serviceResolutionLock unlock];

  return;
}

/* Sent to the NSNetService instance's delegate when an error in resolving the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants).
 */
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
  [serviceResolutionLock lock];

  DLog(@"%s", __PRETTY_FUNCTION__);
  [[self discoveredServers] removeObject:sender];

  // Did not find our registered server.  Fail
  if ([[self discoveredServers] count] == 0) {
    [[self delegate] zSyncServerUnavailable:self];
    [self setServerAction:ZSyncServerActionNoActivity];
  }

  [serviceResolutionLock unlock];
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
  [conn setDelegate:nil];
  [conn close];
//  [[self connection] close];
  [[self openConnections] removeObject:conn];
//  [self setConnection:nil];
  [[self delegate] zSync:self errorOccurred:error];
  [self setRegisteredService:nil];
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
      [self processLatentDeregisterResponse:response fromConnection:conn];
      return;

    case zsActionDeregisterClient:
      [self processDeregisterResponse:response fromConnection:conn];
      return;

    case zsActionFileReceived:
      [self processFileReceivedResponse:response fromConnection:conn];
      return;

    case zsActionSchemaUnsupported:
      [self processSchemaUnsupportedResponse:response fromConnection:conn];
      return;

    case zsActionSchemaSupported:
      [self processSchemaSupportedResponse:response fromConnection:conn];
      return;

    default:
      DLog(@"%s default case encountered", __PRETTY_FUNCTION__);
      ALog(@"%s Unknown response action received: %i", __PRETTY_FUNCTION__, action);
  }
}

- (BOOL)connection:(BLIPConnection *)conn receivedRequest:(BLIPRequest *)request
{
  NSInteger action = [[[request properties] valueOfProperty:zsAction] integerValue];
  switch (action) {
    case zsActionAuthenticateFailed:
      [self processAuthenticationFailedRequest:request fromConnection:conn];
      return YES;

    case zsActionAuthenticatePairing:
      [self processAuthenticatePairingRequest:request fromConnection:conn];
      return YES;

    case zsActionCompleteSync:
      [self processCompleteSyncRequest:request fromConnection:conn];
      return YES;

    case zsActionStoreUpload:
      [self processStoreUploadRequest:request fromConnection:conn];
      return YES;

    case zsActionCancelPairing:
      [self processCancelPairingRequest:request fromConnection:conn];
      return YES;

    default:
      DLog(@"%s default case encountered", __PRETTY_FUNCTION__);
      ALog(@"%s Unknown request action received: %i", __PRETTY_FUNCTION__, action);
      return NO;
  }
}

- (void)connectionDidClose:(TCPConnection *)conn;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  if (![[self openConnections] containsObject:conn]) {
//    if (![self connection]) {
    return;
  }

  // premature closing
  [[self openConnections] removeObject:conn];
  //  [self setConnection:nil];
  [self setServerAction:ZSyncServerActionNoActivity];

  [self setRegisteredService:nil];

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
// @synthesize connection = _connection;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

@synthesize majorVersionNumber;
@synthesize minorVersionNumber;
@synthesize passcode;
@synthesize serverAction;
@synthesize availableServers;
@synthesize discoveredServers;
@synthesize resolvedServices;
@synthesize lock;
@synthesize serviceResolutionLock;
@synthesize storeFileIdentifiers;
@synthesize receivedFileLookupDictionary;
@synthesize openConnections;
@synthesize registeredService;

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