// Copyright 2001-2004 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OAPreferencesWindow.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/rcsid.h>

RCS_ID("$Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniAppKit/Preferences.subproj/OAPreferencesWindow.m,v 1.5 2004/02/10 04:07:36 kc Exp $");

@implementation OAPreferencesWindow

- (void)runToolbarCustomizationPalette:(id)sender;
{
}

- (BOOL)validateMenuItem:(NSMenuItem *)theItem;
{
    if ([theItem action] == @selector(runToolbarCustomizationPalette:))
        return NO;
    else
        return [super validateMenuItem:theItem];
}

@end
