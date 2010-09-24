//
//  ZSyncConnectionDelegate.m
//  ZSyncDaemon
//
//  Created by Marcus S. Zarra on 1/17/10.
//  Copyright 2010 Zarra Studios LLC. All rights reserved.
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
//

#import "ZSyncConnectionDelegate.h"
#import "ZSyncDaemon.h"

#define kPasscodeEntryMaxAttempts 3

@implementation ZSyncConnectionDelegate

// TODO: Need to move this out of here
@synthesize pairingCodeWindowController;

#pragma mark -
#pragma mark Overridden getters/setters

- (NSManagedObjectModel *)managedObjectModel
{
  if (!managedObjectModel) {
    NSBundle *pluginBundle = [[ZSyncHandler shared] pluginForSchema:[[self syncApplication] valueForKey:@"schema"]];
    NSArray *bundles = [NSArray arrayWithObject:pluginBundle];
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:bundles] retain];
  }

  return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
  if (!persistentStoreCoordinator) {
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
  }

  return persistentStoreCoordinator;
}

- (NSManagedObjectContext *)managedObjectContext
{
  if (!managedObjectContext) {
    managedObjectContext = [[NSManagedObjectContext alloc] init];
    [managedObjectContext setPersistentStoreCoordinator:[self persistentStoreCoordinator]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mocSaved:) name:NSManagedObjectContextDidSaveNotification object:managedObjectContext];
  }

  return managedObjectContext;
}

- (NSMutableArray *)storeFileIdentifiers
{
  if (!storeFileIdentifiers) {
    storeFileIdentifiers = [[NSMutableArray alloc] init];
  }

  return storeFileIdentifiers;
}

- (id)pairingCodeWindowController
{
  if (!pairingCodeWindowController) {
    pairingCodeWindowController = [[PairingCodeWindowController alloc] initWithDelegate:self];
  }

  return pairingCodeWindowController;
}

#pragma mark -
#pragma mark Local methods

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

- (void)showCodeWindow
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [[[self pairingCodeWindowController] window] center];
  [[self pairingCodeWindowController] showWindow:self];
}

- (void)addPersistentStore:(BLIPRequest *)request
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  ZAssert([request complete], @"Message is incomplete");

  NSString *filePath = NSTemporaryDirectory();
  filePath = [filePath stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  filePath = [filePath stringByAppendingPathExtension:@"zsync"];
  //  DLog(@"%s request length: %i", __PRETTY_FUNCTION__, [[request body] length]);
  [[request body] writeToFile:filePath atomically:YES];

//  if (!persistentStoreCoordinator) {
//    if (!managedObjectModel) {
//      NSBundle *pluginBundle = [[ZSyncHandler shared] pluginForSchema:[syncApplication valueForKey:@"schema"]];
//      NSArray *bundles = [NSArray arrayWithObject:pluginBundle];
//      managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:bundles] retain];
//    }
//    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
//    managedObjectContext = [[NSManagedObjectContext alloc] init];
//    [managedObjectContext setPersistentStoreCoordinator:persistentStoreCoordinator];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mocSaved:) name:NSManagedObjectContextDidSaveNotification object:managedObjectContext];
//  }

  NSError *error = nil;
  NSPersistentStore *persistentStore = nil;
  persistentStore = [[self persistentStoreCoordinator] addPersistentStoreWithType:[request valueOfProperty:zsStoreType]
                                    configuration:[request valueOfProperty:zsStoreConfiguration]
                                        URL:[NSURL fileURLWithPath:filePath]
                                      options:nil
                                        error:&error];

  ZAssert(persistentStore != nil, @"Error loading persistent store: %@", [error localizedDescription]);

  [persistentStore setIdentifier:[request valueOfProperty:zsStoreIdentifier]];

  BLIPResponse *response = [request response];
  [response setValue:zsActID(zsActionFileReceived) ofProperty:zsAction];
  [response setValue:[persistentStore identifier] ofProperty:zsStoreIdentifier];
  [response send];
}

