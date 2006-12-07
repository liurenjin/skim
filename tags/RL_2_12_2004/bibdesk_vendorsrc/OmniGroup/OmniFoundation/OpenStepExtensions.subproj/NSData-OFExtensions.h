// Copyright 1997-2004 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSData-OFExtensions.h,v 1.26 2004/02/10 04:07:45 kc Exp $

#import <Foundation/NSData.h>

typedef struct OFQuotedPrintableMapping {
    char map[256];   // 256 entries, one for each octet value
    unsigned short translations[8];  // 8 is an arbitrary size; must be at least 2
} OFQuotedPrintableMapping;

@interface NSData (OFExtensions)

+ (NSData *)randomDataOfLength:(unsigned int)length;
// Returns a new autoreleased instance that contains the number of requested random bytes.

+ (id)dataWithHexString:(NSString *)hexString;
- initWithHexString:(NSString *)hexString;
- (NSString *)lowercaseHexString; /* has a leading 0x (sigh) */
- (NSString *)unadornedLowercaseHexString;  /* no 0x */

- initWithASCII85String:(NSString *)ascii85String;
- (NSString *)ascii85String;

+ (id)dataWithBase64String:(NSString *)base64String;
- initWithBase64String:(NSString *)base64String;
- (NSString *)base64String;

// This is our own coding method, not a standard.  This is good
// for NSData strings that users have to type in.
- initWithASCII26String:(NSString *)ascii26String;
- (NSString *)ascii26String;

+ dataWithDecodedURLString:(NSString *)urlString;

// This is a generic implementation of quoted-printable-style encodings, used by methods elsewhere in OmniFoundation
- (NSString *)quotedPrintableStringWithMapping:(const OFQuotedPrintableMapping *)qpMap lengthHint:(unsigned)zeroIfNoHint;
- (unsigned)lengthOfQuotedPrintableStringWithMapping:(const OFQuotedPrintableMapping *)qpMap;

- (unsigned long)indexOfFirstNonZeroByte;
    // Returns the index of the first non-zero byte in the receiver, or NSNotFound if if all the bytes in the data are zero.

- (NSData *)sha1Signature;
    // Uses the SHA-1 algorithm to compute a signature for the receiver.  Obviously, due to the dynamic nature of ObjC, and due to the fact that users will get access to the binary, this cannot be depended upon as an absolutely secure licensing mechanism, but this will prevent users from accidentally breaking the licensing agreement, which is really all we can hope for.

- (NSData *)md5Signature;
    // Computes an MD5 digest of the receiver and returns it. (Derived from the RSA Data Security, Inc. MD5 Message-Digest Algorithm.)

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile createDirectories:(BOOL)shouldCreateDirectories;
    // Will raise an exception if it can't create the required directories.

- (NSData *)dataByAppendingData:(NSData *)anotherData;
    // Returns the catenation of this NSData and the argument
    
- (BOOL)hasPrefix:(NSData *)data;
- (BOOL)containsData:(NSData *)data;

- propertyList;
    // a cover for the CoreFoundation function call

@end
