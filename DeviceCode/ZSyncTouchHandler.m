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

@synthesize socketHandle;
@synthesize outputStream;
@synthesize dataToPush;

static ZSyncTouchHandler *sharedTouchHandler;

+ (id)shared;
{
  if (sharedTouchHandler) return sharedTouchHandler;
  @synchronized(sharedTouchHandler) {
    sharedTouchHandler = [[ZSyncTouchHandler alloc] init];
  }
  return sharedTouchHandler;
}

/* 
 * This is called once we have both the sending and the receiving socket configured.
 */
- (void)beginConversation
{
  
}

/*
 * We want to start looking for desktops to sync with here.  Once started
 * We want to maintain a list of computers found and also send out a notification
 * for every server that we discover
 */
- (void)startBrowser;
{
  if (netServiceBrowser) return; //Already browsing
  DLog(@"%s starting browser", __PRETTY_FUNCTION__);
  
  NSString *testString = @"Test String";
  dataToPush = [[testString dataUsingEncoding:NSUTF8StringEncoding] retain];
  byteOffset = 0;
  
  netServiceBrowser = [[NSNetServiceBrowser alloc] init];
  [netServiceBrowser setDelegate:self]; 
  [netServiceBrowser searchForServicesOfType:kReceivingServiceName 
                                    inDomain:kDomainName];
}

- (void)netServiceBrowser:(NSNetServiceBrowser*)browser 
           didFindService:(NSNetService*)service 
               moreComing:(BOOL)more
{
  DLog(@"%s Service found", __PRETTY_FUNCTION__);
  
  if (!receiveService) { /* Looking for a receive service first */
    receiveService = [service retain];
    [receiveService setDelegate:self];
    //[receiveService resolveWithTimeout:5.0];
    //[receiveService startMonitoring];
    [service getInputStream:nil outputStream:&outputStream];
    
    [outputStream retain];
    [outputStream setDelegate:self];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream open];
    
    [netServiceBrowser stop];
    
    [netServiceBrowser searchForServicesOfType:kReceivingServiceName 
                                      inDomain:kDomainName];
  } else { /* Finding send services now */
    if (![[receiveService hostName] isEqualToString:[service hostName]]) {
      DLog(@"%s Not the sender we were looking for", __PRETTY_FUNCTION__);
      return;
    }
    sendService = [service retain];
    [sendService setDelegate:self];
    [service getInputStream:&inputStream outputStream:nil];
    
    [inputStream retain];
    [inputStream setDelegate:self];
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [inputStream open];
    
    [netServiceBrowser stop];
    [netServiceBrowser release], netServiceBrowser = nil;
  }
  if (receiveService && sendService) {
    [self beginConversation];
  }
}

- (void)netServiceDidResolveAddress:(NSNetService*)service
{
  DLog(@"%s service name %@ on %@", __PRETTY_FUNCTION__, [service name], [service hostName]);
  
//  NSAssert(inputStream != nil, @"input stream is nil");
  
  
//  [inputStream retain];
//  [inputStream setDelegate:self];
//  [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
//  [inputStream open];
  
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)event {
  NSInteger bytesWritten = 0;
  NSUInteger bytesRemaining = [dataToPush length] - byteOffset;
  uint8_t buffer;
  switch (event) {
    case NSStreamEventOpenCompleted:
      DLog(@"%s open", __PRETTY_FUNCTION__);
      break;
    case NSStreamEventHasBytesAvailable:
    {
      DLog(@"%s has bytes", __PRETTY_FUNCTION__);
      
      NSInteger bytesRead;
      uint8_t buffer[32768];
      
      bytesRead = [inputStream read:buffer maxLength:sizeof(buffer)];
      if (bytesRead == -1) {
        DLog(@"%s error reading stream", __PRETTY_FUNCTION__);
      } else if (bytesRead == 0) {
        DLog(@"%s completed read", __PRETTY_FUNCTION__);
        NSString *test = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
        DLog(@"%s test is %@", __PRETTY_FUNCTION__, test);
        [test release], test = nil;
      } else {
        if (!receivedData) receivedData = [[NSMutableData alloc] init];
        [receivedData appendBytes:buffer length:bytesRead];
        DLog(@"%s bytes read %i", __PRETTY_FUNCTION__, bytesRead);
      }
      
      break;
    }
    case NSStreamEventHasSpaceAvailable:
      DLog(@"%s has space", __PRETTY_FUNCTION__);
      [dataToPush getBytes:&buffer range:NSMakeRange(byteOffset, bytesRemaining)];
      bytesWritten = [outputStream write:&buffer maxLength:bytesRemaining];
      NSAssert(bytesWritten != 0, @"failed to write bytes");
      if (bytesWritten == -1) {
        ALog(@"%s Network error", __PRETTY_FUNCTION__);
      }
      byteOffset += bytesWritten;
      DLog(@"%s wrote %i of %i", __PRETTY_FUNCTION__, byteOffset, [dataToPush length]);
      if (byteOffset >= [dataToPush length]) {
        [outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [outputStream setDelegate:nil];
        [outputStream close];
        [outputStream release];
        outputStream = nil;
        DLog(@"%s stream complete", __PRETTY_FUNCTION__);
      }
      break;
    case NSStreamEventErrorOccurred:
      DLog(@"%s error", __PRETTY_FUNCTION__);
      break;
    case NSStreamEventEndEncountered:
      DLog(@"%s end", __PRETTY_FUNCTION__);
      break;
  }
}

@end