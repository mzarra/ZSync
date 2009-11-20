//
//  IPAddress.h
//  MYNetwork
//
//  Created by Jens Alfke on 1/4/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import <Foundation/Foundation.h>


/** Represents an Internet Protocol address and port number (similar to a sockaddr_in).
    IPAddress itself only remembers the raw 32-bit IPv4 address; the subclass HostAddress
    also remembers the DNS host-name. */
@interface IPAddress : NSObject <NSCoding, NSCopying>
{
    @private
    UInt32 _ipv4;       // In network byte order (big-endian), just like struct in_addr
    UInt16 _port;       // native byte order
}

/** Initializes an IPAddress from a host name (which may be a DNS name or dotted-quad numeric form)
    and port number.
    If the hostname is not in dotted-quad form, an instance of the subclass HostAddress will
    be returned instead. */
- (id) initWithHostname: (NSString*)hostname port: (UInt16)port;

/** Creates an IPAddress from a host name (which may be a DNS name or dotted-quad numeric form)
    and port number.
    If the hostname is not in dotted-quad form, an instance of the subclass HostAddress will
    be returned instead. */
+ (IPAddress*) addressWithHostname: (NSString*)hostname port: (UInt16)port;

/** Initializes an IPAddress from a raw IPv4 address (in network byte order, i.e. big-endian)
    and port number (in native byte order) */
- (id) initWithIPv4: (UInt32)ipv4 port: (UInt16)port;

/** Initializes an IPAddress from a raw IPv4 address (in network byte order, i.e. big-endian).
    The port number defaults to zero. */
- (id) initWithIPv4: (UInt32)ipv4;

/** Initializes an IPAddress from a BSD struct sockaddr. */
- (id) initWithSockAddr: (const struct sockaddr*)sockaddr;

/** Initializes an IPAddress from NSData containing a BSD struct sockaddr. */
- (id) initWithData: (NSData*)data;

/** Returns the IP address of this host (plus the specified port number).
    If multiple network interfaces are active, the main one's address is returned. */
+ (IPAddress*) localAddressWithPort: (UInt16)port;

/** Returns the IP address of this host (with a port number of zero).
    If multiple network interfaces are active, the main one's address is returned. */
+ (IPAddress*) localAddress;

/** Returns the address of the peer that an open socket is connected to.
    (This calls getpeername.) */
+ (IPAddress*) addressOfSocket: (CFSocketNativeHandle)socket;

/** Returns YES if the two objects have the same IP address, ignoring port numbers. */
- (BOOL) isSameHost: (IPAddress*)addr;

/** The raw IPv4 address, in network (big-endian) byte order. */
@property (readonly) UInt32 ipv4;               // raw address in network byte order

/** The address as a dotted-quad string, e.g. @"10.0.1.1". */
@property (readonly) NSString* ipv4name;

/** The address as a DNS hostname or else a dotted-quad string.
    (IPAddress itself always returns dotted-quad; HostAddress returns the hostname it was
    initialized with.) */
@property (readonly) NSString* hostname;        // dotted-quad string, or DNS name if I am a HostAddress

/** The port number, or zero if none was specified, in native byte order. */
@property (readonly) UInt16 port;

/** The address as an NSData object containing a struct sockaddr. */
@property (readonly) NSData* asData;

/** Is this IP address in a designated private/local address range, such as 10.0.1.X?
    If so, the address is not globally meaningful outside of the local subnet. */
@property (readonly) BOOL isPrivate;            // In a private/local addr range like 10.0.1.X?
@end



/** A subclass of IPAddress that remembers the DNS hostname instead of a raw address.
    An instance of HostAddress looks up its ipv4 address on the fly by calling gethostbyname. */
@interface HostAddress : IPAddress
{
    @private
    NSString *_hostname;
}

- (id) initWithHostname: (NSString*)hostname port: (UInt16)port;

/** Initializes a HostAddress from a host name, plus a sockaddr struct and a port number.
    (The port number overrides any port specified in the sockaddr struct.) */
- (id) initWithHostname: (NSString*)hostname
               sockaddr: (const struct sockaddr*)sockaddr
                   port: (UInt16)port;

@end



/** An IPAddress that can keep track of statistics on when it was last sucessfully used
    and the number of successful attempts. This is useful when keeping a cache of recent
    addresses for a peer that doesn't have a stable address. */
@interface RecentAddress : IPAddress
{
    @private
    CFAbsoluteTime _lastSuccess;
    UInt32 _successes;
}

/** Initializes a RecentAddress from an IPAddress. (You can also initialize RecentAddress using
    any inherited initializer method.) */
- (id) initWithIPAddress: (IPAddress*)addr;

/** The absolute time that -noteSuccess or -noteSeen was last called. */
@property (readonly) CFAbsoluteTime lastSuccess;

/** The number of times that -noteSuccess has been called. */
@property (readonly) UInt32 successes;

/** Call this to indicate that the address was successfully used to connect to the desired peer.
    Returns YES if the state of the object has changed and it should be re-archived. */
- (BOOL) noteSuccess;

/** Call this to indicate that you have received evidence that this address is currently being
    used by this peer. Unlike -noteSuccess it doesn't increment -successes, and only returns
    YES (to indicate a persistent change) once every 18 hours (to avoid making the client
    save its cache too often.) */
- (BOOL) noteSeen;

@end
