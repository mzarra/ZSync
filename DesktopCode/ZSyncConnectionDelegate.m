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

#import "PairingCodeWindowController.h"

@implementation ZSyncConnectionDelegate

@synthesize connection = _connection;
@synthesize pairingCode;
@synthesize clientIdentifier;

// TODO: Need to move this out of here
@synthesize codeController;

- (void)dealloc
{
  DLog(@"Releasing");
  [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
  [managedObjectModel release], managedObjectModel = nil;
  [_connection release], _connection = nil;
  [super dealloc];
}

- (NSString*)generatePairingCode
{
  NSMutableString *string = [NSMutableString string];
  [string appendFormat:@"%i", (arc4random() % 10)];
  [string appendFormat:@"%i", (arc4random() % 10)];
  [string appendFormat:@"%i", (arc4random() % 10)];
  [string appendFormat:@"%i", (arc4random() % 10)];
  return string;
}

- (void)showCodeWindow
{
  codeController = [[PairingCodeWindowController alloc] initWithCodeString:[self pairingCode]];
  [[codeController window] center];
  [codeController showWindow:self];
}

- (void)addPersistentStore:(BLIPRequest*)request
{
  ZAssert([request complete], @"Message is incomplete");
  NSString *filePath = NSTemporaryDirectory();
  filePath = [filePath stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  filePath = [filePath stringByAppendingPathExtension:@"zsync"];
  DLog(@"request length: %i", [[request body] length]);
  [[request body] writeToFile:filePath atomically:YES];
  
  if (!persistentStoreCoordinator) {
    if (!managedObjectModel) {
      managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
    }
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
    managedObjectContext = [[NSManagedObjectContext alloc] init];
    [managedObjectContext setPersistentStoreCoordinator:persistentStoreCoordinator];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mocSaved:) name: NSManagedObjectContextDidSaveNotification object:managedObjectContext];
  }
  
  NSError *error = nil;
  NSPersistentStore *ps = nil;
  ps = [persistentStoreCoordinator addPersistentStoreWithType:[request valueOfProperty:zsStoreType] 
                                                configuration:[request valueOfProperty:zsStoreConfiguration] 
                                                          URL:[NSURL fileURLWithPath:filePath] 
                                                      options:nil 
                                                        error:&error];
  
  ZAssert(ps != nil, @"Error loading persistent store: %@", [error localizedDescription]);
  
  [ps setIdentifier:[request valueOfProperty:zsStoreIdentifier]];
  
  BLIPResponse *response = [request response];
  [response setValue:zsActID(zsActionFileReceived) ofProperty:zsAction];
  [response setValue:[ps identifier] ofProperty:zsStoreIdentifier];
  [response send];
}

- (void)mocSaved:(NSNotification*)notification
{
  DLog(@"info %@", [notification userInfo]);
}

- (void)transferStoresToDevice
{
  storeFileIdentifiers = [[NSMutableArray alloc] init];
  
  for (NSPersistentStore *store in [persistentStoreCoordinator persistentStores]) {
    NSData *data = [[NSData alloc] initWithContentsOfFile:[[store URL] path]];
    DLog(@"url %@\nIdentifier: %@\nSize: %i", [store URL], [store identifier], [data length]);
    
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    [dictionary setValue:[store identifier] forKey:zsStoreIdentifier];
    [dictionary setValue:[store configurationName] forKey:zsStoreConfiguration];
    [dictionary setValue:[store type] forKey:zsStoreType];
    [dictionary setValue:zsActID(zsActionStoreUpload) forKey:zsAction];
    
    
    BLIPRequest *request = [BLIPRequest requestWithBody:data properties:dictionary];
    [request setCompressed:YES];
    // TODO: Compression is not working.  Need to find out why
    //[request setCompressed:YES];
    [[self connection] sendRequest:request];
    [data release], data = nil;
    [dictionary release], dictionary = nil;
    
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[[store URL] path] error:&error];
    ZAssert(error == nil, @"Error removing file: %@\n%@", [[store URL] path], [error localizedDescription]);
    
    if (![persistentStoreCoordinator removePersistentStore:store error:&error]) {
      ALog(@"Error removing persistent store: %@", [error localizedDescription]);
    }
    
    DLog(@"file uploaded");
    [storeFileIdentifiers addObject:[store identifier]];
  }
}

