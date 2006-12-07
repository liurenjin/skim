// Copyright 1997-2004 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <Foundation/Foundation.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniBase/rcsid.h>

RCS_ID("$Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniFoundation/Tests/SHA1/SHA1_main.m,v 1.11 2004/02/10 04:07:48 kc Exp $")

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *inputFilename;
    NSData *inputData;
    OFSignature *signature;

    if (argc != 2) {
        fprintf(stderr, "usage: %s inputFilename\n", argv[0]);
        return 1;
    }

    inputFilename = [[NSString alloc] initWithCString: argv[1]];
    inputData = [[NSData alloc] initWithContentsOfFile: inputFilename];
    if (!inputData) {
        fprintf(stderr, "Couldn't read %s\n", argv[1]);
        return 1;
    }

    signature = [[OFSignature alloc] init];
    [signature addData: inputData];

    NSLog(@"signature = %@", [signature signatureData]);

    [pool release];
    return 0;
}
