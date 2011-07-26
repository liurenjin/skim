//
//  SKTransitionController.m
//  Skim
//
//  Created by Christiaan Hofman on 7/15/07.
/*
 This software is Copyright (c) 2007
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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
 
/*
 This code is based partly on Apple's AnimatingTabView example code
 and Ankur Kothari's AnimatingTabsDemo application <http://dev.lipidity.com>
*/

#import "SKTransitionController.h"
#import <Quartz/Quartz.h>
#import "NSBitmapImageRep_SKExtensions.h"
#include <unistd.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import "SKFullScreenWindow.h"

BOOL CoreGraphicsServicesTransitionsDefined() {
    return &_CGSDefaultConnection != kUnresolvedCFragSymbolAddress &&
           &CGSNewTransition != kUnresolvedCFragSymbolAddress &&
           &CGSInvokeTransition != kUnresolvedCFragSymbolAddress &&
           &CGSReleaseTransition != kUnresolvedCFragSymbolAddress;
}

@interface SKTransitionAnimation : NSAnimation {
    CIFilter *filter;
}

- (id)initWithFilter:(CIFilter *)aFilter duration:(NSTimeInterval)duration animationCurve:(NSAnimationCurve)animationCurve;
- (CIImage *)currentImage;

@end

#pragma mark -

@implementation SKTransitionController

+ (NSArray *)transitionFilterNames {
    static NSMutableArray *transitionFilterNames = nil;
    
    if(transitionFilterNames == nil) {
        // get all the transition filters
		[CIPlugIn loadAllPlugIns];
        transitionFilterNames = [[CIFilter filterNamesInCategories:[NSArray arrayWithObject:kCICategoryTransition]] copy];
    }
    
    return transitionFilterNames;
}

- (id)initWithView:(NSView *)aView {
    if (self = [super init]) {
        view = aView; // don't retain as it may retain us
        transitionStyle = SKNoTransition;
        duration = 1.0;
        shouldRestrict = YES;
    }
    return self;
}

- (void)dealloc {
    [initialImage release];
    [filters release];
    [super dealloc];
}

- (NSString *)windowNibName { return @"TransitionSheet"; }

- (void)windowDidLoad {
    NSArray *filterNames = [[self class] transitionFilterNames];
    int i, count = [filterNames count];
    for (i = 0; i < count; i++) {
        NSString *name = [filterNames objectAtIndex:i];
        [transitionStylePopUpButton addItemWithTitle:[CIFilter localizedNameForFilterName:name]];
        NSMenuItem *item = [transitionStylePopUpButton lastItem];
        [item setTag:SKCoreImageTransition + i];
    }
}

- (NSView *)view {
    return view;
}

- (void)setView:(NSView *)newView {
    if (view != newView) {
        view = newView;
    }
}

- (SKAnimationTransitionStyle)transitionStyle {
    return transitionStyle;
}

- (void)setTransitionStyle:(SKAnimationTransitionStyle)style {
    transitionStyle = style;
}

- (float)duration {
    return duration;
}

- (void)setDuration:(float)newDuration {
    duration = newDuration;
}

- (BOOL)shouldRestrict {
    return shouldRestrict;
}

- (void)setShouldRestrict:(BOOL)flag {
    shouldRestrict = flag;
}

- (CIFilter *)filterWithName:(NSString *)name {
    if (filters == nil)
        filters = [[NSMutableDictionary alloc] init];
    CIFilter *filter = [filters objectForKey:name];
    if (filter == nil && (filter = [CIFilter filterWithName:name]))
        [filters setObject:filter forKey:name];
    [filter setDefaults];
    return filter;
}

- (CIImage *)inputShadingImage {
    static CIImage *inputShadingImage = nil;
    if (inputShadingImage == nil) {
        NSData *shadingBitmapData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"TransitionShading" ofType:@"tiff"]];
        NSBitmapImageRep *shadingBitmap = [[[NSBitmapImageRep alloc] initWithData:shadingBitmapData] autorelease];
        inputShadingImage = [[CIImage alloc] initWithBitmapImageRep:shadingBitmap];
    }
    return inputShadingImage;
}

