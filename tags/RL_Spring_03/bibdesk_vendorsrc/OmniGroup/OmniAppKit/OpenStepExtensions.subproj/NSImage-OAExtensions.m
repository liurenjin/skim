// Copyright 1997-2003 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// http://www.omnigroup.com/DeveloperResources/OmniSourceLicense.html.

#import <OmniAppKit/NSImage-OAExtensions.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

RCS_ID("$Header: /Network/Source/CVS/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSImage-OAExtensions.m,v 1.23 2003/02/26 00:48:27 rick Exp $")

@implementation NSImage (OAImageExtensions)
+ (NSImage *)imageInClassBundleNamed:(NSString *)imageName;
{
    return [NSImage imageNamed:imageName inBundleForClass:self];
}
@end

@implementation NSImage (OAExtensions)

+ (NSImage *)imageNamed:(NSString *)imageName inBundleForClass:(Class)aClass;
{
    return [self imageNamed:imageName inBundle:[NSBundle bundleForClass:aClass]];
}

+ (NSImage *)imageNamed:(NSString *)imageName inBundle:(NSBundle *)aBundle;
{
    NSImage *image;
    NSString *path;

    image = [self imageNamed:imageName];
    if (image && [image size].width != 0)
        return image;

    path = [aBundle pathForImageResource:imageName];
    if (!path)
        return nil;

    image = [[NSImage alloc] initWithContentsOfFile:path];
    [image setName:imageName];

    return image;
}

+ (NSImage *)imageForFileType:(NSString *)fileType;
    // It turns out that -[NSWorkspace iconForFileType:] doesn't cache previously returned values, so we cache them here.
{
    static NSMutableDictionary *imageDictionary = nil;
    id image;

    ASSERT_IN_MAIN_THREAD(@"+imageForFileType: is not thread-safe; must be called from the main thread");
    // We could fix this by adding locks around imageDictionary

    if (!fileType)
        return nil;
        
    if (imageDictionary == nil)
        imageDictionary = [[NSMutableDictionary alloc] init];

    image = [imageDictionary objectForKey:fileType];
    if (image == nil) {
#ifdef DEBUG
        // Make sure that our caching doesn't go insane (and that we don't ask it to cache insane stuff)
        NSLog(@"Caching workspace image for file type '%@'", fileType);
#endif
        image = [[NSWorkspace sharedWorkspace] iconForFileType:fileType];
        if (image == nil)
            image = [NSNull null];
        [imageDictionary setObject:image forKey:fileType];
    }
    return image != [NSNull null] ? image : nil;
}

#define X_SPACE_BETWEEN_ICON_AND_TEXT_BOX 2
#define X_TEXT_BOX_BORDER 2
#define Y_TEXT_BOX_BORDER 2
static NSDictionary *titleFontAttributes;

+ (NSImage *)draggingIconWithTitle:(NSString *)title andImage:(NSImage *)image;
{
    NSImage *drawImage;
    NSSize imageSize, totalSize;
    NSSize titleSize, titleBoxSize;
    NSRect titleBox;
    NSPoint textPoint;

    OBASSERT(image != nil);
    imageSize = [image size];

    if (!titleFontAttributes)
        titleFontAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont systemFontOfSize:12.0], NSFontAttributeName, [NSColor textColor], NSForegroundColorAttributeName, nil];

    if (!title || [title length] == 0)
        return image;
    
    titleSize = [title sizeWithAttributes:titleFontAttributes];
    titleBoxSize = NSMakeSize(titleSize.width + 2.0 * X_TEXT_BOX_BORDER, titleSize.height + Y_TEXT_BOX_BORDER);

    totalSize = NSMakeSize(imageSize.width + X_SPACE_BETWEEN_ICON_AND_TEXT_BOX + titleBoxSize.width, MAX(imageSize.height, titleBoxSize.height));

    drawImage = [[NSImage alloc] initWithSize:totalSize];
    [drawImage setFlipped:YES];

    [drawImage lockFocus];

    // Draw transparent background
    [[NSColor colorWithDeviceWhite:1.0 alpha:0.0] set];
    NSRectFill(NSMakeRect(0, 0, totalSize.width, totalSize.height));

    // Draw icon
    [image compositeToPoint:NSMakePoint(0.0, rint(totalSize.height / 2.0 + imageSize.height / 2.0)) operation:NSCompositeSourceOver];
    
    // Draw box around title
    titleBox = NSMakeRect(imageSize.width + X_SPACE_BETWEEN_ICON_AND_TEXT_BOX, floor((totalSize.height - titleBoxSize.height)/2.0), titleBoxSize.width, titleBoxSize.height);
    [[[NSColor selectedTextBackgroundColor] colorWithAlphaComponent:0.5] set];
    NSRectFill(titleBox);

    // Draw title
    textPoint = NSMakePoint(imageSize.width + X_SPACE_BETWEEN_ICON_AND_TEXT_BOX + X_TEXT_BOX_BORDER, Y_TEXT_BOX_BORDER - 1);

    [title drawAtPoint:textPoint withAttributes:titleFontAttributes];

    [drawImage unlockFocus];

    return [drawImage autorelease];
}

