#import "ChildViewController.h"

@implementation ChildViewController

@synthesize child;

- (id)init
{
  if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
  
  [self setTitle:@"Child View"];
  
  return self;
}

- (void)dealloc 
{
  [child release], child = nil;
  [super dealloc];
}

#pragma mark Table view methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
  return [[[self child] valueForKey:@"children"] count];
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath 
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
  if (!cell) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier] autorelease];
  }
  
  NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"attribute1" ascending:YES];
  NSArray *sortedChildren = [[[[self child] valueForKey:@"children"] allObjects] sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];
  [sort release], sort = nil;
  
	NSManagedObject *managedObject = [sortedChildren objectAtIndex:[indexPath row]];
	[[cell textLabel] setText:[NSString stringWithFormat:@"Row %i with children %i", [indexPath row], [[managedObject valueForKey:@"children"] count]]];
	
  return cell;
}

@end