- (CIImage *)inputMaskImage {
    static CIImage *inputMaskImage = nil;
    if (inputMaskImage == nil) {
        NSData *maskBitmapData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"TransitionMask" ofType:@"jpg"]];
        NSBitmapImageRep *maskBitmap = [[[NSBitmapImageRep alloc] initWithData:maskBitmapData] autorelease];
        inputMaskImage = [[CIImage alloc] initWithBitmapImageRep:maskBitmap];
    }
    return inputMaskImage;
}

- (CIImage *)cropImage:(CIImage *)image toRect:(NSRect)rect {
    CIFilter *cropFilter = [self filterWithName:@"CICrop"];
    [cropFilter setValue:[CIVector vectorWithX:NSMinX(rect) Y:NSMinY(rect) Z:NSWidth(rect) W:NSHeight(rect)] forKey:@"inputRectangle"];
    [cropFilter setValue:image forKey:@"inputImage"];
    return [cropFilter valueForKey:@"outputImage"];
}

- (CIImage *)translateImage:(CIImage *)image xBy:(float)dx yBy:(float)dy {
    CIFilter *translationFilter = [self filterWithName:@"CIAffineTransform"];
    NSAffineTransform *affineTransform = [NSAffineTransform transform];
    [affineTransform translateXBy:dx yBy:dy];
    [translationFilter setValue:affineTransform forKey:@"inputTransform"];
    [translationFilter setValue:image forKey:@"inputImage"];
    return [translationFilter valueForKey:@"outputImage"];
}

- (CIFilter *)transitionFilterForRect:(NSRect)rect initialCIImage:(CIImage *)initialCIImage finalCIImage:(CIImage *)finalCIImage {
    NSString *filterName = [[[self class] transitionFilterNames] objectAtIndex:transitionStyle - SKCoreImageTransition];
    CIFilter *transitionFilter = [self filterWithName:filterName];
    
    NSRect bounds = [view bounds];
    
    NSEnumerator *keyEnum = [[transitionFilter inputKeys] objectEnumerator];
    NSString *key;
    
    while (key = [keyEnum nextObject]) {
        if([key isEqualToString:@"inputExtent"]) {
            NSRect extent = shouldRestrict ? rect : bounds;
            [transitionFilter setValue:[CIVector vectorWithX:NSMinX(extent) Y:NSMinY(extent) Z:NSWidth(extent) W:NSHeight(extent)] forKey:key];
        } else if([key isEqualToString:@"inputAngle"] && [filterName isEqualToString:@"CIPageCurlTransition"]) {
            [transitionFilter setValue:[NSNumber numberWithFloat:-M_PI_4] forKey:@"inputAngle"];
        } else if([key isEqualToString:@"inputCenter"]) {
            [transitionFilter setValue:[CIVector vectorWithX:NSMidX(rect) Y:NSMidY(rect)] forKey:key];
        } else {
            NSString *classType = [[[transitionFilter attributes] objectForKey:key] objectForKey:kCIAttributeClass];
            
            if([classType isEqualToString:@"CIImage"]) {
                if([key isEqualToString:@"inputShadingImage"]) {
                    [transitionFilter setValue:[self inputShadingImage] forKey:key];
                } else if ([key isEqualToString:@"inputBacksideImage"]) {
                    [transitionFilter setValue:initialCIImage forKey:key];
                } else  {
                    // Scale and translate our mask image to match the transition area size.
                    CIFilter *maskScalingFilter = [self filterWithName:@"CILanczosScaleTransform"];
                    CGRect maskExtent = [[self inputMaskImage] extent];
                    float xScale = NSWidth(rect) / CGRectGetWidth(maskExtent);
                    float yScale = NSHeight(rect) / CGRectGetHeight(maskExtent);
                    [maskScalingFilter setValue:[NSNumber numberWithFloat:yScale] forKey:@"inputScale"];
                    [maskScalingFilter setValue:[NSNumber numberWithFloat:xScale / yScale] forKey:@"inputAspectRatio"];
                    [maskScalingFilter setValue:[self inputMaskImage] forKey:@"inputImage"];
                    
                    [transitionFilter setValue:[self translateImage:[maskScalingFilter valueForKey:@"outputImage"] xBy:NSMinX(rect) - NSMinX(bounds) yBy:NSMinY(rect) - NSMinY(bounds)] forKey:key];
                }
            }
        }
    }
    
    if (NSEqualRects(rect, bounds) == NO) {
        initialCIImage = [self cropImage:initialCIImage toRect:rect];
        finalCIImage = [self cropImage:finalCIImage toRect:rect];
    }
    
    [transitionFilter setValue:initialCIImage forKey:@"inputImage"];
    [transitionFilter setValue:finalCIImage forKey:@"inputTargetImage"];
    
    return transitionFilter;
}

