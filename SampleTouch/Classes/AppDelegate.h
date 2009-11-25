#import "ZSyncTouch.h"

@interface AppDelegate : NSObject <UIApplicationDelegate, ZSyncDelegate> 
{
  NSManagedObjectModel *managedObjectModel;
  NSManagedObjectContext *managedObjectContext;	    
  NSPersistentStoreCoordinator *persistentStoreCoordinator;
  
  UIWindow *window;
  UINavigationController *navigationController;
  UINavigationController *pairingNavController;
}

@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, assign) IBOutlet UINavigationController *navigationController;

- (NSString*)applicationDocumentsDirectory;

@end

