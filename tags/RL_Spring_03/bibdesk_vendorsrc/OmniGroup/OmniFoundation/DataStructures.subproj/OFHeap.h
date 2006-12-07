// Copyright 1997-2003 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.
//
// $Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniFoundation/DataStructures.subproj/OFHeap.h,v 1.12 2003/01/15 22:51:54 kc Exp $

#import <OmniFoundation/OFObject.h>

#import <Foundation/NSObjCRuntime.h> // for NSComparisonResult

@class OFHeap;

// Functions used as the comparison in an OFHeap should return NSOrderedAscending if
// object1 should be above the heap as compared to object2.  That is, the 'least'
// object will be returned from the heap first.
typedef NSComparisonResult (*OFHeapComparisonFunction)(OFHeap *heap, void *userInfo, id object1, id object2);


@interface OFHeap : OFObject
{
    id                        *_objects;
    unsigned int               _count, _capacity;
    OFHeapComparisonFunction   _comparisonFunction;
    void                      *_userInfo;
}

- initWithCapacity: (unsigned int)newCapacity
   compareFunction: (OFHeapComparisonFunction) comparisonFunction
          userInfo: (void *) userInfo;

- initWithCapacity: (unsigned int)newCapacity
   compareSelector: (SEL) comparisonSelector;

- (unsigned int) count;

- (void)addObject:(id) anObject;

- (id) removeObject;
- (id) removeObjectLessThanObject: (id) object;

- (void) removeAllObjects;

- (id) peekObject;

@end
