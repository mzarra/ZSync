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

