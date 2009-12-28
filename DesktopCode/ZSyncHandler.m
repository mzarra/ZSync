/*
 *  ZSyncHandler.m
 *  ZSync
 *
 *  Created by Marcus S. Zarra on 11/8/09.
 *  Copyright 2009 Zarra Studios, LLC. All rights reserved.
 *
 *  Permission is hereby granted, free of charge, to any person
 *  obtaining a copy of this software and associated documentation
 *  files (the "Software"), to deal in the Software without
 *  restriction, including without limitation the rights to use,
 *  copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following
 *  conditions:
 *
 *  The above copyright notice and this permission notice shall be
 *  included in all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 *  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 *  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 *  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 *  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 *  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 *  OTHER DEALINGS IN THE SOFTWARE.
 */

#import "ZSyncHandler.h"
#import "ZSyncShared.h"

#import "PairingCodeWindowController.h"

#define kRegisteredDeviceArray @"kRegisteredDeviceArray"

@interface ZSyncHandler ()

- (void)startBroadcasting;
- (void)connectionClosed:(ZSyncConnectionDelegate*)connection;
- (void)registerDeviceForPairing:(NSString*)deviceID;

@end

@implementation ZSyncHandler

@synthesize delegate = _delegate;
@synthesize connections = _connections;

+ (id)shared;
{
  static ZSyncHandler *zsSharedSyncHandler;
  @synchronized(zsSharedSyncHandler) {
    if (!zsSharedSyncHandler) {
      zsSharedSyncHandler = [[ZSyncHandler alloc] init];
    }
    return zsSharedSyncHandler;
  }
}

- (NSMutableArray*)connections
{
  if (_connections) return _connections;
  _connections = [[NSMutableArray alloc] init];
  return _connections;
}

- (void)startBroadcasting;
{
  _listener = [[BLIPListener alloc] initWithPort: 1123];
  [_listener setDelegate:self];
  [_listener setPickAvailablePort:YES];
  [_listener setBonjourServiceType:zsServiceName];
  
//  NSString *serverName = [[NSProcessInfo processInfo] hostName];
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/Library/Preferences/SystemConfiguration/preferences.plist"];
  NSString *serverName = [dict valueForKeyPath:@"System.System.ComputerName"];
  
  NSString *uuid = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
  if (!uuid) {
    uuid = [[NSProcessInfo processInfo] globallyUniqueString];
    [[NSUserDefaults standardUserDefaults] setValue:uuid forKey:zsServerUUID];
  }
  serverName = [serverName stringByAppendingString:uuid];
  
  [_listener setBonjourServiceName:serverName];
  [_listener open];
}

- (void)stopBroadcasting;
{
  [_listener close];
  [_listener release], _listener = nil;
}

- (void)listener:(TCPListener*)listener didAcceptConnection:(BLIPConnection*)connection
{
  ZSyncConnectionDelegate *delegate = [[ZSyncConnectionDelegate alloc] init];
  [delegate setConnection:connection];
  [connection setDelegate:delegate];
  [[self connections] addObject:delegate];
  [delegate release], delegate = nil;
}

- (void)connection:(TCPConnection*)connection failedToOpen:(NSError*)error
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)connectionClosed:(ZSyncConnectionDelegate*)delegate;
{
  [[self connections] removeObject:delegate];
}

/* This is a place holder for now.  We will be moving this into a Core
 * Data database so that we can track information such as last sync, etc.
 */
- (void)registerDeviceForPairing:(NSString*)deviceID;
{
  @synchronized (self) {
    NSMutableArray *array = [[[NSUserDefaults standardUserDefaults] valueForKey:kRegisteredDeviceArray] mutableCopy];
    if (!array) {
      array = [[NSMutableArray alloc] init];
    }
    [array addObject:deviceID];
    [[NSUserDefaults standardUserDefaults] setObject:array forKey:kRegisteredDeviceArray];
    [array release], array = nil;
  }
}

@end

@implementation ZSyncConnectionDelegate

@synthesize connection = _connection;
@synthesize pairingCode;

// TODO: Need to move this out of here
@synthesize codeController;

- (void)dealloc
{
  DLog(@"%s Releasing", __PRETTY_FUNCTION__);
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
  NSString *filePath = NSTemporaryDirectory();
  filePath = [filePath stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  filePath = [filePath stringByAppendingPathExtension:@"zsync"];
  [[request body] writeToFile:filePath atomically:YES];
  
  if (!persistentStoreCoordinator) {
    if (!managedObjectModel) {
      managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
    }
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
  }
  
  NSError *error = nil;
  NSPersistentStore *persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:[request valueOfProperty:zsStoreType] configuration:[request valueOfProperty:zsStoreConfiguration] URL:[NSURL fileURLWithPath:filePath] options:nil error:&error];
  
  NSAssert1(persistentStore != nil, @"Error loading persistent store: %@", [error localizedDescription]);
  
  [persistentStore setIdentifier:[request valueOfProperty:zsStoreIdentifier]];
}