//

- (void)drawFlippedInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(float)delta;
{
    CGContextRef context;

    context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(context); {
        CGContextTranslateCTM(context, 0, NSMaxY(rect));
        CGContextScaleCTM(context, 1, -1);
        
        rect.origin.y = 0; // We've translated ourselves so it's zero
        [self drawInRect:rect fromRect:NSZeroRect operation:op fraction:delta];
    } CGContextRestoreGState(context);

    /*
        NSAffineTransform *flipTransform;
        NSPoint transformedPoint;
        NSSize transformedSize;
        NSRect transformedRect;

        flipTransform = [[NSAffineTransform alloc] init];
        [flipTransform scaleXBy:1.0 yBy:-1.0];

        transformedPoint = [flipTransform transformPoint:rect.origin];
        transformedSize = [flipTransform transformSize:rect.size];
        [flipTransform concat];
        transformedRect = NSMakeRect(transformedPoint.x, transformedPoint.y + transformedSize.height, transformedSize.width, -transformedSize.height);
        [anImage drawInRect:transformedRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [flipTransform concat];
        [flipTransform release];
        */
}

- (void)drawFlippedInRect:(NSRect)rect operation:(NSCompositingOperation)op;
{
    [self drawFlippedInRect:rect operation:op fraction:1.0];
}

- (int)addDataToPasteboard:(NSPasteboard *)aPasteboard exceptTypes:(NSMutableSet *)notThese
{
    NSArray *myRepresentations;
    int repIndex, repCount;
    int count = 0;

    if (!notThese)
        notThese = [NSMutableSet set];

#define IF_ADD(typename, dataOwner) if( ![notThese containsObject:(typename)] && [aPasteboard addTypes:[NSArray arrayWithObject:(typename)] owner:(dataOwner)] > 0 )

#define ADD_CHEAP_DATA(typename, expr) IF_ADD(typename, nil) { [aPasteboard setData:(expr) forType:(typename)]; [notThese addObject:(typename)]; count ++; }
        
    /* If we have image representations lying around that already have data in some concrete format, add that data to the pasteboard. */
    myRepresentations = [self representations];
    repCount = [myRepresentations count];
    for(repIndex = 0; repIndex < repCount; repIndex ++) {
        NSImageRep *aRep = [myRepresentations objectAtIndex:repIndex];
            
        if ([aRep respondsToSelector:@selector(PDFRepresentation)]) {
            ADD_CHEAP_DATA(NSPDFPboardType, [(NSPDFImageRep *)aRep PDFRepresentation]);
        }

        if ([aRep respondsToSelector:@selector(PICTRepresentation)]) {
            ADD_CHEAP_DATA(NSPICTPboardType, [(NSPICTImageRep *)aRep PICTRepresentation]);
        }

        if ([aRep respondsToSelector:@selector(EPSRepresentation)]) {
            ADD_CHEAP_DATA(NSPostScriptPboardType, [(NSEPSImageRep *)aRep EPSRepresentation]);
        }
    }
    
    /* Always offer to convert to TIFF. Do this lazily, though, since we probably have to extract it from a bitmap image rep. */
    IF_ADD(NSTIFFPboardType, self) {
        count ++;
    }

    return count;
}

