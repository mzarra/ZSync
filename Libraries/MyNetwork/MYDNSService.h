//
//  MYDNSService.h
//  MYNetwork
//
//  Created by Jens Alfke on 4/23/09.
//  Copyright 2009 Jens Alfke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreFoundation/CFSocket.h>
@class MYDNSConnection;


/** Abstract superclass for services based on DNSServiceRefs, such as MYPortMapper. */
@interface MYDNSService : NSObject
{
    @private
    BOOL _usePrivateConnection;
    MYDNSConnection *_connection;
    struct _DNSServiceRef_t *_serviceRef;
    CFSocketRef _socket;
    CFRunLoopSourceRef _socketSource;
    SInt32 _error;
    BOOL _continuous, _gotResponse;
}

/** If NO (the default), the service will stop after it gets a result.
    If YES, it will continue to run until stopped. */
@property BOOL continuous;

/** Starts the service.
    Returns immediately; you can find out when the service actually starts (or fails to)
    by observing the isOpen and error properties.
    It's very unlikely that this call itself will fail (return NO). If it does, it
    probably means that the mDNSResponder process isn't working. */
- (BOOL) start;

/** Stops the service. */
- (void) stop;

/** Has the service started up? */
@property (readonly) BOOL isRunning;


/** The error status, a DNSServiceErrorType enum; nonzero if something went wrong. 
    This property is KV observable. */
@property int32_t error;


/** Utility to construct a service's full name. */
+ (NSString*) fullNameOfService: (NSString*)serviceName
                         ofType: (NSString*)type
                       inDomain: (NSString*)domain;


/** @name Protected
 *  Methods for use only by subclasses
 */
//@{

/** Normally, all DNSService objects use a shared IPC connection to the mDNSResponder daemon.
    If an instance wants to use its own connection instead, it can set this property to YES before
    it starts. If it does so, it must NOT set the kDNSServiceFlagsShareConnection flag when creating
    its underlying DNSService.
    This functionality is only provided because MYBonjourRegistration needs it -- there's a bug
    that prevents DNSServiceUpdateRecord from working with a shared connection. */
@property BOOL usePrivateConnection;

/** Subclass must implement this abstract method to create a new DNSServiceRef.
    This method is called by -open.
    The implementation MUST pass the given sdRefPtr directly to the DNSService function
    that creates the new ref, without setting it to NULL first.
    It MUST also set the kDNSServiceFlagsShareConnection flag, unless it's already set the
    usePrivateConnection property. */
- (int32_t/*DNSServiceErrorType*/) createServiceRef: (struct _DNSServiceRef_t**)sdRefPtr;

/** Subclass's callback must call this method after doing its own work.
    This method will update the error state, and will stop the service if it's not set to be
    continuous. */
- (void) gotResponse: (int32_t/*DNSServiceErrorType*/)errorCode;

/** The underlying DNSServiceRef. This will be NULL except while the service is running. */
@property (readonly) struct _DNSServiceRef_t* serviceRef;

/** Same as -stop, but does not clear the error property.
    (The stop method actually calls this first.) */
- (void) cancel;

/** Block until a message is received from the daemon.
    This will cause the service's callback (defined by the subclass) to be invoked.
    @return  YES if a message is received, NO on error (or if the service isn't started) */
- (BOOL) waitForReply;

//@}

@end




@interface MYDNSConnection : NSObject
{
    struct _DNSServiceRef_t* _connectionRef;
    CFSocketRef _socket;
    CFRunLoopSourceRef _runLoopSource;
}

+ (MYDNSConnection*) sharedConnection;
- (id) initWithServiceRef: (struct _DNSServiceRef_t *)serviceRef;
@property (readonly) struct _DNSServiceRef_t* connectionRef;
- (BOOL) processResult;
- (void) close;

@end
