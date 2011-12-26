//
//  SKRemoteStateWindow.m
//  Skim
//
//  Created by Christiaan Hofman on 12/3/07.
/*
 This software is Copyright (c) 2007-2008
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

#import "SKRemoteStateWindow.h"
#import "NSGeometry_SKExtensions.h"
#import "NSBezierPath_BDSKExtensions.h"


@interface SKRemoteStateView : NSView {
    int remoteState;
}
- (int)remoteState;
- (void)setRemoteState:(int)newRemoteState;
@end


@implementation SKRemoteStateWindow

+ (id)sharedRemoteStateWindow {
    static id sharedRemoteStateWindow = nil;
    if (sharedRemoteStateWindow == nil)
        sharedRemoteStateWindow = [[SKRemoteStateWindow alloc] init];
    return sharedRemoteStateWindow;
}

- (id)init {
    NSRect contentRect = SKRectFromCenterAndSize(NSZeroPoint, SKMakeSquareSize(60.0));
    if (self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO]) {
        [self setIgnoresMouseEvents:YES];
        [self setReleasedWhenClosed:NO];
		[self setBackgroundColor:[NSColor clearColor]];
        [self setAlphaValue:0.95];
		[self setOpaque:NO];
        [self setDisplaysWhenScreenProfileChanges:NO];
        [self setLevel:NSStatusWindowLevel];
        [self setContentView:[[[SKRemoteStateView alloc] init] autorelease]];
    }
    return self;
}

- (BOOL)canBecomeKeyWindow { return NO; }

- (BOOL)canBecomeMainWindow { return NO; }
    
- (void)animationDidEnd:(NSAnimation *)anAnimation {  
    [animation release];
    animation = nil;
    [self orderOut:self];
    [self setAlphaValue:1.0];
}

- (void)animationDidStop:(NSAnimation *)anAnimation {
    [animation release];
    animation = nil;
    [self orderOut:self];
    [self setAlphaValue:1.0];
}

- (void)fadeOut:(id)sender {
    [timer invalidate];
    [timer release];
    timer = nil;
    
    NSDictionary *fadeOutDict = [[NSDictionary alloc] initWithObjectsAndKeys:self, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
    animation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:fadeOutDict, nil]];
    [fadeOutDict release];
    [animation setDuration:1.0];
    [animation setAnimationBlockingMode:NSAnimationNonblocking];
    [animation setDelegate:self];
    [animation startAnimation];
}

- (void)showWithType:(int)remoteState atPoint:(NSPoint)point timeout:(NSTimeInterval)timeout {
    [timer invalidate];
    [timer release];
    timer = nil;
    
    [animation stopAnimation];
    [animation release];
    animation = nil;
    
    [self setFrame:SKRectFromCenterAndSize(point, SKMakeSquareSize(60.0)) display:NO animate:NO];
    [(SKRemoteStateView *)[self contentView] setRemoteState:remoteState];
    
    [self orderFrontRegardless];
    timer = [[NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(fadeOut:) userInfo:nil repeats:NO] retain];
}

+ (void)showWithType:(int)remoteState atPoint:(NSPoint)point timeout:(NSTimeInterval)timeout {
    [[[self class] sharedRemoteStateWindow] showWithType:remoteState atPoint:point timeout:timeout];
}

@end

#pragma mark -

@implementation SKRemoteStateView

- (int)remoteState {
    return remoteState;
}

- (void)setRemoteState:(int)newRemoteState {
    remoteState = newRemoteState;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
    NSRect bounds = [self bounds];
    NSPoint center = SKCenterPoint(bounds);
    
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] setFill];
    [NSBezierPath fillRoundRectInRect:[self bounds] radius:10.0];
    
    NSBezierPath *path = nil;
    
    if (remoteState == SKRemoteStateResize) {
        
        path = [NSBezierPath bezierPathWithRoundRectInRect:NSInsetRect(bounds, 20.0, 20.0) radius:3.0];
        [path appendBezierPath:[NSBezierPath bezierPathWithRect:NSInsetRect(bounds, 24.0, 24.0)]];
        
        NSBezierPath *arrow = [NSBezierPath bezierPath];
        [arrow moveToPoint:NSMakePoint(NSMinX(bounds) + 10.0, NSMinY(bounds) + 10.0)];
        [arrow relativeLineToPoint:NSMakePoint(6.0, 0.0)];
        [arrow relativeLineToPoint:NSMakePoint(-2.0, 2.0)];
        [arrow relativeLineToPoint:NSMakePoint(2.0, 2.0)];
        [arrow relativeLineToPoint:NSMakePoint(2.0, -2.0)];
        [arrow relativeLineToPoint:NSMakePoint(0.0, 6.0)];
        [arrow relativeLineToPoint:NSMakePoint(-6.0, 0.0)];
        [arrow relativeLineToPoint:NSMakePoint(2.0, -2.0)];
        [arrow relativeLineToPoint:NSMakePoint(-2.0, -2.0)];
        [arrow relativeLineToPoint:NSMakePoint(-2.0, 2.0)];
        [arrow closePath];
        
        NSAffineTransform *transform = [[[NSAffineTransform alloc] init] autorelease];
        [transform translateXBy:center.x yBy:center.y];
        [transform rotateByDegrees:90.0];
        [transform translateXBy:-center.x yBy:-center.y];
        [path appendBezierPath:arrow];
        [arrow transformUsingAffineTransform:transform];
        [path appendBezierPath:arrow];
        [arrow transformUsingAffineTransform:transform];
        [path appendBezierPath:arrow];
        [arrow transformUsingAffineTransform:transform];
        [path appendBezierPath:arrow];
        
        arrow = [NSBezierPath bezierPath];
        [arrow moveToPoint:NSMakePoint(NSMinX(bounds) + 5.0, NSMidY(bounds))];
        [arrow relativeLineToPoint:NSMakePoint(10.0, 5.0)];
        [arrow relativeLineToPoint:NSMakePoint(0.0, -10.0)];
        [arrow closePath];
        [path appendBezierPath:arrow];
        [transform translateXBy:center.x yBy:center.y];
        [transform rotateByDegrees:90.0];
        [transform translateXBy:-center.x yBy:-center.y];
        [arrow transformUsingAffineTransform:transform];
        [path appendBezierPath:arrow];
        
        [path setWindingRule:NSEvenOddWindingRule];
        
    } else if (remoteState == SKRemoteStateScroll) {
        
        path = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(bounds, 8.0, 8.0)];
        [path appendBezierPath:[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(bounds, 9.0, 9.0)]];
        [path appendBezierPath:[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(bounds, 25.0, 25.0)]];
        
        NSBezierPath *arrow = [NSBezierPath bezierPath];
        [arrow moveToPoint:NSMakePoint(NSMidX(bounds), NSMinY(bounds) + 12.0)];
        [arrow relativeLineToPoint:NSMakePoint(7.0, 7.0)];
        [arrow relativeLineToPoint:NSMakePoint(-14.0, 0.0)];
        [arrow closePath];
        
        NSAffineTransform *transform = [[[NSAffineTransform alloc] init] autorelease];
        [transform translateXBy:center.x yBy:center.y];
        [transform rotateByDegrees:90.0];
        [transform translateXBy:-center.x yBy:-center.y];
        [path appendBezierPath:arrow];
        [arrow transformUsingAffineTransform:transform];
        [path appendBezierPath:arrow];
        [arrow transformUsingAffineTransform:transform];
        [path appendBezierPath:arrow];
        [arrow transformUsingAffineTransform:transform];
        [path appendBezierPath:arrow];
        
        [path setWindingRule:NSEvenOddWindingRule];
        
    }
    
    [[NSColor colorWithCalibratedWhite:1.0 alpha:1.0] setFill];
    [path fill];
}

@end