- (void)pasteboard:(NSPasteboard *)aPasteboard provideDataForType:(NSString *)wanted
{
    if ([wanted isEqual:NSTIFFPboardType]) {
        [aPasteboard setData:[self TIFFRepresentation] forType:NSTIFFPboardType];
    }
}

//

- (NSImageRep *)imageRepOfClass:(Class)imageRepClass;
{
    NSArray *representations = [self representations];
    unsigned int representationIndex, representationCount = [representations count];
    for (representationIndex = 0; representationIndex < representationCount; representationIndex++) {
        if ([[representations objectAtIndex:representationIndex] isKindOfClass:imageRepClass]) {
            return [representations objectAtIndex:representationIndex];
        }
    }
    return nil;
}

- (NSImageRep *)imageRepOfSize:(NSSize)aSize;
{
    NSArray *representations = [self representations];
    unsigned int representationIndex, representationCount = [representations count];
    for (representationIndex = 0; representationIndex < representationCount; representationIndex++) {
        if (NSEqualSizes([(NSImageRep *)[representations objectAtIndex:representationIndex] size], aSize)) {
            return [representations objectAtIndex:representationIndex];
        }
    }
    return nil;
    
}


#ifdef MAC_OS_X_VERSION_10_2
#include <stdlib.h>
#include <memory.h>

- (NSData *)bmpData;
{
    return [self bmpDataWithBackgroundColor:nil];
}

