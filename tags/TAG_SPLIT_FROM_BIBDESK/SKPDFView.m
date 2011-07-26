//
//  SKPDFView.m
//  Skim
//
//  Created by Michael McCracken on 12/6/06.
/*
 This software is Copyright (c) 2006,2007
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
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

#import "SKPDFView.h"
#import "SKNavigationWindow.h"
#import "SKPDFHoverWindow.h"
#import "SKMainWindowController.h"
#import "SKPDFAnnotationNote.h"
#import "PDFPage_SKExtensions.h"
#import "NSString_SKExtensions.h"
#import "NSCursor_SKExtensions.h"
#import "SKApplication.h"
#import "SKStringConstants.h"
#import "NSUserDefaultsController_SKExtensions.h"

NSString *SKPDFViewToolModeChangedNotification = @"SKPDFViewToolModeChangedNotification";
NSString *SKPDFViewAnnotationModeChangedNotification = @"SKPDFViewAnnotationModeChangedNotification";
NSString *SKPDFViewActiveAnnotationDidChangeNotification = @"SKPDFViewActiveAnnotationDidChangeNotification";
NSString *SKPDFViewDidAddAnnotationNotification = @"SKPDFViewDidAddAnnotationNotification";
NSString *SKPDFViewDidRemoveAnnotationNotification = @"SKPDFViewDidRemoveAnnotationNotification";
NSString *SKPDFViewAnnotationDoubleClickedNotification = @"SKPDFViewAnnotationDoubleClickedNotification";

NSString *SKSkimNotePboardType = @"SKSkimNotePboardType";

@interface PDFView (PDFViewPrivateDeclarations)
- (void)pdfViewControlHit:(id)sender;
- (void)removeAnnotationControl;
@end

#pragma mark -

@interface SKPDFView (Private)

- (NSRect)resizeThumbForRect:(NSRect) rect rotation:(int)rotation;
- (void)transformCGContext:(CGContextRef)context forPage:(PDFPage *)page;

- (void)autohideTimerFired:(NSTimer *)aTimer;
- (void)doAutohide:(BOOL)flag;

- (PDFDestination *)destinationForEvent:(NSEvent *)theEvent isLink:(BOOL *)isLink;

- (void)moveActiveAnnotationForKey:(unichar)eventChar byAmount:(float)delta;

- (BOOL)selectAnnotationWithEvent:(NSEvent *)theEvent;
- (void)dragAnnotationWithEvent:(NSEvent *)theEvent;
- (void)selectSnapshotWithEvent:(NSEvent *)theEvent;
- (void)magnifyWithEvent:(NSEvent *)theEvent;
- (void)dragWithEvent:(NSEvent *)theEvent;
- (void)dragReadingBarWithEvent:(NSEvent *)theEvent;

@end

#pragma mark -

// Adobe Reader recognizes a path from the hyperref command \url{./test.pdf} as a file: URL, but PDFKit turns it into an http: URL (which of course doesn't work); I notice this because my collaborators use Adobe Reader 	 
@interface PDFAnnotationLink (SKRelativePathFix) 	 
- (void)fixRelativeURLIfNeeded; 	 
@end 	 

@implementation PDFAnnotationLink (SKRelativePathFix) 	 

// class posing indicates that setURL: is never called, and neither is setContents: (-contents returns nil), so this is the only way I can find to fix the thing, since we don't have an equivalent to textView:clickedOnLink:atIndex: 	 
- (void)fixRelativeURLIfNeeded { 	 
    NSURL *theURL = [self URL]; 	 
    // http://./path/to/file will never make sense, right? 	 
    if (theURL && [[theURL host] isEqualToString:@"."]) { 	 
        NSString *basePath = [[[[[self page] document] documentURL] path] stringByDeletingLastPathComponent]; 	 
        if (basePath) { 	 
            NSString *realPath = [basePath stringByAppendingPathComponent:[theURL path]]; 	 
            realPath = [realPath stringByStandardizingPath]; 	 
            if (realPath) 	 
                theURL = [NSURL fileURLWithPath:realPath]; 	 
            if (theURL) 	 
                [self setURL:theURL]; 	 
        } 	 
    } 	 
} 	 

@end 	 

#pragma mark -

@implementation SKPDFView

- (void)commonInitialization {
    toolMode = [[NSUserDefaults standardUserDefaults] integerForKey:SKLastToolModeKey];
    
    autohidesCursor = NO;
    hasNavigation = NO;
    autohideTimer = nil;
    navWindow = nil;
    
    readingBar = nil;
    
    activeAnnotation = nil;
    editAnnotation = NO;
    wasBounds = NSZeroRect;
    mouseDownLoc = NSZeroPoint;
    clickDelta = NSZeroPoint;
    resizingAnnotation = NO;
    draggingAnnotation = NO;
    mouseDownInAnnotation = NO;
    
    trackingRect = 0;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAnnotationWillChangeNotification:) 
                                                 name:SKAnnotationWillChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAnnotationDidChangeNotification:) 
                                                 name:SKAnnotationDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleScrollMagnifyNotification:) 
                                                 name:SKScrollMagnifyNotification object:nil];
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeys:
        [NSArray arrayWithObjects:SKReadingBarColorKey, SKReadingBarTransparencyKey, SKReadingBarInvertKey, nil]];
}

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        [self commonInitialization];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        [self commonInitialization];
    }
    return self;
}

- (void)dealloc {
    [[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeys:
        [NSArray arrayWithObjects:SKReadingBarColorKey, SKReadingBarTransparencyKey, SKReadingBarInvertKey, nil]];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self doAutohide:NO]; // invalidates and releases the timer
    [[SKPDFHoverWindow sharedHoverWindow] orderOut:self];
    [navWindow release];
    [readingBar release];
    [super dealloc];
}

#pragma mark Drawing

- (void)drawPage:(PDFPage *)pdfPage {
	// Let PDFView do most of the hard work.
	[super drawPage: pdfPage];
	
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(context);
    
    [self transformCGContext:context forPage:pdfPage];
    SKCGContextSetDefaultRGBColorSpace(context);
    
    NSArray *allAnnotations = [pdfPage annotations];
    
    if (allAnnotations) {
        unsigned int i, count = [allAnnotations count];
        BOOL foundActive = NO;
        
        for (i = 0; i < count; i++) {
            PDFAnnotation *annotation = [allAnnotations objectAtIndex: i];
            if ([annotation isNoteAnnotation] || [[annotation type] isEqualToString:@"Link"]) {
                if (annotation == activeAnnotation) {
                    foundActive = YES;
                } else if ([[annotation type] isEqualToString:@"FreeText"]) {
                    NSRect bounds = [annotation bounds];
                    NSRect rect = NSInsetRect(NSIntegralRect(bounds), 0.5, 0.5);
                    float color[4] = { 0.5, 0.5, 0.5, 1.0 };
                    CGContextSetStrokeColor(context, color);
                    CGContextStrokeRectWithWidth(context, *(CGRect *)&rect, 1.0);
                }
                if ([[annotation type] isEqualToString:@"Link"]) 	 
                    [(PDFAnnotationLink *)annotation fixRelativeURLIfNeeded];
            }
        }
        
        // Draw active annotation last so it is not "painted" over.
        if (foundActive) {
            BOOL isLink = [[activeAnnotation type] isEqualToString:@"Link"];
            float lineWidth = isLink ? 2.0 : 1.0;
            NSRect bounds = [activeAnnotation bounds];
            float color[4] = { 0.0, 0.0, 0.0, 1.0 };
            NSRect rect = NSInsetRect(NSIntegralRect(bounds), 0.5 * lineWidth, 0.5 * lineWidth);
            if (isLink) {
                color[3] = 0.1;
                CGContextSetFillColor(context, color);
                CGContextFillRect(context, *(CGRect *)&rect);
                color[3] = 0.5;
            } else {
                color[3] = 1.0;
            }
            CGContextSetStrokeColor(context, color);
            CGContextStrokeRectWithWidth(context, *(CGRect *)&rect, lineWidth);
            
            if ([activeAnnotation isResizable]) {
                rect = NSIntegralRect([self resizeThumbForRect:bounds rotation:[pdfPage rotation]]);
                CGContextSetFillColor(context, color);
                CGContextFillRect(context, *(CGRect *)&rect);
            }
        }
                
    }
    
    if (readingBar) {
        
        NSRect rect = [readingBar currentBoundsForBox:[self displayBox]];
        BOOL invert = [[NSUserDefaults standardUserDefaults] boolForKey:SKReadingBarInvertKey];
        NSColor *nsColor = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:SKReadingBarColorKey]];
        float alpha = 1.0 - [[NSUserDefaults standardUserDefaults] floatForKey:SKReadingBarTransparencyKey];
        float color[4] = { [nsColor redComponent], [nsColor greenComponent], [nsColor blueComponent], alpha };
        
        CGContextSetFillColor(context, color);
        
        if (invert) {
            NSRect bounds = [pdfPage boundsForBox:[self displayBox]];
            if (NSEqualRects(rect, NSZeroRect) || [[readingBar page] isEqual:pdfPage] == NO) {
                CGContextFillRect(context, *(CGRect *)&bounds);
            } else {
                NSRect outRect, ignored;
                NSDivideRect(bounds, &outRect, &ignored, NSMaxY(bounds) - NSMaxY(rect), NSMaxYEdge);
                CGContextFillRect(context, *(CGRect *)&outRect);
                NSDivideRect(bounds, &outRect, &ignored, NSMinY(rect) - NSMinY(bounds), NSMinYEdge);
                CGContextFillRect(context, *(CGRect *)&outRect);
            }
        } else if ([[readingBar page] isEqual:pdfPage]) {
            CGContextSetBlendMode(context, kCGBlendModeMultiply);        
            CGContextFillRect(context, *(CGRect *)&rect);
        }
    }
    
    CGContextRestoreGState(context);
}

- (void)setNeedsDisplayInRect:(NSRect)rect ofPage:(PDFPage *)page {
    NSRect aRect = [self convertRect:rect fromPage:page];
    float scale = [self scaleFactor];
	NSPoint max = NSMakePoint(ceilf(NSMaxX(aRect)) + scale, ceilf(NSMaxY(aRect)) + scale);
	NSPoint origin = NSMakePoint(floorf(NSMinX(aRect)) - scale, floorf(NSMinY(aRect)) - scale);
	
    [self setNeedsDisplayInRect:NSMakeRect(origin.x, origin.y, max.x - origin.x, max.y - origin.y)];
}

- (void)setNeedsDisplayForAnnotation:(PDFAnnotation *)annotation {
    NSRect bounds = [annotation bounds];
    if ([[annotation type] isEqualToString:@"Underline"]) {
        bounds.origin.y -= 0.03 * NSHeight(bounds);
        bounds.size.height *= 1.03;
    }
    [self setNeedsDisplayInRect:bounds ofPage:[annotation page]];
}

#pragma mark Accessors

- (void)setDocument:(PDFDocument *)document {
    [readingBar release];
    readingBar = nil;
    [super setDocument:document];
}

- (SKToolMode)toolMode {
    return toolMode;
}

- (void)setToolMode:(SKToolMode)newToolMode {
    if (toolMode != newToolMode) {
        if (toolMode == SKTextToolMode && activeAnnotation) {
            if (editAnnotation)
                [self endAnnotationEdit:self];
            [self setActiveAnnotation:nil];
        }
    
        toolMode = newToolMode;
        [[NSUserDefaults standardUserDefaults] setInteger:toolMode forKey:SKLastToolModeKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewToolModeChangedNotification object:self];
        // hack to make sure we update the cursor
        [[self window] makeFirstResponder:self];
    }
}

- (PDFAnnotation *)activeAnnotation {
	return activeAnnotation;
}

- (void)setActiveAnnotation:(PDFAnnotation *)newAnnotation {
	BOOL changed = newAnnotation != activeAnnotation;
	
	// Will need to redraw old active anotation.
	if (activeAnnotation != nil)
		[self setNeedsDisplayForAnnotation:activeAnnotation];
	
	// Assign.
	if (newAnnotation) {
		activeAnnotation = newAnnotation;
		
		// Force redisplay.
		[self setNeedsDisplayForAnnotation:activeAnnotation];
	} else {
		activeAnnotation = nil;
	}
	
	if (changed)
		[[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewActiveAnnotationDidChangeNotification object:self userInfo:nil];
}

#pragma mark Reading bar

- (BOOL)hasReadingBar {
    return readingBar != nil;
}

- (void)toggleReadingBar {
    if (readingBar) {
        [readingBar release];
        readingBar = nil;
        [self setNeedsDisplay:YES];
    } else {
        readingBar = [[SKReadingBar alloc] init];
        [readingBar setPage:[self currentPage]];
        [readingBar goToNextLine];
        [self setNeedsDisplay:YES];
    }
}

#pragma mark Tracking mousemoved fix

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    if ([self window] && trackingRect)
        [self removeTrackingRect:trackingRect];
    trackingRect = [self addTrackingRect:[self bounds] owner:self userData:NULL assumeInside:NO];
}

- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    if ([self window] && trackingRect)
        [self removeTrackingRect:trackingRect];
    trackingRect = [self addTrackingRect:[self bounds] owner:self userData:NULL assumeInside:NO];
}
 
- (void)setBounds:(NSRect)bounds {
    [super setBounds:bounds];
    if ([self window] && trackingRect)
        [self removeTrackingRect:trackingRect];
    trackingRect = [self addTrackingRect:[self bounds] owner:self userData:NULL assumeInside:NO];
}
 
- (void)setBoundsSize:(NSSize)size {
    [super setBoundsSize:size];
    if ([self window] && trackingRect)
        [self removeTrackingRect:trackingRect];
    trackingRect = [self addTrackingRect:[self bounds] owner:self userData:NULL assumeInside:NO];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    if ([self window] && trackingRect)
        [self removeTrackingRect:trackingRect];
}

- (void)viewDidMoveToWindow {
    trackingRect = [self addTrackingRect:[self bounds] owner:self userData:NULL assumeInside:NO];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [super mouseEntered:theEvent];
    if ([theEvent trackingNumber] == trackingRect)
        [[self window] setAcceptsMouseMovedEvents:YES];
}
 
- (void)mouseExited:(NSEvent *)theEvent {
    [super mouseExited:theEvent];
    if ([theEvent trackingNumber] == trackingRect)
        [[self window] setAcceptsMouseMovedEvents:NO];
}

#pragma mark Actions

- (void)delete:(id)sender
{
	if ([activeAnnotation isNoteAnnotation])
        [self removeActiveAnnotation:self];
    else
        NSBeep();
}

- (void)copy:(id)sender
{
    [super copy:sender];
    
    if ([activeAnnotation isNoteAnnotation] && [activeAnnotation isMovable]) {
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[activeAnnotation dictionaryValue]];
        [pboard declareTypes:[NSArray arrayWithObjects:SKSkimNotePboardType, nil] owner:nil];
        [pboard setData:data forType:SKSkimNotePboardType];
    }
}

- (void)pasteNoteAlternate:(BOOL)isAlternate {
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:SKSkimNotePboardType, NSStringPboardType, nil]];
    if (pboardType == nil) {
        NSBeep();
        return;
    }
    
    PDFAnnotation *newAnnotation;
    NSRect viewFrame = [self frame];
    PDFPage *page;
    
    if ([pboardType isEqualToString:SKSkimNotePboardType]) {
    
        NSData *data = [pboard dataForType:SKSkimNotePboardType];
        NSDictionary *note = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSRect bounds, pageBounds;
        
        newAnnotation = [[[PDFAnnotation alloc] initWithDictionary:note] autorelease];
        bounds = [newAnnotation bounds];
        page = [self currentPage];
        pageBounds = [page boundsForBox:[self displayBox]];
        
        if (NSMaxX(bounds) > NSMaxX(pageBounds))
            bounds.origin.x = NSMaxX(pageBounds) - NSWidth(bounds);
        if (NSMinX(bounds) < NSMinX(pageBounds))
            bounds.origin.x = NSMinX(pageBounds);
        if (NSMaxY(bounds) > NSMaxY(pageBounds))
            bounds.origin.y = NSMaxY(pageBounds) - NSHeight(bounds);
        if (NSMinY(bounds) < NSMinY(pageBounds))
            bounds.origin.y = NSMinY(pageBounds);
        
        [newAnnotation setBounds:bounds];
        
    } else {
        
        NSAssert([pboardType isEqualToString:NSStringPboardType], @"inconsistent pasteboard type");
        
        NSPoint center = NSMakePoint(NSMidX(viewFrame), NSMidY(viewFrame));
        NSSize defaultSize;
        NSRect bounds;
        
        page = [self pageForPoint: center nearest: YES];
        defaultSize = isAlternate ? NSMakeSize(16.0, 16.0) : ([page rotation] % 180 == 90) ? NSMakeSize(64.0, 128.0) : NSMakeSize(128.0, 64.0);
        bounds = NSMakeRect(center.x - 0.5 * defaultSize.width, center.y - 0.5 * defaultSize.height, defaultSize.width, defaultSize.height);
       
        if (isAlternate)
            newAnnotation = [[SKPDFAnnotationNote alloc] initWithBounds:bounds];
        else
            newAnnotation = [[SKPDFAnnotationFreeText alloc] initWithBounds:bounds];
        [newAnnotation setContents:[pboard stringForType:NSStringPboardType]];
    }
    
    [page addAnnotation:newAnnotation];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDidAddAnnotationNotification object:self 
        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:newAnnotation, @"annotation", page, @"page", nil]];

    [self setActiveAnnotation:newAnnotation];
}

- (void)paste:(id)sender {
    [self pasteNoteAlternate:NO];
}

- (void)alternatePaste:(id)sender {
    [self pasteNoteAlternate:YES];
}

- (void)cut:(id)sender
{
	if ([activeAnnotation isNoteAnnotation]) {
        [self copy:sender];
        [self delete:sender];
    } else
        NSBeep();
}

- (void)changeToolMode:(id)sender {
    [self setToolMode:[sender tag]];
}

#pragma mark Event Handling

- (void)keyDown:(NSEvent *)theEvent
{
    NSString *characters = [theEvent charactersIgnoringModifiers];
    unichar eventChar = [characters length] > 0 ? [characters characterAtIndex:0] : 0;
	unsigned int modifiers = [theEvent modifierFlags] & (NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask | NSControlKeyMask);
    BOOL isPresentation = hasNavigation && autohidesCursor;
    
	if (isPresentation && (eventChar == NSRightArrowFunctionKey) && (modifiers == 0)) {
        [self goToNextPage:self];
    } else if (isPresentation && (eventChar == NSLeftArrowFunctionKey) && (modifiers == 0)) {
		[self goToPreviousPage:self];
	} else if ((eventChar == NSDeleteCharacter || eventChar == NSDeleteFunctionKey) && (modifiers == 0)) {
		[self delete:self];
    } else if (isPresentation == NO && [self toolMode] == SKTextToolMode && (eventChar == NSEnterCharacter || eventChar == NSFormFeedCharacter || eventChar == NSNewlineCharacter || eventChar == NSCarriageReturnCharacter) && (modifiers == 0)) {
        if (activeAnnotation && activeAnnotation != editAnnotation)
            [self editActiveAnnotation:self];
    } else if (isPresentation == NO && [self toolMode] == SKTextToolMode && (eventChar == NSTabCharacter) && (modifiers == NSAlternateKeyMask)){
        [self selectNextActiveAnnotation:self];
    } else if (isPresentation == NO && [self toolMode] == SKTextToolMode && (eventChar == NSBackTabCharacter) && (modifiers == NSAlternateKeyMask)){
        [self selectPreviousActiveAnnotation:self];
	} else if (isPresentation == NO && [activeAnnotation isNoteAnnotation] && (eventChar == NSRightArrowFunctionKey || eventChar == NSLeftArrowFunctionKey || eventChar == NSUpArrowFunctionKey || eventChar == NSDownArrowFunctionKey) && (modifiers == 0 || modifiers == NSShiftKeyMask)) {
        [self moveActiveAnnotationForKey:eventChar byAmount:(modifiers & NSShiftKeyMask) ? 10.0 : 1.0];
    } else if (readingBar && (eventChar == NSDownArrowFunctionKey) && (modifiers == NSAlternateKeyMask)) {
        if ([readingBar goToNextLine]) {
            if ([[self currentPage] isEqual:[readingBar page]] == NO)
                [self goToPage:[readingBar page]];
            [self setNeedsDisplay:YES];
        }
    } else if (readingBar && (eventChar == NSRightArrowFunctionKey) && (modifiers == NSAlternateKeyMask)) {
        if ([readingBar goToNextPage]) {
            if ([[self currentPage] isEqual:[readingBar page]] == NO)
                [self goToPage:[readingBar page]];
            [self setNeedsDisplay:YES];
        }
    } else if (readingBar && (eventChar == NSUpArrowFunctionKey) && (modifiers == NSAlternateKeyMask)) {
        if ([readingBar goToPreviousLine]) {
            if ([[self currentPage] isEqual:[readingBar page]] == NO)
                [self goToPage:[readingBar page]];
            [self setNeedsDisplay:YES];
        }
    } else if (readingBar && (eventChar == NSLeftArrowFunctionKey) && (modifiers == NSAlternateKeyMask)) {
        if ([readingBar goToPreviousPage]) {
            if ([[self currentPage] isEqual:[readingBar page]] == NO)
                [self goToPage:[readingBar page]];
            [self setNeedsDisplay:YES];
        }
    } else {
		[super keyDown:theEvent];
    }
}

- (void)mouseDown:(NSEvent *)theEvent{
    [[SKPDFHoverWindow sharedHoverWindow] orderOut:self];
    if ([[activeAnnotation type] isEqualToString:@"Link"])
        [self setActiveAnnotation:nil];
    
    mouseDownLoc = [theEvent locationInWindow];

    if ([theEvent modifierFlags] & NSCommandKeyMask) {
        [self selectSnapshotWithEvent:theEvent];
    } else {
        switch (toolMode) {
            case SKTextToolMode:
            {
                NSPoint p = mouseDownLoc;
                p = [self convertPoint:p fromView:nil];
                PDFPage *page = [self pageForPoint:p nearest:NO];
                p = [self convertPoint:p toPage:page];
                if (readingBar && [[readingBar page] isEqual:page] && NSPointInRect(p, [readingBar currentBoundsForBox:[self displayBox]])) {
                    [self dragReadingBarWithEvent:theEvent];
                } else if ([[self document] isLocked] || [self selectAnnotationWithEvent:theEvent] == NO) {
                    PDFAreaOfInterest area = [self areaOfInterestForMouse:theEvent];
                    if (area == kPDFNoArea || (area == kPDFPageArea && [[page selectionForRect:NSMakeRect(p.x - 30.0, p.y - 40.0, 60.0, 80.0)] string] == nil))
                        [self dragWithEvent:theEvent];
                    else
                        [super mouseDown:theEvent];
                }
                break;
            }
            case SKMoveToolMode:
                [self dragWithEvent:theEvent];	
                break;
            case SKMagnifyToolMode:
                if ([self areaOfInterestForMouse:theEvent] == kPDFNoArea)
                    [self dragWithEvent:theEvent];
                else
                    [self magnifyWithEvent:theEvent];
                break;
        }
    }
}

- (void)mouseUp:(NSEvent *)theEvent{
    switch (toolMode) {
        case SKTextToolMode:
            mouseDownInAnnotation = NO;
            if (draggingAnnotation) {
                draggingAnnotation = NO;
                if ([activeAnnotation isEditable] == NO) {
                    NSString *selString = [[[[activeAnnotation page] selectionForRect:[activeAnnotation bounds]] string] stringByCollapsingWhitespaceAndNewlinesAndRemovingSurroundingWhitespaceAndNewlines];
                    [activeAnnotation setContents:selString];
                }
            } else
                [super mouseUp:theEvent];
            break;
        case SKMoveToolMode:
            // shouldn't reach this
            break;
        case SKMagnifyToolMode:
            [super mouseUp:theEvent];
            break;
    }
}

static inline NSRect rectWithCorners(NSPoint p1, NSPoint p2)
{
    NSRect rect;
    rect.size.width = ABS(p2.x - p1.x);
    rect.size.height = ABS(p2.y - p1.y);
    rect.origin.x = MIN(p2.x, p1.x);
    rect.origin.y = MIN(p2.y, p1.y);
    return rect;
}

- (void)mouseDragged:(NSEvent *)theEvent {
    switch (toolMode) {
        case SKTextToolMode:
            if (draggingAnnotation) {
                [self dragAnnotationWithEvent:theEvent];
            } else if (nil == activeAnnotation) {
                if (mouseDownInAnnotation) {
                    // reimplement text selection behavior so we can select text inside markup annotation bounds rectangles (and have a highlight and strikeout on the same line, for instance), but don't select inside an existing markup annotation

                    // if we autoscroll, the mouseDownLoc is no longer correct as a starting point
                    NSPoint mouseDownLocInDoc = [[self documentView] convertPoint:mouseDownLoc fromView:nil];
                    if ([[self documentView] autoscroll:theEvent])
                        mouseDownLoc = [[self documentView] convertPoint:mouseDownLocInDoc toView:nil];

                    NSPoint p1 = [self convertPoint:mouseDownLoc fromView:nil];
                    PDFPage *page1 = [self pageForPoint:p1 nearest:YES];
                    p1 = [self convertPoint:p1 toPage:page1];

                    NSPoint p2 = [self convertPoint:[theEvent locationInWindow] fromView:nil];
                    PDFPage *page2 = [self pageForPoint:p2 nearest:YES];
                    p2 = [self convertPoint:p2 toPage:page2];
                    
                    PDFSelection *sel = nil;
                    if  ([theEvent modifierFlags] & NSAlternateKeyMask) {
                        // how to handle multipage selection?  Preview.app's behavior is screwy as well, so we'll do the same thing
                        sel = [page1 selectionForRect:rectWithCorners(p1, p2)];
                    } else {
                        sel = [[self document] selectionFromPage:page1 atPoint:p1 toPage:page2 atPoint:p2];
                    }

                    [self setCurrentSelection:sel];
                } else {
                    [super mouseDragged:theEvent];
                }
            }
            break;
        case SKMoveToolMode:
            // shouldn't reach this
            break;
        case SKMagnifyToolMode:
            [super mouseDragged:theEvent];
            break;
    }
}

- (void)mouseMoved:(NSEvent *)theEvent {

    // we receive this message whenever we are first responder, so check the location
    NSView *clipView = [[[self documentView] enclosingScrollView] contentView];
    NSPoint p = [clipView convertPoint:[theEvent locationInWindow] fromView:nil];
    NSCursor *cursor = nil;
    
    if (NSPointInRect(p, [clipView visibleRect]) == NO || ([navWindow isVisible] && NSPointInRect([NSEvent mouseLocation], [navWindow frame]))) {
        cursor = [NSCursor arrowCursor];
    } else if ([theEvent modifierFlags] & NSCommandKeyMask) {
        cursor = [NSCursor cameraCursor];
    } else {
        switch (toolMode) {
            case SKTextToolMode:
            {
                p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
                PDFPage *page = [self pageForPoint:p nearest:NO];
                p = [self convertPoint:p toPage:page];
                PDFAreaOfInterest area = [self areaOfInterestForMouse:theEvent];
                if ((readingBar && [[readingBar page] isEqual:page] && NSPointInRect(p, [readingBar currentBoundsForBox:[self displayBox]])) ||
                    (area == kPDFNoArea || (area == kPDFPageArea && [[page selectionForRect:NSMakeRect(p.x - 30.0, p.y - 40.0, 60.0, 80.0)] string] == nil)))
                    cursor = [NSCursor openHandCursor];
                else
                    [super mouseMoved:theEvent];
                break;
            }
            case SKMoveToolMode:
                cursor = [NSCursor openHandCursor];
                break;
            case SKMagnifyToolMode:
                if ([self areaOfInterestForMouse:theEvent] == kPDFNoArea)
                    cursor = [NSCursor openHandCursor];
                else
                    cursor = ([theEvent modifierFlags] & NSShiftKeyMask) ? [NSCursor zoomOutCursor] : [NSCursor zoomInCursor];
                break;
        }
    }
    [cursor set];
    
    BOOL isLink = NO;
    PDFDestination *dest = [self destinationForEvent:theEvent isLink:&isLink];
    
    if (isLink)
        [[SKPDFHoverWindow sharedHoverWindow] showWithDestination:dest atPoint:[[self window] convertBaseToScreen:[theEvent locationInWindow]] fromView:self];
    else
        [[SKPDFHoverWindow sharedHoverWindow] hide];

    if ([[activeAnnotation type] isEqualToString:@"Link"])
        [self setActiveAnnotation:nil];
    
    // in presentation mode only show the navigation window only by moving the mouse to the bottom edge
    BOOL shouldShowNavWindow = hasNavigation && (autohidesCursor == NO || [theEvent locationInWindow].y < 5.0);
    if (autohidesCursor || shouldShowNavWindow) {
        if (shouldShowNavWindow && [navWindow isVisible] == NO) {
            [[self window] addChildWindow:navWindow ordered:NSWindowAbove];
            [navWindow orderFront:self];
        }
        [self doAutohide:YES];
    }
}

- (void)flagsChanged:(NSEvent *)theEvent {
    [super flagsChanged:theEvent];
    
    NSCursor *cursor = nil;
    
    if ([theEvent modifierFlags] & NSCommandKeyMask) {
        cursor = [NSCursor cameraCursor];
    } else {
        switch (toolMode) {
            case SKTextToolMode:
                cursor = [NSCursor arrowCursor];
                break;
            case SKMoveToolMode:
                cursor = [NSCursor openHandCursor];
                break;
            case SKMagnifyToolMode:
                cursor = ([theEvent modifierFlags] & NSShiftKeyMask) ? [NSCursor zoomOutCursor] : [NSCursor zoomInCursor];
                break;
        }
    }
    
    [cursor set];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSMenu *menu = [super menuForEvent:theEvent];
    NSMenu *submenu;
    NSMenuItem *item;
    
    if (hasNavigation && autohidesCursor)
        return menu;
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    submenu = [[NSMenu allocWithZone:[menu zone]] init];
    
    item = [submenu addItemWithTitle:NSLocalizedString(@"Text", @"Menu item title") action:@selector(changeToolMode:) keyEquivalent:@""];
    [item setTag:SKTextToolMode];
    [item setTarget:self];

    item = [submenu addItemWithTitle:NSLocalizedString(@"Scroll", @"Menu item title") action:@selector(changeToolMode:) keyEquivalent:@""];
    [item setTag:SKMoveToolMode];
    [item setTarget:self];

    item = [submenu addItemWithTitle:NSLocalizedString(@"Magnify", @"Menu item title") action:@selector(changeToolMode:) keyEquivalent:@""];
    [item setTag:SKMagnifyToolMode];
    [item setTarget:self];
    
    item = [menu addItemWithTitle:NSLocalizedString(@"Tools", @"Menu item title") action:NULL keyEquivalent:@""];
    [item setSubmenu:submenu];
    [submenu release];
    
    NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    item = [menu addItemWithTitle:NSLocalizedString(@"Take Snapshot", @"Menu item title") action:@selector(takeSnapshot:) keyEquivalent:@""];
    [item setRepresentedObject:[NSValue valueWithPoint:point]];
    [item setTarget:self];
    
    if ([self toolMode] == SKTextToolMode) {
        
        PDFPage *page = [self pageForPoint:point nearest:YES];
        PDFAnnotation *annotation = nil;
        
        if (page) {
            annotation = [page annotationAtPoint:[self convertPoint:point toPage:page]];
            if ([annotation isNoteAnnotation] == NO)
                annotation = nil;
        }
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        submenu = [[NSMenu allocWithZone:[menu zone]] init];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Text Note", @"Menu item title") action:@selector(addAnnotationFromMenu:) keyEquivalent:@""];
        [item setRepresentedObject:[NSValue valueWithPoint:point]];
        [item setTag:SKFreeTextNote];
        [item setTarget:self];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Anchored Note", @"Menu item title") action:@selector(addAnnotationFromMenu:) keyEquivalent:@""];
        [item setRepresentedObject:[NSValue valueWithPoint:point]];
        [item setTag:SKAnchoredNote];
        [item setTarget:self];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Circle", @"Menu item title") action:@selector(addAnnotationFromMenu:) keyEquivalent:@""];
        [item setRepresentedObject:[NSValue valueWithPoint:point]];
        [item setTag:SKCircleNote];
        [item setTarget:self];
        
        item = [submenu addItemWithTitle:NSLocalizedString(@"Box", @"Menu item title") action:@selector(addAnnotationFromMenu:) keyEquivalent:@""];
        [item setRepresentedObject:[NSValue valueWithPoint:point]];
        [item setTag:SKSquareNote];
        [item setTarget:self];
        
        if ([self currentSelection]) {
            item = [submenu addItemWithTitle:NSLocalizedString(@"Highlight", @"Menu item title") action:@selector(addAnnotationFromMenu:) keyEquivalent:@""];
            [item setRepresentedObject:[NSValue valueWithPoint:point]];
            [item setTag:SKHighlightNote];
            [item setTarget:self];
            
            item = [submenu addItemWithTitle:NSLocalizedString(@"Strike Out", @"Menu item title") action:@selector(addAnnotationFromMenu:) keyEquivalent:@""];
            [item setRepresentedObject:[NSValue valueWithPoint:point]];
            [item setTag:SKStrikeOutNote];
            [item setTarget:self];
            
            item = [submenu addItemWithTitle:NSLocalizedString(@"Underline", @"Menu item title") action:@selector(addAnnotationFromMenu:) keyEquivalent:@""];
            [item setRepresentedObject:[NSValue valueWithPoint:point]];
            [item setTag:SKUnderlineNote];
            [item setTarget:self];
        }
        
        item = [menu addItemWithTitle:NSLocalizedString(@"New Note", @"Menu item title") action:NULL keyEquivalent:@""];
        [item setSubmenu:submenu];
        [submenu release];
        
        if (annotation) {
            item = [menu addItemWithTitle:NSLocalizedString(@"Remove Note", @"Menu item title") action:@selector(removeThisAnnotation:) keyEquivalent:@""];
            [item setRepresentedObject:annotation];
            [item setTarget:self];
            
            if ((annotation != activeAnnotation || editAnnotation == nil) && [annotation isEditable]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Edit Note", @"Menu item title") action:@selector(editThisAnnotation:) keyEquivalent:@""];
                [item setRepresentedObject:annotation];
                [item setTarget:self];
            }
        } else if ([activeAnnotation isNoteAnnotation]) {
            item = [menu addItemWithTitle:NSLocalizedString(@"Remove Current Note", @"Menu item title") action:@selector(removeActiveAnnotation:) keyEquivalent:@""];
            [item setTarget:self];
            
            if (editAnnotation == nil && [activeAnnotation isEditable]) {
                item = [menu addItemWithTitle:NSLocalizedString(@"Edit Current Note", @"Menu item title") action:@selector(editActiveAnnotation:) keyEquivalent:@""];
                [item setTarget:self];
            }
        }
        
    }
    
    return menu;
}

- (void)handleScrollMagnifyNotification:(NSNotification *)note {
    float dy = [[note object] deltaY];
    dy = dy > 0 ? MIN(0.2, dy) : MAX(-0.2, dy);
    [self setScaleFactor:[self scaleFactor] + 0.5 * dy];
}

#pragma mark Annotation management

- (void)addAnnotationFromMenu:(id)sender {
    PDFSelection *selection = [self currentSelection];
    NSString *text = [[selection string] stringByCollapsingWhitespaceAndNewlinesAndRemovingSurroundingWhitespaceAndNewlines];
    SKNoteType annotationType = [sender tag];
    NSPoint point = [[sender representedObject] pointValue];
	PDFPage *page = [self pageForPoint:point nearest:YES];
    NSRect bounds;

    if (selection && page) {
        bounds = [selection boundsForPage:page];
    } else {
        NSSize defaultSize = (annotationType == SKAnchoredNote) ? NSMakeSize(16.0, 16.0) : ([page rotation] % 180 == 90) ? NSMakeSize(64.0, 128.0) : NSMakeSize(128.0, 64.0);
        
        point = [self convertPoint:point toPage:page];
        bounds = NSMakeRect(point.x - 0.5 * defaultSize.width, point.y - 0.5 * defaultSize.height, defaultSize.width, defaultSize.height);
    }
    
    [self addAnnotationWithType:annotationType contents:text page:page bounds:bounds];
}

- (void)addAnnotationFromSelectionWithType:(SKNoteType)annotationType {
	PDFPage *page;
	NSRect bounds;
    PDFSelection *selection = [self currentSelection];
    NSString *text = nil;
	
    if (selection != nil) {
        PDFSelection *selection = [self currentSelection];
        
        text = [[selection string] stringByCollapsingWhitespaceAndNewlinesAndRemovingSurroundingWhitespaceAndNewlines];
        
		// Get bounds (page space) for selection (first page in case selection spans multiple pages).
		page = [[selection pages] objectAtIndex: 0];
		bounds = [selection boundsForPage: page];
	} else if (annotationType == SKHighlightNote || annotationType == SKStrikeOutNote || annotationType == SKUnderlineNote) {
        NSBeep();
        return;
    } else {
		// Get center of the PDFView.
		NSRect viewFrame = [self frame];
		NSPoint center = NSMakePoint(NSMidX(viewFrame), NSMidY(viewFrame));
		NSSize defaultSize = (annotationType == SKAnchoredNote) ? NSMakeSize(16.0, 16.0) : NSMakeSize(128.0, 64.0);
		
		// Convert to "page space".
		page = [self pageForPoint: center nearest: YES];
		center = [self convertPoint: center toPage: page];
        if ([page rotation] % 180 == 90)
            defaultSize = NSMakeSize(defaultSize.height, defaultSize.width);
        bounds = NSMakeRect(center.x - 0.5 * defaultSize.width, center.y - 0.5 * defaultSize.height, defaultSize.width, defaultSize.height);
	}
    [self addAnnotationWithType:annotationType contents:text page:page bounds:bounds];
}

- (void)addAnnotationWithType:(SKNoteType)annotationType contents:(NSString *)text page:(PDFPage *)page bounds:(NSRect)bounds {
	PDFAnnotation *newAnnotation = nil;
	// Create annotation and add to page.
    switch (annotationType) {
        case SKFreeTextNote:
            newAnnotation = [[SKPDFAnnotationFreeText alloc] initWithBounds:bounds];
            break;
        case SKAnchoredNote:
            newAnnotation = [[SKPDFAnnotationNote alloc] initWithBounds:bounds];
            break;
        case SKCircleNote:
            newAnnotation = [[SKPDFAnnotationCircle alloc] initWithBounds:NSInsetRect(bounds, -5.0, -5.0)];
            break;
        case SKSquareNote:
            newAnnotation = [[SKPDFAnnotationSquare alloc] initWithBounds:NSInsetRect(bounds, -5.0, -5.0)];
            break;
        case SKHighlightNote:
            newAnnotation = [[SKPDFAnnotationMarkup alloc] initWithSelection:[self currentSelection] markupType:kPDFMarkupTypeHighlight];
            break;
        case SKStrikeOutNote:
            newAnnotation = [[SKPDFAnnotationMarkup alloc] initWithSelection:[self currentSelection] markupType:kPDFMarkupTypeStrikeOut];
            break;
        case SKUnderlineNote:
            newAnnotation = [[SKPDFAnnotationMarkup alloc] initWithSelection:[self currentSelection] markupType:kPDFMarkupTypeUnderline];
            break;
	}
    if (text == nil) {
        if ([newAnnotation isEditable])
            text = NSLocalizedString(@"New note", @"Default text for new note");
        else
            text = [[[page selectionForRect:bounds] string] stringByCollapsingWhitespaceAndNewlinesAndRemovingSurroundingWhitespaceAndNewlines];
    }
        
    [newAnnotation setContents:text];
    
    [page addAnnotation:newAnnotation];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDidAddAnnotationNotification object:self 
        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:newAnnotation, @"annotation", page, @"page", nil]];

    [self setActiveAnnotation:newAnnotation];
    [newAnnotation release];
}

- (void)removeActiveAnnotation:(id)sender{
    if ([activeAnnotation isNoteAnnotation])
        [self removeAnnotation:activeAnnotation];
}

- (void)removeThisAnnotation:(id)sender{
    PDFAnnotation *annotation = [sender representedObject];
    
    if (annotation)
        [self removeAnnotation:annotation];
}

- (void)removeAnnotation:(PDFAnnotation *)annotation{
    PDFAnnotation *wasAnnotation = [annotation retain];
    PDFPage *page = [wasAnnotation page];
    
    if (editAnnotation && activeAnnotation == annotation)
        [self endAnnotationEdit:self];
	if (activeAnnotation == annotation)
		[self setActiveAnnotation:nil];
    [self setNeedsDisplayForAnnotation:wasAnnotation];
    [page removeAnnotation:wasAnnotation];
    [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDidRemoveAnnotationNotification object:self 
        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:wasAnnotation, @"annotation", page, @"page", nil]];
    [wasAnnotation release];
}

- (void)editThisAnnotation:(id)sender {
    PDFAnnotation *annotation = [sender representedObject];
    
    if (annotation == nil || editAnnotation == annotation)
        return;
    
    if (editAnnotation)
        [self endAnnotationEdit:self];
    if (activeAnnotation != annotation)
        [self setActiveAnnotation:annotation];
    [self editActiveAnnotation:sender];
}

- (void)changeFont:(id)sender {
    if ([activeAnnotation respondsToSelector:@selector(setFont:)] && [activeAnnotation respondsToSelector:@selector(font)]) {
        NSFont *font = [[NSFontPanel sharedFontPanel] panelConvertFont:[(PDFAnnotationFreeText *)activeAnnotation font]];
        [(PDFAnnotationFreeText *)activeAnnotation setFont:font];
        [self setNeedsDisplayForAnnotation:activeAnnotation];
    }
}

- (void)editActiveAnnotation:(id)sender {
    if (nil == activeAnnotation)
        return;
    
    [self endAnnotationEdit:self];
    
    NSString *type = [activeAnnotation type];
    
    if ([type isEqualToString:@"Link"]) {
        
        [[SKPDFHoverWindow sharedHoverWindow] orderOut:self];
        [self goToDestination:[activeAnnotation destination]];
        
    } else if ([type isEqualToString:@"Note"]) {
        
		[[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewAnnotationDoubleClickedNotification object:self 
            userInfo:[NSDictionary dictionaryWithObjectsAndKeys:activeAnnotation, @"annotation", nil]];
        
    } else if ([type isEqualToString:@"FreeText"]) {
        
        NSRect editBounds = [activeAnnotation bounds];
        editAnnotation = [[[PDFAnnotationTextWidget alloc] initWithBounds:editBounds] autorelease];
        [editAnnotation setStringValue:[activeAnnotation contents]];
        if ([activeAnnotation respondsToSelector:@selector(font)])
            [editAnnotation setFont:[(PDFAnnotationFreeText *)activeAnnotation font]];
        [editAnnotation setColor:[activeAnnotation color]];
        [[activeAnnotation page] addAnnotation:editAnnotation];
        
        // Start editing
        NSPoint location = [self convertPoint:[self convertPoint:NSMakePoint(NSMidX(editBounds), NSMidY(editBounds)) fromPage:[activeAnnotation page]] toView:nil];
        NSEvent *theEvent = [NSEvent mouseEventWithType:NSLeftMouseDown location:location modifierFlags:0 timestamp:0 windowNumber:[[self window] windowNumber] context:nil eventNumber:0 clickCount:1 pressure:1.0];
        [super mouseDown:theEvent];
        
    }
    
}

- (void)endAnnotationEdit:(id)sender {
    if (editAnnotation) {
        if ([self respondsToSelector:@selector(removeAnnotationControl)])
            [self removeAnnotationControl]; // this removes the textfield from the pdfview, need to do this before we remove the text widget
        if ([[editAnnotation stringValue] isEqualToString:[activeAnnotation contents]] == NO) {
            [activeAnnotation setContents:[editAnnotation stringValue]];
        }
        [[editAnnotation page] removeAnnotation:editAnnotation];
        editAnnotation = nil;
    }
}

// this is the action for the textfield for the text widget. Override to remove it after an edit. 
- (void)pdfViewControlHit:(id)sender{
    if ([PDFView instancesRespondToSelector:@selector(pdfViewControlHit:)] && [sender isKindOfClass:[NSTextField class]]) {
        [super pdfViewControlHit:sender];
        [self endAnnotationEdit:self];
    }
}

- (void)selectNextActiveAnnotation:(id)sender {
    PDFDocument *pdfDoc = [self document];
    int numberOfPages = [pdfDoc pageCount];
    int i = -1;
    int pageIndex, startPageIndex = -1;
    PDFAnnotation *annotation = nil;
    
    if (activeAnnotation) {
        if (editAnnotation)
            [self endAnnotationEdit:self];
        pageIndex = [pdfDoc indexForPage:[activeAnnotation page]];
        i = [[[activeAnnotation page] annotations] indexOfObject:activeAnnotation];
    } else {
        pageIndex = [pdfDoc indexForPage:[self currentPage]];
    }
    while (annotation == nil) {
        NSArray *annotations = [[pdfDoc pageAtIndex:pageIndex] annotations];
        while (++i < (int)[annotations count] && annotation == nil) {
            annotation = [annotations objectAtIndex:i];
            if ([annotation isNoteAnnotation] == NO && [[annotation type] isEqualToString:@"Link"] == NO)
                annotation = nil;
        }
        if (startPageIndex == -1)
            startPageIndex = pageIndex;
        else if (pageIndex == startPageIndex)
            break;
        if (++pageIndex == numberOfPages)
            pageIndex = 0;
        i = -1;
    }
    if (annotation) {
        [[self documentView] scrollRectToVisible:[self convertRect:[self convertRect:[annotation bounds] fromPage:[annotation page]] toView:[self documentView]]];
        [self setActiveAnnotation:annotation];
        if ([[annotation type] isEqualToString:@"Link"]) {
            NSRect bounds = [annotation bounds]; 
            NSPoint point = [self convertPoint:[self convertPoint:NSMakePoint(NSMidX(bounds), NSMidY(bounds)) fromPage:[annotation page]] toView:nil]; 
            [[SKPDFHoverWindow sharedHoverWindow] showWithDestination:[annotation destination] atPoint:[[self window] convertBaseToScreen:point] fromView:self];
        } else {
            [[SKPDFHoverWindow sharedHoverWindow] orderOut:self];
        }
    }
}

- (void)selectPreviousActiveAnnotation:(id)sender {
    PDFDocument *pdfDoc = [self document];
    int numberOfPages = [pdfDoc pageCount];
    int i = numberOfPages;
    int pageIndex, startPageIndex = -1;
    PDFAnnotation *annotation = nil;
    
    if (activeAnnotation) {
        if (editAnnotation)
            [self endAnnotationEdit:self];
        pageIndex = [pdfDoc indexForPage:[activeAnnotation page]];
        i = [[[activeAnnotation page] annotations] indexOfObject:activeAnnotation];
    } else {
        pageIndex = [pdfDoc indexForPage:[self currentPage]];
    }
    while (annotation == nil) {
        NSArray *annotations = [[pdfDoc pageAtIndex:pageIndex] annotations];
        while (--i >= 0 && annotation == nil) {
            annotation = [annotations objectAtIndex:i];
            if ([annotation isNoteAnnotation] == NO && [[annotation type] isEqualToString:@"Link"] == NO)
                annotation = nil;
        }
        if (startPageIndex == -1)
            startPageIndex = pageIndex;
        else if (pageIndex == startPageIndex)
            break;
        if (++pageIndex == numberOfPages)
            pageIndex = numberOfPages - 1;
        i = [[[pdfDoc pageAtIndex:pageIndex] annotations] count];
    }
    if (annotation) {
        [[self documentView] scrollRectToVisible:[self convertRect:[self convertRect:[annotation bounds] fromPage:[annotation page]] toView:[self documentView]]];
        [self setActiveAnnotation:annotation];
        if ([[annotation type] isEqualToString:@"Link"]) {
            NSRect bounds = [annotation bounds]; 
            NSPoint point = [self convertPoint:[self convertPoint:NSMakePoint(NSMidX(bounds), NSMidY(bounds)) fromPage:[annotation page]] toView:nil]; 
            [[SKPDFHoverWindow sharedHoverWindow] showWithDestination:[annotation destination] atPoint:[[self window] convertBaseToScreen:point] fromView:self];
        } else {
            [[SKPDFHoverWindow sharedHoverWindow] orderOut:self];
        }
    }
}

- (void)scrollAnnotationToVisible:(PDFAnnotation *)annotation {
    NSRect rect = [self convertRect:[self convertRect:[annotation bounds] fromPage:[annotation page]] toView:[self documentView]];
    [[self documentView] scrollRectToVisible:rect];
}

#pragma mark Snapshots

- (void)takeSnapshot:(id)sender {
    NSPoint point;
    PDFPage *page;
    NSRect rect;
    
	if ([sender respondsToSelector:@selector(representedObject)] && [[sender representedObject] respondsToSelector:@selector(pointValue)]) {
        point = [[sender representedObject] pointValue];
        page = [self pageForPoint:point nearest:YES];
    } else {
		NSRect viewFrame = [self frame];
        point = NSMakePoint(NSMidX(viewFrame), NSMidY(viewFrame));
        page = [self currentPage];
    }
    
    point = [self convertPoint:point toPage:page];
    
    rect.origin.x = [self convertPoint:[page boundsForBox:[self displayBox]].origin fromPage:page].x;
    rect.origin.y = point.y - 100.0;
    // rowSizeForPage: allows for facing pages, but the snapshot is single page width
    rect.size.width = NSWidth([page boundsForBox:[self displayBox]]);
    rect.size.height = 200.0;
    
    SKMainWindowController *controller = [[self window] windowController];
    
    [controller showSnapshotAtPageNumber:[[self document] indexForPage:page] forRect:[self convertRect:rect toPage:page] factor:1];
}

- (void)handleAnnotationWillChangeNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [notification object];
    if ([[[annotation page] document] isEqual:[self document]] && [[[notification userInfo] objectForKey:@"key"] isEqualToString:@"bounds"])
        [self setNeedsDisplayForAnnotation:annotation];
}

- (void)handleAnnotationDidChangeNotification:(NSNotification *)notification {
    PDFAnnotation *annotation = [notification object];
    if ([[[annotation page] document] isEqual:[self document]])
        [self setNeedsDisplayForAnnotation:annotation];
}

#pragma mark FullScreen navigation and autohide

- (void)handleWindowWillCloseNotification:(NSNotification *)notification {
    [navWindow orderOut:self];
}

- (void)setHasNavigation:(BOOL)hasNav autohidesCursor:(BOOL)hideCursor {
    hasNavigation = hasNav;
    autohidesCursor = hideCursor;
    
    if (hasNavigation) {
        if (navWindow == nil) {
            navWindow = [[SKNavigationWindow alloc] initWithPDFView:self];
            [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(handleWindowWillCloseNotification:) 
                                                         name: NSWindowWillCloseNotification object: [self window]];
        } else if ([[self window] screen] != [navWindow screen]) {
            [navWindow moveToScreen:[[self window] screen]];
        }
        [navWindow setLevel:[[self window] level]];
    } else if ([navWindow isVisible]) {
        [navWindow orderOut:self];
    }
    [self doAutohide:autohidesCursor || hasNavigation];
}

#pragma mark FullScreen navigation and autohide

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL action = [menuItem action];
    if (action == @selector(changeToolMode:)) {
        [menuItem setState:[self toolMode] == (unsigned)[menuItem tag] ? NSOnState : NSOffState];
        return YES;
    } else {
        return [super validateMenuItem:menuItem];
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [NSUserDefaultsController sharedUserDefaultsController] && [keyPath hasPrefix:@"values."]) {
        NSString *key = [keyPath substringFromIndex:7];
        if ([key isEqualToString:SKReadingBarColorKey] || [key isEqualToString:SKReadingBarTransparencyKey] || [key isEqualToString:SKReadingBarInvertKey]) {
            if (readingBar)
                [self setNeedsDisplay:YES];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

#pragma mark -

@implementation SKPDFView (Private)

- (NSRect)resizeThumbForRect:(NSRect) rect rotation:(int)rotation
{
	NSRect thumb = rect;
    float size = 8.0;
    
    thumb.size = NSMakeSize(size, size);
	
	// Use rotation to determine thumb origin.
	switch (rotation) {
		case 0:
            thumb.origin.x += NSWidth(rect) - NSWidth(thumb);
            break;
		case 90:
            thumb.origin.x += NSWidth(rect) - NSWidth(thumb);
            thumb.origin.y += NSHeight(rect) - NSHeight(thumb);
            break;
		case 180:
            thumb.origin.y += NSHeight(rect) - NSHeight(thumb);
            break;
		case 270:
            break;
	}
	
	return thumb;
}

- (void)transformCGContext:(CGContextRef)context forPage:(PDFPage *)page {
    NSRect boxRect = [page boundsForBox:[self displayBox]];
    
    switch ([page rotation]) {
        case 0:
            CGContextTranslateCTM(context, -NSMinX(boxRect), -NSMinY(boxRect));
            break;
        case 90:
            CGContextRotateCTM(context, - M_PI / 2);
            CGContextTranslateCTM(context, -NSMaxX(boxRect), -NSMinY(boxRect));
            break;
        case 180:
            CGContextRotateCTM(context, M_PI);
            CGContextTranslateCTM(context, -NSMaxX(boxRect), -NSMaxY(boxRect));
            break;
        case 270:
            CGContextRotateCTM(context, M_PI / 2);
            CGContextTranslateCTM(context, -NSMinX(boxRect), -NSMaxY(boxRect));
            break;
    }
}

#pragma mark Autohide timer

- (void)autohideTimerFired:(NSTimer *)aTimer {
    if (NSPointInRect([NSEvent mouseLocation], [navWindow frame]))
        return;
    if (autohidesCursor)
        [NSCursor setHiddenUntilMouseMoves:YES];
    if (hasNavigation)
        [navWindow hide];
}

- (void)doAutohide:(BOOL)flag {
    if (autohideTimer) {
        [autohideTimer invalidate];
        [autohideTimer release];
        autohideTimer = nil;
    }
    if (flag)
        autohideTimer  = [[NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(autohideTimerFired:) userInfo:nil repeats:NO] retain];
}

#pragma mark Event handling

- (PDFDestination *)destinationForEvent:(NSEvent *)theEvent isLink:(BOOL *)isLink {
    NSPoint windowMouseLoc = [theEvent locationInWindow];
    
    NSPoint viewMouseLoc = [self convertPoint:windowMouseLoc fromView:nil];
    PDFPage *page = [self pageForPoint:viewMouseLoc nearest:YES];
    NSPoint pageSpaceMouseLoc = [self convertPoint:viewMouseLoc toPage:page];  
    PDFDestination *dest = [[[PDFDestination alloc] initWithPage:page atPoint:pageSpaceMouseLoc] autorelease];
    BOOL link = NO;
    
    if (([self areaOfInterestForMouse: theEvent] &  kPDFLinkArea) != 0) {
        PDFAnnotation *ann = [page annotationAtPoint:pageSpaceMouseLoc];
        if (ann != NULL && [[ann destination] page]){
            dest = [ann destination];
            link = YES;
        } 
        // Set link = NO if the annotation links outside the document (e.g. for a URL); currently this is only used for the hover window.  We could do something clever like show a URL icon in the hover window (or a WebView!), but for now we'll just ignore these links.
    }
    
    if (isLink) *isLink = link;
    return dest;
}

- (void)moveActiveAnnotationForKey:(unichar)eventChar byAmount:(float)delta {
    NSRect bounds = [activeAnnotation bounds];
    NSRect newBounds = bounds;
    PDFPage *page = [activeAnnotation page];
    NSRect pageBounds = [page boundsForBox:[self displayBox]];
    
    if (eventChar == NSRightArrowFunctionKey) {
        if (NSMaxX(bounds) + delta <= NSMaxX(pageBounds))
            newBounds.origin.x += delta;
    } else if (eventChar == NSLeftArrowFunctionKey) {
        if (NSMinX(bounds) - delta >= NSMinX(pageBounds))
            newBounds.origin.x -= delta;
    } else if (eventChar == NSUpArrowFunctionKey) {
        if (NSMaxY(bounds) + delta <= NSMaxY(pageBounds))
            newBounds.origin.y += delta;
    } else if (eventChar == NSDownArrowFunctionKey) {
        if (NSMinY(bounds) - delta >= NSMinY(pageBounds))
            newBounds.origin.y -= delta;
    }
    if (NSEqualRects(bounds, newBounds) == NO) {
        [activeAnnotation setBounds:newBounds];
        NSString *selString = [[[[activeAnnotation page] selectionForRect:newBounds] string] stringByCollapsingWhitespaceAndNewlinesAndRemovingSurroundingWhitespaceAndNewlines];
        [activeAnnotation setContents:selString];
    }
}

- (BOOL)selectAnnotationWithEvent:(NSEvent *)theEvent {
    PDFAnnotation *newActiveAnnotation = NULL;
    PDFAnnotation *wasActiveAnnotation;
    NSArray *annotations;
    int i;
    NSPoint pagePoint;
    BOOL changed;
    PDFPage *activePage;
    
    // Mouse in display view coordinates.
    mouseDownLoc = [theEvent locationInWindow];
    
    NSPoint mouseDownOnPage = [self convertPoint:mouseDownLoc fromView:nil];
    
    // Page we're on.
    activePage = [self pageForPoint:mouseDownOnPage nearest:YES];
    
    // Get mouse in "page space".
    pagePoint = [self convertPoint:mouseDownOnPage toPage:activePage];
    
    // Hit test for annotation.
    annotations = [activePage annotations];
    i = [annotations count];
    
    while (i-- > 0) {
        NSRect annotationBounds;
        PDFAnnotation *annotationHit = [annotations objectAtIndex:i];
        
        // Hit test annotation.
        annotationBounds = [annotationHit bounds];
        if (NSPointInRect(pagePoint, annotationBounds)) {
            if ([annotationHit isNoteAnnotation]) {
                mouseDownInAnnotation = YES;
                
                if ([annotationHit respondsToSelector:@selector(linesContainPoint:)]) {
                    // markup annotations aren't necessarily defined by a box
                    if ([(SKPDFAnnotationMarkup *)annotationHit linesContainPoint:pagePoint]) {
                        newActiveAnnotation = annotationHit;
                        break;
                    }
                } else {
                    // We count this one.
                    newActiveAnnotation = annotationHit;
                    
                    // Remember click point relative to annotation origin.
                    clickDelta.x = pagePoint.x - annotationBounds.origin.x;
                    clickDelta.y = pagePoint.y - annotationBounds.origin.y;
                    break;
                }
            }
        }
    }
    
    // Flag indicating if activeAnnotation will change. 
    changed = (activeAnnotation != newActiveAnnotation);
    
    // Deselect old annotation when appropriate.
    if (activeAnnotation && changed)
		[self setNeedsDisplayForAnnotation:activeAnnotation];
    
    if (changed) {
        if (editAnnotation)
            [self endAnnotationEdit:self];
        
        // Assign.
        wasActiveAnnotation = activeAnnotation;
        activeAnnotation = (PDFAnnotationFreeText *)newActiveAnnotation;
        
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:2];
        if (wasActiveAnnotation)
            [userInfo setObject:wasActiveAnnotation forKey:@"wasActiveAnnotation"];
        if (activeAnnotation)
            [userInfo setObject:activeAnnotation forKey:@"activeAnnotation"];
        [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewActiveAnnotationDidChangeNotification object:self userInfo:userInfo];
    }
    
    if (newActiveAnnotation == nil) {
        //[super mouseDown:theEvent];
    } else if ([theEvent clickCount] == 2 && [[activeAnnotation type] isEqualToString:@"FreeText"]) {
        // probably we should use the note window for Text annotations
        NSRect editBounds = [activeAnnotation bounds];
        editAnnotation = [[[PDFAnnotationTextWidget alloc] initWithBounds:editBounds] autorelease];
        [editAnnotation setStringValue:[activeAnnotation contents]];
        if ([activeAnnotation respondsToSelector:@selector(font)])
            [editAnnotation setFont:[(PDFAnnotationFreeText *)activeAnnotation font]];
        [editAnnotation setColor:[activeAnnotation color]];
        [[activeAnnotation page] addAnnotation:editAnnotation];
        
        // Start editing
        [super mouseDown:theEvent];
        
    } else if ([theEvent clickCount] == 2 && [[activeAnnotation type] isEqualToString:@"Note"]) {
        
		[[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewAnnotationDoubleClickedNotification object:self 
            userInfo:[NSDictionary dictionaryWithObjectsAndKeys:activeAnnotation, @"annotation", nil]];
        
    } else { 
        // Old (current) annotation location.
        wasBounds = [activeAnnotation bounds];
        
        // Force redisplay.
		[self setNeedsDisplayForAnnotation:activeAnnotation];
        draggingAnnotation = [activeAnnotation isMovable];
        
        // Hit-test for resize box.
        resizingAnnotation = [[activeAnnotation type] isEqualToString:@"Note"] == NO && NSPointInRect(pagePoint, [self resizeThumbForRect:wasBounds rotation:[activePage rotation]]);
    }
    
    return newActiveAnnotation != nil;
}

- (void)dragAnnotationWithEvent:(NSEvent *)theEvent {
    PDFPage *activePage = [activeAnnotation page];
    NSRect newBounds;
    NSRect currentBounds = [activeAnnotation bounds];
    
    if (resizingAnnotation) {
        NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        NSPoint startPoint = [self convertPoint:[self convertPoint:mouseDownLoc fromView:nil] toPage:activePage];
        NSPoint endPt = [self convertPoint:mouseLoc toPage:activePage];
        NSPoint relPoint = NSMakePoint(endPt.x - startPoint.x, endPt.y - startPoint.y);
        newBounds = wasBounds;
        
        // Resize the annotation.
        switch ([activePage rotation]) {
            case 0:
                newBounds.origin.y += relPoint.y;
                newBounds.size.width += relPoint.x;
                newBounds.size.height -= relPoint.y;
                if (NSWidth(newBounds) < 8.0) {
                    newBounds.size.width = 8.0;
                }
                if (NSHeight(newBounds) < 8.0) {
                    newBounds.origin.y += NSHeight(newBounds) - 8.0;
                    newBounds.size.height = 8.0;
                }
                break;
            case 90:
                newBounds.size.width += relPoint.x;
                newBounds.size.height += relPoint.y;
                if (NSWidth(newBounds) < 8.0) {
                    newBounds.size.width = 8.0;
                }
                if (NSHeight(newBounds) < 8.0) {
                    newBounds.size.height = 8.0;
                }
                break;
            case 180:
                newBounds.origin.x += relPoint.x;
                newBounds.size.width -= relPoint.x;
                newBounds.size.height += relPoint.y;
                if (NSWidth(newBounds) < 8.0) {
                    newBounds.origin.x += NSWidth(newBounds) - 8.0;
                    newBounds.size.width = 8.0;
                }
                if (NSHeight(newBounds) < 8.0) {
                    newBounds.size.height = 8.0;
                }
                break;
            case 270:
                newBounds.origin.x += relPoint.x;
                newBounds.origin.y += relPoint.y;
                newBounds.size.width -= relPoint.x;
                newBounds.size.height -= relPoint.y;
                if (NSWidth(newBounds) < 8.0) {
                    newBounds.origin.x += NSWidth(newBounds) - 8.0;
                    newBounds.size.width = 8.0;
                }
                if (NSHeight(newBounds) < 8.0) {
                    newBounds.origin.y += NSHeight(newBounds) - 8.0;
                    newBounds.size.height = 8.0;
                }
                break;
        }
        
        // Keep integer.
        newBounds = NSIntegralRect(newBounds);
    } else {
        // Move annotation.
        [[self documentView] autoscroll:theEvent];
        
        NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        PDFPage *newActivePage = [self pageForPoint:mouseLoc nearest:YES];
        NSRect pageBounds = [newActivePage  boundsForBox:[self displayBox]];
        
        if (newActivePage == nil) {
            // this should never happen, but just to be sure
            newBounds = wasBounds;
        } else {
            if (newActivePage != activePage) {
                // move the annotation to the new page
                [activeAnnotation retain];
                [self setNeedsDisplayForAnnotation:activeAnnotation];
                [activePage removeAnnotation:activeAnnotation];
                [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDidRemoveAnnotationNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:activePage, @"page", activeAnnotation, @"annotation", nil]];                
                [newActivePage addAnnotation:activeAnnotation];
                [activeAnnotation release];
                [[NSNotificationCenter defaultCenter] postNotificationName:SKPDFViewDidAddAnnotationNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:newActivePage, @"page", activeAnnotation, @"annotation", nil]];                
                activePage = newActivePage;
            }
            
            NSPoint endPt = [self convertPoint:mouseLoc toPage:activePage];
            newBounds = currentBounds;
            newBounds.origin.x = roundf(endPt.x - clickDelta.x);
            newBounds.origin.y = roundf(endPt.y - clickDelta.y);
            // constrain bounds inside page bounds
            if (NSMaxX(newBounds) > NSMaxX(pageBounds))
                newBounds.origin.x = NSMaxX(pageBounds) - NSWidth(newBounds);
            if (NSMinX(newBounds) < NSMinX(pageBounds))
                newBounds.origin.x = NSMinX(pageBounds);
            if (NSMaxY(newBounds) > NSMaxY(pageBounds))
                newBounds.origin.y = NSMaxY(pageBounds) - NSHeight(newBounds);
            if (NSMinY(newBounds) < NSMinY(pageBounds))
                newBounds.origin.y = NSMinY(pageBounds);
        }
    }
    
    // Change annotation's location.
    [activeAnnotation setBounds:newBounds];
    
    // Force redraw.
    [self setNeedsDisplayInRect:NSUnionRect(currentBounds, newBounds) ofPage:activePage];
}

- (void)dragWithEvent:(NSEvent *)theEvent {
	NSPoint initialLocation = [theEvent locationInWindow];
	NSRect visibleRect = [[self documentView] visibleRect];
	BOOL keepGoing = YES;
	
    [[NSCursor closedHandCursor] push];
    
	while (keepGoing) {
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
		switch ([theEvent type]) {
			case NSLeftMouseDragged:
            {
				NSPoint	newLocation;
				NSRect	newVisibleRect;
				float	xDelta, yDelta;
				
				newLocation = [theEvent locationInWindow];
				xDelta = initialLocation.x - newLocation.x;
				yDelta = initialLocation.y - newLocation.y;
				if ([self isFlipped])
					yDelta = -yDelta;
				
				newVisibleRect = NSOffsetRect (visibleRect, xDelta, yDelta);
				[[self documentView] scrollRectToVisible: newVisibleRect];
			}
				break;
				
			case NSLeftMouseUp:
				keepGoing = NO;
				break;
				
			default:
				/* Ignore any other kind of event. */
				break;
		} // end of switch (event type)
	} // end of mouse-tracking loop
    
    [NSCursor pop];
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(mouseMoved:) withObject:theEvent afterDelay:0];
}