- (void)performSync
{
  NSError *error = nil;
  
  ISyncClient *syncClient = [[ISyncManager sharedManager] clientWithIdentifier:[self clientIdentifier]];
  ZAssert(syncClient != nil, @"Sync Client not found");
  
//  NSMutableArray *replaceEntityNames = [NSMutableArray array];
//  for (NSString *entityName in [syncClient enabledEntityNames]) {
//    NSDate *lastSyncDate = [syncClient lastSyncDateForEntityName:entityName];
//    DLog(@"%@ %@", entityName, lastSyncDate);
//    if (!lastSyncDate) {
//      DLog(@"requesting replace on %@", entityName);
//      [replaceEntityNames addObject:entityName];
//    }
//  }
//  [syncClient setShouldReplaceClientRecords:YES forEntityNames:replaceEntityNames];
  
  if (![persistentStoreCoordinator syncWithClient:syncClient inBackground:NO handler:self error:&error]) {
    ALog(@"Error starting sync session: %@", [error localizedDescription]);
  }
  
  ZAssert([managedObjectContext save:&error], @"Error saving context: %@", [error localizedDescription]);
  
  //Sync is complete and saved.  Push the data back to the device.
  [self transferStoresToDevice];
}

- (void)sendDownloadComplete
{
  NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
  [dictionary setValue:zsActID(zsActionCompleteSync) forKey:zsAction];
  
  BLIPRequest *request = [[self connection] requestWithBody:nil properties:dictionary];
  [request setNoReply:YES];
  [dictionary release], dictionary = nil;
  [request send];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [managedObjectContext release], managedObjectContext = nil;
  [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
  [managedObjectModel release], managedObjectModel = nil;
}

#pragma mark -
#pragma mark NSPersistentStoreCoordinatorSyncing

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator*)coordinator didFinishSyncSession:(ISyncSession*)session
{
  DLog(@"sync is complete");
}

- (NSArray *)managedObjectContextsToMonitorWhenSyncingPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator;
{
  return [NSArray arrayWithObject:managedObjectContext];
}

- (NSArray *)managedObjectContextsToReloadAfterSyncingPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator;
{
  return [NSArray arrayWithObject:managedObjectContext];
}

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator willPushChangesInSyncSession:(ISyncSession *)session;
{
  DLog(@"entered");
}

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator didPushChangesInSyncSession:(ISyncSession *)session;
{
  DLog(@"entered");
}

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator willPullChangesInSyncSession:(ISyncSession *)session;
{
  DLog(@"entered");
}

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator didPullChangesInSyncSession:(ISyncSession *)session;
{
  DLog(@"entered");
}

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator didCancelSyncSession:(ISyncSession *)session error:(NSError *)error;
{
  DLog(@"entered");
}

#pragma mark -
#pragma mark BLIPConnectionDelegate

