
@interface AppDelegate : NSObject <UIApplicationDelegate, ZSyncDelegate> 
{
  NSManagedObjectModel *managedObjectModel;
  NSManagedObjectContext *managedObjectContext;	    
  NSPersistentStoreCoordinator *persistentStoreCoordinator;
  
  UIWindow *window;
  UIView *hoverView;
  UILabel *hoverLabel;
  UINavigationController *navigationController;
  UINavigationController *pairingNavController;
}

@property (nonatomic, retain, readonly) IBOutlet UIView *hoverView;
@property (nonatomic, retain, readonly) IBOutlet UILabel *hoverLabel;


@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, assign) IBOutlet UINavigationController *navigationController;
@property (nonatomic, assign) UINavigationController *pairingNavController;

- (NSString*)applicationDocumentsDirectory;

@end

