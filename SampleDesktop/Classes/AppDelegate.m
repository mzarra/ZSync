#import "AppDelegate.h"

@interface AppDelegate()

- (ISyncClient*)syncClient;

@end

@implementation AppDelegate

@synthesize window;

- (NSString*)applicationSupportDirectory 
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
  return [basePath stringByAppendingPathComponent:@"SampleDesktop"];
}

#pragma mark -
#pragma mark Application Delegate

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
  //Register the sync client
  NSString *path = [[NSBundle mainBundle] pathForResource:@"ZSyncSample" ofType:@"syncschema"];
  ZAssert([[ISyncManager sharedManager] registerSchemaWithBundlePath:path], @"Failed to register sync schema");
  [[self syncClient] setSyncAlertHandler:self selector:@selector(syncClient:willSyncEntityNames:)];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender 
{
  if (!managedObjectContext) return NSTerminateNow;
  
  if (![managedObjectContext commitEditing]) {
    NSLog(@"%@:%s unable to commit editing to terminate", [self class], _cmd);
    return NSTerminateCancel;
  }
  
  if (![managedObjectContext hasChanges]) return NSTerminateNow;
  
  NSError *error = nil;
  if (![managedObjectContext save:&error]) {
    
    BOOL result = [sender presentError:error];
    if (result) return NSTerminateCancel;
    
    NSString *question = NSLocalizedString(@"Could not save changes while quitting.  Quit anyway?", @"Quit without saves error question message");
    NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
    NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
    NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:question];
    [alert setInformativeText:info];
    [alert addButtonWithTitle:quitButton];
    [alert addButtonWithTitle:cancelButton];
    
    NSInteger answer = [alert runModal];
    [alert release];
    alert = nil;
    
    if (answer == NSAlertAlternateReturn) return NSTerminateCancel;
    
  }
  
  return NSTerminateNow;
}

- (ISyncClient*)syncClient;
{
  NSString *clientIdentifier = [[NSBundle mainBundle] bundleIdentifier];
  ISyncClient *client = nil;
  client = [[ISyncManager sharedManager] registerClientWithIdentifier:clientIdentifier descriptionFilePath:[[NSBundle mainBundle] pathForResource:@"clientDescription" ofType:@"plist"]];
  [client setShouldSynchronize:YES withClientsOfType:ISyncClientTypeApplication];
  [client setShouldSynchronize:YES withClientsOfType:ISyncClientTypeDevice];
  [client setShouldSynchronize:YES withClientsOfType:ISyncClientTypeServer];
  [client setShouldSynchronize:YES withClientsOfType:ISyncClientTypePeer];  
  return client;
}

- (void)syncClient:(ISyncClient*)syncClient willSyncEntityNames:(NSArray*)entityNames;
{
  DLog(@"%s fired %@", __PRETTY_FUNCTION__, entityNames);
  NSError *error = nil;
  [[self persistentStoreCoordinator] syncWithClient:syncClient inBackground:NO handler:self error:&error];
  ZAssert(error == nil, @"Error requesting sync: %@", [error localizedDescription]);
}

#pragma mark -
#pragma mark Window Delegate

- (NSUndoManager*)windowWillReturnUndoManager:(NSWindow*)window 
{
  return [[self managedObjectContext] undoManager];
}

#pragma mark -
#pragma mark Core Data

- (void)insertSecondChildren:(NSManagedObject*)parent
{
	NSManagedObjectContext *context = [self managedObjectContext];
  NSProcessInfo *info = [NSProcessInfo processInfo];
  
  NSInteger count = arc4random() % 10;
  for (NSInteger index = 0; index < count; ++index) {
    NSManagedObject *child = [NSEntityDescription insertNewObjectForEntityForName:@"SecondChild" 
                                                           inManagedObjectContext:context];
    [child setValue:[info globallyUniqueString] forKey:@"attribute1"];
    [child setValue:[info globallyUniqueString] forKey:@"attribute2"];
    [child setValue:[info globallyUniqueString] forKey:@"attribute3"];
    [child setValue:[info globallyUniqueString] forKey:@"attribute4"];
    [child setValue:parent forKey:@"parent"];
  }
}

