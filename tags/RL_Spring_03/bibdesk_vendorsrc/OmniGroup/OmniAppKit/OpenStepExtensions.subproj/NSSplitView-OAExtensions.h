// Copyright 1997-2003 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.
//
// $Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSSplitView-OAExtensions.h,v 1.8 2003/01/15 22:51:38 kc Exp $

#import <AppKit/NSSplitView.h>

@interface NSSplitView (OAExtensions)
- (float)fraction;
- (void)setFraction:(float)newFract;
- (int)topPixels;
- (void)setTopPixels:(int)newTop;
- (int)bottomPixels;
- (void)setBottomPixels:(int)newBottom;
@end