- (void)mocSaved:(NSNotification *)notification
{
  DLog(@"%s info %@", __PRETTY_FUNCTION__, [notification userInfo]);
}

- (void)transferStoresToDevice
{
  DLog(@"%s", __PRETTY_FUNCTION__);
//  storeFileIdentifiers = [[NSMutableArray alloc] init];

  for (NSPersistentStore *persistentStore in [[self persistentStoreCoordinator] persistentStores]) {
    NSData *data = [[NSData alloc] initWithContentsOfFile:[[persistentStore URL] path]];
    DLog(@"%s url %@\nIdentifier: %@\nSize: %i", __PRETTY_FUNCTION__, [persistentStore URL], [persistentStore identifier], [data length]);

    NSMutableDictionary *requestPropertiesDictionary = [[NSMutableDictionary alloc] init];
    [requestPropertiesDictionary setValue:[persistentStore identifier] forKey:zsStoreIdentifier];
    [requestPropertiesDictionary setValue:[persistentStore configurationName] forKey:zsStoreConfiguration];
    [requestPropertiesDictionary setValue:[persistentStore type] forKey:zsStoreType];
    [requestPropertiesDictionary setValue:zsActID(zsActionStoreUpload) forKey:zsAction];

    BLIPRequest *request = [BLIPRequest requestWithBody:data properties:requestPropertiesDictionary];
    [request setCompressed:YES];
    [[self connection] sendRequest:request];

    [data release], data = nil;
    [requestPropertiesDictionary release], requestPropertiesDictionary = nil;

    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[[persistentStore URL] path] error:&error];
    ZAssert(error == nil, @"Error removing file: %@\n%@", [[persistentStore URL] path], [error localizedDescription]);

    if (![[self persistentStoreCoordinator] removePersistentStore:persistentStore error:&error]) {
      ALog(@"Error removing persistent store: %@", [error localizedDescription]);
    }

    DLog(@"%s file uploaded", __PRETTY_FUNCTION__);
    [[self storeFileIdentifiers] addObject:[persistentStore identifier]];
  }
}

- (void)performSync
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSError *error = nil;

  NSString *clientIdentifier = [[self syncApplication] valueForKey:@"uuid"];
  DLog(@"%s clientID %@", __PRETTY_FUNCTION__, clientIdentifier);
  ISyncClient *syncClient = [[ISyncManager sharedManager] clientWithIdentifier:clientIdentifier];
  ZAssert(syncClient != nil, @"Sync Client not found");

  if (![[self persistentStoreCoordinator] syncWithClient:syncClient inBackground:NO handler:self error:&error]) {
    ALog(@"Error starting sync session: %@", [error localizedDescription]);
  }

  ZAssert([[self managedObjectContext] save:&error], @"Error saving context: %@", [error localizedDescription]);

  // Sync is complete and saved.  Push the data back to the device.
  [self transferStoresToDevice];
}

/*
 * Sent to the device after all of the files have been pushed.
 * Now we tear down the core data stack and update the sync date
 */
- (void)sendDownloadComplete
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSMutableDictionary *requestPropertiesDictionary = [[NSMutableDictionary alloc] init];
  [requestPropertiesDictionary setValue:zsActID(zsActionCompleteSync) forKey:zsAction];

  BLIPRequest *request = [[self connection] requestWithBody:nil properties:requestPropertiesDictionary];
  [request setNoReply:YES];
  [requestPropertiesDictionary release], requestPropertiesDictionary = nil;
  [request send];

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [self setManagedObjectContext:nil];
  [self setPersistentStoreCoordinator:nil];
  [self setManagedObjectModel:nil];
//  [managedObjectContext release], managedObjectContext = nil;
//  [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
//  [managedObjectModel release], managedObjectModel = nil;

  [[self syncApplication] setValue:[NSDate date] forKey:@"lastSync"];
}