- (NSData *)bmpDataWithBackgroundColor:(NSColor *)backgroundColor;
{
    /* 	This is a Unix port of the bitmap.c code that writes .bmp files to disk.
    It also runs on Win32, and should be easy to get to run on other platforms.
    Please visit my web page, http://www.ece.gatech.edu/~slabaugh and click on "c" and "Writing Windows Bitmaps" for a further explanation.  This code has been tested and works on HP-UX 11.00 using the cc compiler.  To compile, just type "cc -Ae bitmapUnix.c" at the command prompt.

    The Windows .bmp format is little endian, so if you're running this code on a big endian system it will be necessary to swap bytes to write out a little endian file.

    Thanks to Robin Pitrat for testing on the Linux platform.

    Greg Slabaugh, 11/05/01
    */


    // This pragma is necessary so that the data in the structures is aligned to 2-byte boundaries.  Some different compilers have a different syntax for this line.  For example, if you're using cc on Solaris, the line should be #pragma pack(2).
#pragma pack(2)

    // Default data types.  Here, uint16 is an unsigned integer that has size 2 bytes (16 bits), and uint32 is datatype that has size 4 bytes (32 bits).  You may need to change these depending on your compiler.
#define uint16 unsigned short
#define uint32 unsigned int

#define BI_RGB 0
#define BM 19778

    typedef struct {
        uint16 bfType;
        uint32 bfSize;
        uint16 bfReserved1;
        uint16 bfReserved2;
        uint32 bfOffBits;
    } BITMAPFILEHEADER;

    typedef struct {
        uint32 biSize;
        uint32 biWidth;
        uint32 biHeight;
        uint16 biPlanes;
        uint16 biBitCount;
        uint32 biCompression;
        uint32 biSizeImage;
        uint32 biXPelsPerMeter;
        uint32 biYPelsPerMeter;
        uint32 biClrUsed;
        uint32 biClrImportant;
    } BITMAPINFOHEADER;


    typedef struct {
        unsigned char rgbBlue;
        unsigned char rgbGreen;
        unsigned char rgbRed;
        unsigned char rgbReserved;
    } RGBQUAD;


    NSBitmapImageRep *bitmapImageRep = (id)[self imageRepOfClass:[NSBitmapImageRep class]];
    if (bitmapImageRep == nil || backgroundColor != nil) {
        NSRect imageBounds = {NSZeroPoint, [self size]};
        NSImage *newImage = [[NSImage alloc] initWithSize:imageBounds.size];
        [newImage lockFocus]; {
            [backgroundColor ? backgroundColor : [NSColor clearColor] set];
            NSRectFill(imageBounds);
            [self drawInRect:imageBounds fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
            bitmapImageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:imageBounds] autorelease];
        } [newImage unlockFocus];
        [newImage release];
    }

    uint32 width = [bitmapImageRep pixelsWide];
    uint32 height= [bitmapImageRep pixelsHigh];
    unsigned char *image = [bitmapImageRep bitmapData];
    unsigned int samplesPerPixel = [bitmapImageRep samplesPerPixel];

    /*
     This function writes out a 24-bit Windows bitmap file that is readable by Microsoft Paint.
     The image data is a 1D array of (r, g, b) triples, where individual (r, g, b) values can
     each take on values between 0 and 255, inclusive.

     The input to the function is:
     uint32 width:					The width, in pixels, of the bitmap
     uint32 height:					The height, in pixels, of the bitmap
     unsigned char *image:				The image data, where each pixel is 3 unsigned chars (r, g, b)

     Written by Greg Slabaugh (slabaugh@ece.gatech.edu), 10/19/00
     */
    uint32 extrabytes = (4 - (width * 3) % 4) % 4;

    /* This is the size of the padded bitmap */
    uint32 bytesize = (width * 3 + extrabytes) * height;

    NSMutableData *mutableBMPData = [NSMutableData data];

    /* Fill the bitmap file header structure */
    BITMAPFILEHEADER bmpFileHeader;
    bmpFileHeader.bfType = NSSwapHostShortToLittle(BM);   /* Bitmap header */
    bmpFileHeader.bfSize = NSSwapHostIntToLittle(0);      /* This can be 0 for BI_RGB bitmaps */
    bmpFileHeader.bfReserved1 = NSSwapHostShortToLittle(0);
    bmpFileHeader.bfReserved2 = NSSwapHostShortToLittle(0);
    bmpFileHeader.bfOffBits = NSSwapHostIntToLittle(sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER));
    [mutableBMPData appendBytes:&bmpFileHeader length:sizeof(BITMAPFILEHEADER)];

    /* Fill the bitmap info structure */
    BITMAPINFOHEADER bmpInfoHeader;
    bmpInfoHeader.biSize = NSSwapHostIntToLittle(sizeof(BITMAPINFOHEADER));
    bmpInfoHeader.biWidth = NSSwapHostIntToLittle(width);
    bmpInfoHeader.biHeight = NSSwapHostIntToLittle(height);
    bmpInfoHeader.biPlanes = NSSwapHostShortToLittle(1);
    bmpInfoHeader.biBitCount = NSSwapHostShortToLittle(24);            /* 24 - bit bitmap */
    bmpInfoHeader.biCompression = NSSwapHostIntToLittle(BI_RGB);
    bmpInfoHeader.biSizeImage = NSSwapHostIntToLittle(bytesize);     /* includes padding for 4 byte alignment */
    bmpInfoHeader.biXPelsPerMeter = NSSwapHostIntToLittle(0);
    bmpInfoHeader.biYPelsPerMeter = NSSwapHostIntToLittle(0);
    bmpInfoHeader.biClrUsed = NSSwapHostIntToLittle(0);
    bmpInfoHeader.biClrImportant = NSSwapHostIntToLittle(0);
    [mutableBMPData appendBytes:&bmpInfoHeader length:sizeof(BITMAPINFOHEADER)];

    /* Allocate memory for some temporary storage */
    unsigned char *paddedImage = (unsigned char *)calloc(sizeof(unsigned char), bytesize);

    // This code does three things.  First, it flips the image data upside down, as the .bmp format requires an upside down image.  Second, it pads the image data with extrabytes number of bytes so that the width in bytes of the image data that is written to the file is a multiple of 4.  Finally, it swaps (r, g, b) for (b, g, r).  This is another quirk of the .bmp file format.

    uint32 row, column;
    for (row = 0; row < height; row++) {
        unsigned char *imagePtr = image + (height - 1 - row) * width * samplesPerPixel;
        unsigned char *paddedImagePtr = paddedImage + row * (width * 3 + extrabytes);
        for (column = 0; column < width; column++) {
            *paddedImagePtr = *(imagePtr + 2);
            *(paddedImagePtr + 1) = *(imagePtr + 1);
            *(paddedImagePtr + 2) = *imagePtr;
            imagePtr += samplesPerPixel;
            paddedImagePtr += 3;
        }
    }

    /* Write bmp data */
    [mutableBMPData appendBytes:paddedImage length:bytesize];

    free(paddedImage);

    return mutableBMPData;
}
#endif