- (void)dragReadingBarWithEvent:(NSEvent *)theEvent {
	BOOL keepGoing = YES;
    PDFPage *page = [readingBar page];
    NSArray *lineBounds = [page lineBounds];
	
    [[NSCursor closedHandCursor] push];
    
	while (keepGoing) {
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
		switch ([theEvent type]) {
			case NSLeftMouseDragged:
            {
                [[self documentView] autoscroll:theEvent];
                NSPoint mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
                PDFPage *currentPage = [self pageForPoint:mouseLoc nearest:YES];
                
                mouseLoc = [self convertPoint:mouseLoc toPage:currentPage];
                
                if ([currentPage isEqual:page] == NO) {
                    page = currentPage;
                    lineBounds = [page lineBounds];
                }
                
                int i, iMax = [lineBounds count];
                
                for (i = 0; i < iMax; i++) {
                    NSRect rect = [[lineBounds objectAtIndex:i] rectValue];
                    if (NSMinY(rect) <= mouseLoc.y && NSMaxY(rect) >= mouseLoc.y) {
                        [readingBar setPage:page];
                        [readingBar setCurrentLine:i];
                        [self setNeedsDisplay:YES];
                        break;
                    }
                }
				break;
            }
			case NSLeftMouseUp:
				keepGoing = NO;
				break;
				
			default:
				/* Ignore any other kind of event. */
				break;
		} // end of switch (event type)
	} // end of mouse-tracking loop
    
    [NSCursor pop];
    // ??? PDFView's delayed layout seems to reset the cursor to an arrow
    [self performSelector:@selector(mouseMoved:) withObject:theEvent afterDelay:0];
}

