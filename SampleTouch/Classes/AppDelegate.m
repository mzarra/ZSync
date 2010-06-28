#import "AppDelegate.h"
#import "RootViewController.h"
#import "PairingDisplayController.h"
#import "PairingServerTableViewController.h"

@implementation AppDelegate

#pragma mark -
#pragma mark Application lifecycle

- (void)applicationDidFinishLaunching:(UIApplication*)application 
{
	id rootViewController = [navigationController topViewController];
	[rootViewController setManagedObjectContext:[self managedObjectContext]];
	
	[window addSubview:[navigationController view]];
  [window makeKeyAndVisible];
  
  [[ZSyncTouchHandler shared] registerDelegate:self withPersistentStoreCoordinator:[self persistentStoreCoordinator]];
  
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
  
  NSMutableDictionary *options = [NSMutableDictionary dictionary];
  [options setValue:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
  [options setValue:[NSNumber numberWithBool:YES] forKey:NSInferMappingModelAutomaticallyOption];
	
	NSError *error = nil;
  persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
  if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:options error:&error]) {
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
#pragma mark ZSyncDelegate (Required)

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
  UINavigationController *pairingNavController = [[UINavigationController alloc] initWithRootViewController:controller];
  [controller release], controller = nil;
  [[self navigationController] presentModalViewController:pairingNavController animated:YES];
  [pairingNavController release], pairingNavController = nil;
}

- (void)zSyncStarted:(ZSyncTouchHandler*)handler;
{
  DLog(@"entered");
  [navigationController popToRootViewControllerAnimated:YES];
  
  [self showHoverViewWithMessage:@"Syncing"];
}

- (void)zSyncFinished:(ZSyncTouchHandler*)handler;
{
  DLog(@"entered");
  [self hideHoverView];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshMOC object:self];
}

- (void)showCode:(NSString*)code
{
  PairingDisplayController *controller = [[PairingDisplayController alloc] initWithPasscode:code];
  [[self navigationController] presentModalViewController:controller animated:YES];
  [controller release], controller = nil;
}

- (void)zSyncHandler:(ZSyncTouchHandler*)handler displayPairingCode:(NSString*)passcode;
{
  //Let the run cycle complete and insure the previous modal was dismissed
  [self performSelector:@selector(showCode:) withObject:passcode afterDelay:0.1];
}

- (void)zSyncPairingCodeCompleted:(ZSyncTouchHandler*)handler;
{
  [[self navigationController] dismissModalViewControllerAnimated:YES];
}

- (void)zSyncPairingCodeCancelled:(ZSyncTouchHandler*)handler;
{
  [[self navigationController] dismissModalViewControllerAnimated:YES];
}

- (void)zSyncPairingCodeRejected:(ZSyncTouchHandler*)handler;
{
  [[self navigationController] dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark ZSyncDelegate (Optional)

- (void)zSyncDeregisterComplete:(ZSyncTouchHandler*)handler;
{
  DLog(@"fired");
}

- (void)zSync:(ZSyncTouchHandler*)handler errorOccurred:(NSError*)error;
{
  [self hideHoverView];
  
  [[self navigationController] dismissModalViewControllerAnimated:YES];
  
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

- (void)zSyncFileDownloadStarted:(ZSyncTouchHandler*)handler;
{
  DLog(@"entered");
  [self showHoverViewWithMessage:@"Download Started"];
}

- (void)zSyncServerUnavailable:(ZSyncTouchHandler*)handler;
{
  DLog(@"entered");
}

@synthesize window;
@synthesize navigationController;
@synthesize hoverView;
@synthesize hoverLabel;

@end