//
//  NSSocket+ZSExtensions.m
//  SampleDesktop
//
//  Created by Marcus S. Zarra on 11/8/09.
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

#import "NSSocket+ZSExtensions.h"

#import <netinet/in.h>
#import <sys/socket.h>


@implementation NSSocketPort (ZSExtensions)

- (uint16_t)port;
{
  uint16_t port = 0;
  struct sockaddr *address = (struct sockaddr*)[[self address] bytes];
  
  if (address->sa_family == AF_INET) { 
    port = ntohs(((struct sockaddr_in*)address)->sin_port);
  } else if (address->sa_family == AF_INET6) { 
    port = ntohs(((struct sockaddr_in6*)address)->sin6_port);
  } else { 
    @throw [NSException exceptionWithName:@"Socket Error" reason:@"Unknown network type" userInfo:nil];  
  }
  
  return port;
}

@end
