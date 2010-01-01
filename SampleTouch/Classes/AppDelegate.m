#import "AppDelegate.h"
#import "RootViewController.h"
#import "PairingEntryController.h"
#import "PairingServerTableViewController.h"

@implementation AppDelegate

@synthesize window;
@synthesize navigationController;
@synthesize pairingNavController;
@synthesize hoverView, hoverLabel;

#pragma mark -
#pragma mark Application lifecycle

- (void)applicationDidFinishLaunching:(UIApplication*)application 
{
	id rootViewController = [navigationController topViewController];
	[rootViewController setManagedObjectContext:[self managedObjectContext]];
	
	[window addSubview:[navigationController view]];
  [window makeKeyAndVisible];
  
  [[ZSyncTouchHandler shared] registerDelegate:self withPersistentStoreCoordinator:[self persistentStoreCoordinator] schemaName:kSyncSchemaName];
  
  [[[self hoverView] layer] setCornerRadius:10.0f];
  [[[self hoverView] layer] setBorderColor:[[UIColor whiteColor] CGColor]];
  [[[self hoverView] layer] setBorderWidth:2.0f];
  [[self hoverView] setCenter:CGPointMake(160, 240)];
  [[[self hoverView] layer] setZPosition:100.0f];
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

- (void)hideHoverView
{
  if (![[self hoverView] superview]) return;
  [[self hoverView] removeFromSuperview];
}

- (void)showHoverViewWithMessage:(NSString*)message
{
  [[self hoverLabel] setText:message];
  if ([[self hoverView] superview]) return;
  [[self window] addSubview:[self hoverView]];
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
  }
  id controller = [[PairingServerTableViewController alloc] initWithServers:availableServers];
  pairingNavController = [[UINavigationController alloc] initWithRootViewController:controller];
  [[self navigationController] presentModalViewController:pairingNavController animated:YES];
  [controller release], controller = nil;
}

- (void)zSync:(ZSyncTouchHandler*)handler errorOccurred:(NSError*)error;
{
  [self hideHoverView];
  
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sync Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
  [alert show];
  [alert release], alert = nil;
  
  DLog(@"Failure: %@", [error localizedDescription]);
}

- (void)zSync:(ZSyncTouchHandler*)handler serverVersionUnsupported:(NSError*)error;
{
  [self hideHoverView];
  
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sync Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Close" otherButtonTitles:nil];
  [alert show];
  [alert release], alert = nil;
  
  DLog(@"Failure: %@", [error localizedDescription]);
}

- (void)zSyncStarted:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  [navigationController popToRootViewControllerAnimated:YES];
  
  [self showHoverViewWithMessage:@"Syncing"];
}

- (void)zSyncFinished:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  [self hideHoverView];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshMOC object:self];
}

- (void)zSyncPairingRequestAccepted:(ZSyncTouchHandler*)handler;
{
  PairingEntryController *controller = [[PairingEntryController alloc] init];
  if (![self pairingNavController]) {
    [[self navigationController] presentModalViewController:controller animated:YES];
  } else {
    [[self pairingNavController] pushViewController:controller animated:YES];
  }
  [controller release], controller = nil;
}

- (void)zSyncPairingCodeRejected:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  PairingEntryController *controller = [[PairingEntryController alloc] init];
  [[self navigationController] presentModalViewController:controller animated:YES];
  [controller release], controller = nil;
}

- (void)zSyncPairingCodeApproved:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  [self showHoverViewWithMessage:@"Download Started"];
  [self performSelector:@selector(hideHoverView) withObject:nil afterDelay:5.0];
}

- (void)zSyncFileDownloadStarted:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
  [self showHoverViewWithMessage:@"Download Started"];
}

- (void)zSyncServerUnavailable:(ZSyncTouchHandler*)handler;
{
  DLog(@"%s entered", __PRETTY_FUNCTION__);
}

@end