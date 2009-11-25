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

@interface ZSyncHandler ()

- (void)startBroadcasting;
- (void)connectionClosed:(ZSyncConnectionDelegate*)connection;

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
  
  NSString *serverName = [[NSProcessInfo processInfo] hostName];
  
  NSString *uuid = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
  if (!uuid) {
    uuid = [[NSProcessInfo processInfo] globallyUniqueString];
    [[NSUserDefaults standardUserDefaults] setValue:uuid forKey:zsServerUUID];
  }
  
  DLog(@"%s uuid length %i", __PRETTY_FUNCTION__, [uuid length]);
  serverName = [serverName stringByAppendingString:uuid];
  
  [_listener setBonjourServiceName:serverName];
  DLog(@"%s service name: %@", __PRETTY_FUNCTION__, [_listener bonjourServiceName]);
  [_listener open];
  NSLog(@"%@ is listening...", self);
}

- (void)stopBroadcasting;
{
  [_listener close];
  [_listener release], _listener = nil;
}

- (void)listener:(TCPListener*)listener didAcceptConnection:(BLIPConnection*)connection
{
  DLog(@"%s entered %x", __PRETTY_FUNCTION__, connection);
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

@end

@implementation ZSyncConnectionDelegate

@synthesize connection = _connection;
@synthesize pairingCode;

- (void)dealloc
{
  DLog(@"%s delegate releasing", __PRETTY_FUNCTION__);
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

- (BOOL)connectionReceivedCloseRequest:(BLIPConnection*)connection;
{
  DLog(@"%s closing", __PRETTY_FUNCTION__);
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
    case zsActionRequestPairing:
      [self setPairingCode:[self generatePairingCode]];
      [response setValue:[NSString stringWithFormat:@"%i", zsActionRequestPairing] ofProperty:zsAction];
      [response send];
      
      return YES;
    case zsActionAuthenticatePairing:
      if ([[self pairingCode] isEqualToString:[request bodyString]]) {
      } else {
        [response setValue:[NSString stringWithFormat:@"%i", zsActionAuthenticateFailed] ofProperty:zsAction];
        [response send];
      }
    default:
      NSAssert1(NO, @"Unknown action received: %i", action);
      return NO;
  }
}

@end