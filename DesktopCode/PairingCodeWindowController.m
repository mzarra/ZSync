//
//  PairingCodeWindowController.m
//  SampleDesktop
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

#import "PairingCodeWindowController.h"

@implementation PairingCodeWindowController

- (id)initWithDelegate:(id<PairingCodeDelegate>)aDelegate;
{
  if (![super initWithWindowNibName:@"PairingWindow"]) return nil;
  
  [self setDelegate:aDelegate];
  
  return self;
}

- (void)windowDidLoad
{
  DLog(@"%s fired", __PRETTY_FUNCTION__);
  [super windowDidLoad];
  [[self window] center];
  [[self textField] setStringValue:@""];
  [[self window] makeKeyAndOrderFront:self];
}

- (void)windowDidBecomeKey:(NSNotification*)notification
{
  DLog(@"%s fired", __PRETTY_FUNCTION__);
  [[self textField] becomeFirstResponder];
}

- (void) dealloc
{
  DLog(@"%s window released cleanly", __PRETTY_FUNCTION__);
  [super dealloc];
}

- (IBAction)enterCode:(id)sender;
{
  [[self delegate] pairingCodeWindowController:self codeEntered:[[self textField] stringValue]];
  [[self window] orderOut:nil];
}

- (IBAction)cancel:(id)sender;
{
  [[self delegate] pairingCodeWindowControllerCancelled:self];
  [[self window] orderOut:nil];
}

@synthesize textField;
@synthesize delegate;

@end