- (CIImage *)createCurrentImage {
    NSRect bounds = [view bounds];
    NSBitmapImageRep *contentBitmap = [view bitmapImageRepForCachingDisplayInRect:bounds];
    
    [contentBitmap clear];
    [view cacheDisplayInRect:bounds toBitmapImageRep:contentBitmap];
    
    return [[CIImage alloc] initWithBitmapImageRep:contentBitmap];
}

- (NSWindow *)transitionWindow {
    if (transitionWindow == nil)
        [self window];
    return transitionWindow;
}

- (SKTransitionView *)transitionView {
    if (transitionView == nil)
        [self window];
    return transitionView;
}

- (void)prepareAnimationForRect:(NSRect)rect {
	if (transitionStyle == SKNoTransition) {
        // Do nothing
	} else if (transitionStyle < SKCoreImageTransition) {
        if (CoreGraphicsServicesTransitionsDefined()) {
            if (shouldRestrict) {
                [initialImage release];
                initialImage = [self createCurrentImage];
            }
            // We don't want the window to draw the next state before the animation is run
            [[view window] disableFlushWindow];
        }
    } else {
        [initialImage release];
        initialImage = [self createCurrentImage];
        
        // We don't want the window to draw the next state before the animation is run
        [[view window] disableFlushWindow];
    }
    imageRect = rect;
}

