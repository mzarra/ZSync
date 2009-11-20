//
//  BLIPDispatcher.h
//  MYNetwork
//
//  Created by Jens Alfke on 5/15/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import <Foundation/Foundation.h>
@class MYTarget, BLIPMessage;


/** Routes BLIP messages to targets based on a series of rules.
 
    Every BLIPConnection has a BLIPDispatcher, which is initially empty, but you can add rules
    to it.
 
    Every BLIPListener also has a dispatcher, which is inherited as the parent by every
    connection that it accepts, so you can add rules to the listener's dispatcher to share them
    between all connections.
 
    It's not necessary to use a dispatcher. Any undispatched requests will be sent to the
    BLIPConnection's delegate's -connection:receivedRequest: method, which can do its own
    custom handling. But it's often easier to use the dispatcher to associate handlers with
    request based on property values. */
@interface BLIPDispatcher : NSObject 
{
    @private
    NSMutableArray *_predicates, *_targets;
    BLIPDispatcher *_parent;
}

/** The inherited parent dispatcher.
    If a message does not match any of this dispatcher's rules, it will next be passed to
    the parent, if there is one. */
@property (retain) BLIPDispatcher *parent;

/** Convenience method that adds a rule that compares a property against a string. */
- (void) addTarget: (MYTarget*)target forValueOfProperty: (NSString*)value forKey: (NSString*)key;

#if ! TARGET_OS_IPHONE      /* NSPredicate is not available on iPhone, unfortunately */
/** Adds a new rule, to call a given target method if a given predicate matches the message. */
- (void) addTarget: (MYTarget*)target forPredicate: (NSPredicate*)predicate;
#endif

/** Removes all rules with the given target method. */
- (void) removeTarget: (MYTarget*)target;

/** Tests the message against all the rules, in the order they were added, and calls the
    target of the first matching rule.
    If no rule matches, the message is passed to the parent dispatcher's -dispatchMessage:,
    if there is a parent.
    If no rules at all match, NO is returned. */
- (BOOL) dispatchMessage: (BLIPMessage*)message;

/** Returns a target object that will call this dispatcher's -dispatchMessage: method.
    This can be used to make this dispatcher the target of another dispatcher's rule,
    stringing them together hierarchically. */
- (MYTarget*) asTarget;

@end
