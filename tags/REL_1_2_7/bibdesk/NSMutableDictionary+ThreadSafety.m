//
//  NSMutableDictionary+ThreadSafety.m
//  BibDesk
//
//  Created by Adam Maxwell on 01/27/05.
/*
 This software is Copyright (c) 2005, 2006
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

#import "NSMutableDictionary+ThreadSafety.h"
#import "BDSKCountedSet.h"

@implementation NSMutableDictionary (ThreadSafety)

- (id)objectForKey:(id)aKey usingLock:(NSLock *)aLock{

    id result;
    
    [aLock lock];
    result = [self objectForKey:aKey];
    [[result retain] autorelease];
    [aLock unlock];
    
    return result;
}

- (void)removeObjectForKey:(id)aKey usingLock:(NSLock *)aLock{
    
    [aLock lock];
    [self removeObjectForKey:aKey];
    [aLock unlock];
}

- (void)setObject:(id)anObject forKey:(id)aKey usingLock:(NSLock *)aLock{
    
    [aLock lock];
    [anObject retain];
    [self setObject:anObject forKey:aKey];
    [anObject release];
    [aLock unlock];
}

- (NSArray *)allKeysUsingLock:(NSLock *)aLock{
    
    NSArray *result;
    
    [aLock lock];
    result = [self allKeys];
    [[result retain] autorelease];
    [aLock unlock];
    
    return result;
}

- (NSArray *)allValuesUsingLock:(NSLock *)aLock{
    
    NSArray *result;
    
    [aLock lock];
    result = [self allValues];
    [[result retain] autorelease];
    [aLock unlock];
    
    return result;
}

- (void)removeObjectsForKeys:(NSArray *)keyArray usingLock:(NSLock *)aLock{
    
    [aLock lock];
    [self removeObjectsForKeys:keyArray];
    [aLock unlock];
}

- (unsigned)countUsingLock:(NSLock *)aLock;
{
    unsigned int count;
    [aLock lock];
    count = [self count];
    [aLock unlock];
    return count;
}

- (void)removeAllObjectsUsingLock:(NSLock *)aLock;
{
    [aLock lock];
    [self removeAllObjects];
    [aLock unlock];
}

NSMutableDictionary *BDSKCreateCaseInsensitiveKeyMutableDictionary(void)
{
    return (NSMutableDictionary *)CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &BDSKCaseInsensitiveStringKeyDictionaryCallBacks, &OFNSObjectDictionaryValueCallbacks);
}

@end
