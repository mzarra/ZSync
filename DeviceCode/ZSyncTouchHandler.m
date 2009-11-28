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

#import "ZSyncTouchHandler.h"
#import "ZSyncShared.h"

#define zsUUIDStringLength 53

@implementation ZSyncTouchHandler

@synthesize delegate, currentAction;

@synthesize serviceBrowser = _serviceBrowser;
@synthesize connection = _connection;


+ (id)shared;
{
  static ZSyncTouchHandler *sharedTouchHandler;
  if (sharedTouchHandler) return sharedTouchHandler;
  @synchronized(sharedTouchHandler) {
    sharedTouchHandler = [[ZSyncTouchHandler alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:sharedTouchHandler 
                                             selector:@selector(applicationWillTerminate:) 
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
  }
  return sharedTouchHandler;
}

- (void)applicationWillTerminate:(NSNotification*)notification
{
  DLog(@"%s closing connection", __PRETTY_FUNCTION__);
  if ([self connection]) {
    [[self connection] close];
  }
  if ([self serviceBrowser]) {
    [[self serviceBrowser] stop];
    [_serviceBrowser release], _serviceBrowser = nil;
  }
}

- (void)requestSync;
{
  if (_serviceBrowser) return; //Already in the middle of something
  
  //Need to find all of the available servers
  _serviceBrowser = [[MYBonjourBrowser alloc] initWithServiceType:zsServiceName];
  [_serviceBrowser start];
  
  // TODO: This sucks.  Has to be a better way
  // No call back from BLIP when it finds servers so we need to poll for now
  [NSTimer scheduledTimerWithTimeInterval:0.10 target:self selector:@selector(services:) userInfo:nil repeats:YES];
}

- (void)cancelPairing;
{
  if (!_connection) return;
  
  //Start a pairing request
  DLog(@"%s sending a pairing cancel", __PRETTY_FUNCTION__);
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  [dictionary setValue:[NSString stringWithFormat:@"%i", zsActionCancelPairing] forKey:zsAction];
  
  NSString *deviceUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsDeviceID];
  if (!deviceUUID) {
    deviceUUID = [[NSProcessInfo processInfo] globallyUniqueString];
    [[NSUserDefaults standardUserDefaults] setValue:deviceUUID forKey:zsDeviceID];
  }
  
  [dictionary setValue:deviceUUID forKey:zsDeviceID];
  
  BLIPRequest *request = [BLIPRequest requestWithBody:nil properties:dictionary];
  [_connection sendRequest:request];
}

- (void)requestPairing:(ZSyncService*)server;
{
  [self setCurrentAction:zsActionRequestPairing];
  MYBonjourService *service = [server service];
  _connection = [[BLIPConnection alloc] initToBonjourService:service];
  [_connection setDelegate:self];
  [_connection open];
}

- (void)authenticatePairing:(NSString*)code;
{
  if (!_connection) return;
  
  //Start a pairing request
  DLog(@"%s sending a pairing code", __PRETTY_FUNCTION__);
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  [dictionary setValue:[NSString stringWithFormat:@"%i", zsActionAuthenticatePairing] forKey:zsAction];
  
  NSString *deviceUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsDeviceID];
  if (!deviceUUID) {
    deviceUUID = [[NSProcessInfo processInfo] globallyUniqueString];
    [[NSUserDefaults standardUserDefaults] setValue:deviceUUID forKey:zsDeviceID];
  }
  [dictionary setValue:deviceUUID forKey:zsDeviceID];

  NSData *codeData = [code dataUsingEncoding:NSUTF8StringEncoding];
  BLIPRequest *request = [BLIPRequest requestWithBody:codeData properties:dictionary];
  [_connection sendRequest:request];
}

- (void)beginSyncWithService:(MYBonjourService*)service
{
  _connection = [[BLIPConnection alloc] initToBonjourService:service];
  [_connection setDelegate:self];
  [_connection open];
}

- (void)services:(NSTimer*)timer
{
  if (![[_serviceBrowser services] count]) {
    // TODO: This should time out at some point
    return;
  }
  [timer invalidate];
  
  NSString *serverUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID];
  
  if (serverUUID) { //See if the server is in this list
    for (MYBonjourService *service in [_serviceBrowser services]) {
      NSString *serverName = [service name];
      NSString *serverUUID = [serverName substringWithRange:NSMakeRange([serverName length] - zsUUIDStringLength, zsUUIDStringLength)];
      DLog(@"%s serverName: %@\nserverUUID: %@", __PRETTY_FUNCTION__, serverName, serverUUID);
      if (![serverUUID isEqualToString:serverUUID]) continue;
      
      //Found our server, start the sync
      [self beginSyncWithService:service];
      [_serviceBrowser stop];
      [_serviceBrowser release], _serviceBrowser = nil;
      return;
    }
    //Did not find our registered server.  Fail
    [[self delegate] zSyncServerUnavailable:self];
    return;
  }
  
  [[self delegate] zSyncNoServerPaired:[self availableServers]];
}