- (void)selectSnapshotWithEvent:(NSEvent *)theEvent {
    NSPoint mouseLoc = [theEvent locationInWindow];
	NSPoint startPoint = [[self documentView] convertPoint:mouseLoc fromView:nil];
	NSPoint	currentPoint;
    NSRect selectionRect = {startPoint, NSZeroSize};
    NSRect bounds;
    float minX, maxX, minY, maxY;
    BOOL dragged = NO;
    BOOL keepGoing = YES;
	
    [[self window] discardCachedImage];
    
	while (keepGoing) {
		theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSFlagsChangedMask];
        
        [[self window] restoreCachedImage];
        [[self window] flushWindow];
		
        switch ([theEvent type]) {
			case NSLeftMouseDragged:
				[[self documentView] autoscroll:theEvent];
                mouseLoc = [theEvent locationInWindow];
                dragged = YES;
                
			case NSFlagsChanged:
                currentPoint = [[self documentView] convertPoint:mouseLoc fromView:nil];
				
                minX = fmin(startPoint.x, currentPoint.x);
                maxX = fmax(startPoint.x, currentPoint.x);
                minY = fmin(startPoint.y, currentPoint.y);
                maxY = fmax(startPoint.y, currentPoint.y);
                // center around startPoint when holding down the Shift key
                if ([theEvent modifierFlags] & NSShiftKeyMask) {
                    if (currentPoint.x > startPoint.x)
                        minX -= maxX - minX;
                    else
                        maxX += maxX - minX;
                    if (currentPoint.y > startPoint.y)
                        minY -= maxY - minY;
                    else
                        maxY += maxY - minY;
                }
                // intersect with the bounds, project on the bounds if necessary and allow zero width or height
                bounds = [[self documentView] bounds];
                minX = fmin(fmax(minX, NSMinX(bounds)), NSMaxX(bounds));
                maxX = fmax(fmin(maxX, NSMaxX(bounds)), NSMinX(bounds));
                minY = fmin(fmax(minY, NSMinY(bounds)), NSMaxY(bounds));
                maxY = fmax(fmin(maxY, NSMaxY(bounds)), NSMinY(bounds));
                selectionRect = NSMakeRect(minX, minY, maxX - minX, maxY - minY);
                
                [[self window] cacheImageInRect:NSInsetRect([[self documentView] convertRect:selectionRect toView:nil], -2.0, -2.0)];
                
                [self lockFocus];
                [NSGraphicsContext saveGraphicsState];
                [[NSColor blackColor] set];
                [NSBezierPath strokeRect:NSInsetRect(NSIntegralRect([self convertRect:selectionRect fromView:[self documentView]]), 0.5, 0.5)];
                [NSGraphicsContext restoreGraphicsState];
                [self unlockFocus];
                [[self window] flushWindow];
                
				break;
				
			case NSLeftMouseUp:
				keepGoing = NO;
				break;
				
			default:
				/* Ignore any other kind of event. */
				break;
		} // end of switch (event type)
	} // end of mouse-tracking loop
    
    [[self window] discardCachedImage];
	[self flagsChanged:theEvent];
    
    NSPoint point = [self convertPoint:NSMakePoint(NSMidX(selectionRect), NSMidY(selectionRect)) fromView:[self documentView]];
    PDFPage *page = [self pageForPoint:point nearest:YES];
    NSRect rect = [self convertRect:selectionRect fromView:[self documentView]];
    int factor = 1;
    
    if (dragged == NO) {
        
        BOOL isLink = NO;
        PDFDestination *dest = [self destinationForEvent:theEvent isLink:&isLink];
        
        if (isLink) {
            page = [dest page];
            point = [self convertPoint:[dest point] fromPage:page];
            point.y -= 100.0;
        }
        
        rect.origin.x = [self convertPoint:[page boundsForBox:[self displayBox]].origin fromPage:page].x;
        rect.origin.y = point.y - 100.0;
        // rowSizeForPage: allows for facing pages, but the snapshot is single page width
        rect.size.width = NSWidth([page boundsForBox:[self displayBox]]);
        rect.size.height = 200.0;
        
    } else {
    
        bounds = [self convertRect:[[self documentView] bounds] fromView:[self documentView]];
        
        if (NSWidth(rect) < 40.0 && NSHeight(rect) < 40.0)
            factor = 3;
        else if (NSWidth(rect) < 60.0 && NSHeight(rect) < 60.0)
            factor = 2;
        
        if (factor * NSWidth(rect) < 60.0) {
            rect = NSInsetRect(rect, 0.5 * (NSWidth(rect) - 60.0 / factor), 0.0);
            if (NSMinX(rect) < NSMinX(bounds))
                rect.origin.x = NSMinX(bounds);
            if (NSMaxX(rect) > NSMaxX(bounds))
                rect.origin.x = NSMaxX(bounds) - NSWidth(rect);
        }
        if (factor * NSHeight(rect) < 60.0) {
            rect = NSInsetRect(rect, 0.5 * (NSHeight(rect) - 60.0 / factor), 0.0);
            if (NSMinY(rect) < NSMinY(bounds))
                rect.origin.y = NSMinY(bounds);
            if (NSMaxX(rect) > NSMaxY(bounds))
                rect.origin.y = NSMaxY(bounds) - NSHeight(rect);
        }
    }
    
    SKMainWindowController *controller = [[self window] windowController];
    
    [controller showSnapshotAtPageNumber:[[self document] indexForPage:page] forRect:[self convertRect:rect toPage:page] factor:factor];
}

