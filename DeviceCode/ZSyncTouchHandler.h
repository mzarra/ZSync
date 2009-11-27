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

/* This message is sent when a list of servers has been created and there is
 * no server currently paired.  It is expected that the app will present a 
 * list of servers or optionally request pairing automatically
 */
- (void)zSyncNoServerPaired:(NSArray*)availableServers;

/* This message is sent when the file has been received back from the server
 * and has been stored in a temporary cache.  The application is expected
 * to transfer this new file to its permanent location and handle the update
 * of the UI.
 */
- (void)zSync:(ZSyncTouchHandler*)handler downloadFinished:(NSString*)tempPath;

/* This message can be sent at any time when an error occurred.  The description
 * will be populated with information about the failure.
 */
- (void)zSync:(ZSyncTouchHandler*)handler errorOccurred:(NSError*)error;

/* This is an information message to indicate that a sync has begun.
 */
- (void)zSyncStarted:(ZSyncTouchHandler*)handler;

/* ZSync has started the transfer of data to the server to be synced.  This is
 * an information message only so that the app can update the user on the 
 * status of the sync.
 */
- (void)zSyncFileUploaded:(ZSyncTouchHandler*)handler;

/* Notification that the server has accepted the device and is awaiting
 * a pairing code to be sent back.  The pairing code will be displayed
 * on the server.
 */
- (void)zSyncPairingRequestAccepted:(ZSyncTouchHandler*)handler;

/* A pairing code was sent to the server and the server rejected it.
 * Another opportunity to enter the pairing code should be displayed
 */
- (void)zSyncPairingCodeRejected:(ZSyncTouchHandler*)handler;

/* The pairing code was accepted by the server and a sync is starting
 */
- (void)zSyncPairingCodeApproved:(ZSyncTouchHandler*)handler;

/* The data file transfer (from the server) has started.  This is for 
 * information purposes only and does not require any action by the app.
 */
- (void)zSyncFileDownloadStarted:(ZSyncTouchHandler*)handler;

/* This is a information message indicating that the previously paired
 * server cannot be located.  The app can now request a list of other servers
 * to let the user change what server is paird.
 */
- (void)zSyncServerUnavailable:(ZSyncTouchHandler*)handler;

@end

@interface ZSyncTouchHandler : NSObject <BLIPConnectionDelegate>
{
  MYBonjourBrowser *_serviceBrowser;
  BLIPConnection *_connection;
  
  id delegate;
  
  NSInteger currentAction;
  
  /* We are going to start off by trying to swap out the persistent stores
   * internally.  If this goes badly then we can had it back out to the 
   * application instead.
   */
  NSPersistentStoreCoordinator *persistentStoreCoordinator;
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