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

#import "ZSyncDaemon.h"
#import "ZSyncHandler.h"
#import "ZSyncShared.h"

#define kRegisteredDeviceArray @"kRegisteredDeviceArray"

@implementation ZSyncHandler

@synthesize delegate = _delegate;
@synthesize connections = _connections;
@synthesize serverName = _serverName;
@synthesize listener = _listener;

#pragma mark -
#pragma mark Class methods

+ (id)shared;
{
  static ZSyncHandler *zsSharedSyncHandler;
  @synchronized(zsSharedSyncHandler)
  {
    if (!zsSharedSyncHandler) {
      zsSharedSyncHandler = [[ZSyncHandler alloc] init];
    }
  }

  return zsSharedSyncHandler;
}

#pragma mark -
#pragma mark Overridden getters/setters

- (NSMutableArray *)connections
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  if (_connections) {
    return _connections;
  }

  _connections = [[NSMutableArray alloc] init];

  return _connections;
}

- (NSManagedObjectContext *)managedObjectContext
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  if (managedObjectContext) {
    return managedObjectContext;
  }

  NSString *managedObjectModelPath = [[NSBundle mainBundle] pathForResource:@"ZSyncModel" ofType:@"mom"];
  NSManagedObjectModel *managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:managedObjectModelPath]];

  ZAssert(managedObjectModel != nil, @"Failed to find model at path: %@", managedObjectModelPath);

  NSString *basePath = [ZSyncDaemon basePath];
  NSError *error = nil;
  ZAssert([ZSyncDaemon checkBasePath:basePath error:&error], @"Failed to check base path: %@", error);

  NSString *filePath = [basePath stringByAppendingPathComponent:@"SyncHistory.sqlite"];

  NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
  ZAssert(persistentStoreCoordinator != nil, @"Failed to initialize NSPersistentStoreCoordinator");

  ZAssert([persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:filePath] options:nil error:&error], @"Error adding persistent store: %@\n%@", [error localizedDescription], [error userInfo]);

  managedObjectContext = [[NSManagedObjectContext alloc] init];
  [managedObjectContext setPersistentStoreCoordinator:persistentStoreCoordinator];
  [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
  [managedObjectModel release], managedObjectModel = nil;

  return managedObjectContext;
}

- (BLIPListener *)listener
{
  if (!_listener) {
    _listener = [[BLIPListener alloc] initWithPort:1123];
    [_listener setDelegate:self];
    [_listener setPickAvailablePort:YES];
    [_listener setBonjourServiceType:zsServiceName];
  }

  return _listener;
}

#pragma mark -
#pragma mark Local methods

- (void)startBroadcasting;
{
  DLog(@"%s", __PRETTY_FUNCTION__);

  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/Library/Preferences/SystemConfiguration/preferences.plist"];
  [self setServerName:[dict valueForKeyPath:@"System.System.ComputerName"]];

  NSString *serverUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
  if (!serverUUID) {
    serverUUID = [[NSProcessInfo processInfo] globallyUniqueString];
    [[NSUserDefaults standardUserDefaults] setValue:serverUUID forKey:zsServerUUID];
  }

  [[self listener] setBonjourServiceName:@""];
  [[self listener] open];

  NSDictionary *txtRecordDictionary = [NSDictionary dictionaryWithObjectsAndKeys:serverUUID, zsServerUUID, [self serverName], zsServerName, nil];
  [[self listener] setBonjourTXTRecord:txtRecordDictionary];
}

- (void)stopBroadcasting;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [[self listener] close];
  [self setListener:nil];
}

- (void)connectionClosed:(ZSyncConnectionDelegate *)connectionDelegate;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [[self connections] removeObject:connectionDelegate];
}

- (void)unregisterApplication:(NSManagedObject *)applicationObject;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  [[self managedObjectContext] deleteObject:applicationObject];
}