- (void)insertFirstChildren:(NSManagedObject*)parent
{
	NSManagedObjectContext *context = [self managedObjectContext];
  NSProcessInfo *info = [NSProcessInfo processInfo];
  
  NSInteger count = arc4random() % 10;
  for (NSInteger index = 0; index < count; ++index) {
    NSManagedObject *child = [NSEntityDescription insertNewObjectForEntityForName:@"FirstChild" 
                                                           inManagedObjectContext:context];
    [child setValue:[info globallyUniqueString] forKey:@"attribute1"];
    [child setValue:[info globallyUniqueString] forKey:@"attribute2"];
    [child setValue:[info globallyUniqueString] forKey:@"attribute3"];
    [child setValue:[info globallyUniqueString] forKey:@"attribute4"];
    [child setValue:parent forKey:@"parent"];
    [self insertSecondChildren:child];
  }
}

- (void)insertNewObject 
{
	// Create a new instance of the entity managed by the fetched results controller.
	NSManagedObjectContext *context = [self managedObjectContext];
	NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"TopLevelObject"
                                                                    inManagedObjectContext:context];
	
	// If appropriate, configure the new managed object.
  NSProcessInfo *info = [NSProcessInfo processInfo];
  
  [newManagedObject setValue:[NSDate date] forKey:@"createDate"];
	[newManagedObject setValue:[info globallyUniqueString] forKey:@"attribute1"];
	[newManagedObject setValue:[info globallyUniqueString] forKey:@"attribute2"];
	[newManagedObject setValue:[info globallyUniqueString] forKey:@"attribute3"];
	[newManagedObject setValue:[info globallyUniqueString] forKey:@"attribute4"];
  [self insertFirstChildren:newManagedObject];
	
	// Save the context.
  NSError *error = nil;
  ZAssert([context save:&error], @"Error saving context: %@", [error localizedDescription]);
}

- (void)modifySecondChild:(NSManagedObject*)object
{
  NSProcessInfo *info = [NSProcessInfo processInfo];
  
	[object setValue:[info globallyUniqueString] forKey:@"attribute1"];
	[object setValue:[info globallyUniqueString] forKey:@"attribute2"];
	[object setValue:[info globallyUniqueString] forKey:@"attribute3"];
	[object setValue:[info globallyUniqueString] forKey:@"attribute4"];
}

- (void)modifyFirstChild:(NSManagedObject*)object
{
  NSProcessInfo *info = [NSProcessInfo processInfo];
  
	[object setValue:[info globallyUniqueString] forKey:@"attribute1"];
	[object setValue:[info globallyUniqueString] forKey:@"attribute2"];
	[object setValue:[info globallyUniqueString] forKey:@"attribute3"];
	[object setValue:[info globallyUniqueString] forKey:@"attribute4"];
  
  if ((arc4random() % 4) == 1) [self insertSecondChildren:object];
  for (NSManagedObject *child in [object valueForKey:@"children"]) {
    switch ((arc4random() % 10)) {
      case 1:
        [[self managedObjectContext] deleteObject:child];
        break;
      case 5:
        [self modifySecondChild:child];
    }
  }
}