- (void)performSync
{
  // TODO: This identifier needs to be based per plugin
  ISyncClient *syncClient = [[ISyncManager sharedManager] clientWithIdentifier:@"com.zarrastudios.ZSync"];
  NSError *error = nil;
  if (![persistentStoreCoordinator syncWithClient:syncClient inBackground:YES handler:self error:&error]) {
    NSAssert1(NO, @"Error starting sync session: %@", [error localizedDescription]);
  }
}

#pragma mark -
#pragma mark NSPersistentStoreCoordinatorSyncing

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator*)coordinator 
              didFinishSyncSession:(ISyncSession*)session
{
  DLog(@"%s sync complete", __PRETTY_FUNCTION__);
  
  NSArray *stores = [persistentStoreCoordinator persistentStores];
  for (NSPersistentStore *store in stores) {
    DLog(@"%s url %@\nIdentifier: %@", __PRETTY_FUNCTION__, [store URL], [store identifier]);
    NSData *data = [[NSData alloc] initWithContentsOfMappedFile:[[store URL] path]];
    
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    [dictionary setValue:[store identifier] forKey:zsStoreIdentifier];
    [dictionary setValue:[store configurationName] forKey:zsStoreConfiguration];
    [dictionary setValue:[store type] forKey:zsStoreType];
    [dictionary setValue:zsActID(zsActionStoreUpload) forKey:zsAction];
    
    BLIPRequest *request = [BLIPRequest requestWithBody:data properties:dictionary];
    // TODO: Compression is not working.  Need to find out why
    //[request setCompressed:YES];
    [[self connection] sendRequest:request];
    [data release], data = nil;
    [dictionary release], dictionary = nil;
    
    [[NSFileManager defaultManager] removeFileAtPath:[[store URL] path] handler:nil];
    NSError *error = nil;
    if (![persistentStoreCoordinator removePersistentStore:store error:&error]) {
      NSAssert1(NO, @"Error removing persistent store: %@", [error localizedDescription]);
    }
    
    DLog(@"%s file uploaded", __PRETTY_FUNCTION__);
  }
  
  NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
  [dictionary setValue:zsActID(zsActionCompleteSync) forKey:zsAction];
  BLIPRequest *request = [BLIPRequest requestWithBody:nil properties:dictionary];
  [[self connection] sendRequest:request];
  [dictionary release], dictionary = nil;
  
  //Clean up the persistent store and prep for release
  [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
  [managedObjectModel release], managedObjectModel = nil;
}

#pragma mark -
#pragma mark BLIPConnectionDelegate

- (BOOL)connectionReceivedCloseRequest:(BLIPConnection*)connection;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  [connection setDelegate:nil];
  [[ZSyncHandler shared] connectionClosed:self];
  return YES;
}

- (void)connection:(BLIPConnection*)connection receivedResponse:(BLIPResponse*)response;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)connection:(BLIPConnection*)connection closeRequestFailedWithError:(NSError*)error;
{
  DLog(@"%s error %@", __PRETTY_FUNCTION__, error);
}

- (BOOL)connection:(BLIPConnection*)connection receivedRequest:(BLIPRequest*)request
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  NSInteger action = [[[request properties] valueOfProperty:zsAction] integerValue];
  BLIPResponse *response = [request response];
  switch (action) {
    case zsActionVerifySchema:
      // TODO: Compare schema string and version numbers
      
      [response setValue:zsActID(zsActionSchemaSupported) ofProperty:zsAction];
      [response send];
      
      return YES;
    case zsActionRequestPairing:
      [self setPairingCode:[self generatePairingCode]];
      [self showCodeWindow];
      [response setValue:zsActID(zsActionRequestPairing) ofProperty:zsAction];
      [response send];
      
      return YES;
    case zsActionAuthenticatePairing:
      if ([[self pairingCode] isEqualToString:[request bodyString]]) {
        DLog(@"%s passed '%@' '%@'", __PRETTY_FUNCTION__, [request bodyString], [self pairingCode]);
        // TODO: Register the unique ID of this service
        [[ZSyncHandler shared] registerDeviceForPairing:[request valueOfProperty:zsDeviceID]];
        [response setValue:zsActID(zsActionAuthenticatePassed) ofProperty:zsAction];
        [response send];
        [codeController close];
        [codeController release], codeController = nil;
      } else {
        DLog(@"%s failed '%@' '%@'", __PRETTY_FUNCTION__, [request bodyString], [self pairingCode]);
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
      NSAssert1(NO, @"Unknown action received: %i", action);
      return NO;
  }
}

@end