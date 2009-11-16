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

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

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
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  /* TODO: This probably needs to be handled async */
  NSFileHandle *handle = [[notification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];
  DLog(@"%s handle received", __PRETTY_FUNCTION__);
  NSData *data = [handle readDataToEndOfFile];
  DLog(@"%s data read", __PRETTY_FUNCTION__);
  NSString *test = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  DLog(@"%s string received %@", __PRETTY_FUNCTION__, test);
  [test release];

  //[handle writeData:[@"ack" dataUsingEncoding:NSUTF8StringEncoding]];
  
  /* Each connection causes the socket to stop listening */
  [listeningHandle acceptConnectionInBackgroundAndNotify];
}

- (void)startReceiver
{
  /* Set up the receiving service */
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
  [[NSNotificationCenter defaultCenter] addObserver:self 
                                           selector:@selector(connectionReceived:) 
                                               name:NSFileHandleConnectionAcceptedNotification 
                                             object:listeningHandle];
  
  listeningService = [[NSNetService alloc] initWithDomain:kDomainName 
                                                     type:kReceivingServiceName 
                                                     name:kReceivingServerName 
                                                     port:chosenPort];
  
  [listeningService setDelegate:self];
  [listeningHandle acceptConnectionInBackgroundAndNotify];
  [listeningService publish];
}

- (void)startSender
{
  /* Set up the receiving service */
  uint16_t chosenPort = 0;
  
  int fdForSending;
  struct sockaddr_in serverAddress;
  socklen_t namelen = sizeof(serverAddress);
  
  fdForSending = socket(AF_INET, SOCK_STREAM, 0);
  NSAssert(fdForSending > 0, @"Error creating socket");
  
  memset(&serverAddress, 0, sizeof(serverAddress));
  serverAddress.sin_family = AF_INET;
  serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
  serverAddress.sin_port = 0; /* TODO: Need to set this at some point (probably) */
  
  if (bind(fdForSending, (struct sockaddr *)&serverAddress, sizeof(serverAddress)) < 0) {
    close(fdForSending);
    ALog(@"%s failed to create service", __PRETTY_FUNCTION__);
    return;
  }
  
  // Find out what port number was chosen for us.
  if (getsockname(fdForSending, (struct sockaddr *)&serverAddress, &namelen) < 0) {
    close(fdForSending);
    ALog(@"%s failed to get port number", __PRETTY_FUNCTION__);
    return;
  }
  
  chosenPort = ntohs(serverAddress.sin_port);
  
  if(listen(fdForSending, 1) == 0) {
    sendingHandle = [[NSFileHandle alloc] initWithFileDescriptor:fdForSending 
                                                    closeOnDealloc:YES];
  }
  [[NSNotificationCenter defaultCenter] addObserver:self 
                                           selector:@selector(sendConnectionReceived:) 
                                               name:NSFileHandleConnectionAcceptedNotification 
                                             object:sendingHandle];
  
  sendingService = [[NSNetService alloc] initWithDomain:kDomainName 
                                                   type:kSendingServiceName 
                                                   name:kSendingServerName 
                                                   port:chosenPort];
  
  [sendingService setDelegate:self];
  [sendingHandle acceptConnectionInBackgroundAndNotify];
  [sendingService publish];
}

- (void)startBroadcasting;
{
  [self startReceiver];
  [self startSender];
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
