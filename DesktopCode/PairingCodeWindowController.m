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
  if (![super initWithWindowNibName:@"PairingWindow"]) {
    return nil;
  }
  
  [self setDelegate:aDelegate];
  
  return self;
}

- (void)windowDidLoad
{
  [super windowDidLoad];
  
  [NSApp activateIgnoringOtherApps:YES];
  
  [[self window] center];
  [[self textField1] setStringValue:@""];
  [[self textField2] setStringValue:@""];
  [[self textField3] setStringValue:@""];
  [[self textField4] setStringValue:@""];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:[self textField1]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:[self textField2]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:[self textField3]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSControlTextDidChangeNotification object:[self textField4]];
  
  [[self window] makeKeyAndOrderFront:self];
  [[self textField1] becomeFirstResponder];
}

- (void)textDidChange:(NSNotification *)aNotification
{
  NSTextField *textField = [aNotification object];
  if ([textField isEqual:[self textField1]]) {
    if ([[textField stringValue] length] > 0) {
      [[textField nextKeyView] becomeFirstResponder];
    }
  } else if ([textField isEqual:[self textField2]]) {
    if ([[textField stringValue] length] > 0) {
      [[textField nextKeyView] becomeFirstResponder];
    } else {
      [[self textField1] becomeFirstResponder];
    }
  } else if ([textField isEqual:[self textField3]]) {
    if ([[textField stringValue] length] > 0) {
      [[textField nextKeyView] becomeFirstResponder];
    } else {
      [[self textField2] becomeFirstResponder];
    }
  } else if ([textField isEqual:[self textField4]]) {
    if ([[textField stringValue] length] == 0) {
      [[self textField3] becomeFirstResponder];
    }
  }
}

- (void)dealloc
{
  [textField1 release], textField1 = nil;
  [textField2 release], textField2 = nil;
  [textField3 release], textField3 = nil;
  [textField4 release], textField4 = nil;
  
  DLog(@"window released cleanly");
  [super dealloc];
}

- (IBAction)enterCode:(id)sender;
{
  NSString *pairingCode = [[[self textField1] stringValue] stringByAppendingFormat:@"%@%@%@", [[self textField2] stringValue], [[self textField3] stringValue], [[self textField4] stringValue]];
  [[self delegate] pairingCodeWindowController:self codeEntered:pairingCode];
}

- (IBAction)cancel:(id)sender;
{
  [[self delegate] pairingCodeWindowControllerCancelled:self];
  [NSApp hide:self];
}

- (CAKeyframeAnimation *)shakeAnimation:(NSRect)frame
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
  [[self textField1] setStringValue:@""];
  [[self textField2] setStringValue:@""];
  [[self textField3] setStringValue:@""];
  [[self textField4] setStringValue:@""];
  [[self textField1] becomeFirstResponder];
}

@synthesize textField1;
@synthesize textField2;
@synthesize textField3;
@synthesize textField4;
@synthesize delegate;

@end
