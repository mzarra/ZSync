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

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

#define kDomainName @"local."
#define kServiceName @"_zsync._tcp"
//TODO Change this to reflect a unique name of the machine
#define kServerName @"ZSyncServer" 

@interface ZSyncHandler () <NSNetServiceDelegate>

- (void)startBroadcasting;

@end

@implementation ZSyncHandler

static ZSyncHandler *zsSharedSyncHandler;

@synthesize listeningHandle;
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
  /* TODO: This probably needs to be handled async */
  NSFileHandle *handle = [[notification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];
  NSData *data = [handle readDataToEndOfFile];
  NSString *test = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  DLog(@"%s string received %@", __PRETTY_FUNCTION__, test);
  [test release];
  
  /* Each connection causes the socket to stop listening */
  [listeningHandle acceptConnectionInBackgroundAndNotify];
}

- (void)startBroadcasting;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  [[NSNotificationCenter defaultCenter] addObserver:self 
                                           selector:@selector(connectionReceived:) 
                                               name:NSFileHandleConnectionAcceptedNotification 
                                             object:nil];
  
  uint16_t chosenPort = 0;
  
  int fdForListening;
  struct sockaddr_in serverAddress;
  socklen_t namelen = sizeof(serverAddress);
  
  fdForListening = socket(AF_INET, SOCK_STREAM, 0);
  NSAssert(fdForListening > 0, @"Error creating socket");
  
  memset(&serverAddress, 0, sizeof(serverAddress));
  serverAddress.sin_family = AF_INET;
  serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
  serverAddress.sin_port = 0; /* TODO: Need to set this at some point (probably) */
  
  if (bind(fdForListening, (struct sockaddr *)&serverAddress, sizeof(serverAddress)) < 0) {
    close(fdForListening);
    ALog(@"%s failed to create service", __PRETTY_FUNCTION__);
    return;
  }
  
  // Find out what port number was chosen for us.
  if (getsockname(fdForListening, (struct sockaddr *)&serverAddress, &namelen) < 0) {
    close(fdForListening);
    ALog(@"%s failed to get port number", __PRETTY_FUNCTION__);
    return;
  }
  
  chosenPort = ntohs(serverAddress.sin_port);
  
  if(listen(fdForListening, 1) == 0) {
    listeningHandle = [[NSFileHandle alloc] initWithFileDescriptor:fdForListening 
                                                    closeOnDealloc:YES];
  }
  
  serverService = [[NSNetService alloc] initWithDomain:kDomainName 
                                                  type:kServiceName 
                                                  name:kServerName 
                                                  port:chosenPort];
  
  [serverService setDelegate:self];
  [listeningHandle acceptConnectionInBackgroundAndNotify];
  [serverService publish];
  
}

- (void)stopBroadcasting;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  [serverService stop];
  [serverService release], serverService = nil;
  [listeningHandle release], listeningHandle = nil;
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
