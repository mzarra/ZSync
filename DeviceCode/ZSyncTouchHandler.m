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

#define kDomainName @"local."
#define kServiceName @"_zsync._tcp"

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
 * We want to start looking for desktops to sync with here.  Once started
 * We want to maintain a list of computers found and also send out a notification
 * for every server that we discover
 */
- (void)startBrowser;
{
  if (netServiceBrowser) return; //Already browsing
  DLog(@"%s starting browser", __PRETTY_FUNCTION__);
  netServiceBrowser = [[NSNetServiceBrowser alloc] init];
  [netServiceBrowser setDelegate:self]; 
  [netServiceBrowser searchForServicesOfType:kServiceName 
                                    inDomain:kDomainName];
}

- (void)netServiceBrowser:(NSNetServiceBrowser*)browser 
           didFindService:(NSNetService*)service 
               moreComing:(BOOL)more
{
  DLog(@"%s Service found", __PRETTY_FUNCTION__);
  
  [service retain];
  [service setDelegate:self];
  [service resolveWithTimeout:5.0];
  [service startMonitoring];
  
  [netServiceBrowser stop];
  [netServiceBrowser release], netServiceBrowser = nil;
}

- (void)netServiceDidResolveAddress:(NSNetService*)service
{
  DLog(@"%s service name %@", __PRETTY_FUNCTION__, [service hostName]);
  outputStream = nil;
  [service getInputStream:nil outputStream:&outputStream];
  if (outputStream) {
    DLog(@"%s outputStream obtained %@", __PRETTY_FUNCTION__, [outputStream class]);
  } else {
    DLog(@"%s outputStream is nil", __PRETTY_FUNCTION__);
  }
  
  [outputStream retain];
  [outputStream setDelegate:self];
  [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  [outputStream open];
  
  NSString *testString = @"Test String";
  dataToPush = [[testString dataUsingEncoding:NSUTF8StringEncoding] retain];
  byteOffset = 0;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)event {
  DLog(@"%s event received", __PRETTY_FUNCTION__);
  NSInteger bytesWritten = 0;
  NSUInteger bytesRemaining = [dataToPush length] - byteOffset;
  uint8_t buffer;
  switch (event) {
    case NSStreamEventOpenCompleted:
      DLog(@"%s open", __PRETTY_FUNCTION__);
      break;
    case NSStreamEventHasBytesAvailable:
      DLog(@"%s has bytes", __PRETTY_FUNCTION__);
      break;
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