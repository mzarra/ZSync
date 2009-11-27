//
//  PairingEntryController.m
//  SampleTouch
//
//  Created by Marcus S. Zarra on 11/23/09.
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

#import "PairingEntryController.h"

@implementation PairingEntryController

@synthesize field1;
@synthesize field2;
@synthesize field3;
@synthesize field4;

- (id)init;
{
  if (!(self = [super initWithNibName:@"PairingView" bundle:nil])) return nil;
  
  return self;
}

- (void)cancel
{
  [self dismissModalViewControllerAnimated:YES];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self setTitle:@"Authenticate"];
  
  [[self view] setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
  
  if ([[[self navigationController] viewControllers] count] == 1) {
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    [[self navigationItem] setLeftBarButtonItem:button];
    [button release], button = nil;
  }
  
  [[self field1] becomeFirstResponder];
}

- (void)authenticate
{
  NSMutableString *string = [NSMutableString string];
  [string appendString:[[self field1] text]];
  [string appendString:[[self field2] text]];
  [string appendString:[[self field3] text]];
  [string appendString:[[self field4] text]];
  [[ZSyncTouchHandler shared] authenticatePairing:string];
  [self dismissModalViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
  [textField setText:@""];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
  NSMutableString *tempString = [NSMutableString stringWithString:[textField text]];
  [tempString replaceCharactersInRange:range withString:string];
  if ([tempString length] <= 0) return YES;
  if ([tempString length] > 1) return NO;
  
  if (textField == [self field1]) {
    [[self field2] performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.01];
  } else if (textField == [self field2]) {
    [[self field3] performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.01];
  } else if (textField == [self field3]) {
    [[self field4] performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.01];
  } else if (textField == [self field4]) {
    [self performSelector:@selector(authenticate) withObject:nil afterDelay:0.1];
  }
  return YES;
}

@end