/*
 * We want to start looking for desktops to sync with here.  Once started
 * We want to maintain a list of computers found and also send out a notification
 * for every server that we discover
 */
- (void)startBrowser;
{
  DLog(@"%s starting request", __PRETTY_FUNCTION__);
  if (_serviceBrowser) return;
  _serviceBrowser = [[MYBonjourBrowser alloc] initWithServiceType:zsServiceName];
  [_serviceBrowser start];
  
  [NSTimer scheduledTimerWithTimeInterval:0.10 target:self selector:@selector(services:) userInfo:nil repeats:YES];
}

- (NSArray*)availableServers;
{
  NSMutableSet *set = [NSMutableSet set];
  for (MYBonjourService *bonjourService in [_serviceBrowser services]) {
    NSString *serverName = [bonjourService name];
    NSString *serverUUID = [serverName substringWithRange:NSMakeRange([serverName length] - zsUUIDStringLength, zsUUIDStringLength)];
    serverName = [serverName substringToIndex:([serverName length] - zsUUIDStringLength)];
    
    ZSyncService *zSyncService = [[ZSyncService alloc] init];
    [zSyncService setService:bonjourService];
    [zSyncService setName:serverName];
    [zSyncService setUuid:serverUUID];
    [set addObject:zSyncService];
  }
  
  DLog(@"%s servers %@", __PRETTY_FUNCTION__, set);
  
  NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
  NSArray *result = [set allObjects];
  result = [result sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];
  [sort release], sort = nil;
  
  return result;
}

- (void)uploadRepositoryToServer
{
  
}

#pragma mark -
#pragma mark BLIP Delegate

/* Two possible states at this point. If we have a server UUID
 * then we are ready to start a sync.  If we do not have a server UUID
 * then we need to start a pairing.
 */
- (void)connectionDidOpen:(TCPConnection*)connection 
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  if ([[NSUserDefaults standardUserDefaults] valueForKey:zsServerUUID]) {
    //Start a sync by pushing the data file to the server
    
    [self uploadRepositoryToServer];
  } else {
    //Start a pairing request
    DLog(@"%s sending a pairing request", __PRETTY_FUNCTION__);
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:[NSString stringWithFormat:@"%i", zsActionRequestPairing] forKey:zsAction];
    
    NSString *deviceUUID = [[NSUserDefaults standardUserDefaults] valueForKey:zsDeviceID];
    if (!deviceUUID) {
      deviceUUID = [[NSProcessInfo processInfo] globallyUniqueString];
      [[NSUserDefaults standardUserDefaults] setValue:deviceUUID forKey:zsDeviceID];
    }
    
    [dictionary setValue:deviceUUID forKey:zsDeviceID];
    
    BLIPRequest *request = [BLIPRequest requestWithBody:nil properties:dictionary];
    [_connection sendRequest:request];
  }
}

/* We had an error talking to the server.  Push this error on to our delegate
 * and close the connection
 */
- (void)connection:(TCPConnection*)connection failedToOpen:(NSError*)error
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  [_connection close];
  _connection = nil;
  [[self delegate] zSync:self errorOccurred:error];
}

- (void)connection:(BLIPConnection*)connection receivedResponse:(BLIPResponse*)response;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  NSInteger action = [[[response properties] valueOfProperty:zsAction] integerValue];
  switch (action) {
    case zsActionRequestPairing:
      //Server has accepted the pairing request
      //Notify the delegate to present a pairing dialog
      [[self delegate] zSyncPairingRequestAccepted:self];
      return;
    case zsActionAuthenticatePassed:
      [[self delegate] zSyncPairingCodeApproved:self];
      // TODO: Start the sync
      return;
    case zsActionAuthenticateFailed:
      [[self delegate] zSyncPairingCodeRejected:self];
      return;
    default:
      DLog(@"%s unknown action received %i", __PRETTY_FUNCTION__, action);
      //NSAssert1(NO, @"Unknown action received: %i", action);
  }
}

- (BOOL)connection:(BLIPConnection*)connection receivedRequest:(BLIPRequest*)request
{
  DLog(@"%s entered: %@", __PRETTY_FUNCTION__, [request bodyString]);
  return YES;
}

- (void)connectionDidClose:(TCPConnection*)connection;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

@end

@implementation ZSyncService

@synthesize name;
@synthesize uuid;
@synthesize service;

- (NSString*)description
{
  return [NSString stringWithFormat:@"[%@:%@]", [self name], [self uuid]];
}

- (NSUInteger)hash
{
  return [[self description] hash];
}

- (BOOL)isEqual:(id)object
{
  if (!object || ![object isKindOfClass:[ZSyncService class]]) return NO;
  
  if (![[object name] isEqualToString:[self name]]) return NO;
  if (![[object uuid] isEqualToString:[self uuid]]) return NO;
  
  return YES;
}

@end