#import "ZSyncDaemon.h"

@implementation ZSyncDaemon

+ (NSString*)basePath
{
  //Build our standard install path
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
  basePath = [basePath stringByAppendingPathComponent:@"ZSyncDaemon"];
  return basePath;
}

+ (NSString*)applicationPath
{
  NSString *basePath = [self basePath];
  return [basePath stringByAppendingPathComponent:@"ZSyncDaemon.app"];
}

+ (BOOL)checkBasePath:(NSString*)basePath error:(NSError**)error;
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  if (![fileManager fileExistsAtPath:basePath isDirectory:&isDirectory]) {
    return NO;
  }
  if (!isDirectory) {
    NSString *errorDesc = [NSString stringWithFormat:@"Unknown file at base installation path: %@", basePath];
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey];
    *error = [NSError errorWithDomain:@"ZSync" code:1123 userInfo:dictionary];
    return NO;
  }
  return YES;
}

+ (BOOL)checkApplicationPath:(NSString*)applicationPath error:(NSError**)error;
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  if (![fileManager fileExistsAtPath:applicationPath isDirectory:&isDirectory]) {
    return NO;
  }
  if (!isDirectory) {
    NSString *errorDesc = [NSString stringWithFormat:@"Unknown file at daemon application installation path: %@", applicationPath];
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey];
    *error = [NSError errorWithDomain:@"ZSync" code:1124 userInfo:dictionary];
    return NO;
  }
  return YES;
}

+ (BOOL)isDaemonInstalled:(NSError**)error;
{
  NSString *basePath = [self basePath];
  if (![self checkBasePath:basePath error:error]) {
    if (error) {
      return NO;
    }
    if (![[NSFileManager defaultManager] createDirectoryAtPath:basePath 
                                   withIntermediateDirectories:YES 
                                                    attributes:nil 
                                                         error:error]) {
      return NO;
    }
  }
  NSString *applicationPath = [self applicationPath];
  return [self checkApplicationPath:applicationPath error:error];
}

+ (BOOL)installDaemon:(NSError**)error;
{
  NSString *myBundlePath = [[NSBundle mainBundle] bundlePath];
  NSString *applicationPath = [self applicationPath];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  return [fileManager copyItemAtPath:myBundlePath toPath:applicationPath error:error];
}

+ (BOOL)stopDaemon:(NSError**)error
{
  NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
  NSString *command = [NSString stringWithFormat:@"tell application \"%@\" to quit", appName];
  NSAppleScript *quitScript;
  quitScript = [[NSAppleScript alloc] initWithSource:command];
  NSDictionary *errorDict = nil;
  // TODO: This should be turned into an NSError response
  if (![quitScript executeAndReturnError:&errorDict]) {
    ALog(@"Failure. What does it look like: %@", errorDict);
    [quitScript release], quitScript = nil;
    return NO;
  }
  [quitScript release], quitScript = nil;
  return YES;
}

+ (BOOL)updateInstalledApplication:(NSError**)error;
{
  NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"];
  
  if ([self isDaemonRunning] && ![self stopDaemon:error]) return NO;
  
  NSString *myBundlePath = [[NSBundle mainBundle] bundlePath];
  
  NSString *applicationPath = [self applicationPath];
  NSString *basePath = [self basePath];
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  if (![workspace performFileOperation:NSWorkspaceRecycleOperation 
                                source:basePath 
                           destination:@"" 
                                 files:[NSArray arrayWithObject:appName] 
                                   tag:NULL]) {
    NSString *errorDesc = [NSString stringWithFormat:@"Failed to move old app version to the trash"];
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey];
    *error = [NSError errorWithDomain:@"ZSync" code:1126 userInfo:dictionary];
    return NO;
  }
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  return [fileManager copyItemAtPath:myBundlePath toPath:applicationPath error:error];
}

+ (NSString*)pluginPath
{
  NSString *basePath = [self basePath];
  return [basePath stringByAppendingPathComponent:@"Plugins"];
}

+ (BOOL)isPluginInstalled:(NSString*)path error:(NSError**)error
{
  NSString *pluginPath = [self pluginPath];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  if (![fileManager fileExistsAtPath:pluginPath isDirectory:&isDirectory]) {
    return NO;
  }
  if (!isDirectory) {
    NSString *errorDesc = [NSString stringWithFormat:@"Unknown file at plugin installation path: %@", pluginPath];
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey];
    *error = [NSError errorWithDomain:@"ZSync" code:1123 userInfo:dictionary];
    return NO;
  }
  
  NSString *finalPath = [pluginPath stringByAppendingPathComponent:[path lastPathComponent]];
  if (![fileManager fileExistsAtPath:finalPath isDirectory:&isDirectory]) {
    return NO;
  }
  return YES;
}

+ (BOOL)installPluginAtPath:(NSString*)path intoDaemonWithError:(NSError**)error;
{
  if (![[path pathExtension] isEqualToString:@"zsyncPlugin"]) {
    NSString *errorDesc = [NSString stringWithFormat:@"url is not a valid ZSync plugin: %@", path];
    NSDictionary *dictionary = [NSDictionary dictionaryWithObject:errorDesc forKey:NSLocalizedDescriptionKey];
    *error = [NSError errorWithDomain:@"ZSync" code:1125 userInfo:dictionary];
    return NO;
  }
  
  BOOL isDaemonInstalled = [self isDaemonInstalled:error];
  
  if (!isDaemonInstalled && *error) {
    return NO;
  }
  
  if (!isDaemonInstalled) {
    if (![self installDaemon:error]) return NO;
  } else {
    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSInteger currentVersionNumber = [[infoDictionary objectForKey:ZSyncVersionNumber] integerValue];
  
    NSBundle *installed = [NSBundle bundleWithPath:[self applicationPath]];
    NSInteger installedVersionNumber = [[[installed infoDictionary] objectForKey:ZSyncVersionNumber] integerValue];
    
    if (installedVersionNumber < currentVersionNumber && ![self updateInstalledApplication:error]) return NO;
  }
  
  //Is plugin already installed?
  if ([self isPluginInstalled:path error:error]) {
    return YES;
  }
  
  //Shutdown the daemon to install the plugin
  if ([self isDaemonRunning] && ![self stopDaemon:error]) {
    return NO;
  }
  
  //Install the plugin
  NSString *pluginPath = [[self pluginPath] stringByAppendingPathComponent:[path lastPathComponent]];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if (![fileManager copyItemAtPath:path toPath:pluginPath error:error]) {
    return NO;
  }
  
  //Start the daemon back up
  [self startDaemon];
  
  return YES;
}

+ (BOOL)isDaemonRunning;
{
  NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
  NSString *myBundleID = [infoDictionary objectForKey:@"CFBundleIdentifier"];
  
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  NSArray *apps = [workspace launchedApplications];
  for (NSDictionary *appDict in apps) {
    NSString *bundleID = [appDict objectForKey:@"NSApplicationBundleIdentifier"];
    if ([bundleID isEqualToString:myBundleID]) return YES;
  }
  return NO;
}

+ (void)startDaemon;
{
  NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
  NSString *appName = [infoDictionary objectForKey:@"CFBundleExecutable"];
  
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  [workspace launchApplication:appName];
}

@end