- (void)deregisterSyncClient:(BLIPRequest *)request
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSString *clientID = [request bodyString];
  DLog(@"%s clientID %@", __PRETTY_FUNCTION__, clientID);
  // TODO: Compare version numbers
  ZAssert(clientID != nil, @"Body string is nil in request\n%@", [[request properties] allProperties]);

  BLIPResponse *response = [request response];
  [response setValue:zsActID(zsActionDeregisterClient) ofProperty:zsAction];

  ISyncClient *syncClient = [[ISyncManager sharedManager] clientWithIdentifier:clientID];
  if (syncClient) {
    [[ISyncManager sharedManager] unregisterClient:syncClient];
  }

  [response send];
}

- (void)deregisterLatentSyncClient:(BLIPRequest *)request
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSString *clientID = [request bodyString];
  DLog(@"%s clientID %@", __PRETTY_FUNCTION__, clientID);
  // TODO: Compare version numbers
  ZAssert(clientID != nil, @"Body string is nil in request\n%@", [[request properties] allProperties]);

  BLIPResponse *response = [request response];
  [response setValue:zsActID(zsActionLatentDeregisterClient) ofProperty:zsAction];
  [response setValue:[[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID] ofProperty:zsServerUUID];

  ISyncClient *syncClient = [[ISyncManager sharedManager] clientWithIdentifier:clientID];
  if (syncClient) {
    [[ISyncManager sharedManager] unregisterClient:syncClient];
  }

  [response send];
}

- (BOOL)verifySchema:(BLIPRequest *)request
{
  DLog(@"%s", __PRETTY_FUNCTION__);

  NSString *clientID = [request bodyString];
  DLog(@"%s clientID %@", __PRETTY_FUNCTION__, clientID);
  ZAssert(clientID != nil, @"Body string is nil in request\n%@", [[request properties] allProperties]);

  NSString *schemaIdentifier = [request valueOfProperty:zsSchemaIdentifier];
  NSBundle *plugin = [[ZSyncHandler shared] pluginForSchema:schemaIdentifier];
  BLIPResponse *response = [request response];
  if (!plugin) {
    [response setValue:zsActID(zsActionSchemaUnsupported) ofProperty:zsAction];
    [response setBodyString:[NSString stringWithFormat:NSLocalizedString(@"No Sync Client Registered for %@", @"no sync client registered error message"), schemaIdentifier]];
    [response setValue:zsActID(zsErrorNoSyncClientRegistered) ofProperty:zsErrorCode];
    [response send];
    return NO;
  }
  [response setValue:zsActID(zsActionSchemaSupported) ofProperty:zsAction];
  [response send];

  return YES;
}

- (void)registerSyncClient:(BLIPRequest *)request
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSString *clientID = [request valueOfProperty:zsSyncGUID];
  DLog(@"%s clientID %@", __PRETTY_FUNCTION__, clientID);
  // TODO: Compare version numbers
  ZAssert(clientID != nil, @"Body string is nil in request\n%@", [[request properties] allProperties]);

  BLIPResponse *response = [request response];

  NSString *schemaIdentifier = [request valueOfProperty:zsSchemaIdentifier];
  NSBundle *zsyncPlugin = [[ZSyncHandler shared] pluginForSchema:schemaIdentifier];

  ISyncClient *syncClient = [[ISyncManager sharedManager] clientWithIdentifier:clientID];
  if (!syncClient) {
    NSString *clientDescription = [zsyncPlugin pathForResource:@"clientDescription" ofType:@"plist"];
    @try {
      syncClient = [[ISyncManager sharedManager] registerClientWithIdentifier:clientID descriptionFilePath:clientDescription];
    } @catch (NSException *exception) {
      DLog(@"exception caught: %@", exception);
    }
    NSString *displayName = [syncClient displayName];
    displayName = [displayName stringByAppendingFormat:@": %@", [request valueOfProperty:zsDeviceName]];
    [syncClient setDisplayName:displayName];
    DLog(@"%s display name: %@", __PRETTY_FUNCTION__, [syncClient displayName]);

    [syncClient setShouldSynchronize:YES withClientsOfType:ISyncClientTypeApplication];
    [syncClient setShouldSynchronize:YES withClientsOfType:ISyncClientTypeDevice];
  } else {
    DLog(@"%s client already registered: %@", __PRETTY_FUNCTION__, [syncClient displayName]);
  }

  if (!syncClient) {
    [response setValue:zsActID(zsActionSchemaUnsupported) ofProperty:zsAction];
    [response setBodyString:[NSString stringWithFormat:NSLocalizedString(@"No Sync Client Registered for %@", @"no sync client registered error message"), schemaIdentifier]];
    [response setValue:zsActID(zsErrorNoSyncClientRegistered) ofProperty:zsErrorCode];
    [response send];
    return;
  }

  NSString *deviceName = [request valueOfProperty:zsDeviceName];
  NSString *deviceUUID = [request valueOfProperty:zsDeviceGUID];

  NSManagedObject *device = [[ZSyncHandler shared] registerDevice:deviceUUID withName:deviceName];
  [self setSyncApplication:[[ZSyncHandler shared] registerApplication:schemaIdentifier withClient:clientID withDevice:device]];
}

