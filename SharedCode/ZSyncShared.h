#ifdef DEBUG
#define DLog(...) NSLog(__VA_ARGS__)
#define ALog(...) [[NSAssertionHandler currentHandler] handleFailureInFunction:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding] file:[NSString stringWithCString:__FILE__ encoding:NSUTF8StringEncoding] lineNumber:__LINE__ description:__VA_ARGS__]
#else
#define DLog(...) do { } while (0)
#define NS_BLOCK_ASSERTIONS
#define ALog(...) NSLog(__VA_ARGS__)
#endif

#define ZAssert(condition, ...) do { if (!(condition)) { ALog(__VA_ARGS__); }} while(0)

#define zsDomainName @"local."
#define zsServiceName @"_zsync._tcp"
#define zsServerUUID @"zsyncServerUUID"
#define zsServerName @"zsServerName"
#define zsErrorDomain @"zsErrorDomain"
#define zsErrorCode @"zsErrorCode"

#define zsAction @"kZSyncAction"
#define zsDeviceID @"kZSyncDeviceID"
#define zsStoreIdentifier @"zsStoreIdentifier"
#define zsStoreConfiguration @"zsStoreConfiguration"
#define zsStoreType @"zsStoreType"
#define zsTempFilePath @"zsTempFilePath"

#define zsSyncSchemaName @"ZSyncSchemaName"
#define zsSchemaMajorVersion @"zsSchemaMajorVersion"
#define zsSchemaMinorVersion @"zsSchemaMinorVersion"
#define zsSyncGUID @"zsSyncGUID"
#define zsDeviceName @"zsDeviceName"

#define zsServerNameSeperator @"**/**"

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
  zsActionSchemaUnsupported,
  zsActionFileReceived,
  zsActionTestFileTransfer,
  zsActionDeregisterClient
};

typedef enum {
  zsErrorFailedToReceiveAllFiles = 1123,
  zsErrorServerHungUp,
  zsErrorAnotherActivityInProgress,
  zsErrorNoSyncClientRegistered
} ZSErrorCode;

#import "MYNetwork.h"