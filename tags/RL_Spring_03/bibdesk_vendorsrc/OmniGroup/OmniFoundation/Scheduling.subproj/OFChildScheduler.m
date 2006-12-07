// Copyright 1999-2003 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.

#import "OFChildScheduler.h"

#import <Foundation/NSLock.h> // Working around precompiler bug
#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>

#import "OFScheduledEvent.h"

RCS_ID("$Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniFoundation/Scheduling.subproj/OFChildScheduler.m,v 1.6 2003/01/15 22:52:01 kc Exp $")

@implementation OFChildScheduler

// Init and dealloc

- initWithParentScheduler:(OFScheduler *)aParent;
{
    if ([super init] == nil)
        return nil;
    parent = [aParent retain];
    return self;
}


- (void)dealloc;
{
    [self cancelScheduledEvents];
    [parent release];
    [super dealloc];
}


// OFScheduler subclass

- (void)invokeScheduledEvents;
{
    [scheduleLock lock];
    [parentAlarmEvent release];
    parentAlarmEvent = nil;
    [scheduleLock unlock];
    [super invokeScheduledEvents];
}

- (void)scheduleEvents;
{
    NSDate *dateOfFirstEvent;

    [scheduleLock lock];
    // Reschedule with parent
    [self cancelScheduledEvents];
    dateOfFirstEvent = [self dateOfFirstEvent];
    if (dateOfFirstEvent != nil) {
        OBASSERT(parentAlarmEvent == nil);
        parentAlarmEvent = [[parent scheduleSelector:@selector(invokeScheduledEvents) onObject:self withObject:nil atDate:dateOfFirstEvent] retain];
    }
    [scheduleLock unlock];
}

- (void)cancelScheduledEvents;
{
    [scheduleLock lock];
    if (parentAlarmEvent != nil) {
        [parent abortEvent:parentAlarmEvent];
        [parentAlarmEvent release];
        parentAlarmEvent = nil;
    }
    [scheduleLock unlock];
}

// OBObject subclass

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (parent != nil)
        [debugDictionary setObject:[parent shortDescription] forKey:@"parent"];
    if (parentAlarmEvent != nil)
        [debugDictionary setObject:parentAlarmEvent forKey:@"parentAlarmEvent"];

    return debugDictionary;
}

@end
