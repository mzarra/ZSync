//
//  MYBonjourService.h
//  MYNetwork
//
//  Created by Jens Alfke on 1/22/08.
//  Copyright 2008 Jens Alfke. All rights reserved.
//

#import "MYDNSService.h"
@class MYBonjourBrowser, MYBonjourQuery, MYAddressLookup;


/** Represents a Bonjour service discovered by a MYBonjourBrowser. */
@interface MYBonjourService : MYDNSService 
{
    @private
    MYBonjourBrowser *_bonjourBrowser;
    NSString *_name, *_fullName, *_type, *_domain, *_hostname;
    uint32_t _interfaceIndex;
    BOOL _startedResolve;
    UInt16 _port;
    NSDictionary *_txtRecord;
    MYBonjourQuery *_txtQuery;
    MYAddressLookup *_addressLookup;
}

/** The browser I belong to. */
@property (readonly) MYBonjourBrowser *bonjourBrowser;

/** The service's name. */
@property (readonly) NSString *name;

/** The service's type. */
@property (readonly) NSString *type;

/** The service's domain. */
@property (readonly) NSString *domain;

/** The service's full name -- the name, type and domain concatenated together. */
@property (readonly,copy) NSString* fullName;

/** The index of the network interface on which this service was found. */
@property (readonly) uint32_t interfaceIndex;


/** @name Addressing
 *  Getting the IP address of the service
 */
//@{

/** The hostname of the machine providing this service. */
@property (readonly, copy) NSString *hostname;

/** The IP port number of this service on its host. */
@property (readonly) UInt16 port;

/** Returns a MYDNSLookup object that resolves the raw IP address(es) of this service.
    Subsequent calls to this method will always return the same object. */
- (MYAddressLookup*) addressLookup;

//@}


/** @name TXT and other DNS records
 */
//@{

/** The service's metadata dictionary, from its DNS TXT record */
@property (readonly,copy) NSDictionary *txtRecord;

/** A convenience to access a single property from the TXT record. */
- (NSString*) txtStringForKey: (NSString*)key;

/** Starts a new MYBonjourQuery for the specified DNS record type of this service.
    @param recordType  The DNS record type, e.g. kDNSServiceType_TXT; see the enum in <dns_sd.h>. */
- (MYBonjourQuery*) queryForRecord: (UInt16)recordType;

//@}


/** @name Protected
 *  Advanced methods that may be overridden by subclasses, but should not be called directly.
 */
//@{

/** Designated initializer. You probably don't want to create MYBonjourService instances yourself,
    but if you subclass you might need to override this initializer. */
- (id) initWithBrowser: (MYBonjourBrowser*)browser
                  name: (NSString*)serviceName
                  type: (NSString*)type
                domain: (NSString*)domain
             interface: (UInt32)interfaceIndex;

/** Called when this service is officially added to its browser's service set.
    You can override this, but be sure to call the superclass method. */
- (void) added;

/** Called when this service is officially removed to its browser's service set.
    You can override this, but be sure to call the superclass method. */
- (void) removed;

/** Called when this service's TXT record changes.
    You can override this, but be sure to call the superclass method. */
- (void) txtRecordChanged;

/** Called when a query started by this service updates.
    You can override this, but be sure to call the superclass method. */
- (void) queryDidUpdate: (MYBonjourQuery*)query;

//@}

@end
