//
//  BLIPProperties.h
//  MYNetwork
//
//  Created by Jens Alfke on 5/13/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import <Foundation/Foundation.h>


/** A key/value property store, like a set of MIME or RFC822 headers (but without the weird details).
    It can be written to or read from a block of data; the data is binary, not the textual
    format that MIME uses. */
@interface BLIPProperties : NSObject <NSCopying, NSMutableCopying>

/** Parse properties from a block of data.
    On success, returns a Properties object and sets *usedLength to the number of bytes of
    data consumed.
    If the data doesn't contain the complete properties, returns nil and sets *usedLength to zero.
    If the properties are syntactically invalid, returns nil and sets *usedLength to a negative number.
*/
+ (BLIPProperties*) propertiesWithEncodedData: (NSData*)data
                                   usedLength: (ssize_t*)usedLength;

/** Returns an empty autoreleased instance. */
+ (BLIPProperties*) properties;

/** Property value lookup. (Case-sensitive, like NSDictionary, but unlike RFC822.) */
- (NSString*) valueOfProperty: (NSString*)prop;

/** Returns all the properties/values as a dictionary. */
@property (readonly) NSDictionary* allProperties;

/** The number of properties. */
@property (readonly) NSUInteger count;

/** The raw data representation of the properties. */
@property (readonly) NSData *encodedData;

@end



/** Mutable subclass of BLIPProperties, used for creating new instances. */
@interface BLIPMutableProperties : BLIPProperties
{
    @private
    NSMutableDictionary *_properties;
}

/** Initializes a new instance, adding all the key/value pairs from the given NSDictionary. */
- (id) initWithDictionary: (NSDictionary*)dict;

/** Sets the value of a property. A nil value is allowed, and removes the property. */
- (void) setValue: (NSString*)value ofProperty: (NSString*)prop;

/** Sets the receiver's key/value pairs from the given NSDictionary.
    All previously existing properties are removed first. */
- (void) setAllProperties: (NSDictionary*)properties;

@end