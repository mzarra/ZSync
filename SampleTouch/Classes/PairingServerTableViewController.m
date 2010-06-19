//
//  PairingServerTableViewController.m
//  SampleTouch
//
//  Created by Marcus S. Zarra on 11/25/09.
//  Copyright 2009 Zarra Studios, LLC. All rights reserved.
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

#import "PairingServerTableViewController.h"
#import "ZSyncTouch.h"

@implementation PairingServerTableViewController

@synthesize servers = _servers;

- (id)initWithServers:(NSArray*)servers;
{
  if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
  
  _servers = [servers retain];
  
  return self;
}

- (void)viewDidLoad 
{
  [super viewDidLoad];
  
  [self setTitle:@"Select Server"];
  
  UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
  [[self navigationItem] setLeftBarButtonItem:button];
  [button release], button = nil;
}

- (void)cancel
{
  [self dismissModalViewControllerAnimated:YES];
}

- (void)viewWillAppear:(BOOL)animated 
{
  [super viewWillAppear:animated];
  NSIndexPath *indexPath = [[self tableView] indexPathForSelectedRow];
  if (!indexPath) return;
  [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark Table view methods

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section 
{
  return [[self servers] count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
  if (!cell) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCellIdentifier] autorelease];
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
  }
  
  ZSyncService *service = [[self servers] objectAtIndex:[indexPath row]];
  [[cell textLabel] setText:[service valueForKey:@"name"]];
  [[cell detailTextLabel] setText:[service valueForKey:@"uuid"]];
	
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
  ZSyncService *service = [[self servers] objectAtIndex:[indexPath row]];
  [[ZSyncTouchHandler shared] performSelector:@selector(requestPairing:) withObject:service afterDelay:0.25];
  [self dismissModalViewControllerAnimated:YES];
}

- (void)dealloc 
{
  [_servers release], _servers = nil;
  [super dealloc];
}


@end