@interface ZSyncDaemon : NSObject 
{

}

+ (BOOL)installPluginAtPath:(NSString*)path intoDaemonWithError:(NSError**)error;
+ (BOOL)isDaemonRunning;
+ (void)startDaemon;

@end
