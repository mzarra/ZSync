//
//  TCPEndpoint.h
//  MYNetwork
//
//  Created by Jens Alfke on 5/14/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/SecBase.h>
#if TARGET_OS_IPHONE
#include <CFNetwork/CFSocketStream.h>
#else
#import <CoreServices/CoreServices.h>
#endif


// SSL properties:

/** This defines the SSL identity to be used by this endpoint.
    The value is an NSArray (or CFArray) whose first item must be a SecIdentityRef;
    optionally, it can also contain SecCertificateRefs for supporting certificates in the
    validation chain. */
#define kTCPPropertySSLCertificates  ((NSString*)kCFStreamSSLCertificates)

/** If set to YES, the connection will accept self-signed certificates from the peer,
    or any certificate chain that terminates in an unrecognized root. */
#define kTCPPropertySSLAllowsAnyRoot ((NSString*)kCFStreamSSLAllowsAnyRoot)

/** This sets the hostname that the peer's certificate must have.
    (The default value is the hostname, if any, that the connection was opened with.)
    Setting a value of [NSNull null] completely disables host-name checking. */
#define kTCPPropertySSLPeerName      ((NSString*)kCFStreamSSLPeerName)

/** Specifies whether the client (the peer that opened the connection) will use a certificate.
    The value is a TCPAuthenticate enum value wrapped in an NSNumber. */
extern NSString* const kTCPPropertySSLClientSideAuthentication;

typedef enum {
	kTCPNeverAuthenticate,			/* skip client authentication */
	kTCPAlwaysAuthenticate,         /* require it */
	kTCPTryAuthenticate             /* try to authenticate, but not error if client has no cert */
} TCPAuthenticate; // these MUST have same values as SSLAuthenticate enum in SecureTransport.h!


/** Abstract base class of TCPConnection and TCPListener.
    Mostly just manages the SSL properties. */
@interface TCPEndpoint : NSObject
{
    NSMutableDictionary *_sslProperties;
    id _delegate;
}

/** The desired security level. Use the security level constants from NSStream.h,
    such as NSStreamSocketSecurityLevelNegotiatedSSL. */
@property (copy) NSString *securityLevel;

/** Detailed SSL settings. This is the same as CFStream's kCFStreamPropertySSLSettings
    property. */
@property (copy) NSMutableDictionary *SSLProperties;

/** Shortcut to set a single SSL property. */
- (void) setSSLProperty: (id)value 
                 forKey: (NSString*)key;

/** High-level setup for secure P2P connections. Uses the given identity for SSL,
    requires peers to use SSL, turns off root checking and peer-name checking. */
- (void) setPeerToPeerIdentity: (SecIdentityRef)identity;

//protected:
- (void) tellDelegate: (SEL)selector withObject: (id)param;

@end
