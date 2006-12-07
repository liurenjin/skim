//
//  NSImage+Toolbox.m
//  BibDesk
//
//  Created by Sven-S. Porst on Thu Jul 29 2004.
/*
 This software is Copyright (c) 2004,2005
 Sven-S. Porst. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Sven-S. Porst nor the names of any
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

#import "NSImage+Toolbox.h"
/* ssp: 30-07-2004 

	A category on NSImage that creates an NSImage containing an icon from the system specified by an OSType.
	LIMITATION: This always creates 32x32 images as are useful for toolbars.
 
	Code taken from http://cocoa.mamasam.com/MACOSXDEV/2002/01/2/22427.php
*/

static NSImage *cautionIconImage = nil;

@implementation NSImage (Toolbox)

+ (NSImage *)imageWithLargeIconForToolboxCode:(OSType) code {
	int width = 32;
	int height = 32;
	IconRef iconref;
	OSErr myErr = GetIconRef (kOnSystemDisk, kSystemIconsCreator, code, &iconref);
	
	NSImage* image = [[NSImage alloc] initWithSize:NSMakeSize(width,height)]; 
	[image lockFocus]; 
	
	CGRect rect =  CGRectMake(0,0,width,height);
	
	PlotIconRefInContext((CGContextRef)[[NSGraphicsContext currentContext] graphicsPort],
						&rect,
						 kAlignAbsoluteCenter, //kAlignNone,
						 kTransformNone,
						 NULL /*inLabelColor*/,
						 kPlotIconRefNormalFlags,
						 iconref); 
	[image unlockFocus]; 
	
	myErr = ReleaseIconRef(iconref);
	
	[image autorelease];	
	return image;
}

+ (NSImage *)cautionIconImage {
	if (!cautionIconImage) {
		cautionIconImage = [[self imageWithLargeIconForToolboxCode:kAlertCautionBadgeIcon] retain];
	}
	return cautionIconImage;
}

@end