- (NSManagedObject *)registerDevice:(NSString *)deviceUUID withName:(NSString *)deviceName;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSManagedObjectContext *moc = [self managedObjectContext];
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];

  [fetchRequest setEntity:[NSEntityDescription entityForName:@"Device" inManagedObjectContext:moc]];
  [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"uuid == %@", deviceUUID]];

  NSError *error = nil;
  id device = [[moc executeFetchRequest:fetchRequest error:&error] lastObject];
  [fetchRequest release], fetchRequest = nil;
  ZAssert(error == nil, @"Failed to retrieve device: %@\n%@", [error localizedDescription], [error userInfo]);

  if (!device) {
    device = [NSEntityDescription insertNewObjectForEntityForName:@"Device" inManagedObjectContext:moc];
    [device setValue:deviceUUID forKey:@"uuid"];
  }

  [device setValue:deviceName forKey:@"name"];
  return device;
}

- (NSManagedObject *)registerApplication:(NSString *)schema withClient:(NSString *)clientUUID withDevice:(NSManagedObject *)device;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  // Find any other clients registered for this device with this schema and remove them
  NSSet *clients = [[device valueForKey:@"applications"] filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"uuid != %@", clientUUID]];
  for (NSManagedObject *client in clients) {
    ISyncClient *syncClient = [[ISyncManager sharedManager] clientWithIdentifier:[client valueForKey:@"uuid"]];
    if (syncClient) {
      [[ISyncManager sharedManager] unregisterClient:syncClient];
    }
    [[self managedObjectContext] deleteObject:client];
  }

  id client = [[[device valueForKey:@"applications"] filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"uuid == %@", clientUUID]] anyObject];

  if (client) {
    return client;
  }

  client = [NSEntityDescription insertNewObjectForEntityForName:@"Application" inManagedObjectContext:[self managedObjectContext]];
  [client setValue:device forKey:@"device"];
  [client setValue:clientUUID forKey:@"uuid"];
  [client setValue:schema forKey:@"schema"];

  NSError *error = nil;
  ZAssert([[self managedObjectContext] save:&error], @"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);

  return client;
}

- (NSBundle *)pluginForSchema:(NSString *)schema;
{
  DLog(@"%s", __PRETTY_FUNCTION__);
  NSString *pluginPath = [ZSyncDaemon pluginPath];
  DLog(@"pluginPath %@", pluginPath);

  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSError *error = nil;
  NSArray *pluginArray = [fileManager contentsOfDirectoryAtPath:pluginPath error:&error];
  ZAssert(pluginArray != nil && error == nil, @"Error fetching plugins: %@\n%@", [error localizedDescription], [error userInfo]);

  for (NSString *filename in pluginArray) {
    DLog(@"item found in plugin directory: '%@'", filename);
    if (![filename hasSuffix:@"zsyncPlugin"]) {
      continue;
    }
    NSString *pluginResourcePath = [pluginPath stringByAppendingPathComponent:filename];
    NSBundle *bundle = [NSBundle bundleWithPath:pluginResourcePath];
    NSString *schemaID = [[bundle infoDictionary] objectForKey:zsSchemaIdentifier];
    if ([[schemaID lowercaseString] isEqualToString:[schema lowercaseString]]) {
      DLog(@"plugin for '%@' found at %@", schema, pluginResourcePath);
      return bundle;
    }
  }

  DLog(@"failed to find plugin for schema '%@'", schema);
  return nil;
}

#pragma mark -
#pragma mark TCPListenerDelegate methods

- (void)listener:(TCPListener *)listener didAcceptConnection:(BLIPConnection *)connection
{
  DLog(@"%s fired", __PRETTY_FUNCTION__);
  ZSyncConnectionDelegate *connectionDelegate = [[ZSyncConnectionDelegate alloc] init];
  [connectionDelegate setConnection:connection];
  [connection setDelegate:connectionDelegate];
  [[self connections] addObject:connectionDelegate];
  [connectionDelegate release], connectionDelegate = nil;
}

#pragma mark -
#pragma mark BLIPConnectionDelegate methods

- (void)connection:(TCPConnection *)connection failedToOpen:(NSError *)error
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

#pragma mark -

@end