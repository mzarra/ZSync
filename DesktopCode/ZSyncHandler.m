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
#import "ZSyncDaemon.h"

#define kRegisteredDeviceArray @"kRegisteredDeviceArray"

@implementation ZSyncHandler

@synthesize delegate = _delegate;
@synthesize connections = _connections;
@synthesize serverName = _serverName;

+ (id)shared;
{
  static ZSyncHandler *zsSharedSyncHandler;
  @synchronized(zsSharedSyncHandler) {
    if (!zsSharedSyncHandler) {
      zsSharedSyncHandler = [[ZSyncHandler alloc] init];
    }
  }
  return zsSharedSyncHandler;
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
  
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@"/Library/Preferences/SystemConfiguration/preferences.plist"];
  [self setServerName:[dict valueForKeyPath:@"System.System.ComputerName"]];
  
  NSString *uuid = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
  if (!uuid) {
    uuid = [[NSProcessInfo processInfo] globallyUniqueString];
    [[NSUserDefaults standardUserDefaults] setValue:uuid forKey:zsServerUUID];
  }
  NSString *broadcastName = [[self serverName] stringByAppendingFormat:@"%@%@", zsServerNameSeperator, uuid];
  
  [_listener setBonjourServiceName:broadcastName];
  [_listener open];
}

- (void)stopBroadcasting;
{
  [_listener close];
  [_listener release], _listener = nil;
}

- (void)listener:(TCPListener*)listener didAcceptConnection:(BLIPConnection*)connection
{
  DLog(@"fired");
  ZSyncConnectionDelegate *delegate = [[ZSyncConnectionDelegate alloc] init];
  [delegate setConnection:connection];
  [connection setDelegate:delegate];
  [[self connections] addObject:delegate];
  [delegate release], delegate = nil;
}

- (void)connection:(TCPConnection*)connection failedToOpen:(NSError*)error
{
  DLog(@"entered");
}

- (void)connectionClosed:(ZSyncConnectionDelegate*)delegate;
{
  [[self connections] removeObject:delegate];
}

- (NSManagedObjectContext*)managedObjectContext
{
  if (managedObjectContext) return managedObjectContext;
  
  NSString *path = [[NSBundle mainBundle] pathForResource:@"ZSyncModel" ofType:@"mom"];
  NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]];
  
  ZAssert(model != nil, @"Failed to find model at path: %@", path);
  
  NSString *basePath = [ZSyncDaemon basePath];
  NSError *error = nil;
  ZAssert([ZSyncDaemon checkBasePath:basePath error:&error], @"Failed to check base path: %@", error);
  
  NSString *filePath = [basePath stringByAppendingPathComponent:@"SyncHistory.sqlite"];
  
  NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
  ZAssert(psc != nil, @"Failed to initialize NSPersistentStoreCoordinator");
  
  ZAssert([psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:filePath] options:nil error:&error], @"Error adding persistent store: %@\n%@", [error localizedDescription], [error userInfo]);
  
  managedObjectContext = [[NSManagedObjectContext alloc] init];
  [managedObjectContext setPersistentStoreCoordinator:psc];
  [psc release], psc = nil;
  [model release], model = nil;
  return managedObjectContext;
}

- (void)unregisterApplication:(NSManagedObject*)applicationObject;
{
  [[self managedObjectContext] deleteObject:applicationObject];
}

- (NSManagedObject*)registerDevice:(NSString*)deviceUUID withName:(NSString*)deviceName;
{
  NSManagedObjectContext *moc = [self managedObjectContext];
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  
  [request setEntity:[NSEntityDescription entityForName:@"Device" inManagedObjectContext:moc]];
  [request setPredicate:[NSPredicate predicateWithFormat:@"uuid == %@", deviceUUID]];
  
  NSError *error = nil;
  id device = [[moc executeFetchRequest:request error:&error] lastObject];
  [request release], request = nil;
  ZAssert(error == nil, @"Failed to retrieve device: %@\n%@", [error localizedDescription], [error userInfo]);
  
  if (!device) {
    device = [NSEntityDescription insertNewObjectForEntityForName:@"Device" inManagedObjectContext:moc];
    [device setValue:deviceUUID forKey:@"uuid"];
  }
  
  [device setValue:deviceName forKey:@"name"];
  return device;
}

- (NSManagedObject*)registerApplication:(NSString*)schema withClient:(NSString*)clientUUID withDevice:(NSManagedObject*)device;
{
  //Find any other clients registered for this device with this schema and remove them
  NSSet *clients = [[device valueForKey:@"applications"] filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"uuid != %@", clientUUID]];
  for (NSManagedObject *client in clients) {
    ISyncClient *syncClient = [[ISyncManager sharedManager] clientWithIdentifier:[client valueForKey:@"uuid"]];
    if (syncClient) {
      [[ISyncManager sharedManager] unregisterClient:syncClient];
    }
    [[self managedObjectContext] deleteObject:client];
  }
  
  id client = [[[device valueForKey:@"applications"] filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"uuid == %@", clientUUID]] anyObject];
  
  if (client) return client;
  
  client = [NSEntityDescription insertNewObjectForEntityForName:@"Application" inManagedObjectContext:[self managedObjectContext]];
  [client setValue:device forKey:@"device"];
  [client setValue:clientUUID forKey:@"uuid"];
  [client setValue:schema forKey:@"schema"];
  
  NSError *error = nil;
  ZAssert([[self managedObjectContext] save:&error], @"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
  
  return client;
}

- (NSBundle*)pluginForSchema:(NSString*)schema;
{
  NSString *pluginPath = [ZSyncDaemon pluginPath];
  DLog(@"pluginPath %@", pluginPath);
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSError *error = nil;
  NSArray *pluginArray = [fileManager contentsOfDirectoryAtPath:pluginPath error:&error];
  ZAssert(pluginArray != nil && error == nil, @"Error fetching plugins: %@\n%@", [error localizedDescription], [error userInfo]);
  
  for (NSString *filename in pluginArray) {
    DLog(@"item found in plugin directory: '%@'", filename);
    if (![filename hasSuffix:@"zsyncPlugin"]) continue;
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

@end