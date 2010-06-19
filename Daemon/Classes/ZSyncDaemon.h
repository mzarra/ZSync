#define zsSchemaIdentifier @"ZSyncSchemaIdentifier"
#define ZSDaemonHandler [[NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"ZSyncInstaller" ofType:@"bundle"]] principalClass]

@interface ZSyncDaemon : NSObject 
{

}

+ (BOOL)installPluginAtPath:(NSString*)path intoDaemonWithError:(NSError**)error;
+ (BOOL)isDaemonRunning;
+ (void)startDaemon;

+ (BOOL)checkBasePath:(NSString*)basePath error:(NSError**)error;
+ (NSString*)basePath;
+ (NSString*)pluginPath;

/*
 * You can confirm a valid UUID as it has the format of
 * XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
 */
+ (BOOL)deregisterDeviceForUUID:(NSString*)uuid error:(NSError**)error;

/* 
 * This method is VERY expensive.  DO NOT call this method repeatedly
 */
+ (NSArray*)devicesRegisteredForSchema:(NSString*)schema error:(NSError**)error;

@end