- (void)modifyTopObject:(NSManagedObject*)object
{
  NSProcessInfo *info = [NSProcessInfo processInfo];
  
	[object setValue:[info globallyUniqueString] forKey:@"attribute1"];
	[object setValue:[info globallyUniqueString] forKey:@"attribute2"];
	[object setValue:[info globallyUniqueString] forKey:@"attribute3"];
	[object setValue:[info globallyUniqueString] forKey:@"attribute4"];
  
  if ((arc4random() % 4) == 1) [self insertFirstChildren:object];
  for (NSManagedObject *child in [object valueForKey:@"children"]) {
    switch ((arc4random() % 10)) {
      case 1:
        [[self managedObjectContext] deleteObject:child];
        break;
      case 5:
        [self modifyFirstChild:child];
    }
  }
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
  
  NSManagedObjectModel *mom = [self managedObjectModel];
  
  if (!mom) {
    ALog(@"Managed object model is nil");
    NSLog(@"%@:%s No model to generate a store from", [self class], _cmd);
    return nil;
  }
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *applicationSupportDirectory = [self applicationSupportDirectory];
  NSError *error = nil;
  
  if (![fileManager fileExistsAtPath:applicationSupportDirectory isDirectory:NULL]) {
		if (![fileManager createDirectoryAtPath:applicationSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error]) {
      ALog(@"Failed to create App Support directory %@ : %@", applicationSupportDirectory, error);
      return nil;
		}
  }
  
  NSURL *url = [NSURL fileURLWithPath: [applicationSupportDirectory stringByAppendingPathComponent: @"dataFile.sqlite"]];
  persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: mom];
  
  NSPersistentStore *store = nil;
  store = [persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType 
                                                   configuration:nil 
                                                             URL:url 
                                                         options:nil 
                                                           error:&error];
  ZAssert(store != nil, @"Error creating store: %@", [error localizedDescription]);
  
  NSURL *fastSyncURL = [NSURL fileURLWithPath:[applicationSupportDirectory stringByAppendingPathComponent:@"dataFile.fastsyncstore"]];
  [persistentStoreCoordinator setStoresFastSyncDetailsAtURL:fastSyncURL forPersistentStore:store];
  
  
  return persistentStoreCoordinator;
}

- (NSManagedObjectContext*)managedObjectContext 
{
  if (managedObjectContext) return managedObjectContext;
  
  NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
  if (!coordinator) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
    [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
    NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
    [[NSApplication sharedApplication] presentError:error];
    return nil;
  }
  managedObjectContext = [[NSManagedObjectContext alloc] init];
  [managedObjectContext setPersistentStoreCoordinator: coordinator];
  
  return managedObjectContext;
}

#pragma mark -
#pragma mark Actions

- (IBAction)addData:(id)sender;
{
  NSInteger numberOfNewRecords = arc4random() % 100;
  for (NSInteger index = 0; index < numberOfNewRecords; ++index) {
    [self insertNewObject];
  }
  NSError *error = nil;
  ZAssert([[self managedObjectContext] save:&error], @"Error saving context: %@", [error localizedDescription]);
}

- (IBAction)changeData:(id)sender;
{
  NSManagedObjectContext *moc = [self managedObjectContext];
  NSFetchRequest *request = [[NSFetchRequest alloc] init];
  [request setEntity:[NSEntityDescription entityForName:@"TopLevelObject" inManagedObjectContext:moc]];
  
  NSError *error = nil;
  NSArray *array = [moc executeFetchRequest:request error:&error];
  ZAssert(error == nil, @"Error fetching objects: %@", [error localizedDescription]);
  
  for (NSManagedObject *topLevelObject in array) {
    if ((arc4random() % 3) == 0) continue;
    [self modifyTopObject:topLevelObject];
  }
  
  ZAssert([moc save:&error], @"Error saving context: %@", [error localizedDescription]);
}

- (IBAction)saveAction:(id)sender 
{
  NSError *error = nil;
  
  ZAssert([[self managedObjectContext] commitEditing], @"Failed to commit");
  ZAssert([[self managedObjectContext] save:&error], @"Error saving context: %@", [error localizedDescription]);
  
  ISyncClient *client = [self syncClient];
  ZAssert(client != nil,@"Sync client is nil");
  [[self persistentStoreCoordinator] syncWithClient:client inBackground:NO handler:self error:&error];
  ZAssert(error == nil, @"Error requesting sync: %@", [error localizedDescription]);
}

#pragma mark - 
#pragma mark NSPersistentStoreCoordinatorSyncing

- (void)persistentStoreCoordinator:(NSPersistentStoreCoordinator*)coordinator 
              didFinishSyncSession:(ISyncSession*)session
{
  DLog(@"%s fired", __PRETTY_FUNCTION__);
}

@end