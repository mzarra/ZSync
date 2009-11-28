#define zsDomainName @"local."
#define zsServiceName @"_zsync._tcp"
#define zsServerUUID @"zsyncServerUUID"

#define zsAction @"kZSyncAction"
#define zsDeviceID @"kZSyncDeviceID"

enum {
  zsActionRequestPairing = 1123,
  zsActionCancelPairing,
  zsActionAuthenticatePairing,
  zsActionAuthenticateFailed,
  zsActionAuthenticatePassed
};

#import "MYNetwork.h"

