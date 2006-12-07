// Copyright 2000-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <SenTestingKit/SenTestingKit.h>
// put other imports here

RCS_ID("$Header$")

@interface OFNumberFormatterTest : SenTestCase
{
}

@end

@implementation OFNumberFormatterTest

- (void)testNegativeDecimalString;
{
    NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
    [numberFormatter setFormat:@"###;$0.00;(0.00000)"];

    NSDecimalNumber *originalValue = [NSDecimalNumber decimalNumberWithString:@"-1.01234"];
    NSString *str = [numberFormatter stringForObjectValue:originalValue];
    shouldBeEqual(str, @"(1.01234)");

    id objectValue;
    NSString *error;
    BOOL result = [numberFormatter getObjectValue:&objectValue forString:str errorDescription:&error];
    should(error == nil);
    should(result);
    shouldBeEqual(objectValue, originalValue);
}

@end
