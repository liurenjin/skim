// Copyright 2002-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/SourceRelease_2005-10-03/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSAppleEventDescriptor-OAExtensions.h 68913 2005-10-03 19:36:19Z kc $

#import <Foundation/NSAppleEventDescriptor.h>

#ifdef MAC_OS_X_VERSION_10_2

@interface NSAppleEventDescriptor (OAExtensions)

// Why Apple dodn't write this convenience method, I don't know.
+ (NSAppleEventDescriptor *)descriptorWithAEDescNoCopy:(const AEDesc *)aeDesc;

@end

#endif
