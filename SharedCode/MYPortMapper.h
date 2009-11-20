//
//  MYPortMapper.m
//  MYNetwork
//
//  Created by Jens Alfke on 1/4/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import "MYDNSService.h"
@class IPAddress;


/*  MYPortMapper attempts to make a particular network port on this computer publicly reachable
    for incoming connections, by "opening a hole" through a Network Address Translator 
    (NAT) or firewall that may be in between the computer and the public Internet.
 
    The port mapping may fail if:
    * the NAT/router/firewall does not support either the UPnP or NAT-PMP protocols;
    * the device doesn't implement the protocols correctly (this happens);
    * the network administrator has disabled port-mapping;
    * there is a second layer of NAT/firewall (this happens in some ISP networks.)
 
    The PortMapper is asynchronous. It will take a nonzero amount of time to set up the
    mapping, and the mapping may change in the future as the network configuration changes.
    To be informed of changes, either use key-value observing to watch the "error" and
    "publicAddress" properties, or observe the MYPortMapperChangedNotification.
 
    Typical usage is to:
    * Start a network service that listens for incoming connections on a port
    * Open a MYPortMapper
    * When the MYPortMapper reports the public address and port of the mapping, you somehow
      notify other peers of that address and port, so they can connect to you.
    * When the MYPortMapper reports changes, you (somehow) notify peers of the changes.
    * When closing the network service, close the MYPortMapper object too.
*/ 
@interface MYPortMapper : MYDNSService
{
    @private
    UInt16 _localPort, _desiredPublicPort;
    BOOL _mapTCP, _mapUDP;
    IPAddress *_publicAddress, *_localAddress;
}

/** Initializes a PortMapper that will map the given local (private) port.
    By default it will map TCP and not UDP, and will not suggest a desired public port,
    but this can be configured by setting properties before opening the PortMapper. */
- (id) initWithLocalPort: (UInt16)localPort;

/** Initializes a PortMapper that will not map any ports.
    This is useful if you just want to find out your public IP address.
    (For a simplified, but synchronous, convenience method for this, see
    +findPublicAddress.) */
- (id) initWithNullMapping;

/** Should the TCP or UDP port, or both, be mapped? By default, TCP only.
    These properties have no effect if changed while the PortMapper is open. */
@property BOOL mapTCP, mapUDP;

/** You can set this to the public port number you'd like to get.
    It defaults to 0, which means "no preference".
    This property has no effect if changed while the PortMapper is open. */
@property UInt16 desiredPublicPort;

/** Blocks till the PortMapper finishes opening. Returns YES if it opened, NO on error.
    It's not usually a good idea to use this, as it will lock up your application
    until a response arrives from the NAT. Listen for asynchronous notifications instead.
    If called when the PortMapper is closed, it will call -open for you.
    If called when it's already open, it just returns YES. */
- (BOOL) waitTillOpened;

/** The known public IPv4 address/port, once it's been determined.
    This property is KV observable. */
@property (readonly,retain) IPAddress* publicAddress;

/** The current local address/port, as of the time the port mapping was last updated.
    The address part is of the main interface; the port is the specified local port.
    This property is KV observable. */
@property (readonly,retain) IPAddress* localAddress;

/** Returns YES if a non-null port mapping is in effect: 
    that is, if the public address differs from the local one. */
@property (readonly) BOOL isMapped;


// UTILITY CLASS METHOD:

/** Determine the main interface's public IP address, without mapping any ports.
    This method internally calls -waitTillOpened, so it may take a nontrivial amount
    of time (and will crank the runloop while it waits.)
    If you want to do this asynchronously, you should instead create a new
    MYPortMapper instance using -initWithNullMapping. */
+ (IPAddress*) findPublicAddress;

@end


/** This notification is posted asynchronously when the status of a PortMapper
    (its error, publicAddress or publicPort) changes. */
extern NSString* const MYPortMapperChangedNotification;
