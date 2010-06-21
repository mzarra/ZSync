
@interface AppDelegate : NSObject <NSPersistentStoreCoordinatorSyncing>
{
  NSPanel *clientSheet;
  NSArray *clientList;
  NSArrayController *clientListController;
  NSPersistentStoreCoordinator *persistentStoreCoordinator;
  NSManagedObjectModel *managedObjectModel;
  NSManagedObjectContext *managedObjectContext;
  
  NSPanel *syncPanel;
  
  NSWindow *window;
}

@property (nonatomic, retain) IBOutlet NSWindow *window;
@property (nonatomic, retain) IBOutlet NSPanel *syncPanel;
@property (nonatomic, retain) IBOutlet NSArrayController *clientListController;
@property (nonatomic, retain) IBOutlet NSPanel *clientSheet;

@property (nonatomic, retain) NSArray *clientList;

@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;

- (void)validateZSync;

- (IBAction)saveAction:(id)sender;
- (IBAction)addData:(id)sender;
- (IBAction)changeData:(id)sender;
- (IBAction)performSync:(id)sender;
- (IBAction)showClients:(id)sender;
- (IBAction)closeClients:(id)sender;
- (IBAction)deregisterClient:(id)sender;

@end