#pragma mark -
#pragma mark PairingCodeDelegate

- (void)pairingCodeWindowController:(PairingCodeWindowController *)pairingWindowController codeEntered:(NSString *)userEnteredPairingCode;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [self setPairingCodeEntryCount:([self pairingCodeEntryCount] + 1)];

  if (![userEnteredPairingCode isEqualToString:[self pairingCode]]) {
    if ([self pairingCodeEntryCount] < kPasscodeEntryMaxAttempts) {
      [pairingWindowController refuseCode];
      return;
    }

    [[self pairingCodeWindowController] close];
    NSMutableDictionary *requestPropertiesDictionary = [NSMutableDictionary dictionary];
    [requestPropertiesDictionary setValue:zsActID(zsActionAuthenticateFailed) forKey:zsAction];
    [requestPropertiesDictionary setValue:[[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID] forKey:zsServerUUID];

    [[self connection] sendRequest:[BLIPRequest requestWithBody:nil properties:requestPropertiesDictionary]];
    [self setPairingCodeWindowController:nil];

    return;
  }

  BLIPRequest *request = [BLIPRequest requestWithBodyString:userEnteredPairingCode];
  [request setValue:zsActID(zsActionAuthenticatePairing) ofProperty:zsAction];
  [request setValue:[[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID] ofProperty:zsServerUUID];

  [[self connection] sendRequest:request];
  [[self pairingCodeWindowController] close];
  [self setPairingCodeWindowController:nil];
}

- (void)pairingCodeWindowControllerCancelled:(PairingCodeWindowController *)pairingWindowController
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSMutableDictionary *requestPropertiesDictionary = [NSMutableDictionary dictionary];
  [requestPropertiesDictionary setValue:zsActID(zsActionCancelPairing) forKey:zsAction];

  BLIPRequest *request = [BLIPRequest requestWithBody:nil properties:requestPropertiesDictionary];
  [[self connection] sendRequest:request];
  [[self pairingCodeWindowController] close];
  [self setPairingCodeWindowController:nil];
}

#pragma mark -
#pragma mark NSPersistentStoreCoordinatorSyncing

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator didFinishSyncSession:(ISyncSession *)session
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  DLog(@"%s sync is complete", __PRETTY_FUNCTION__);
}

- (NSArray *)managedObjectContextsToMonitorWhenSyncingPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator;
{
  return [NSArray arrayWithObject:[self managedObjectContext]];
}

- (NSArray *)managedObjectContextsToReloadAfterSyncingPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator;
{
  return [NSArray arrayWithObject:[self managedObjectContext]];
}

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator willPushChangesInSyncSession:(ISyncSession *)session;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator didPushChangesInSyncSession:(ISyncSession *)session;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator willPullChangesInSyncSession:(ISyncSession *)session;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator didPullChangesInSyncSession:(ISyncSession *)session;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator didCancelSyncSession:(ISyncSession *)session error:(NSError *)error;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

#pragma mark -
#pragma mark BLIPConnectionDelegate methods

- (BOOL)connectionReceivedCloseRequest:(BLIPConnection *)conn;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);

  [conn setDelegate:nil];
  [[ZSyncHandler shared] connectionClosed:self];
  [[self pairingCodeWindowController] close];

  return YES;
}

