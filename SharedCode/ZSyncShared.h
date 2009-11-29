#define zsDomainName @"local."
#define zsServiceName @"_zsync._tcp"
#define zsServerUUID @"zsyncServerUUID"

#define zsAction @"kZSyncAction"
#define zsDeviceID @"kZSyncDeviceID"
#define zsStoreIdentifier @"zsStoreIdentifier"
#define zsStoreConfiguration @"zsStoreConfiguration"
#define zsStoreType @"zsStoreType"

#define zsSyncSchemaName @"ZSyncSchemaName"
#define zsSchemaMajorVersion @"zsSchemaMajorVersion"
#define zsSchemaMinorVersion @"zsSchemaMinorVersion"

#define zsActID(__ENUM__) [NSString stringWithFormat:@"%i", __ENUM__]

enum {
  zsActionRequestPairing = 1123,
  zsActionCancelPairing,
  zsActionAuthenticatePairing,
  zsActionAuthenticateFailed,
  zsActionAuthenticatePassed,
  zsActionStoreUpload,
  zsActionPerformSync,
  zsActionCompleteSync,
  zsActionVerifySchema,
  zsActionSchemaSupported,
  zsActionSchemaUnsupported
};

#import "MYNetwork.h"