- (void)registerSyncClient:(BLIPRequest*)request
{
  // TODO: Compare version numbers
  ZAssert([request bodyString] != nil, @"Body string is nil in request\n%@", [[request properties] allProperties]);
  
  NSString *clientDescription = [[NSBundle mainBundle] pathForResource:@"clientDescription" ofType:@"plist"];
  ISyncClient *syncClient = [[ISyncManager sharedManager] registerClientWithIdentifier:[request bodyString] descriptionFilePath:clientDescription];
  NSString *displayName = [syncClient displayName];
  displayName = [displayName stringByAppendingFormat:@": %@", [request valueOfProperty:zsDeviceName]];
  [syncClient setDisplayName:displayName];
  DLog(@"display name: %@", [syncClient displayName]);
  
  [syncClient setShouldSynchronize:YES withClientsOfType:ISyncClientTypeApplication];
  [syncClient setShouldSynchronize:YES withClientsOfType:ISyncClientTypeDevice];
  
  BLIPResponse *response = [request response];
  
  if (syncClient) {
    [self setClientIdentifier:[request bodyString]];
    [response setValue:zsActID(zsActionSchemaSupported) ofProperty:zsAction];
    [response send];
    return;
  }
  
  [response setValue:zsActID(zsActionSchemaUnsupported) ofProperty:zsAction];
  [response setBodyString:[NSString stringWithFormat:NSLocalizedString(@"No Sync Client Registered for %@", @"no sync client registered error message"), [request bodyString]]];
  [response setValue:zsActID(zsErrorNoSyncClientRegistered) ofProperty:zsErrorCode];
  [response send];
}

- (BOOL)connectionReceivedCloseRequest:(BLIPConnection*)connection;
{
  DLog(@"entered");
  [connection setDelegate:nil];
  [[ZSyncHandler shared] connectionClosed:self];
  return YES;
}

- (void)connection:(BLIPConnection*)connection receivedResponse:(BLIPResponse*)response;
{
  if (![[response properties] valueOfProperty:zsAction]) {
    DLog(@"received empty response, ignoring");
    return;
  }
  DLog(@"entered\n%@", [[response properties] allProperties]);
  NSInteger action = [[[response properties] valueOfProperty:zsAction] integerValue];
  switch (action) {
    case zsActionFileReceived:
      ZAssert(storeFileIdentifiers != nil, @"zsActionFileReceived with a nil storeFileIdentifiers");
      [storeFileIdentifiers removeObject:[[response properties] valueOfProperty:zsStoreIdentifier]];
      if ([storeFileIdentifiers count] == 0) {
        [self sendDownloadComplete];
        [storeFileIdentifiers release], storeFileIdentifiers = nil;
      }
      break;
    default:
      ALog(@"Unknown action received: %i", action);
      break;
  }
}

- (void)connection:(BLIPConnection*)connection closeRequestFailedWithError:(NSError*)error;
{
  ALog(@"error %@", error);
}

- (BOOL)connection:(BLIPConnection*)connection receivedRequest:(BLIPRequest*)request
{
  DLog(@"entered");
  NSInteger action = [[[request properties] valueOfProperty:zsAction] integerValue];
  BLIPResponse *response = [request response];
  switch (action) {
    case zsActionVerifySchema:
      [self registerSyncClient:request];
      return YES;
    case zsActionRequestPairing:
      [self setPairingCode:[self generatePairingCode]];
      [self showCodeWindow];
      [response setValue:zsActID(zsActionRequestPairing) ofProperty:zsAction];
      [response send];
      return YES;
    case zsActionAuthenticatePairing:
      if ([[self pairingCode] isEqualToString:[request bodyString]]) {
        DLog(@"passed '%@' '%@'", [request bodyString], [self pairingCode]);
        // TODO: Register the unique ID of this service
        [[ZSyncHandler shared] registerDeviceForPairing:[request valueOfProperty:zsDeviceID]];
        [response setValue:zsActID(zsActionAuthenticatePassed) ofProperty:zsAction];
        [response setValue:[[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID] ofProperty:zsServerUUID];
        [response setValue:[[ZSyncHandler shared] serverName] ofProperty:zsServerName];
        [response send];
        [codeController close];
        [codeController release], codeController = nil;
      } else {
        DLog(@"failed '%@' '%@'", [request bodyString], [self pairingCode]);
        [response setValue:zsActID(zsActionAuthenticateFailed) ofProperty:zsAction];
        [response send];
      }
      return YES;
    case zsActionStoreUpload:
      [self addPersistentStore:request];
      return YES;
    case zsActionPerformSync:
      [self performSelector:@selector(performSync) withObject:nil afterDelay:0.01];
      return YES;
    default:
      ALog(@"Unknown action received: %i", action);
      return NO;
  }
}

@end