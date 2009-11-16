#import "AppDelegate.h"
#import "RootViewController.h"

#import "ZSyncTouch.h"

@implementation AppDelegate

@synthesize window;
@synthesize navigationController;

#pragma mark -
#pragma mark Application lifecycle

- (void)applicationDidFinishLaunching:(UIApplication *)application 
{
	id rootViewController = [navigationController topViewController];
	[rootViewController setManagedObjectContext:[self managedObjectContext]];
	
	[window addSubview:[navigationController view]];
  [window makeKeyAndVisible];
  
  [[ZSyncTouchHandler shared] startBrowser];
}

- (void)applicationWillTerminate:(UIApplication *)application 
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

- (NSManagedObjectContext *) managedObjectContext 
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

- (NSManagedObjectModel *)managedObjectModel 
{
  if (managedObjectModel) return managedObjectModel;

  managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
  
  return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator 
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

- (NSString *)applicationDocumentsDirectory 
{
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

@end
