//
//  BLIPRequest.h
//  MYNetwork
//
//  Created by Jens Alfke on 5/22/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import "BLIPMessage.h"
@class BLIPResponse, MYTarget;


/** A Request, or initiating message, in the <a href=".#blipdesc">BLIP</a> protocol. */
@interface BLIPRequest : BLIPMessage <NSMutableCopying>
{
    @private
    BLIPResponse *_response;
}

/** Creates an outgoing request.
    The body may be nil.
    The request is not associated with any BLIPConnection yet, so you must either set its
    connection property before calling -send, or pass the request as a parameter to
    -[BLIPConnection sendRequest:]. */
+ (BLIPRequest*) requestWithBody: (NSData*)body;

/** Creates an outgoing request.
    This is just like requestWithBody: except that you supply a string. */
+ (BLIPRequest*) requestWithBodyString: (NSString*)bodyString;

/** Creates an outgoing request.
    The body or properties may be nil.
    The request is not associated with any BLIPConnection yet, so you must either set its
    connection property before calling -send, or pass the request as a parameter to
    -[BLIPConnection sendRequest:]. */
+ (BLIPRequest*) requestWithBody: (NSData*)body
                      properties: (NSDictionary*)properties;

/** BLIPRequest extends the -connection property to be settable.
    This allows a request to be created without a connection (i.e. before the connection is created).
    It can later be sent by setting the connection property and calling -send. */
@property (retain) BLIPConnection *connection;

/** Sends this request over its connection.
    (Actually, the connection queues it to be sent; this method always returns immediately.)
    Its matching response object will be returned, or nil if the request couldn't be sent.
    If this request has not been assigned to a connection, an exception will be raised. */
- (BLIPResponse*) send;

/** Does this request not need a response?
    This property can only be set before sending the request. */
@property BOOL noReply;

/** Returns YES if you've replied to this request (by accessing its -response property.) */
@property (readonly) BOOL repliedTo;

/** The request's response. This can be accessed at any time, even before sending the request,
    but the contents of the response won't be filled in until it arrives, of course. */
@property (readonly) BLIPResponse *response;

/** Call this when a request arrives, to indicate that you want to respond to it later.
    It will prevent a default empty response from being sent upon return from the request handler. */
- (void) deferResponse;

/** Shortcut to respond to this request with the given data.
    The contentType, if not nil, is stored in the "Content-Type" property. */
- (void) respondWithData: (NSData*)data contentType: (NSString*)contentType;

/** Shortcut to respond to this request with the given string (which will be encoded in UTF-8). */
- (void) respondWithString: (NSString*)string;

/** Shortcut to respond to this request with an error. */
- (void) respondWithError: (NSError*)error;

/** Shortcut to respond to this request with the given error code and message.
    The BLIPErrorDomain is assumed. */
- (void) respondWithErrorCode: (int)code message: (NSString*)message; //, ... __attribute__ ((format (__NSString__, 2,3)));;

/** Shortcut to respond to this message with an error indicating that an exception occurred. */
- (void) respondWithException: (NSException*)exception;

@end




/** A reply to a BLIPRequest, in the <a href=".#blipdesc">BLIP</a> protocol. */
@interface BLIPResponse : BLIPMessage
{
    @private
    NSError *_error;
    MYTarget *_onComplete;
}

/** Sends this response. */
- (BOOL) send;

/** The error returned by the peer, or nil if the response is successful. */
@property (retain) NSError* error;

/** Sets a target/action to be called when an incoming response is complete.
    Use this on the response returned from -[BLIPRequest send], to be notified when the response is available. */
@property (retain) MYTarget *onComplete;


@end
