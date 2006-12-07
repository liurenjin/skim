//
//  BDSKFontManager.m
//  BibDesk
//
//  Created by Adam Maxwell on 02/25/05.
/*
 This software is Copyright (c) 2001,2002,2003,2004,2005
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

#import "BDSKFontManager.h"

static BDSKFontManager *privateFontManager = nil;

@implementation BDSKFontManager

+ (BDSKFontManager *)sharedFontManager{
    if(!privateFontManager){
        privateFontManager = [[self alloc] init];
    }
    return privateFontManager;
}

- (id)init{
    if(self){ // don't send [super init]
        cachedFontsForPreviewPane = nil;
        [self setupFonts];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(setupFonts) 
                                                     name:BDSKPreviewPaneFontChangedNotification
                                                   object:nil];
    }
   return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [cachedFontsForPreviewPane release];
    [super dealloc];
}

NSFont *titleFontForFamily(NSString *tryFamily)
{
    NSFont *font = [NSFont fontWithName:[tryFamily stringByAppendingString:@" Bold Italic"] size:14.0];
    if(!font){
        font = [NSFont fontWithName:[tryFamily stringByAppendingString:@" Bold Oblique"] size:14.0];
        if(!font){
            font = [NSFont fontWithName:[tryFamily stringByAppendingString:@" Bold"] size:14.0];
            if(!font){
                font = [NSFont fontWithName:[tryFamily stringByAppendingString:@" Black Italic"] size:14.0];
                if(!font){
                    font = [NSFont boldSystemFontOfSize:14.0];
                }
            }
        }
    }
    return font;
}

NSFont *typeFontForFamily(NSString *tryFamily)
{
    NSFont *font = [NSFont fontWithName:tryFamily size:10.0];
    if(!font){
        font = [NSFont systemFontOfSize:10.0];
    }
    return font;
}    

NSFont *keyFontForFamily(NSString *tryFamily)
{
    NSFont *font = [NSFont fontWithName:[tryFamily stringByAppendingString:@" Bold"] size:12.0];
    if(!font){
        [NSFont fontWithName:[tryFamily stringByAppendingString:@" Black"] size:12.0];
        if(!font){
            font = [NSFont boldSystemFontOfSize:12.0];
        }
    }
    return font;
}

NSFont *bodyFontForFamily(NSString *tryFamily)
{
    NSFont *font = [NSFont fontWithName:tryFamily size:12.0];
    if(!font){
        font = [NSFont systemFontOfSize:12.0];
    }
    return font;
}

- (void)setupFonts{
    NSString *fontFamily = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKPreviewPaneFontFamilyKey];
    [cachedFontsForPreviewPane release];
    cachedFontsForPreviewPane = [[NSDictionary dictionaryWithObjectsAndKeys:
        titleFontForFamily(fontFamily), @"Title",
        typeFontForFamily(fontFamily), @"Type",
        keyFontForFamily(fontFamily), @"Key",
        bodyFontForFamily(fontFamily), @"Body",
        nil] retain];
}

- (NSDictionary *)cachedFontsForPreviewPane{
    return cachedFontsForPreviewPane;
}

- (NSFontTraitMask)fontTraitMaskForTeXStyle:(NSString *)style{
    if([style isEqualToString:@"\\textit"])
        return NSItalicFontMask;
    else if([style isEqualToString:@"\\textbf"])
        return NSBoldFontMask;
    else if([style isEqualToString:@"\\textsc"])
        return NSSmallCapsFontMask;
    else if([style isEqualToString:@"\\emph"])
        return NSItalicFontMask;
    else if([style isEqualToString:@"\\textup"])
        return NSUnitalicFontMask;
    else return 0;
}
@end