- (void)connection:(BLIPConnection *)con receivedResponse:(BLIPResponse *)response;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  if (![[response properties] valueOfProperty:zsAction]) {
    DLog(@"%s received empty response, ignoring", __PRETTY_FUNCTION__);
    return;
  }

  DLog(@"%s entered\n%@", __PRETTY_FUNCTION__, [[response properties] allProperties]);
  NSInteger action = [[[response properties] valueOfProperty:zsAction] integerValue];
  switch (action) {
    case zsActionFileReceived:
      [[self storeFileIdentifiers] removeObject:[[response properties] valueOfProperty:zsStoreIdentifier]];
      if ([[self storeFileIdentifiers] count] == 0) {
        [self sendDownloadComplete];
        [self setStoreFileIdentifiers:nil];
      }
      break;
    default:
      ALog(@"Unknown action received: %i", action);
      break;
  }
}

- (void)connection:(BLIPConnection *)con closeRequestFailedWithError:(NSError *)error;
{
  ALog(@"%s error %@", __PRETTY_FUNCTION__, error);
}

- (BOOL)connection:(BLIPConnection *)con receivedRequest:(BLIPRequest *)request
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);

  NSInteger action = [[[request properties] valueOfProperty:zsAction] integerValue];
  switch (action) {
    case zsActionLatentDeregisterClient:
      DLog(@"%s zsActionLatentDeregisterClient", __PRETTY_FUNCTION__);
      [self deregisterLatentSyncClient:request];
      return YES;

    case zsActionDeregisterClient:
      DLog(@"%s zsActionDeregisterClient", __PRETTY_FUNCTION__);
      [self deregisterSyncClient:request];
      return YES;

    case zsActionVerifySchema:
      DLog(@"%s zsActionVerifySchema", __PRETTY_FUNCTION__);
      [self verifySchema:request];
      // We return YES here even if the schema fails to verify because that method handles sending the failure response to the client
      return YES;

    case zsActionRequestPairing:
      DLog(@"%s zsActionRequestPairing", __PRETTY_FUNCTION__);
      [self setPairingCode:[request bodyString]];
      [self showCodeWindow];
      return YES;

    case zsActionVerifyPairing:
      // TODO: This method should verify that the client is paired properly, responding accordingly
      return YES;

    case zsActionStoreUpload:
      DLog(@"%s zsActionStoreUpload", __PRETTY_FUNCTION__);
      [self registerSyncClient:request];
      [self addPersistentStore:request];
      return YES;

    case zsActionPerformSync:
      DLog(@"%s zsActionPerformSync", __PRETTY_FUNCTION__);
      [self performSelector:@selector(performSync) withObject:nil afterDelay:0.01];
      return YES;

    case zsActionCancelPairing:
      DLog(@"%s zsActionCancelPairing", __PRETTY_FUNCTION__);
      [[self pairingCodeWindowController] close];
      return YES;

    default:
      DLog(@"%s default", __PRETTY_FUNCTION__);
      ALog(@"Unknown action received: %i", action);
      return NO;
  }
}

#pragma mark -
#pragma mark Memory management and property declarations

- (void)dealloc
{
  DLog(@"%s Releasing", __PRETTY_FUNCTION__);
  [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
  [managedObjectModel release], managedObjectModel = nil;
  [_connection release], _connection = nil;
  [managedObjectModel release], managedObjectModel = nil;
  [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
  [managedObjectContext release], managedObjectContext = nil;
  [pairingCodeWindowController release], pairingCodeWindowController = nil;
  [storeFileIdentifiers release], storeFileIdentifiers = nil;
  [syncApplication release], syncApplication = nil;

  [super dealloc];
}

@synthesize connection = _connection;
@synthesize pairingCode;
@synthesize pairingCodeEntryCount;
@synthesize managedObjectModel;
@synthesize persistentStoreCoordinator;
@synthesize managedObjectContext;
@synthesize storeFileIdentifiers;
@synthesize syncApplication;

@end