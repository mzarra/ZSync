//
//  ZSyncTouchHandler.h
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

#import "ZSyncShared.h"

@class ZSyncTouchHandler;

@interface ZSyncService : NSObject
{
  NSString *name;
  NSString *uuid;
  MYBonjourService *service;
}

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *uuid;
@property (nonatomic, retain) MYBonjourService *service;

@end

@protocol ZSyncDelegate 

- (void)zSyncNoServerPaired:(NSArray*)availableServers;
- (void)zSync:(ZSyncTouchHandler*)handler downloadFinished:(NSString*)tempPath;
- (void)zSync:(ZSyncTouchHandler*)handler errorOccurred:(NSError*)error;

- (void)zSyncStarted:(ZSyncTouchHandler*)handler;
- (void)zSyncFileUploaded:(ZSyncTouchHandler*)handler;
- (void)zSyncPairingRequestAccepted:(ZSyncTouchHandler*)handler;
- (void)zSyncFileSyncPing:(ZSyncTouchHandler*)handler;
- (void)zSyncFileDownloadStarted:(ZSyncTouchHandler*)handler;
- (void)zSyncServerUnavailable:(ZSyncTouchHandler*)handler;

@end

@interface ZSyncTouchHandler : NSObject <BLIPConnectionDelegate>
{
  MYBonjourBrowser *_serviceBrowser;
  BLIPConnection *_connection;
  
  id delegate;
  
  NSInteger currentAction;
}

@property (nonatomic, retain) MYBonjourBrowser *serviceBrowser;
@property (nonatomic, assign) BLIPConnection *connection;
@property (nonatomic, assign) NSInteger currentAction;
@property (nonatomic, assign) id<ZSyncDelegate> delegate;

+ (id)shared;

- (void)requestSync;
- (void)requestPairing:(ZSyncService*)server;
- (void)authenticatePairing:(NSString*)code;
- (void)cancelPairing;

- (NSArray*)availableServers;

@end