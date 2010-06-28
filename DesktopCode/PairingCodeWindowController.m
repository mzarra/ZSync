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
#import <QuartzCore/CoreAnimation.h>

@implementation PairingCodeWindowController

static int numberOfShakes = 4;
static float durationOfShake = 0.1f;
static float vigourOfShake = 0.02f;

- (id)initWithDelegate:(id<PairingCodeDelegate>)aDelegate;
{
  if (![super initWithWindowNibName:@"PairingWindow"]) return nil;
  
  [self setDelegate:aDelegate];
  
  return self;
}

- (void)windowDidLoad
{
  [super windowDidLoad];
  
  [NSApp activateIgnoringOtherApps:YES];
  
  [[self window] center];
  [[self textField] setStringValue:@""];
  [[self window] makeKeyAndOrderFront:self];
  [[self textField] becomeFirstResponder];
}

- (void) dealloc
{
  DLog(@"window released cleanly");
  [super dealloc];
}

- (IBAction)enterCode:(id)sender;
{
  [[self delegate] pairingCodeWindowController:self codeEntered:[[self textField] stringValue]];
}

- (IBAction)cancel:(id)sender;
{
  [[self delegate] pairingCodeWindowControllerCancelled:self];
  [NSApp hide:self];
}

- (CAKeyframeAnimation*)shakeAnimation:(NSRect)frame
{
  CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"frame"];
  
  NSRect rect1 = NSMakeRect(NSMinX(frame) - frame.size.width * vigourOfShake, NSMinY(frame), frame.size.width, frame.size.height);
  NSRect rect2 = NSMakeRect(NSMinX(frame) + frame.size.width * vigourOfShake, NSMinY(frame), frame.size.width, frame.size.height);
  NSArray *arr = [NSArray arrayWithObjects:[NSValue valueWithRect:rect1], [NSValue valueWithRect:rect2], nil];
  [animation setValues:arr];
  
  [animation setDuration:durationOfShake];
  [animation setRepeatCount:numberOfShakes];
  
  return animation;
}

- (void)refuseCode;
{
  NSRect frame = [[self window] frame];
  [[self window] setAnimations:[NSDictionary dictionaryWithObject:[self shakeAnimation:frame] forKey:@"frame"]];
  [[[self window] animator] setFrame:frame display:NO];
  [[self textField] setStringValue:@""];
  [[self textField] becomeFirstResponder];
}

@synthesize textField;
@synthesize delegate;

@end