#define MAG_RECT_1 NSMakeRect(-150.0, -100.0, 300.0, 200.0)
#define MAG_RECT_2 NSMakeRect(-300.0, -200.0, 600.0, 400.0)

- (void)magnifyWithEvent:(NSEvent *)theEvent {
	NSPoint mouseLoc = [theEvent locationInWindow];
    NSScrollView *scrollView = [[self documentView] enclosingScrollView];
    NSView *documentView = [scrollView documentView];
    NSView *clipView = [scrollView contentView];
	NSRect originalBounds = [documentView bounds];
    NSRect visibleRect = [clipView convertRect:[clipView visibleRect] toView: nil];
    NSRect magBounds, magRect, outlineRect;
	float magScale = 1.0;
    BOOL mouseInside = NO;
	int currentLevel = 0;
    int originalLevel = [theEvent clickCount]; // this should be at least 1
	BOOL postNotification = [documentView postsBoundsChangedNotifications];
    NSBezierPath *path;
    
	[documentView setPostsBoundsChangedNotifications: NO];
	
	[[self window] discardCachedImage]; // make sure not to use the cached image
        
	while ([theEvent type] != NSLeftMouseUp) {
        
        // set up the currentLevel and magScale
        if ([theEvent type] == NSLeftMouseDown || [theEvent type] == NSFlagsChanged) {	
            unsigned modifierFlags = [theEvent modifierFlags];
            currentLevel = originalLevel + ((modifierFlags & NSAlternateKeyMask) ? 1 : 0);
            if (currentLevel > 2) {
                [[self window] restoreCachedImage];
                [[self window] cacheImageInRect:visibleRect];
            }
            magScale = (modifierFlags & NSCommandKeyMask) ? 4.0 : (modifierFlags & NSControlKeyMask) ? 1.5 : 2.5;
            if ((modifierFlags & NSShiftKeyMask) == 0)
                magScale = 1.0 / magScale;
            [self flagsChanged:theEvent]; // update the cursor
        }
        
        // get Mouse location and check if it is with the view's rect
        if ([theEvent type] == NSLeftMouseDragged)
            mouseLoc = [theEvent locationInWindow];
        
        if ([self mouse:mouseLoc inRect:visibleRect]) {
            if (mouseInside == NO) {
                mouseInside = YES;
                [NSCursor hide];
            }
            // define rect for magnification in window coordinate
            if (currentLevel > 2) { 
                magRect = visibleRect;
            } else {
                magRect = currentLevel == 2 ? MAG_RECT_2 : MAG_RECT_1;
                magRect.origin.x += mouseLoc.x;
                magRect.origin.y += mouseLoc.y;
                // restore the cached image in order to clear the rect
                [[self window] restoreCachedImage];
                [[self window] cacheImageInRect:NSIntersectionRect(NSInsetRect(magRect, -2.0, -2.0), visibleRect)];
            }
            
            // resize bounds around mouseLoc
            magBounds.origin = [documentView convertPoint:mouseLoc fromView:nil];
            magBounds = NSMakeRect(magBounds.origin.x + magScale * (originalBounds.origin.x - magBounds.origin.x), 
                                   magBounds.origin.y + magScale * (originalBounds.origin.y - magBounds.origin.y), 
                                   magScale * NSWidth(originalBounds), magScale * NSHeight(originalBounds));
            
            [documentView setBounds:magBounds];
            [self displayRect:[self convertRect:NSInsetRect(magRect, 1.0, 1.0) fromView:nil]]; // this flushes the buffer
            [documentView setBounds:originalBounds];
            
            [clipView lockFocus];
            NSGraphicsContext *ctxt = [NSGraphicsContext currentContext];
            [ctxt saveGraphicsState];
            outlineRect = NSInsetRect(NSIntegralRect([clipView convertRect:magRect fromView:nil]), 0.5, 0.5);
            path = [NSBezierPath bezierPathWithRect:outlineRect];
            [path setLineWidth:1.0];
            [[NSColor blackColor] set];
            [path stroke];
            [ctxt flushGraphics];
            [ctxt restoreGraphicsState];
            [clipView unlockFocus];
            
        } else { // mouse is not in the rect
            // show cursor 
            if (mouseInside == YES) {
                mouseInside = NO;
                [NSCursor unhide];
                // restore the cached image in order to clear the rect
                [[self window] restoreCachedImage];
                [[self window] flushWindowIfNeeded];
            }
            if ([theEvent type] == NSLeftMouseDragged)
                [documentView autoscroll:theEvent];
            if (currentLevel > 2)
                [[self window] cacheImageInRect:visibleRect];
            else
                [[self window] discardCachedImage];
        }
        theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSFlagsChangedMask];
	}
	
	[[self window] restoreCachedImage];
	[[self window] flushWindowIfNeeded];
	[NSCursor unhide];
	[documentView setPostsBoundsChangedNotifications:postNotification];
	[self flagsChanged:theEvent]; // update cursor
}

