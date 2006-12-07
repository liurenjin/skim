//
//  NSMutableArray+ThreadSafety.m
//  BibDesk
//
//  Created by Adam Maxwell on 01/27/05.
/*
 This software is Copyright (c) 2005
 Adam Maxwell. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Adam Maxwell nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSMutableArray+ThreadSafety.h"


@implementation NSMutableArray (ThreadSafety)

- (void)addObject:(id)anObject usingLock:(NSLock *)aLock{
    
    [aLock lock];
    [anObject retain];
    [self addObject:anObject];
    [anObject release];
    [aLock unlock];    
}

- (void)insertObject:(id)anObject atIndex:(unsigned)index usingLock:(NSLock *)aLock{
    
    [aLock lock];
    [anObject retain];
    [self insertObject:anObject atIndex:index];
    [anObject release];
    [aLock unlock];    
}

- (id)objectAtIndex:(unsigned)index usingLock:(NSLock *)aLock{
    
    id result;
    
    [aLock lock];
    result = [self objectAtIndex:index];
    [[result retain] autorelease];
    [aLock unlock];
    
    return result;
}
    
- (void)removeObjectAtIndex:(unsigned)index usingLock:(NSLock *)aLock{
    
    [aLock lock];
    [self removeObjectAtIndex:index];
    [aLock unlock];
}

- (void)removeObject:(id)anObject usingLock:(NSLock *)aLock{
    
    [aLock lock];
    [self removeObject:anObject];
    [aLock unlock];
}

- (BOOL)containsObject:(id)anObject usingLock:(NSLock *)aLock{
    
    BOOL yn;
    
    [aLock lock];
    [anObject retain];
    yn = [self containsObject:anObject];
    [anObject release];
    [aLock unlock];
    
    return yn;
}

- (void)removeObjectIdenticalTo:(id)anObject usingLock:(NSLock *)aLock{
    
    [aLock lock];
    [self removeObjectIdenticalTo:anObject];
    [aLock unlock];
}

- (void)addObjectsFromArray:(NSArray *)anArray usingLock:(NSLock *)aLock{
    
    [aLock lock];
    [anArray retain];
    [self addObjectsFromArray:anArray];
    [anArray release];
    [aLock unlock];
}

- (void)removeAllObjectsUsingLock:(NSLock *)aLock{
    
    [aLock lock];
    [self removeAllObjects];
    [aLock unlock];
}

- (unsigned)indexOfObjectIdenticalTo:(id)anObject usingLock:(NSLock *)aLock{
    
    unsigned index;
    [aLock lock];
    [anObject retain];
    index = [self indexOfObjectIdenticalTo:anObject];
    [anObject release];
    [aLock unlock];
    return index;
}

- (void)sortUsingSelector:(SEL)comparator ascending:(BOOL)ascend usingLock:(NSLock *)aLock;
{
    [aLock lock];
    [self sortUsingSelector:comparator];
    [aLock unlock];
    
    if(ascend)
        return;
    
    [aLock lock];
    
    int rhIndex = ([self count] - 1);
    int lhIndex = 0;
    
    while( (rhIndex - lhIndex) > 0)
        [self exchangeObjectAtIndex:rhIndex-- withObjectAtIndex:lhIndex++];
    
    [aLock unlock];

}

- (void)sortUsingDescriptors:(NSArray *)sortDescriptors usingLock:(NSLock *)aLock;
{
    [aLock lock];
    [self sortUsingDescriptors:sortDescriptors];
    [aLock unlock];
}

@end

#import <OmniBase/assertions.h>

@implementation BDSKArray

/* ARM:  Since Foundation implements objectsAtIndexes: on 10.4+, we just ignore this implementation, which is crude anyway.  We could also implement this using a different method name in a category, e.g. "objectsAtArrayIndexes:", but that's annoying to maintain, and we'd have to check a variable each time to get the 10.4 implementation.  What I really want is a way to conditionally add a category, but can't figure out how to do that.
*/

+ (void)performPosing;
{
    if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3)
        class_poseAs(self, NSClassFromString(@"NSArray"));
}
        
- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexes;
{
    OBASSERT(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3);

    // could be more clever/efficient by using getObjects:range:
    unsigned index;
    index = [indexes firstIndex];
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[indexes count]];
    
    while(index != NSNotFound){
        [array addObject:(id)CFArrayGetValueAtIndex((CFArrayRef)self, index)];
        index = [indexes indexGreaterThanIndex:index];
    }
    
    NSArray *copy = [[array copy] autorelease];
    [array release];
    
    return copy;

}

@end
