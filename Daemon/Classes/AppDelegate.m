//
//  DaemonAppDelegate.m
//  Daemon
//
//  Created by Marcus S. Zarra on 12/31/09.
//  Copyright 2009 Zarra Studios LLC. All rights reserved.
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
//

#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification 
{
  [[ZSyncHandler shared] setDelegate:self];
  [[ZSyncHandler shared] startBroadcasting];
  
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"ZSync"];
  
  NSMenuItem *aboutMenu = [[NSMenuItem alloc] initWithTitle:@"About" action:@selector(about:) keyEquivalent:@""];
  [menu addItem:aboutMenu];
  [aboutMenu release], aboutMenu = nil;

  [menu addItem:[NSMenuItem separatorItem]];
  
  NSMenuItem *quitMenu = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@""];
  [menu addItem:quitMenu];
  [quitMenu release], quitMenu = nil;
  
  NSImage *statusImage = [NSImage imageNamed:@"menubar.png"];
  
  statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:[statusImage size].width] retain];
  [statusItem setMenu:menu];
  [statusItem setToolTip:NSLocalizedString(@"ZSync Daemon", @"ZSync menu bar toolitp")];
  [statusItem setImage:statusImage];
  [statusItem setAction:@selector(statusItemSelected:)];
  
  [menu release], menu = nil;
  
  [[NSApplication sharedApplication] hide:self];
}

- (IBAction)about:(id)sender
{
  DLog(@"fired");
}

- (IBAction)quit:(id)sender
{
  DLog(@"fired");
  [[NSApplication sharedApplication] terminate:self];
}

@synthesize statusItem;

@end