@end

#pragma mark -

@implementation SKReadingBar

- (id)init {
    if (self = [super init]) {
        page = nil;
        lineBounds = nil;
        currentLine = -1;
    }
    return self;
}

- (void)dealloc {
    [page release];
    [lineBounds release];
    [super dealloc];
}

- (PDFPage *)page {
    return page;
}

- (void)setPage:(PDFPage *)newPage {
    if (page != newPage) {
        [page release];
        page = [newPage retain];
        [lineBounds release];
        lineBounds = [[page lineBounds] retain];
        currentLine = -1;
    } 
}

- (int)currentLine {
    return currentLine;
}

- (void)setCurrentLine:(int)lineIndex {
    currentLine = lineIndex;
}

- (unsigned int)numberOfLines {
    return [lineBounds count];
}

- (NSRect)currentBounds {
    if (page == nil || currentLine == -1)
        return NSZeroRect;
    return [[lineBounds objectAtIndex:currentLine] rectValue];
}

- (NSRect)currentBoundsForBox:(PDFDisplayBox)box {
    if (page == nil || currentLine == -1)
        return NSZeroRect;
    NSRect rect = [self currentBounds];
    NSRect bounds = [page boundsForBox:box];
    rect.origin.x = NSMinX(bounds);
    rect.size.width = NSWidth(bounds);
    return rect;
}