- (void)animateForRect:(NSRect)rect forward:(BOOL)forward {
	if (transitionStyle == SKNoTransition) {
        // Do nothing
	} else if (transitionStyle < SKCoreImageTransition) {
        if (CoreGraphicsServicesTransitionsDefined()) {
            
            CIImage *finalImage = nil;
            
            if (shouldRestrict) {
                if (initialImage == nil)
                    [self prepareAnimationForRect:rect];
                
                NSRect bounds = [view bounds];
                imageRect = NSIntegralRect(NSIntersectionRect(NSUnionRect(imageRect, rect), bounds));
                
                finalImage = [self createCurrentImage];
                
                float dx = NSMinX(bounds) - NSMinX(imageRect);
                float dy = NSMinY(bounds) - NSMinY(imageRect);
                initialImage = [self translateImage:[self cropImage:[initialImage autorelease] toRect:rect] xBy:dx yBy:dy];
                finalImage = [self translateImage:[self cropImage:[finalImage autorelease] toRect:rect] xBy:dx yBy:dy];
                
                NSRect frame = [view convertRect:imageRect toView:nil];
                frame.origin = [[view window] convertBaseToScreen:frame.origin];
                
                [[self transitionView] setImage:initialImage];
                initialImage = nil;
                
                [[self transitionWindow] setFrame:frame display:YES];
                [[self transitionWindow] orderBack:nil];
                [[view window] addChildWindow:[self transitionWindow] ordered:NSWindowAbove];
            }
            
            // declare our variables  
            int handle = -1;
            CGSTransitionSpec spec;
            // specify our specifications
            spec.unknown1 = 0;
            spec.type =  transitionStyle;
            spec.option = forward ? CGSLeft : CGSRight;
            spec.backColour = NULL;
            spec.wid = [(shouldRestrict ? [self transitionWindow] : [view window]) windowNumber];
            
            // Let's get a connection
            CGSConnection cgs = _CGSDefaultConnection();
            
            // Create a transition
            CGSNewTransition(cgs, &spec, &handle);
            
            if (shouldRestrict) {
                [[self transitionView] setImage:finalImage];
                [[self transitionView] display];
            }
            
            // Redraw the window
            [[view window] display];
            // Remember we disabled flushing in the previous method, we need to balance that.
            [[view window] enableFlushWindow];
            [[view window] flushWindow];
            
            CGSInvokeTransition(cgs, handle, duration);
            // We need to wait for the transition to finish before we get rid of it, otherwise we'll get all sorts of nasty errors... or maybe not.
            usleep((useconds_t)(duration * 1000000));
            
            CGSReleaseTransition(cgs, handle);
            handle = 0;
            
            if (shouldRestrict) {
                [[view window] removeChildWindow:[self transitionWindow]];
                [[self transitionWindow] orderOut:nil];
                [[self transitionView] setImage:nil];
            }
		}
	} else {
        
        if (initialImage == nil)
            [self prepareAnimationForRect:rect];
        
        NSRect bounds = [view bounds];
        imageRect = NSIntegralRect(NSIntersectionRect(NSUnionRect(imageRect, rect), bounds));
        
        CIImage *finalImage = [self createCurrentImage];
        
        CIFilter *transitionFilter = [self transitionFilterForRect:imageRect initialCIImage:initialImage finalCIImage:finalImage];
        
        [finalImage release];
        [initialImage release];
        initialImage = nil;
        
        NSRect frame = [view convertRect:[view frame] toView:nil];
        frame.origin = [[view window] convertBaseToScreen:frame.origin];
        
        SKTransitionAnimation *animation = [[SKTransitionAnimation alloc] initWithFilter:transitionFilter duration:duration animationCurve:NSAnimationEaseInOut];
        [[self transitionView] setAnimation:animation];
        [animation release];
        
        [[self transitionWindow] setFrame:frame display:NO];
        [[self transitionWindow] orderBack:nil];
        [[view window] addChildWindow:[self transitionWindow] ordered:NSWindowAbove];
        
        [animation startAnimation];
        
        // Update the view and its window, so it shows the correct state when it is shown.
        [view display];
        // Remember we disabled flushing in the previous method, we need to balance that.
        [[view window] enableFlushWindow];
        [[view window] flushWindow];
        
        [[view window] removeChildWindow:[self transitionWindow]];
        [[self transitionWindow] orderOut:nil];
        [[self transitionView] setAnimation:nil];
        
    }
}

#pragma mark Setup sheet

- (void)transitionSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSOKButton) {
        [self setTransitionStyle:[[transitionStylePopUpButton selectedItem] tag]];
        [self setDuration:fmaxf([transitionDurationField floatValue], 0.0)];
        [self setShouldRestrict:(BOOL)[[transitionExtentMatrix selectedCell] tag]];
    }
}

- (void)chooseTransitionModalForWindow:(NSWindow *)window {
    [self window];
    [transitionStylePopUpButton selectItemWithTag:[self transitionStyle]];
    [transitionDurationField setFloatValue:[self duration]];
    [transitionDurationSlider setFloatValue:[self duration]];
    [transitionExtentMatrix selectCellWithTag:(int)[self shouldRestrict]];
	[NSApp beginSheet:[self window]
       modalForWindow:window
        modalDelegate:self 
       didEndSelector:@selector(transitionSheetDidEnd:returnCode:contextInfo:)
          contextInfo:NULL];
}

- (IBAction)dismissTransitionSheet:(id)sender {
    [NSApp endSheet:[self window] returnCode:[sender tag]];
    [[self window] orderOut:self];
}

@end

#pragma mark -

@implementation SKTransitionAnimation

- (id)initWithFilter:(CIFilter *)aFilter duration:(NSTimeInterval)duration animationCurve:(NSAnimationCurve)animationCurve {
    if (self = [super initWithDuration:duration animationCurve:animationCurve]) {
        filter = [aFilter retain];
    }
    return self;
}

- (void)dealloc {
    [filter release];
    [super dealloc];
}

- (void)setCurrentProgress:(NSAnimationProgress)progress {
    [super setCurrentProgress:progress];
    [filter setValue:[NSNumber numberWithFloat:[self currentValue]] forKey:@"inputTime"];
    [[self delegate] display];
}