+ (NSImage *)documentIconWithContent:(NSImage *)contentImage;
{
    NSImage *templateImage, *contentMask;

    templateImage = [NSImage imageNamed:@"DocumentIconTemplate"];
    contentMask = [NSImage imageNamed:@"DocumentIconMask"];
    return [self documentIconWithTemplate:templateImage content:contentImage contentMask:contentMask];
}

#define ICON_SIZE_LARGE NSMakeSize(128.0, 128.0)
#define ICON_SIZE_SMALL NSMakeSize(32.0, 32.0)
#define ICON_SIZE_TINY NSMakeSize(16.0, 16.0)

+ (NSImage *)documentIconWithTemplate:(NSImage *)templateImage content:(NSImage *)contentImage contentMask:(NSImage *)contentMask;
{
    NSImage *newImage;
    NSImage *largeImage, *smallImage, *tinyImage;
    NSRect bounds;

    largeImage = [[[NSImage alloc] initWithSize:ICON_SIZE_LARGE] autorelease];
    bounds = (NSRect){NSZeroPoint, ICON_SIZE_LARGE};
    [largeImage lockFocus];
    {
        [[contentImage imageRepOfSize:ICON_SIZE_LARGE] drawInRect:bounds];
        [contentMask drawInRect:bounds fromRect:NSZeroRect operation:NSCompositeDestinationIn fraction:1.0];
        [templateImage drawInRect:bounds fromRect:NSZeroRect operation:NSCompositeDestinationAtop fraction:1.0];
    }
    [largeImage unlockFocus];

    smallImage = [[[NSImage alloc] initWithSize:ICON_SIZE_SMALL] autorelease];
    bounds = (NSRect){NSZeroPoint, ICON_SIZE_SMALL};
    [smallImage lockFocus];
    {
        [[contentImage imageRepOfSize:ICON_SIZE_SMALL] drawInRect:bounds];
        [contentMask drawInRect:bounds fromRect:NSZeroRect operation:NSCompositeDestinationIn fraction:1.0];
        [templateImage drawInRect:bounds fromRect:NSZeroRect operation:NSCompositeDestinationAtop fraction:1.0];
    }
    [smallImage unlockFocus];

    tinyImage = [[[NSImage alloc] initWithSize:ICON_SIZE_TINY] autorelease];
    bounds = (NSRect){NSZeroPoint, ICON_SIZE_TINY};
    [tinyImage lockFocus];
    {
        [[contentImage imageRepOfSize:ICON_SIZE_TINY] drawInRect:bounds];
        [contentMask drawInRect:bounds fromRect:NSZeroRect operation:NSCompositeDestinationIn fraction:1.0];
        [templateImage drawInRect:bounds fromRect:NSZeroRect operation:NSCompositeDestinationAtop fraction:1.0];
    }
    [tinyImage unlockFocus];

    newImage = [[NSImage alloc] initWithSize:ICON_SIZE_SMALL]; // prefer 32x32, to be consistent with icons returned by NSWorkspace methods
    [newImage addRepresentation:[[largeImage representations] objectAtIndex:0]];
    [newImage addRepresentation:[[smallImage representations] objectAtIndex:0]];
    [newImage addRepresentation:[[tinyImage representations] objectAtIndex:0]];

    return [newImage autorelease];
}

@end