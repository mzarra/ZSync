#import "AppDelegate.h"
#import "RootViewController.h"
#import "PairingEntryController.h"
#import "PairingServerTableViewController.h"

@implementation AppDelegate

@synthesize window;
@synthesize navigationController;

#pragma mark -
#pragma mark Application lifecycle

- (void)applicationDidFinishLaunching:(UIApplication*)application 
{
	id rootViewController = [navigationController topViewController];
	[rootViewController setManagedObjectContext:[self managedObjectContext]];
	
	[window addSubview:[navigationController view]];
  [window makeKeyAndVisible];
  
  [[ZSyncTouchHandler shared] setDelegate:self];
}

- (void)applicationWillTerminate:(UIApplication*)application 
{
  NSError *error = nil;
  if (!managedObjectContext) return;
  if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  } 
}

#pragma mark -
#pragma mark Core Data stack

- (NSManagedObjectContext*) managedObjectContext 
{
  if (managedObjectContext) return managedObjectContext;
	
  NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
  if (!coordinator) {
    NSLog(@"Failed to load persistent store");
    abort();
  }
  
  managedObjectContext = [[NSManagedObjectContext alloc] init];
  [managedObjectContext setPersistentStoreCoordinator: coordinator];

  return managedObjectContext;
}

- (NSManagedObjectModel*)managedObjectModel 
{
  if (managedObjectModel) return managedObjectModel;

  managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
  
  return managedObjectModel;
}

- (NSPersistentStoreCoordinator*)persistentStoreCoordinator 
{
  if (persistentStoreCoordinator) return persistentStoreCoordinator;
	
  NSURL *storeUrl = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"ApplicationData.sqlite"]];
	
	NSError *error = nil;
  persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
  if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:nil error:&error]) {
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
  }    
  
  return persistentStoreCoordinator;
}

#pragma mark -
#pragma mark Application's Documents directory

- (NSString*)applicationDocumentsDirectory 
{
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

#pragma mark -
#pragma mark ZSyncDelegate

- (void)zSyncNoServerPaired:(NSArray*)availableServers;
{
  //If there is only one server prompt the passkey
  if ([availableServers count] == 0) {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Pairing Error" message:@"No servers were located to pair with" delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
    [alertView show];
    [alertView release], alertView = nil;
    return;
//  } else if ([availableServers count] == 1) {
//    [[ZSyncTouchHandler shared] requestPairing:[availableServers lastObject]];
//    return;
  }
  id controller = [[PairingServerTableViewController alloc] initWithServers:availableServers];
  pairingNavController = [[UINavigationController alloc] initWithRootViewController:controller];
  [[self navigationController] presentModalViewController:pairingNavController animated:YES];
  [controller release], controller = nil;
}

- (void)zSync:(ZSyncTouchHandler*)handler downloadFinished:(NSString*)tempPath;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)zSync:(ZSyncTouchHandler*)handler errorOccurred:(NSError*)error;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}


- (void)zSyncStarted:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)zSyncFileUploaded:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)zSyncPairingRequestAccepted:(ZSyncTouchHandler*)handler;
{
  PairingEntryController *controller = [[PairingEntryController alloc] init];
  [[self navigationController] presentModalViewController:controller animated:YES];
  [controller release], controller = nil;
}

- (void)zSyncFileSyncPing:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)zSyncFileDownloadStarted:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

- (void)zSyncServerUnavailable:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

@end