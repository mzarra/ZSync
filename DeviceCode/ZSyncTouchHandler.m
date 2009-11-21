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

@implementation ZSyncTouchHandler

@synthesize delegate;

+ (id)shared;
{
  static ZSyncTouchHandler *sharedTouchHandler;
  if (sharedTouchHandler) return sharedTouchHandler;
  @synchronized(sharedTouchHandler) {
    sharedTouchHandler = [[ZSyncTouchHandler alloc] init];
  }
  return sharedTouchHandler;
}

- (void)requestSync;
{
  if (_serviceBrowser) return; //Already in the middle of something
  
  //Need to find all of the available servers
  _serviceBrowser = [[MYBonjourBrowser alloc] initWithServiceType:kZSyncServiceName];
  [_serviceBrowser start];
  
  // TODO: This sucks.  Has to be a better way
  // No call back from BLIP when it finds servers so we need to poll for now
  [NSTimer scheduledTimerWithTimeInterval:0.10 target:self selector:@selector(services:) userInfo:nil repeats:YES];
}

- (void)requestPairing:(ZSyncService*)server;
{
  MYBonjourService *service = [server service];
  _connection = [[BLIPConnection alloc] initToBonjourService:service];
  [_connection setDelegate:self];
  [_connection open];
}

- (BOOL)authenticatePairing:(NSString*)code;
{
  return YES;
}

- (void)services:(NSTimer*)timer
{
  if (![[_serviceBrowser services] count]) return;
  [timer invalidate];
  
  NSString *serverUUID = [[NSUserDefaults standardUserDefaults] valueForKey:kZSyncServerUUID];
  if (serverUUID) { //See if the server is in this list
    for (MYBonjourService *service in [_serviceBrowser services]) {
      NSString *serverName = [service name];
      NSString *serverUUID = [serverName substringWithRange:NSMakeRange([serverName length] - 58, 58)];
      if (![serverUUID isEqualToString:serverUUID]) continue;
      
      //Found our server, start the sync
      [self beginSyncWithService:service];
      [_serviceBrowser stop];
      [_serviceBrowser release], _serviceBrowser = nil;
      return;
    }
  }
  
  NSMutableArray *array = [NSMutableArray array];
  for (MYBonjourService *bonjourService in [_serviceBrowser services]) {
    NSString *serverName = [bonjourService name];
    NSString *serverUUID = [serverName substringWithRange:NSMakeRange([serverName length] - 58, 58)];
    serverName = [serverName substringToIndex:([serverName length] - 58)];
    
    ZSyncService *zSyncService = [[ZSyncService alloc] init];
    [zSyncService setService:bonjourService];
    [zSyncService setName:serverName];
    [zSyncService setUuid:serverUUID];
    [array addObject:zSyncService];
  }
  
  [_serviceBrowser stop];
  [_serviceBrowser release], _serviceBrowser = nil;
  
  [[self delegate] zSyncNoServerFound:array];
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
  _serviceBrowser = [[MYBonjourBrowser alloc] initWithServiceType:kZSyncServiceName];
  [_serviceBrowser start];
  
  [NSTimer scheduledTimerWithTimeInterval:0.10 target:self selector:@selector(services:) userInfo:nil repeats:YES];
}

#pragma mark -
#pragma mark BLIP Delegate

- (void)connectionDidOpen:(TCPConnection*)connection 
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  
  NSData *imageData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"MyBike" ofType:@"jpg"]];
  DLog(@"%s length %i", __PRETTY_FUNCTION__, [imageData length]);
  BLIPRequest *request = [BLIPRequest requestWithBody:imageData];
  [_connection sendRequest:request];
}

- (void)connection:(BLIPConnection*)connection receivedResponse:(BLIPResponse*)response;
{
  DLog(@"%s response %@", __PRETTY_FUNCTION__, [response bodyString]);
}

- (void)connection:(TCPConnection*)connection failedToOpen:(NSError*)error
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
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

@end