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
#import "NSSocket+ZSExtensions.h"

#define kDomainName @"local."
#define kServiceName @"_zsync._tcp"
//TODO Change this to reflect a unique name of the machine
#define kServerName @"ZSyncServer" 

@interface ZSyncHandler () <NSNetServiceDelegate>

- (void)startBroadcasting;

@end

@implementation ZSyncHandler

static ZSyncHandler *zsSharedSyncHandler;

@synthesize receiveSocket;
@synthesize serverConnection;
@synthesize serverService;

+ (id)shared;
{
  @synchronized(zsSharedSyncHandler) {
    if (!zsSharedSyncHandler) {
      zsSharedSyncHandler = [[ZSyncHandler alloc] init];
    }
    return zsSharedSyncHandler;
  }
}

- (id)init
{
  if (zsSharedSyncHandler) {
    NSAssert(NO, @"Attempt to initialize second handler");
    [self autorelease];
    return zsSharedSyncHandler;
  }
  if (!(self = [super init])) return nil;
  
  return self;
}

- (void)connectionReceived:(NSNotification*)notification
{
  DLog(@"%s Received a connection", __PRETTY_FUNCTION__);
}

- (void)startBroadcasting;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  receiveSocket = [[NSSocketPort alloc] init];
  
  serverConnection = [[NSConnection alloc] initWithReceivePort:receiveSocket sendPort:nil];
  [serverConnection setRootObject:self];
  
  serverService = [[NSNetService alloc] initWithDomain:kDomainName type:kServiceName name:kServerName port:[receiveSocket port]];
  
  [serverService setDelegate:self];
  [serverService publish];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionReceived:) name:NSFileHandleConnectionAcceptedNotification object:receiveSocket];
}

- (void)stopBroadcasting;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  [serverService stop];
  [serverService release], serverService = nil;
  [serverConnection release], serverConnection = nil;
  [receiveSocket release], receiveSocket = nil;
}

#pragma mark -
#pragma mark NSNetServiceDelegate

- (void)netServiceWillPublish:(NSNetService *)sender
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)netServiceWillResolve:(NSNetService *)sender
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)netServiceDidStop:(NSNetService *)sender
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)netServiceDidPublish:(NSNetService *)sender
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

@end
