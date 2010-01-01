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
#import "ChildViewController.h"

#import "ZSyncTouch.h"

@implementation RootViewController

@synthesize fetchedResultsController, managedObjectContext;

- (void)refresh:(id)sender
{
  NSError *error = nil;
  [[self fetchedResultsController] performFetch:&error];
  ZAssert(error == nil, @"Error fetching: %@", [error localizedDescription]);
}

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad 
{
  [super viewDidLoad];
  
  [self setTitle:@"ZSync Demo"];
  
  UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject)];
  [[self navigationItem] setRightBarButtonItem:button];
  [button release], button = nil;
  
  button = [[UIBarButtonItem alloc] initWithTitle:@"Sync" style:UIBarButtonItemStyleDone target:self action:@selector(sync)];
  [[self navigationItem] setLeftBarButtonItem:button];
  [button release], button = nil;
	
	NSError *error = nil;
  ZAssert([[self fetchedResultsController] performFetch:&error],@"Error fetching: %@", [error localizedDescription]);
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:kRefreshMOC object:nil];
}

- (void)sync
{
  [[ZSyncTouchHandler shared] requestSync];
}

#pragma mark -
#pragma mark Add a new object

- (void)insertSecondChildren:(NSManagedObject*)parent
{
	NSManagedObjectContext *context = [fetchedResultsController managedObjectContext];
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
	NSManagedObjectContext *context = [fetchedResultsController managedObjectContext];
  NSProcessInfo *info = [NSProcessInfo processInfo];
  
  NSInteger count = arc4random() % 10;
  for (NSInteger index = 0; index < count; ++index) {
    NSManagedObject *child = [NSEntityDescription insertNewObjectForEntityForName:@"FirstChild" inManagedObjectContext:context];
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
	NSManagedObjectContext *context = [fetchedResultsController managedObjectContext];
	NSEntityDescription *entity = [[fetchedResultsController fetchRequest] entity];
	NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
	
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
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
  }
  
	NSManagedObject *managedObject = [fetchedResultsController objectAtIndexPath:indexPath];
	[[cell textLabel] setText:[NSString stringWithFormat:@"Row %i with children %i", [indexPath row], [[managedObject valueForKey:@"children"] count]]];
	
  return cell;
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	NSManagedObject *managedObject = [fetchedResultsController objectAtIndexPath:indexPath];
  
  id controller = [[ChildViewController alloc] init];
  [controller setChild:managedObject];
  [[self navigationController] pushViewController:controller animated:YES];
  [controller release], controller = nil;
}

#pragma mark -
#pragma mark Fetched results controller

- (NSFetchedResultsController*)fetchedResultsController 
{
  if (fetchedResultsController) return fetchedResultsController;
  
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"TopLevelObject" inManagedObjectContext:managedObjectContext];
	[fetchRequest setEntity:entity];
	[fetchRequest setFetchBatchSize:20];
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createDate" ascending:NO];
	NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
	
	[fetchRequest setSortDescriptors:sortDescriptors];
	
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
  DLog(@"%s ----------------------------------------------------FIRED!!!!!", __PRETTY_FUNCTION__);
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