- (CIImage *)currentImage {
    return [filter valueForKey:@"outputImage"];
}

@end

#pragma mark -

@implementation SKTransitionView

+ (NSOpenGLPixelFormat *)defaultPixelFormat {
    static NSOpenGLPixelFormat *pf;

    if (pf == nil) {
        NSOpenGLPixelFormatAttribute attr[] = {
            NSOpenGLPFAAccelerated,
            NSOpenGLPFANoRecovery,
            NSOpenGLPFAColorSize, 32,
            0
        };
        
        pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attr];
    }

    return pf;
}

- (void)dealloc {
    [animation release];
    [context release];
    [super dealloc];
}

- (void)reshape	{
    needsReshape = YES;
}

- (void)prepareOpenGL {
    // Enable beam-synced updates.
    long parm = 1;
    [[self openGLContext] setValues:&parm forParameter:NSOpenGLCPSwapInterval];
    
    // Make sure that everything we don't need is disabled.
    // Some of these are enabled by default and can slow down rendering.
    
    glDisable(GL_ALPHA_TEST);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_SCISSOR_TEST);
    glDisable(GL_BLEND);
    glDisable(GL_DITHER);
    glDisable(GL_CULL_FACE);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glDepthMask(GL_FALSE);
    glStencilMask(0);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glHint(GL_TRANSFORM_HINT_APPLE, GL_FASTEST);
    
    needsReshape = YES;
}

- (SKTransitionAnimation *)animation {
    return animation;
}

- (void)setAnimation:(SKTransitionAnimation *)newAnimation {
    if (animation != newAnimation) {
        [animation release];
        animation = [newAnimation retain];
        [animation setDelegate:self];
        [self setNeedsDisplay:YES];
    }
}

- (CIImage *)image {
    return image;
}

- (void)setImage:(CIImage *)newImage {
    if (image != newImage) {
        [image release];
        image = [newImage retain];
        [self setNeedsDisplay:YES];
    }
}

- (CIImage *)currentImage {
    return image ? image : [animation currentImage];
}

- (CIContext *)ciContext {
    if (context == nil) {
        [[self openGLContext] makeCurrentContext];
        
        NSOpenGLPixelFormat *pf = [self pixelFormat];
        if (pf == nil)
            pf = [[self class] defaultPixelFormat];
        
        context = [[CIContext contextWithCGLContext:CGLGetCurrentContext() pixelFormat:[pf CGLPixelFormatObj] options:nil] retain];
    }
    return context;
}

- (void)updateMatrices {
    NSRect bounds = [self bounds];
    
    [[self openGLContext] update];
    
    glViewport(0, 0, NSWidth(bounds), NSHeight(bounds));

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(NSMinX(bounds), NSMaxX(bounds), NSMinY(bounds), NSMaxY(bounds), -1, 1);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    needsReshape = NO;
}

- (void)drawRect:(NSRect)rect {
    
    [[self openGLContext] makeCurrentContext];
    
    if (needsReshape)
        [self updateMatrices];
    
    glColor4f(0.0f, 0.0f, 0.0f, 0.0f);
    glBegin(GL_POLYGON);
        glVertex2f(NSMinX(rect), NSMinY(rect));
        glVertex2f(NSMaxX(rect), NSMinY(rect));
        glVertex2f(NSMaxX(rect), NSMaxY(rect));
        glVertex2f(NSMinX(rect), NSMaxY(rect));
    glEnd();
    
    CIImage *currentImage = [self currentImage];
    if (currentImage) {
        NSRect bounds = [self bounds];
        [[self ciContext] drawImage:currentImage inRect:*(CGRect*)&bounds fromRect:*(CGRect*)&bounds];
    }
    
    glFlush();
}

@end


@implementation SKTransitionWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation {
    if (self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:bufferingType defer:deferCreation]) {
        [self setReleasedWhenClosed:NO];
        [self setIgnoresMouseEvents:YES];
    }
    return self;
}

- (BOOL)canBecomeMainWindow { return NO; }
- (BOOL)canBecomeKeyWindow { return NO; }

@end