//
//  BLIPConnection.h
//  MYNetwork
//
//  Created by Jens Alfke on 5/10/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import "TCPConnection.h"
#import "TCPListener.h"
@class BLIPRequest, BLIPResponse, BLIPDispatcher;
@protocol BLIPConnectionDelegate;


/** Represents a connection to a peer, using the <a href=".#blipdesc">BLIP</a> protocol over a TCP socket.
    Outgoing connections are made simply by instantiating a BLIPConnection via -initToAddress:.
    Incoming connections are usually set up by a BLIPListener and passed to the listener's
    delegate.
    Most of the API is inherited from TCPConnection. */
@interface BLIPConnection : TCPConnection
{
    @private
    BLIPDispatcher *_dispatcher;
    BOOL _blipClosing;
}

/** The delegate object that will be called when the connection opens, closes or receives messages. */
@property (assign) id<BLIPConnectionDelegate> delegate;

/** The connection's request dispatcher. By default it's not configured to do anything; but you
    can add rules to the dispatcher to call specific target methods based on properties of the
    incoming requests.
 
    Requests that aren't handled by the dispatcher (i.e. all of them, by default) will be
    passed to the delegate's connection:receivedRequest: method; or if there's no delegate,
    a generic error response will be returned. */
@property (readonly) BLIPDispatcher *dispatcher;

/** Creates a new, empty outgoing request.
    You should add properties and/or body data to the request, before sending it by
    calling its -send method. */
- (BLIPRequest*) request;

/** Creates a new outgoing request.
    The body or properties may be nil; you can add additional data or properties by calling
    methods on the request itself, before sending it by calling its -send method. */
- (BLIPRequest*) requestWithBody: (NSData*)body
                      properties: (NSDictionary*)properies;

/** Sends a request over this connection.
    (Actually, it queues it to be sent; this method always returns immediately.)
    Call this instead of calling -send on the request itself, if the request was created with
    +[BLIPRequest requestWithBody:] and hasn't yet been assigned to any connection.
    This method will assign it to this connection before sending it.
    The request's matching response object will be returned, or nil if the request couldn't be sent. */
- (BLIPResponse*) sendRequest: (BLIPRequest*)request;
@end



/** The delegate messages that BLIPConnection will send,
    in addition to the ones inherited from TCPConnectionDelegate.
    All methods are optional. */
@protocol BLIPConnectionDelegate <TCPConnectionDelegate>
@optional

/** Called when a BLIPRequest is received from the peer, if there is no BLIPDispatcher
    rule to handle it.
    If the delegate wants to accept the request it should return YES; if it returns NO,
    a kBLIPError_NotFound error will be returned to the sender.
    The delegate should get the request's response object, fill in its data and properties
    or error property, and send it.
    If it doesn't explicitly send a response, a default empty one will be sent;
    to prevent this, call -deferResponse on the request if you want to send a response later. */
- (BOOL) connection: (BLIPConnection*)connection receivedRequest: (BLIPRequest*)request;

/** Called when a BLIPResponse (to one of your requests) is received from the peer.
    This is called <i>after</i> the response object's onComplete target, if any, is invoked.*/
- (void) connection: (BLIPConnection*)connection receivedResponse: (BLIPResponse*)response;

/** Called when the peer wants to close the connection. Return YES to allow, NO to prevent. */
- (BOOL) connectionReceivedCloseRequest: (BLIPConnection*)connection;

/** Called if the peer refuses a close request. 
    The typical error is kBLIPError_Forbidden. */
- (void) connection: (BLIPConnection*)connection closeRequestFailedWithError: (NSError*)error;
@end




/** A "server" that listens on a TCP socket for incoming <a href=".#blipdesc">BLIP</a> connections and creates
    BLIPConnection instances to handle them.
    Most of the API is inherited from TCPListener. */
@interface BLIPListener : TCPListener
{
    BLIPDispatcher *_dispatcher;
}

/** The default request dispatcher that will be inherited by all BLIPConnections opened by this
    listener.
    If a connection's own dispatcher doesn't have a rule to match a message, this inherited
    dispatcher will be checked next. Only if it fails too will the delegate be called. */
@property (readonly) BLIPDispatcher *dispatcher;

@end
