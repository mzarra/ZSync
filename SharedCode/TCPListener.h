//
//  TCPListener.m
//  MYNetwork
//
//  Created by Jens Alfke on 5/10/08.
//  Copyright 2008 Jens Alfke. All rights reserved.

#import "TCPEndpoint.h"
@class TCPConnection, IPAddress;
@protocol TCPListenerDelegate;


/** Generic TCP-based server that listens for incoming connections on a port.

    For each incoming connection, it creates an instance of (a subclass of) the generic TCP
    client class TCPClient. The -connectionClass property lets you customize which subclass
    to use.
 
    TCPListener supports SSL, Bonjour advertisements for the service, and automatic port renumbering
    if there are conflicts. (The SSL related methods are inherited from TCPEndpoint.) 
 
    You will almost always need to implement the TCPListenerDelegate protocol in your own
    code, and set an instance as the listener's delegate property, in order to be informed
    of important events such as incoming connections. */
@interface TCPListener : TCPEndpoint 
{
    @private
    uint16_t _port;
    BOOL _pickAvailablePort;
    BOOL _useIPv6;
    CFSocketRef _ipv4socket;
    CFSocketRef _ipv6socket;
    
    NSString *_bonjourServiceType, *_bonjourServiceName;
    NSNetServiceOptions _bonjourServiceOptions;
    NSNetService *_netService;
    NSDictionary *_bonjourTXTRecord;
    BOOL _bonjourPublished;
    NSInteger /*NSNetServicesError*/ _bonjourError;

    Class _connectionClass;
}

/** Initializes a new TCPListener that will listen on the given port when opened. */
- (id) initWithPort: (UInt16)port;

/** The subclass of TCPConnection that will be instantiated. */
@property Class connectionClass;

/** Delegate object that will be called when interesting things happen to the listener --
    most importantly, when a new incoming connection is accepted. */
@property (assign) id<TCPListenerDelegate> delegate;

/** Should the server listen for IPv6 connections (on the same port number)? Defaults to NO. */
@property BOOL useIPv6;

/** The port number to listen on.
    If the pickAvailablePort property is enabled, this value may be updated after the server opens
    to reflect the actual port number being used. */
@property uint16_t port;

/** Should the server pick a higher port number if the desired port is already in use?
    Defaults to NO. If enabled, the port number will be incremented until a free port is found. */
@property BOOL pickAvailablePort;

/** Opens the server. You must call this after configuring all desired properties (property
    changes are ignored while the server is open.) */
- (BOOL) open: (NSError **)error;

/** Opens the server, without returning a specific error code.
    (In case of error the delegate's -listener:failedToOpen: method will be called with the
    error code, anyway.) */
- (BOOL) open;

/** Closes the server. */
- (void) close;

/** Is the server currently open? */
@property (readonly) BOOL isOpen;


#pragma mark BONJOUR:

/** The Bonjour service type to advertise. Defaults to nil; setting it implicitly enables Bonjour.
    The value should look like e.g. "_http._tcp."; for details, see the NSNetService documentation. */
@property (copy) NSString *bonjourServiceType;

/** The Bonjour service name to advertise. Defaults to nil, meaning that a default name will be
    automatically generated if Bonjour is enabled (by setting -bonjourServiceType). */
@property (copy) NSString *bonjourServiceName;

/** Options to use when publishing the Bonjour service. */
@property NSNetServiceOptions bonjourServiceOptions;

/** The dictionary form of the Bonjour TXT record: metadata about the service that can be browsed
    by peers. Changes to this dictionary will be pushed in near-real-time to interested peers. */
@property (copy) NSDictionary *bonjourTXTRecord;

/** Is this service currently published/advertised via Bonjour? */
@property (readonly) BOOL bonjourPublished;

/** Current error status of Bonjour service advertising. See NSNetServicesError for error codes. */
@property (readonly) NSInteger /*NSNetServicesError*/ bonjourError;

/** The NSNetService being published. */
@property (readonly) NSNetService* bonjourService;


@end



#pragma mark -

/** The delegate messages sent by TCPListener.
    All are optional except -listener:didAcceptConnection:. */
@protocol TCPListenerDelegate <NSObject>

/** Called after an incoming connection arrives and is opened;
    the connection is now ready to send and receive data.
    To control whether or not a connection should be accepted, implement the
    -listener:shouldAcceptConnectionFrom: method.
    To use a different class than TCPConnection, set the listener's -connectionClass property.
    (This is the only required delegate method; the others are optional to implement.) */
- (void) listener: (TCPListener*)listener didAcceptConnection: (TCPConnection*)connection;

@optional
/** Called after the listener successfully opens. */
- (void) listenerDidOpen: (TCPListener*)listener;
/** Called if the listener fails to open due to an error. */
- (void) listener: (TCPListener*)listener failedToOpen: (NSError*)error;
/** Called after the listener closes. */
- (void) listenerDidClose: (TCPListener*)listener;
/** Called when an incoming connection request arrives, but before the conncetion is opened;
    return YES to accept the connection, NO to refuse it.
    This method can only use criteria like the peer IP address, or the number of currently
    open connections, to determine whether to accept. If you also want to check the
    peer's SSL certificate, then return YES from this method, and use the TCPConnection
    delegate method -connection:authorizeSSLPeer: to examine the certificate. */
- (BOOL) listener: (TCPListener*)listener shouldAcceptConnectionFrom: (IPAddress*)address;
@end