- (BOOL)goToNextLine {
    BOOL didMove = NO;
    if (currentLine < (int)[lineBounds count] - 1) {
        ++currentLine;
        didMove = YES;
    } else if ([self goToNextPage]) {
        didMove = YES;
    }
    return didMove;
}

- (BOOL)goToPreviousLine {
    BOOL didMove = NO;
    if (currentLine == -1 && [lineBounds count])
        currentLine = [lineBounds count];
    if (currentLine > 0) {
        --currentLine;
        didMove =  YES;
    } else if ([self goToPreviousPage]) {
        currentLine = [lineBounds count] - 1;
        didMove = YES;
    }
    return didMove;
}

- (BOOL)goToNextPage {
    BOOL didMove = NO;
    PDFDocument *doc = [page document];
    int i = [doc indexForPage:page], iMax = [doc pageCount];
    
    while (++i < iMax) {
        PDFPage *nextPage = [doc pageAtIndex:i];
        NSArray *lines = [nextPage lineBounds];
        if ([lines count]) {
            [page release];
            page = [nextPage retain];
            [lineBounds release];
            lineBounds = [lines retain];
            currentLine = 0;
            didMove = YES;
            break;
        }
    }
    return didMove;
}

- (BOOL)goToPreviousPage {
    BOOL didMove = NO;
    PDFDocument *doc = [page document];
    int i = [doc indexForPage:page];
    
    while (i-- > 0) {
        PDFPage *prevPage = [doc pageAtIndex:i];
        NSArray *lines = [prevPage lineBounds];
        if ([lines count]) {
            [page release];
            page = [prevPage retain];
            [lineBounds release];
            lineBounds = [lines retain];
            currentLine = 0;
            didMove = YES;
            break;
        }
    }
    return didMove;
}

@end