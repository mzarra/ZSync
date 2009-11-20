//
//  TCPConnection.h
//  MYNetwork
//
//  Created by Jens Alfke on 5/18/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import "TCPEndpoint.h"
#import <Security/Security.h>
@class IPAddress;
@class TCPReader, TCPWriter, TCPListener, MYBonjourService;
@protocol TCPConnectionDelegate;


typedef enum {
    kTCP_Disconnected = -1,
    kTCP_Closed,
    kTCP_Opening,
    kTCP_Open,
    kTCP_Closing
} TCPConnectionStatus;


/** A generic class that manages a TCP socket connection.
    It creates a TCPReader and a TCPWriter to handle I/O.
    TCPConnection itself mostly deals with SSL setup and opening/closing the socket.
    (The SSL related methods are inherited from TCPEndpoint.) */
@interface TCPConnection : TCPEndpoint
{
    @private
    TCPListener *_server;
    IPAddress *_address;
    BOOL _isIncoming, _checkedPeerCert;
    TCPConnectionStatus _status;
    TCPReader *_reader;
    TCPWriter *_writer;
    NSError *_error;
    NSTimeInterval _openTimeout;
}

/** Initializes a TCPConnection to the given IP address.
    Afer configuring settings, you should call -open to begin the connection. */
- (id) initToAddress: (IPAddress*)address;

/** Initializes a TCPConnection to the given NSNetService's address and port.
    If the service's address cannot be resolved, nil is returned. */
- (id) initToNetService: (NSNetService*)service;

/** Initializes a TCPConnection to the given MYBonjourService's address and port.
    If the service's address cannot be resolved, nil is returned. */
- (id) initToBonjourService: (MYBonjourService*)service;

/** Initializes a TCPConnection from an incoming TCP socket.
    You don't usually need to call this; TCPListener does it automatically. */
- (id) initIncomingFromSocket: (CFSocketNativeHandle)socket listener: (TCPListener*)listener;

/** Timeout for waiting to open a connection. (Default is zero, meaning the OS default timeout.) */
@property NSTimeInterval openTimeout;

/** The delegate object that will be called when the connection opens, closes or receives messages. */
@property (assign) id<TCPConnectionDelegate> delegate;

/** The certificate(s) of the connected peer, if this connection uses SSL.
    The items in the array are SecCertificateRefs; use the Keychain API to work with them. */
@property (readonly) NSArray *peerSSLCerts;

/** Connection's current status */
@property (readonly) TCPConnectionStatus status;

/** Opens the connection. This happens asynchronously; wait for a delegate method to be called.
    You don't need to open incoming connections received via a TCPListener. */
- (void) open;

/** Closes the connection, after waiting for all in-progress messages to be sent or received.
    This happens asynchronously; wait for a delegate method to be called.*/
- (void) close;

/** Closes the connection, like -close, but if it hasn't closed by the time the timeout
    expires, it will disconnect the socket. */
- (void) closeWithTimeout: (NSTimeInterval)timeout;

/** Closes all open TCPConnections. */
+ (void) closeAllWithTimeout: (NSTimeInterval)timeout;

/** Blocks until all open TCPConnections close. You should call +closeAllWithTimeout: first. */
+ (void) waitTillAllClosed;

/** The IP address of the other peer. */
@property (readonly,retain) IPAddress *address;

/** The TCPListener that created this incoming connection, or nil */
@property (readonly) TCPListener *server;

/** Is this an incoming connection, received via a TCPListener? */
@property (readonly) BOOL isIncoming;

/** The fatal error, if any, 
    that caused the connection to fail to open or to disconnect unexpectedly. */
@property (readonly) NSError *error;

/** The actual security level of this connection. 
    Value is nil or one of the security level constants from NSStream.h,
    such as NSStreamSocketSecurityLevelTLSv1. */
@property (readonly) NSString* actualSecurityLevel;


@property (readonly) TCPReader *reader;
@property (readonly) TCPWriter *writer;


// protected:
- (Class) readerClass;
- (Class) writerClass;
- (void) _beginClose;
- (void) _unclose;

@end



/** The delegate messages sent by TCPConnection.
    All methods are optional. */
@protocol TCPConnectionDelegate <NSObject>
@optional
/** Called after the connection successfully opens. */
- (void) connectionDidOpen: (TCPConnection*)connection;
/** Called after the connection fails to open due to an error. */
- (void) connection: (TCPConnection*)connection failedToOpen: (NSError*)error;
/** Called when the identity of the peer is known, if using an SSL connection and the SSL
    settings say to check the peer's certificate.
    This happens, if at all, after the -connectionDidOpen: call. */
- (BOOL) connection: (TCPConnection*)connection authorizeSSLPeer: (SecCertificateRef)peerCert;
/** Called after the connection closes.
    You can check the connection's error property to see if it was normal or abnormal. */
- (void) connectionDidClose: (TCPConnection*)connection;
@end
