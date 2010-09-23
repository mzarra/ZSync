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

#import "ServerBrowserDelegate.h"
#import "ZSyncShared.h"

@class ZSyncTouchHandler;
@class ServerBrowser;

@interface ZSyncService : NSObject
{
  NSString *name;
  NSString *uuid;
  NSNetService *service;
}

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *uuid;
@property (nonatomic, retain) NSNetService *service;

@end

@protocol ZSyncDelegate

@required

/* Notification that the server has accepted the device and is awaiting
 * a pairing code to be sent back.  The pairing code will be displayed
 * on the server.
 */
- (void)zSyncHandler:(ZSyncTouchHandler *)handler displayPairingCode:(NSString *)passcode;

/* The pairing code has been entered correctly on the server. The client should
 * dismiss the code display at this time.
 */
- (void)zSyncPairingCodeCompleted:(ZSyncTouchHandler *)handler;

/* The pairing code was entered incorrectly too many times so everything resets.
 * The user can select the server again or try another server.
 */
- (void)zSyncPairingCodeRejected:(ZSyncTouchHandler *)handler;

/* The pairing code window was cancelled on the server or the connection to the
 * server was severed. The client should dismiss the code display at this time.
 */
- (void)zSyncPairingCodeCancelled:(ZSyncTouchHandler *)handler;

/* This is an information message to indicate that a sync has finished.
 * The application should at this point refresh all displays from the NSManagedObjectContext
 */
- (void)zSyncFinished:(ZSyncTouchHandler *)handler;

/* This is an information message to indicate that a sync has begun.
 * This is a good place to presenta  dialog and pop the UI back to its root
 */
- (void)zSyncStarted:(ZSyncTouchHandler *)handler;

/* This message is sent when a list of servers has been created and there is
 * no server currently paired.  It is expected that the app will present a
 * list of servers or optionally request pairing automatically
 */
- (void)zSyncNoServerPaired:(NSArray *)availableServers;

@optional

/* This message will be sent after a successful deregister.
 * ZSync will not remove the data local to the device.
 */
- (void)zSyncDeregisterComplete:(ZSyncTouchHandler *)handler;

/* This message can be sent at any time when an error occurred.  The description
 * will be populated with information about the failure.
 */
- (void)zSync:(ZSyncTouchHandler *)handler errorOccurred:(NSError *)error;

/* This is an information message letting the application know that the server
 * either selected or previously paired with can no longer talk to this version
 * of the touch code.  The user should be notified of this and know that syncing
 * is currently unavailable
 */
- (void)zSync:(ZSyncTouchHandler *)handler serverVersionUnsupported:(NSError *)error;

/* The data file transfer (from the server) has started.  This is for
 * information purposes only and does not require any action by the app.
 */
- (void)zSyncFileDownloadStarted:(ZSyncTouchHandler *)handler;

/* This is a information message indicating that the previously paired
 * server cannot be located.  The app can now request a list of other servers
 * to let the user change what server is paird.
 */
- (void)zSyncServerUnavailable:(ZSyncTouchHandler *)handler;

@end

typedef enum {
  ZSyncServerActionNoActivity = 0,
  ZSyncServerActionSync,
  ZSyncServerActionDeregister,
  ZSyncServerActionLatentDeregistration
} ZSyncServerAction;

@interface ZSyncTouchHandler : NSObject <BLIPConnectionDelegate, ServerBrowserDelegate, NSNetServiceDelegate>
{
  NSTimer *networkTimer;
  NSDate *findServerTimeoutDate;

  NSMutableArray *storeFileIdentifiers;
  NSMutableArray *availableServers;
  NSMutableArray *discoveredServers;
  ServerBrowser *_serviceBrowser;
  BLIPConnection *_connection;

  NSInteger majorVersionNumber;
  NSInteger minorVersionNumber;

  NSMutableDictionary *receivedFileLookupDictionary;

  NSString *passcode;

  id _delegate;

  /* We are going to start off by trying to swap out the persistent stores
   * internally.  If this goes badly then we can had it back out to the
   * application instead.
   */
  NSPersistentStoreCoordinator *_persistentStoreCoordinator;

  ZSyncServerAction serverAction;

  NSLock *lock;
}

@property (nonatomic, assign) ZSyncServerAction serverAction;
@property (nonatomic, retain) ServerBrowser *serviceBrowser;
@property (nonatomic, retain) BLIPConnection *connection;
//@property (nonatomic, assign) BLIPConnection *connection;
@property (nonatomic, assign) NSInteger majorVersionNumber;
@property (nonatomic, assign) NSInteger minorVersionNumber;
@property (nonatomic, copy) NSString *passcode;
@property (retain) NSMutableArray *availableServers;
@property (retain) NSMutableArray *discoveredServers;
@property (retain) NSLock *lock;
@property (nonatomic, retain) NSMutableArray *storeFileIdentifiers;
@property (nonatomic, retain) NSMutableDictionary *receivedFileLookupDictionary;

/* This shared singleton design should probably go away.  We cannot assume
 * that the parent app will want to keep us around all of the time and may
 * want to drop us to conserve memory and resources.
 */
+ (id)shared;

- (void)registerDelegate:(id<ZSyncDelegate>)delegate withPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator;

- (void)requestSync;
- (void)stopRequestingSync;
- (void)requestPairing:(ZSyncService *)server;
//- (void)authenticatePairing:(NSString *)code;
- (void)cancelPairing;
- (void)disconnectPairing;

/*
 * When this is called the client will attempt to connect to the server and deregister any sync data.
 * The client will not forget about the server but will lose all sync history
 */
- (void)deregister;

- (NSString *)serverName;

@end
