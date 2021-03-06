//
//  SKLineWell.m
//  Skim
//
//  Created by Christiaan Hofman on 6/22/07.
/*
 This software is Copyright (c) 2007-2018
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

#import "SKLineWell.h"
#import "SKLineInspector.h"
#import "NSGraphics_SKExtensions.h"
#import "NSBezierPath_SKExtensions.h"
#import "NSImage_SKExtensions.h"
#import "NSView_SKExtensions.h"

NSString *SKPasteboardTypeLineStyle = @"net.sourceforge.skim-app.pasteboard.line-style";

NSString *SKLineWellLineWidthKey = @"lineWidth";
NSString *SKLineWellStyleKey = @"style";
NSString *SKLineWellDashPatternKey = @"dashPattern";
NSString *SKLineWellStartLineStyleKey = @"startLineStyle";
NSString *SKLineWellEndLineStyleKey = @"endLineStyle";

#define DISPLAYSTYLE_KEY @"lwFlags.displayStyle"
#define ACTIVE_KEY @"active"
#define ACTION_KEY @"action"
#define TARGET_KEY @"target"

#define SKLineWellWillBecomeActiveNotification @"SKLineWellWillBecomeActiveNotification"
#define EXCLUSIVE_KEY @"exclusive"

@implementation SKLineWell

@synthesize lineWidth, style, dashPattern, startLineStyle, endLineStyle;
@dynamic isActive, canActivate, displayStyle;

+ (void)initialize {
    SKINITIALIZE;
    
    [self exposeBinding:SKLineWellLineWidthKey];
    [self exposeBinding:SKLineWellStyleKey];
    [self exposeBinding:SKLineWellDashPatternKey];
    [self exposeBinding:SKLineWellStartLineStyleKey];
    [self exposeBinding:SKLineWellEndLineStyleKey];
}

- (Class)valueClassForBinding:(NSString *)binding {
    if ([binding isEqualToString:SKLineWellDashPatternKey])
        return [NSArray class];
    else
        return [NSNumber class];
}

- (void)commonInit {
    lwFlags.canActivate = 1;
    lwFlags.existsActiveLineWell = 0;
    
    [self registerForDraggedTypes:[NSArray arrayWithObjects:SKPasteboardTypeLineStyle, nil]];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        lineWidth = 1.0;
        style = kPDFBorderStyleSolid;
        dashPattern = nil;
        startLineStyle = kPDFLineStyleNone;
        endLineStyle = kPDFLineStyleNone;
        lwFlags.displayStyle = SKLineWellDisplayStyleLine;
        lwFlags.active = 0;
        lwFlags.canActivate = 0;
        lwFlags.existsActiveLineWell = 0;
        
        target = nil;
        action = NULL;
        
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (self) {
        lineWidth = [decoder decodeDoubleForKey:SKLineWellLineWidthKey];
        style = [decoder decodeIntegerForKey:SKLineWellStyleKey];
        dashPattern = [[decoder decodeObjectForKey:SKLineWellDashPatternKey] retain];
        startLineStyle = [decoder decodeIntegerForKey:SKLineWellStartLineStyleKey];
        endLineStyle = [decoder decodeIntegerForKey:SKLineWellEndLineStyleKey];
        lwFlags.displayStyle = [decoder decodeIntegerForKey:DISPLAYSTYLE_KEY];
        lwFlags.active = [decoder decodeBoolForKey:ACTIVE_KEY];
        action = NSSelectorFromString([decoder decodeObjectForKey:ACTION_KEY]);
        target = [decoder decodeObjectForKey:TARGET_KEY];
        [self commonInit];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeDouble:lineWidth forKey:SKLineWellLineWidthKey];
    [coder encodeInteger:style forKey:SKLineWellStyleKey];
    [coder encodeObject:dashPattern forKey:SKLineWellDashPatternKey];
    [coder encodeInteger:startLineStyle forKey:SKLineWellStartLineStyleKey];
    [coder encodeInteger:endLineStyle forKey:SKLineWellEndLineStyleKey];
    [coder encodeInteger:(NSInteger)(lwFlags.displayStyle) forKey:DISPLAYSTYLE_KEY];
    [coder encodeBool:(BOOL)(lwFlags.active) forKey:ACTIVE_KEY];
    [coder encodeObject:NSStringFromSelector(action) forKey:ACTION_KEY];
    [coder encodeConditionalObject:target forKey:TARGET_KEY];
}

- (void)dealloc {
    SKENSURE_MAIN_THREAD(
        [self unbind:SKLineWellLineWidthKey];
        [self unbind:SKLineWellStyleKey];
        [self unbind:SKLineWellDashPatternKey];
        [self unbind:SKLineWellStartLineStyleKey];
        [self unbind:SKLineWellEndLineStyleKey];
    );
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SKDESTROY(dashPattern);
    [super dealloc];
}

- (BOOL)isOpaque{ return YES; }

- (BOOL)acceptsFirstResponder { return [self canActivate]; }

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent { return [self canActivate]; }

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    [self deactivate];
    [super viewWillMoveToWindow:newWindow];
}

- (NSBezierPath *)path {
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSRect bounds = [self bounds];
    
    if ([self displayStyle] == SKLineWellDisplayStyleLine) {
        CGFloat offset = 0.5 * lineWidth - floor(0.5 * lineWidth);
        NSPoint startPoint = NSMakePoint(NSMinX(bounds) + ceil(0.5 * NSHeight(bounds)), round(NSMidY(bounds)) - offset);
        NSPoint endPoint = NSMakePoint(NSMaxX(bounds) - ceil(0.5 * NSHeight(bounds)), round(NSMidY(bounds)) - offset);
        
        switch (startLineStyle) {
            case kPDFLineStyleNone:
                break;
            case kPDFLineStyleSquare:
                [path appendBezierPathWithRect:NSMakeRect(startPoint.x - 1.5 * lineWidth, startPoint.y - 1.5 * lineWidth, 3 * lineWidth, 3 * lineWidth)];
                break;
            case kPDFLineStyleCircle:
                [path appendBezierPathWithOvalInRect:NSMakeRect(startPoint.x - 1.5 * lineWidth, startPoint.y - 1.5 * lineWidth, 3 * lineWidth, 3 * lineWidth)];
                break;
            case kPDFLineStyleDiamond:
                [path moveToPoint:NSMakePoint(startPoint.x - 1.5 * lineWidth, startPoint.y)];
                [path lineToPoint:NSMakePoint(startPoint.x,  startPoint.y + 1.5 * lineWidth)];
                [path lineToPoint:NSMakePoint(startPoint.x + 1.5 * lineWidth, startPoint.y)];
                [path lineToPoint:NSMakePoint(startPoint.x,  startPoint.y - 1.5 * lineWidth)];
                [path closePath];
                break;
            case kPDFLineStyleOpenArrow:
                [path moveToPoint:NSMakePoint(startPoint.x + 3.0 * lineWidth, startPoint.y - 1.5 * lineWidth)];
                [path lineToPoint:NSMakePoint(startPoint.x,  startPoint.y)];
                [path lineToPoint:NSMakePoint(startPoint.x + 3.0 * lineWidth, startPoint.y + 1.5 * lineWidth)];
                break;
            case kPDFLineStyleClosedArrow:
                [path moveToPoint:NSMakePoint(startPoint.x + 3.0 * lineWidth, startPoint.y - 1.5 * lineWidth)];
                [path lineToPoint:NSMakePoint(startPoint.x,  startPoint.y)];
                [path lineToPoint:NSMakePoint(startPoint.x + 3.0 * lineWidth, startPoint.y + 1.5 * lineWidth)];
                [path closePath];
                break;
        }
        
        [path moveToPoint:startPoint];
        [path lineToPoint:endPoint];
        
        switch (endLineStyle) {
            case kPDFLineStyleNone:
                break;
            case kPDFLineStyleSquare:
                [path appendBezierPathWithRect:NSMakeRect(endPoint.x - 1.5 * lineWidth, endPoint.y - 1.5 * lineWidth, 3 * lineWidth, 3 * lineWidth)];
                break;
            case kPDFLineStyleCircle:
                [path appendBezierPathWithOvalInRect:NSMakeRect(endPoint.x - 1.5 * lineWidth, endPoint.y - 1.5 * lineWidth, 3 * lineWidth, 3 * lineWidth)];
                break;
            case kPDFLineStyleDiamond:
                [path moveToPoint:NSMakePoint(endPoint.x + 1.5 * lineWidth, endPoint.y)];
                [path lineToPoint:NSMakePoint(endPoint.x,  endPoint.y + 1.5 * lineWidth)];
                [path lineToPoint:NSMakePoint(endPoint.x - 1.5 * lineWidth, endPoint.y)];
                [path lineToPoint:NSMakePoint(endPoint.x,  endPoint.y - 1.5 * lineWidth)];
                [path closePath];
                break;
            case kPDFLineStyleOpenArrow:
                [path moveToPoint:NSMakePoint(endPoint.x - 3.0 * lineWidth, endPoint.y + 1.5 * lineWidth)];
                [path lineToPoint:NSMakePoint(endPoint.x,  endPoint.y)];
                [path lineToPoint:NSMakePoint(endPoint.x - 3.0 * lineWidth, endPoint.y - 1.5 * lineWidth)];
                break;
            case kPDFLineStyleClosedArrow:
                [path moveToPoint:NSMakePoint(endPoint.x - 3.0 * lineWidth, endPoint.y + 1.5 * lineWidth)];
                [path lineToPoint:NSMakePoint(endPoint.x,  endPoint.y)];
                [path lineToPoint:NSMakePoint(endPoint.x - 3.0 * lineWidth, endPoint.y - 1.5 * lineWidth)];
                [path closePath];
                break;
        }
    } else if ([self displayStyle] == SKLineWellDisplayStyleSimpleLine) {
        CGFloat offset = 0.5 * lineWidth - floor(0.5 * lineWidth);
        [path moveToPoint:NSMakePoint(NSMinX(bounds) + ceil(0.5 * NSHeight(bounds)), round(NSMidY(bounds)) - offset)];
        [path lineToPoint:NSMakePoint(NSMaxX(bounds) - ceil(0.5 * NSHeight(bounds)), round(NSMidY(bounds)) - offset)];
    } else if ([self displayStyle] == SKLineWellDisplayStyleRectangle) {
        CGFloat inset = 7.0 + 0.5 * lineWidth;
        [path appendBezierPathWithRect:NSInsetRect(bounds, inset, inset)];
    } else {
        CGFloat inset = 7.0 + 0.5 * lineWidth;
        [path appendBezierPathWithOvalInRect:NSInsetRect(bounds, inset, inset)];
    }
    
    [path setLineWidth:lineWidth];
    
    if (style == kPDFBorderStyleDashed)
        [path setDashPattern:dashPattern];
    
    return path;
}

- (void)drawRect:(NSRect)rect {
    NSRect bounds = [self bounds];
    
    SKDrawTextFieldBezel(bounds, self);
    
    if ([self isActive]) {
        [NSGraphicsContext saveGraphicsState];
        [[NSColor selectedControlColor] setFill];
        NSRectFillUsingOperation(bounds, NSCompositePlusDarker);
        [NSGraphicsContext restoreGraphicsState];
    }
    if ([self isHighlighted]) {
        [NSGraphicsContext saveGraphicsState];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] setFill];
        NSFrameRectWithWidthUsingOperation([self bounds], 1.0, NSCompositePlusDarker);
        [NSGraphicsContext restoreGraphicsState];
    }
    
    if (lineWidth > 0.0) {
        [NSGraphicsContext saveGraphicsState];
        [[NSBezierPath bezierPathWithRect:NSInsetRect(bounds, 2.0, 2.0)] addClip];
        [[NSColor blackColor] setStroke];
        [[self path] stroke];
        [NSGraphicsContext restoreGraphicsState];
    }
    
    if ([self refusesFirstResponder] == NO && [NSApp isActive] && [[self window] isKeyWindow] && [[self window] firstResponder] == self) {
        [NSGraphicsContext saveGraphicsState];
        NSSetFocusRingStyle(NSFocusRingOnly);
        NSRectFill(bounds);
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (NSImage *)dragImage {
    NSRect bounds = [self bounds];
    NSBezierPath *path = lineWidth > 0.0 ? [self path] : nil;
    CGFloat scale = [self backingScale];
    
    NSImage *image = [NSImage bitmapImageWithSize:bounds.size scale:scale drawingHandler:^(NSRect rect){
        CGContextSetAlpha([[NSGraphicsContext currentContext] graphicsPort], 0.7);
        [[NSColor darkGrayColor] setFill];
        NSRectFill(NSInsetRect(rect, 1.0, 1.0));
        [[NSColor controlBackgroundColor] setFill];
        NSRectFill(NSInsetRect(rect, 2.0, 2.0));
        [[NSColor blackColor] setStroke];
        [path stroke];
    }];
    
    return image;
}

- (void)changedValueForKey:(NSString *)key {
    if ([self isActive])
        [[SKLineInspector sharedLineInspector] setValue:[self valueForKey:key] forKey:key];
    [self setNeedsDisplay:YES];
}

- (void)takeValueForKey:(NSString *)key from:(id)object {
    [self setValue:[object valueForKey:key] forKey:key];
    NSDictionary *info = [self infoForBinding:key];
    [[info objectForKey:NSObservedObjectKey] setValue:[self valueForKey:key] forKeyPath:[info objectForKey:NSObservedKeyPathKey]];
}

- (void)mouseDown:(NSEvent *)theEvent {
    if ([self isEnabled]) {
        [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
        [self setNeedsDisplay:YES];
        NSUInteger modifiers = [theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
		BOOL keepOn = YES;
        while (keepOn) {
			theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
			switch ([theEvent type]) {
				case NSLeftMouseDragged:
                {
                    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithDouble:lineWidth], SKLineWellLineWidthKey, [NSNumber numberWithInteger:style], SKLineWellStyleKey, dashPattern, SKLineWellDashPatternKey, nil];
                    if ([self displayStyle] == SKLineWellDisplayStyleLine) {
                        [dict setObject:[NSNumber numberWithInteger:startLineStyle] forKey:SKLineWellStartLineStyleKey];
                        [dict setObject:[NSNumber numberWithInteger:endLineStyle] forKey:SKLineWellEndLineStyleKey];
                    }
                    
                    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
                    [pboard clearContents];
                    [pboard setPropertyList:dict forType:SKPasteboardTypeLineStyle];
                    
                    NSRect bounds = [self bounds];
                    [self dragImage:[self dragImage] at:bounds.origin offset:NSZeroSize event:theEvent pasteboard:pboard source:self slideBack:YES];
                    
                    keepOn = NO;
                    break;
				}
                case NSLeftMouseUp:
                    if ([self isActive])
                        [self deactivate];
                    else
                        [self activate:(modifiers & NSShiftKeyMask) == 0];
                    keepOn = NO;
                    break;
				default:
                    break;
            }
        }
    }
}

- (void)performClick:(id)sender {
    if ([self isEnabled]) {
        if ([self isActive])
            [self deactivate];
        else
            [self activate:YES];
    }
}

- (void)existsActiveLineWell {
    lwFlags.existsActiveLineWell = 1;
}

- (void)lineWellWillBecomeActive:(NSNotification *)notification {
    id sender = [notification object];
    if (sender != self && [self isActive]) {
        if ([[[notification userInfo] valueForKey:EXCLUSIVE_KEY] boolValue])
            [self deactivate];
        else
            [sender existsActiveLineWell];
    }
}

- (void)lineInspectorWindowWillClose:(NSNotification *)notification {
    [self deactivate];
}

- (void)activate:(BOOL)exclusive {
    if ([self canActivate]) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        SKLineInspector *inspector = [SKLineInspector sharedLineInspector];
        
        lwFlags.existsActiveLineWell = 0;
        
        [nc postNotificationName:SKLineWellWillBecomeActiveNotification object:self
                        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:exclusive], EXCLUSIVE_KEY, nil]];
        
        if (lwFlags.existsActiveLineWell) {
            [self takeValueForKey:SKLineWellLineWidthKey from:inspector];
            [self takeValueForKey:SKLineWellDashPatternKey from:inspector];
            [self takeValueForKey:SKLineWellStyleKey from:inspector];
            if ([self displayStyle] == SKLineWellDisplayStyleLine) {
                [self takeValueForKey:SKLineWellStartLineStyleKey from:inspector];
                [self takeValueForKey:SKLineWellEndLineStyleKey from:inspector];
            }
        } else {
            [inspector setLineWidth:[self lineWidth]];
            [inspector setDashPattern:[self dashPattern]];
            [inspector setStyle:[self style]];
            if ([self displayStyle] == SKLineWellDisplayStyleLine) {
                [inspector setStartLineStyle:[self startLineStyle]];
                [inspector setEndLineStyle:[self endLineStyle]];
            }
        }
        [[inspector window] orderFront:self];
        
        [nc addObserver:self selector:@selector(lineWellWillBecomeActive:)
                   name:SKLineWellWillBecomeActiveNotification object:nil];
        [nc addObserver:self selector:@selector(lineInspectorWindowWillClose:)
                   name:NSWindowWillCloseNotification object:[inspector window]];
        [nc addObserver:self selector:@selector(lineInspectorLineAttributeChanged:)
                   name:SKLineInspectorLineAttributeDidChangeNotification object:inspector];
        
        lwFlags.active = 1;
        
        [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
        [self setNeedsDisplay:YES];
    }
}

- (void)deactivate {
    if ([self isActive]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        lwFlags.active = 0;
        [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
        [self setNeedsDisplay:YES];
    }
}

#pragma mark Accessors

- (SEL)action { return action; }

- (void)setAction:(SEL)newAction { action = newAction; }

- (id)target { return target; }

- (void)setTarget:(id)newTarget { target = newTarget; }

- (BOOL)isActive {
    return lwFlags.active;
}

- (BOOL)canActivate {
    return lwFlags.canActivate;
}

- (void)setCanActivate:(BOOL)flag {
    if (lwFlags.canActivate != flag) {
        lwFlags.canActivate = flag;
        if ([self isActive] && lwFlags.canActivate == 0)
            [self deactivate];
    }
}

- (BOOL)isHighlighted {
    return lwFlags.highlighted;
}

- (void)setHighlighted:(BOOL)flag {
    if (lwFlags.highlighted != flag) {
        lwFlags.highlighted = flag;
    }
}

- (SKLineWellDisplayStyle)displayStyle {
    return lwFlags.displayStyle;
}

- (void)setDisplayStyle:(SKLineWellDisplayStyle)newStyle {
    if (lwFlags.displayStyle != newStyle) {
        lwFlags.displayStyle = newStyle;
        [self setNeedsDisplay:YES];
    }
}

- (void)setLineWidth:(CGFloat)width {
    if (fabs(lineWidth - width) > 0.00001) {
        lineWidth = width;
        [self changedValueForKey:SKLineWellLineWidthKey];
    }
}

- (void)setStyle:(PDFBorderStyle)newStyle {
    if (newStyle != style) {
        style = newStyle;
        [self changedValueForKey:SKLineWellStyleKey];
    }
}

- (void)setDashPattern:(NSArray *)pattern {
    if (NSIsControllerMarker(pattern)) pattern = nil;
    if ([pattern isEqualToArray:dashPattern] == NO && (pattern || dashPattern)) {
        [dashPattern release];
        dashPattern = [pattern copy];
        [self changedValueForKey:SKLineWellDashPatternKey];
    }
}

- (void)setStartLineStyle:(PDFLineStyle)newStyle {
    if (newStyle != startLineStyle) {
        startLineStyle = newStyle;
        [self changedValueForKey:SKLineWellStartLineStyleKey];
    }
}

- (void)setEndLineStyle:(PDFLineStyle)newStyle {
    if (newStyle != endLineStyle) {
        endLineStyle = newStyle;
        [self changedValueForKey:SKLineWellEndLineStyleKey];
    }
}

- (void)setNilValueForKey:(NSString *)key {
    if ([key isEqualToString:SKLineWellLineWidthKey] || [key isEqualToString:SKLineWellStyleKey] || 
        [key isEqualToString:SKLineWellStartLineStyleKey] || [key isEqualToString:SKLineWellEndLineStyleKey]) {
        [self setValue:[NSNumber numberWithInteger:0] forKey:key];
    } else {
        [super setNilValueForKey:key];
    }
}

#pragma mark Notification handlers

- (void)lineInspectorLineAttributeChanged:(NSNotification *)notification {
    SKLineInspector *inspector = [notification object];
    NSString *key = nil;
    switch ([inspector currentLineChangeAction]) {
        case SKLineWidthLineChangeAction:
            key = SKLineWellLineWidthKey;
            break;
        case SKStyleLineChangeAction:
            key = SKLineWellStyleKey;
            break;
        case SKDashPatternLineChangeAction:
            key = SKLineWellDashPatternKey;
            break;
        case SKStartLineStyleLineChangeAction:
            if ([self displayStyle] == SKLineWellDisplayStyleLine)
                key = SKLineWellStartLineStyleKey;
            break;
        case SKEndLineStyleLineChangeAction:
            if ([self displayStyle] == SKLineWellDisplayStyleLine)
                key = SKLineWellEndLineStyleKey;
            break;
        case SKNoLineChangeAction:
            break;
    }
    if (key) {
        [self takeValueForKey:key from:inspector];
        [self sendAction:[self action] to:[self target]];
    }
}

#pragma mark NSDraggingSource protocol 

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    return NSDragOperationGeneric;
}

#pragma mark NSDraggingDestination protocol 

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    if ([self isEnabled] && [sender draggingSource] != self && [[sender draggingPasteboard] canReadItemWithDataConformingToTypes:[NSArray arrayWithObjects:SKPasteboardTypeLineStyle, nil]]) {
        [self setHighlighted:YES];
        [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
        [self setNeedsDisplay:YES];
        return NSDragOperationEvery;
    } else
        return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    if ([self isEnabled] && [sender draggingSource] != self && [[sender draggingPasteboard] canReadItemWithDataConformingToTypes:[NSArray arrayWithObjects:SKPasteboardTypeLineStyle, nil]]) {
        [self setHighlighted:NO];
        [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
    return [self isEnabled] && [sender draggingSource] != self && [[sender draggingPasteboard] canReadItemWithDataConformingToTypes:[NSArray arrayWithObjects:SKPasteboardTypeLineStyle, nil]];
} 

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender{
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    [pboard types];
    
    NSDictionary *dict = [pboard propertyListForType:SKPasteboardTypeLineStyle];
    
    if ([dict objectForKey:SKLineWellLineWidthKey])
        [self takeValueForKey:SKLineWellLineWidthKey from:dict];
    if ([dict objectForKey:SKLineWellStyleKey])
        [self takeValueForKey:SKLineWellStyleKey from:dict];
    [self takeValueForKey:SKLineWellDashPatternKey from:dict];
    if ([self displayStyle] == SKLineWellDisplayStyleLine) {
        if ([dict objectForKey:SKLineWellStartLineStyleKey])
            [self takeValueForKey:SKLineWellStartLineStyleKey from:dict];
        if ([dict objectForKey:SKLineWellEndLineStyleKey])
            [self takeValueForKey:SKLineWellEndLineStyleKey from:dict];
    }
    [self sendAction:[self action] to:[self target]];
    
    [self setHighlighted:NO];
    [self setKeyboardFocusRingNeedsDisplayInRect:[self bounds]];
    [self setNeedsDisplay:YES];
    
	return dict != nil;
}

#pragma mark Accessibility

- (NSArray *)accessibilityAttributeNames {
    static NSArray *attributes = nil;
    if (attributes == nil) {
        attributes = [[NSArray alloc] initWithObjects:
	    NSAccessibilityRoleAttribute,
	    NSAccessibilityRoleDescriptionAttribute,
        NSAccessibilityValueAttribute,
        NSAccessibilityTitleAttribute,
        NSAccessibilityHelpAttribute,
	    NSAccessibilityFocusedAttribute,
	    NSAccessibilityParentAttribute,
	    NSAccessibilityWindowAttribute,
	    NSAccessibilityTopLevelUIElementAttribute,
	    NSAccessibilityPositionAttribute,
	    NSAccessibilitySizeAttribute,
	    nil];
    }
    return attributes;
}

- (id)accessibilityAttributeValue:(NSString *)attribute {
    if ([attribute isEqualToString:NSAccessibilityRoleAttribute]) {
        return NSAccessibilityCheckBoxRole;
    } else if ([attribute isEqualToString:NSAccessibilityRoleDescriptionAttribute]) {
        return NSAccessibilityRoleDescription(NSAccessibilityCheckBoxRole, nil);
    } else if ([attribute isEqualToString:NSAccessibilityValueAttribute]) {
        return [NSNumber numberWithInteger:[self isActive]];
    } else if ([attribute isEqualToString:NSAccessibilityTitleAttribute]) {
        return [NSString stringWithFormat:@"%@ %ld", NSLocalizedString(@"line width", @"Accessibility description"), (long)[self lineWidth]];
    } else if ([attribute isEqualToString:NSAccessibilityHelpAttribute]) {
        return [self toolTip];
    } else if ([attribute isEqualToString:NSAccessibilityFocusedAttribute]) {
        // Just check if the app thinks we're focused.
        id focusedElement = [NSApp accessibilityAttributeValue:NSAccessibilityFocusedUIElementAttribute];
        return [NSNumber numberWithBool:[focusedElement isEqual:self]];
    } else if ([attribute isEqualToString:NSAccessibilityParentAttribute]) {
        return NSAccessibilityUnignoredAncestor([self superview]);
    } else if ([attribute isEqualToString:NSAccessibilityWindowAttribute]) {
        // We're in the same window as our parent.
        return [NSAccessibilityUnignoredAncestor([self superview]) accessibilityAttributeValue:NSAccessibilityWindowAttribute];
    } else if ([attribute isEqualToString:NSAccessibilityTopLevelUIElementAttribute]) {
        // We're in the same top level element as our parent.
        return [NSAccessibilityUnignoredAncestor([self superview]) accessibilityAttributeValue:NSAccessibilityTopLevelUIElementAttribute];
    } else if ([attribute isEqualToString:NSAccessibilityPositionAttribute]) {
        return [NSValue valueWithPoint:[[self window] convertBaseToScreen:[self convertPoint:[self bounds].origin toView:nil]]];
    } else if ([attribute isEqualToString:NSAccessibilitySizeAttribute]) {
        return [NSValue valueWithSize:[self convertSize:[self bounds].size toView:nil]];
    } else {
        return nil;
    }
}

- (BOOL)accessibilityIsAttributeSettable:(NSString *)attribute {
    if ([attribute isEqualToString:NSAccessibilityFocusedAttribute]) {
        return [self canActivate];
    } else {
        return NO;
    }
}

- (void)accessibilitySetValue:(id)value forAttribute:(NSString *)attribute {
    if ([attribute isEqualToString:NSAccessibilityFocusedAttribute]) {
        [[self window] makeFirstResponder:self];
    }
}


// actions

- (NSArray *)accessibilityActionNames {
    return [NSArray arrayWithObject:NSAccessibilityPressAction];
}

- (NSString *)accessibilityActionDescription:(NSString *)anAction {
    return NSAccessibilityActionDescription(anAction);
}

- (void)accessibilityPerformAction:(NSString *)anAction {
    if ([anAction isEqualToString:NSAccessibilityPressAction])
        [self performClick:self];
}


// misc

- (BOOL)accessibilityIsIgnored {
    return NO;
}

- (id)accessibilityHitTest:(NSPoint)point {
    return NSAccessibilityUnignoredAncestor(self);
}

- (id)accessibilityFocusedUIElement {
    return NSAccessibilityUnignoredAncestor(self);
}

@end
