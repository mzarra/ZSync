//
//  RootViewController.m
//  SampleTouch
//
//  Created by Marcus S. Zarra on 11/8/09.
//  Copyright Zarra Studios, LLC 2009. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.

#import "RootViewController.h"

#import "ZSyncTouch.h"

@implementation RootViewController

@synthesize fetchedResultsController, managedObjectContext;

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad 
{
  [super viewDidLoad];
  
  [self setTitle:@"ZSync Demo"];
  
//  [[self navigationItem] setLeftBarButtonItem:[self editButtonItem]];
  
  UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject)];
  [[self navigationItem] setRightBarButtonItem:button];
  [button release], button = nil;
  
  button = [[UIBarButtonItem alloc] initWithTitle:@"Pair" style:UIBarButtonItemStyleDone target:self action:@selector(pair)];
  [[self navigationItem] setLeftBarButtonItem:button];
  [button release], button = nil;
	
	NSError *error = nil;
	if (![[self fetchedResultsController] performFetch:&error]) {
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
	}
}

- (void)pair
{
  [[ZSyncTouchHandler shared] requestSync];
}

#pragma mark -
#pragma mark Add a new object

- (void)insertNewObject 
{
	// Create a new instance of the entity managed by the fetched results controller.
	NSManagedObjectContext *context = [fetchedResultsController managedObjectContext];
	NSEntityDescription *entity = [[fetchedResultsController fetchRequest] entity];
	NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
	
	// If appropriate, configure the new managed object.
	[newManagedObject setValue:[NSDate date] forKey:@"timeStamp"];
	
	// Save the context.
  NSError *error = nil;
  if (![context save:&error]) {
		/*
		 Replace this implementation with code to handle the error appropriately.
		 
		 abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
		 */
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
  }
}

#pragma mark -
#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView 
{
  return [[fetchedResultsController sections] count];
}


- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section 
{
	id sectionInfo = [[fetchedResultsController sections] objectAtIndex:section];
  return [sectionInfo numberOfObjects];
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath 
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
  if (!cell) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier] autorelease];
  }
  
	NSManagedObject *managedObject = [fetchedResultsController objectAtIndexPath:indexPath];
	[[cell textLabel] setText:[[managedObject valueForKey:@"timeStamp"] description]];
	
  return cell;
}

// Override to support editing the table view.
- (void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath 
{
  
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    // Delete the managed object for the given index path
		NSManagedObjectContext *context = [fetchedResultsController managedObjectContext];
		[context deleteObject:[fetchedResultsController objectAtIndexPath:indexPath]];
		
		// Save the context.
		NSError *error = nil;
		if (![context save:&error]) {
			NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
			abort();
		}
	}   
}

- (BOOL)tableView:(UITableView*)tableView canMoveRowAtIndexPath:(NSIndexPath*)indexPath 
{
  // The table view should not be re-orderable.
  return NO;
}

#pragma mark -
#pragma mark Fetched results controller

- (NSFetchedResultsController*)fetchedResultsController 
{
  if (fetchedResultsController) return fetchedResultsController;
  
  /*
	 Set up the fetched results controller.
   */
	// Create the fetch request for the entity.
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	// Edit the entity name as appropriate.
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:managedObjectContext];
	[fetchRequest setEntity:entity];
	
	// Set the batch size to a suitable number.
	[fetchRequest setFetchBatchSize:20];
	
	// Edit the sort key as appropriate.
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO];
	NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
	
	[fetchRequest setSortDescriptors:sortDescriptors];
	
	// Edit the section name key path and cache name if appropriate.
  // nil for section name key path means "no sections".
	NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:managedObjectContext sectionNameKeyPath:nil cacheName:@"Root"];
  [aFetchedResultsController setDelegate:self];
	[self setFetchedResultsController:aFetchedResultsController];
	
	[aFetchedResultsController release], aFetchedResultsController = nil;
	[fetchRequest release], fetchRequest = nil;
	[sortDescriptor release], sortDescriptor = nil;
	[sortDescriptors release], sortDescriptors = nil;
	
	return fetchedResultsController;
}    

- (void)controllerDidChangeContent:(NSFetchedResultsController*)controller 
{
	[[self tableView] reloadData];
}

#pragma mark -
#pragma mark Memory management

- (void)dealloc 
{
	[fetchedResultsController release], fetchedResultsController = nil;
	[managedObjectContext release], managedObjectContext = nil;
  [super dealloc];
}

@end