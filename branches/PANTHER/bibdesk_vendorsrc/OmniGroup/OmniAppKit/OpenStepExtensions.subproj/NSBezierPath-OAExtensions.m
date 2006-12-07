// Copyright 2000-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "NSBezierPath-OAExtensions.h"

#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/SourceRelease_2005-10-03/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSBezierPath-OAExtensions.m 66043 2005-07-25 21:17:05Z kc $")


@interface NSBezierPath (PrivateOAExtensions)
NSString *_roundedStringForPoint(NSPoint point);

NSPoint _getCurvePoint(NSPoint*c, float u, float offset);
NSPoint _getLinePoint(NSPoint*a, float position, float offset);
NSRect _curveBounds(NSPoint *curve);
// wants 4 coefficients and 3 roots
// returns the number of solutions
int _solveCubic(double *c, double *roots);
void _parameterizeLine(NSPoint *coefficients, NSPoint startPoint, NSPoint endPoint);
void _parameterizeCurve(NSPoint *coefficients, NSPoint startPoint, NSPoint endPoint, NSPoint controlPoint1, NSPoint controlPoint2);

- (BOOL)_curvedIntersection:(float *)length time:(float *)time curve:(NSPoint *)c line:(NSPoint *)a;

BOOL _straightLineIntersectsRect(NSPoint *a, NSRect rect);
void _splitCurve(NSPoint*c, NSPoint*left, NSPoint*right); 
BOOL _curvedLineIntersectsRect(NSPoint *c, NSRect rect, float tolerance);

- (BOOL)_curvedLineHit:(NSPoint)point startPoint:(NSPoint)startPoint endPoint:(NSPoint)endPoint controlPoint1:(NSPoint)controlPoint1 controlPoint2:(NSPoint)controlPoint2 position:(float *)position padding:(float)padding;
- (BOOL)_straightLineIntersection:(float *)length time:(float *)time segment:(NSPoint *)s line:(NSPoint *)l;
- (BOOL)_straightLineHit:(NSPoint)startPoint :(NSPoint)endPoint :(NSPoint)point  :(float *)position padding:(float)padding;
- (int)_segmentHitByPoint:(NSPoint)point position:(float *)position padding:(float)padding;
- (NSPoint)_endPointForSegment:(int)i;

@end


@implementation NSBezierPath (OAExtensions)

- (BOOL)strokesSimilarlyIgnoringEndcapsToPath:(NSBezierPath *)otherPath;
{
    return [[self countedSetOfEncodedStrokeSegments] isEqual:[otherPath countedSetOfEncodedStrokeSegments]];
}

- (NSCountedSet *)countedSetOfEncodedStrokeSegments;
{
    NSPoint unlikelyPoint = {-10275847.33894, -10275847.33894};
    NSPoint firstPoint = unlikelyPoint, currentPoint = NSZeroPoint;

    NSCountedSet *countedSetOfEncodedStrokeSegments = [NSCountedSet set];
    int elementIndex, elementCount = [self elementCount];
    for(elementIndex=0; elementIndex<elementCount; elementIndex++) {
        NSPoint points[3];
        NSBezierPathElement element = [self elementAtIndex:elementIndex associatedPoints:points];
        NSString *currentSegmentString = nil;

        switch(element) {
            case NSMoveToBezierPathElement:
                currentPoint = points[0];
                if (NSEqualPoints(firstPoint, unlikelyPoint))
                    firstPoint = currentPoint;
                break;
            case NSClosePathBezierPathElement:
            case NSLineToBezierPathElement: {
                NSString *firstPointString, *lastPointString;

                NSPoint lineToPoint;
                if (element == NSClosePathBezierPathElement)
                    lineToPoint = firstPoint;
                else
                    lineToPoint = points[0];

                if (NSEqualPoints(currentPoint, lineToPoint))
                    break;
                firstPointString = _roundedStringForPoint(currentPoint);
                lastPointString = _roundedStringForPoint(lineToPoint);
                if ([firstPointString compare:lastPointString] == NSOrderedDescending)
                    SWAP(firstPointString, lastPointString);
                currentSegmentString = [NSString stringWithFormat:@"%@%@", firstPointString, lastPointString];
                currentPoint = lineToPoint;
                break;
            }
            case NSCurveToBezierPathElement: {
                NSString *firstPointString, *lastPointString;
                NSString *controlPoint1String, *controlPoint2String;
                NSComparisonResult comparisonResult;

                firstPointString = _roundedStringForPoint(currentPoint);
                controlPoint1String = _roundedStringForPoint(points[0]);
                controlPoint2String = _roundedStringForPoint(points[1]);
                lastPointString = _roundedStringForPoint(points[2]);
                comparisonResult = [firstPointString compare:lastPointString];
                if (comparisonResult == NSOrderedDescending || (comparisonResult == NSOrderedSame && [controlPoint1String compare:controlPoint2String] == NSOrderedDescending)) {
                    SWAP(firstPointString, lastPointString);
                    SWAP(controlPoint1String, controlPoint2String);
                }
                [countedSetOfEncodedStrokeSegments addObject:[NSString stringWithFormat:@"%@%@%@%@", firstPointString, controlPoint1String, controlPoint2String, lastPointString]];
                currentPoint = points[2];
                break;
            }
        }
        if (currentSegmentString != nil)
            [countedSetOfEncodedStrokeSegments addObject:currentSegmentString];
    }

    return countedSetOfEncodedStrokeSegments;
}


//

- (BOOL)intersectsRect:(NSRect)rect
{
    int count = [self elementCount];
    int i;
    NSPoint points[3];
    NSPoint startPoint;
    NSPoint currentPoint;
    NSPoint line[2];
    NSPoint curve[4];
    int element;
    BOOL needANewStartPoint;

    if (count == 0)
        return NO;

    element = [self elementAtIndex:0 associatedPoints:points];
    if (element != NSMoveToBezierPathElement) {
        return NO;  // must start with a moveTo
    }

    startPoint = currentPoint = points[0];
    needANewStartPoint = NO;
    
    for(i=1;i<count;i++) {
        element = [self elementAtIndex:i associatedPoints:points];
        switch(element) {
            case NSMoveToBezierPathElement:
                currentPoint = points[0];
                if (needANewStartPoint) {
                    startPoint = currentPoint;
                    needANewStartPoint = NO;
                }
                break;
            case NSClosePathBezierPathElement:
                _parameterizeLine(line, currentPoint,startPoint);
                if (_straightLineIntersectsRect(line, rect)) {
                    return YES;
                }
                currentPoint = startPoint;
                needANewStartPoint = YES;
                break;
            case NSLineToBezierPathElement:
                _parameterizeLine(line, currentPoint,points[0]);
                if (_straightLineIntersectsRect(line, rect)){
                    return YES;
                }
                currentPoint = points[0];
                break;
            case NSCurveToBezierPathElement: {
                _parameterizeCurve(curve, currentPoint, points[2], points[0], points[1]);
                if (_curvedLineIntersectsRect(curve, rect, [self lineWidth]+1)) {
                    return YES;
                }
                currentPoint = points[2];
                break;
            }
        }
    }

    return NO;
}

- (BOOL)intersectionWithLine:(NSPoint *)result lineStart:(NSPoint)lineStart lineEnd:(NSPoint)lineEnd
{
    NSPoint curveCoefficients[4];
    NSPoint points[3];
    NSPoint segmentCoefficients[2];
    NSPoint lineCoefficients[2];
    NSPoint startPoint;
    NSPoint currentPoint;
    float minimumLength = 1.0;
    int element;
    int count = [self elementCount];
    int i;
    BOOL needANewStartPoint;

    if (count == 0)
        return NO;
        
    element = [self elementAtIndex:0 associatedPoints:points];

    if (element != NSMoveToBezierPathElement) 
        return NO;  // must start with a moveTo

    _parameterizeLine(lineCoefficients,lineStart,lineEnd);
    
    startPoint = currentPoint = points[0];
    needANewStartPoint = NO;
    
    for(i=1;i<count;i++) {
        float ignored, currentLength = 1.0;

        element = [self elementAtIndex:i associatedPoints:points];
        switch(element) {
            case NSMoveToBezierPathElement:
                currentPoint = points[0];
                if (needANewStartPoint) {
                    startPoint = currentPoint;
                    needANewStartPoint = NO;
                }
                break;
            case NSClosePathBezierPathElement:
                _parameterizeLine(segmentCoefficients,currentPoint,startPoint);
                if ([self _straightLineIntersection:&currentLength time:&ignored segment:segmentCoefficients line:lineCoefficients]) {
                    if (currentLength < minimumLength) {
                        minimumLength = currentLength;
                    }
                }
                currentPoint = startPoint;
                needANewStartPoint = YES;
                break;
            case NSLineToBezierPathElement:
                _parameterizeLine(segmentCoefficients, currentPoint, points[0]);
                if ([self _straightLineIntersection:&currentLength time:&ignored segment:segmentCoefficients line:lineCoefficients]) {
                    if (currentLength < minimumLength) {
                        minimumLength = currentLength;
                    }
                }
                currentPoint = points[0];
                break;
            case NSCurveToBezierPathElement:
                _parameterizeCurve(curveCoefficients, currentPoint, points[2], points[0], points[1]);
                if ([self _curvedIntersection:&currentLength time:&ignored curve:curveCoefficients line:lineCoefficients]) {
                    if (currentLength < minimumLength) {
                        minimumLength = currentLength;
                    }
                }
                currentPoint = points[2];
                break;
        }
    }

    if (minimumLength < 1.0) {
        result->x = lineCoefficients[0].x + minimumLength * lineCoefficients[1].x;
        result->y = lineCoefficients[0].y + minimumLength * lineCoefficients[1].y;
        return YES;
    }
    return NO;
}

- (void)addIntersectionsWithLineStart:(NSPoint)lineStart lineEnd:(NSPoint)lineEnd toArray:(NSMutableArray *)array;
{
    NSPoint points[3];
    NSPoint segmentCoefficients[2];
    NSPoint curveCoefficients[4];
    NSPoint lineCoefficients[2];
    NSPoint startPoint;
    NSPoint currentPoint;
    int element;
    int count = [self elementCount];
    int i;
    BOOL needANewStartPoint;
    float ignored, time;
    float positionPerSegment = 1.0 / (float)(count - 1);
    
    if (count == 0)
        return;
        
    element = [self elementAtIndex:0 associatedPoints:points];

    if (element != NSMoveToBezierPathElement)
        return;  // must start with a moveTo

    _parameterizeLine(lineCoefficients,lineStart,lineEnd);
    
    startPoint = currentPoint = points[0];
    needANewStartPoint = NO;
    
    for(i=1;i<count;i++) {
        element = [self elementAtIndex:i associatedPoints:points];
        switch(element) {
            case NSMoveToBezierPathElement:
                currentPoint = points[0];
                if (needANewStartPoint) {
                    startPoint = currentPoint;
                    needANewStartPoint = NO;
                }
                break;
            case NSClosePathBezierPathElement:
                _parameterizeLine(segmentCoefficients,currentPoint,startPoint);
                if ([self _straightLineIntersection:&ignored time:&time segment:segmentCoefficients line:lineCoefficients]) {
                    float position = positionPerSegment * ((float)i - 1 + time);
                    if (position >= 0.0 && position <= 1.0)
                        [array addObject:[NSNumber numberWithFloat:position]];
                }
                currentPoint = startPoint;
                needANewStartPoint = YES;
                break;
            case NSLineToBezierPathElement:
                _parameterizeLine(segmentCoefficients, currentPoint, points[0]);
                if ([self _straightLineIntersection:&ignored time:&time segment:segmentCoefficients line:lineCoefficients]) {
                    float position = positionPerSegment * ((float)i - 1 + time);
                    if (position >= 0.0 && position <= 1.0)
                        [array addObject:[NSNumber numberWithFloat:position]];
                }
                currentPoint = points[0];
                break;
            case NSCurveToBezierPathElement:
                _parameterizeCurve(curveCoefficients, currentPoint, points[2], points[0], points[1]);
                if ([self _curvedIntersection:&ignored time:&time curve:curveCoefficients line:lineCoefficients]) {
                    float position = positionPerSegment * ((float)i - 1 + time);
                    if (position >= 0.0 && position <= 1.0)
                        [array addObject:[NSNumber numberWithFloat:position]];
                }
                currentPoint = points[2];
                break;
        }
    }
}

void splitBezierCurveTo(NSPoint *c, float t, NSPoint *l, NSPoint *r)
{
    NSPoint mid;
    float oneMinusT = 1.0 - t;
    
    l[0] = c[0];
    r[3] = c[3];
    l[1].x = c[0].x * oneMinusT + c[1].x * t;
    l[1].y = c[0].y * oneMinusT + c[1].y * t;
    r[2].x = c[2].x * oneMinusT + c[3].x * t;
    r[2].y = c[2].y * oneMinusT + c[3].y * t;
    mid.x = c[1].x * oneMinusT + c[2].x * t;
    mid.y = c[1].y * oneMinusT + c[2].y * t;
    l[2].x = l[1].x * oneMinusT + mid.x * t;
    l[2].y = l[1].y * oneMinusT + mid.y * t;
    r[1].x = mid.x * oneMinusT + r[2].x * t;
    r[1].y = mid.y * oneMinusT + r[2].y * t;
    l[3].x = l[2].x * oneMinusT + r[1].x * t;
    l[3].y = l[2].y * oneMinusT + r[1].y * t;
    r[0] = l[3];
}

NSRect _bezierCurveToBounds(NSPoint *c)
{
    NSPoint low, high;
    
    low.x = MIN(MIN(c[0].x, c[1].x), MIN(c[2].x, c[3].x));
    low.y = MIN(MIN(c[0].y, c[1].y), MIN(c[2].y, c[3].y));
    high.x = MAX(MAX(c[0].x, c[1].x), MAX(c[2].x, c[3].x));
    high.y = MAX(MAX(c[0].y, c[1].y), MAX(c[2].y, c[3].y));
    
    return NSMakeRect(low.x, low.y, high.x - low.x, high.y - low.y);
}

- (void)_addCurveToCurveIntersections:(NSMutableArray *)array onCurve:(NSPoint *)c otherCurve:(NSPoint *)o bezierLowPosition:(float)low bezierInterval:(float)interval cubicLowPosition:(float)cubicLow cubicInterval:(float)cubicInterval originalCubic:(NSPoint *)originalCurve;
{
    float ignored, time;
    NSPoint lineCoefficients[2];
    NSPoint curveCoefficients[4];

    if (!NSIntersectsRect(_bezierCurveToBounds(c), _bezierCurveToBounds(o)))
        return;
    if ([self _straightLineHit:o[0] :o[3] :o[1] :&ignored padding:1.0] && [self _straightLineHit:o[0] :o[3] :o[2] :&ignored padding:1.0]) {
        // other is close enough to being a line
        _parameterizeLine(lineCoefficients, o[0], o[3]);
        _parameterizeCurve(curveCoefficients, c[0], c[3], c[1], c[2]);
        if ([self _curvedIntersection:&ignored time:&time curve:curveCoefficients line:lineCoefficients]) {
            float position = low + time * interval;
            if (position >= 0.0 && position <= 1.0)
                [array addObject:[NSNumber numberWithFloat:position]];
        }
    } else {
        NSPoint cl[4], cr[4], ol[4], or[4];
        
        splitBezierCurveTo(c, 0.5, cl, cr);
        splitBezierCurveTo(o, 0.5, ol, or);
        interval /= 2.0;
        [self _addCurveToCurveIntersections:array onCurve:cl otherCurve:ol bezierLowPosition:low bezierInterval:interval cubicLowPosition:cubicLow cubicInterval:cubicInterval originalCubic:originalCurve];
        [self _addCurveToCurveIntersections:array onCurve:cl otherCurve:or bezierLowPosition:low bezierInterval:interval cubicLowPosition:cubicLow cubicInterval:cubicInterval originalCubic:originalCurve];
        low += interval;
        [self _addCurveToCurveIntersections:array onCurve:cr otherCurve:ol bezierLowPosition:low bezierInterval:interval cubicLowPosition:cubicLow cubicInterval:cubicInterval originalCubic:originalCurve];
        [self _addCurveToCurveIntersections:array onCurve:cr otherCurve:or bezierLowPosition:low bezierInterval:interval cubicLowPosition:cubicLow cubicInterval:cubicInterval originalCubic:originalCurve];
    }    
}

- (void)addIntersectionsWithCurveTo:(NSPoint *)curve toArray:(NSMutableArray *)array;
{
    NSPoint points[3];
    NSPoint segmentCoefficients[2];
    NSPoint curveCoefficients[4];
    NSPoint startPoint;
    NSPoint currentPoint;
    NSPoint intersectionPoint;
    int element;
    int count = [self elementCount];
    int i;
    BOOL needANewStartPoint;
    float ignored, time;
    float positionPerSegment = 1.0 / (float)(count - 1);
    
    if (count == 0)
        return;
        
    element = [self elementAtIndex:0 associatedPoints:points];

    if (element != NSMoveToBezierPathElement)
        return;  // must start with a moveTo

    startPoint = currentPoint = points[0];
    needANewStartPoint = NO;
    _parameterizeCurve(curveCoefficients, curve[0], curve[3], curve[1], curve[2]);
    
    for(i=1;i<count;i++) {
        element = [self elementAtIndex:i associatedPoints:points];
        switch(element) {
            case NSMoveToBezierPathElement:
                currentPoint = points[0];
                if (needANewStartPoint) {
                    startPoint = currentPoint;
                    needANewStartPoint = NO;
                }
                break;
            case NSClosePathBezierPathElement:
                _parameterizeLine(segmentCoefficients,currentPoint,startPoint);
                if ([self _curvedIntersection:&ignored time:&time curve:curveCoefficients line:segmentCoefficients]) {
                    intersectionPoint = _getCurvePoint(curveCoefficients, time, 0.0);
                    if ([self _straightLineHit:currentPoint :startPoint :intersectionPoint :&time padding:1.0]) {
                        float position = positionPerSegment * ((float)i - 1 + time);
                        if (position >= 0.0 && position <= 1.0)
                            [array addObject:[NSNumber numberWithFloat:position]];
                    }
                }
                currentPoint = startPoint;
                needANewStartPoint = YES;
                break;
            case NSLineToBezierPathElement:
                _parameterizeLine(segmentCoefficients, currentPoint, points[0]);
                if ([self _curvedIntersection:&ignored time:&time curve:curveCoefficients line:segmentCoefficients]) {
                    intersectionPoint = _getCurvePoint(curveCoefficients, time, 0.0);
                    if ([self _straightLineHit:currentPoint :points[0] :intersectionPoint :&time padding:1.0]) {
                        float position = positionPerSegment * ((float)i - 1 + time);
                        if (position >= 0.0 && position <= 1.0)
                            [array addObject:[NSNumber numberWithFloat:position]];
                    }
                }
                currentPoint = points[0];
                break;
            case NSCurveToBezierPathElement: {
                NSPoint thisCurve[4];
                float lowPosition = positionPerSegment * ((float)i - 1);
                thisCurve[0] = currentPoint;
                thisCurve[1] = points[0];
                thisCurve[2] = points[1];
                thisCurve[3] = points[2];
                [self _addCurveToCurveIntersections:array onCurve:thisCurve otherCurve:curve bezierLowPosition:lowPosition bezierInterval:positionPerSegment cubicLowPosition:lowPosition cubicInterval:positionPerSegment originalCubic:thisCurve];
                currentPoint = points[2];
                break;
            }
        }
    }
}

- (NSArray *)intersectionsWithPath:(NSBezierPath *)other;
{    
    NSMutableArray *array = [NSMutableArray array];
    NSPoint points[3];
    NSPoint startPoint;
    NSPoint currentPoint;
    int element;
    int count = [other elementCount];
    int i;
    BOOL needANewStartPoint;

    if (count == 0)
        return NO;

    element = [other elementAtIndex:0 associatedPoints:points];

    if (element != NSMoveToBezierPathElement) 
        return nil;  // must start with a moveTo
        
    startPoint = currentPoint = points[0];
    needANewStartPoint = NO;
    
    for(i=1;i<count;i++) {
        element = [other elementAtIndex:i associatedPoints:points];
        switch(element) {
            case NSMoveToBezierPathElement:
                currentPoint = points[0];
                if (needANewStartPoint) {
                    startPoint = currentPoint;
                    needANewStartPoint = NO;
                }
                break;
            case NSClosePathBezierPathElement:
                [self addIntersectionsWithLineStart:currentPoint lineEnd:startPoint toArray:array];
                currentPoint = startPoint;
                needANewStartPoint = YES;
                break;
            case NSLineToBezierPathElement:
                [self addIntersectionsWithLineStart:currentPoint lineEnd:points[0] toArray:array];
                currentPoint = points[0];
                break;
            case NSCurveToBezierPathElement: {
                NSPoint curve[4];
                
                curve[0] = currentPoint;
                curve[1] = points[0];
                curve[2] = points[1];
                curve[3] = points[2];
                [self addIntersectionsWithCurveTo:curve toArray:array];
                currentPoint = points[2];
                break;
                
            }
        }
    }
	
	// sort and unique the results
	[array sortUsingSelector:@selector(compare:)];
	i = [array count] - 1;
	float last = [[array lastObject] floatValue];
	while (i-- > 0) {
		float this = [[array objectAtIndex:i] floatValue];
		if (ABS(this-last) < 0.005)
			[array removeObjectAtIndex:i];
		last = this;
	}
	if ([array count] >= 2 && [[array objectAtIndex:0] floatValue] < 0.0025 && [[array lastObject] floatValue] > 0.9975)
		[array removeLastObject];
    return array;
}

- (int)segmentHitByPoint:(NSPoint)point padding:(float)padding {
    float position = 0;
    return [self _segmentHitByPoint:point position:&position padding:padding];
}

- (int)segmentHitByPoint:(NSPoint)point  {
    float position = 0;
    return [self _segmentHitByPoint:point position:&position padding:5.0];
}

- (BOOL)isStrokeHitByPoint:(NSPoint)point padding:(float)padding
{
    int segment = [self segmentHitByPoint:point padding:padding];
    return (segment != 0);
}

- (BOOL)isStrokeHitByPoint:(NSPoint)point
{
    int segment = [self segmentHitByPoint:point padding:5.0];
    return (segment != 0);
}

//

// From Scott Anguish's Cocoa book, I believe.
- (void)appendBezierPathWithRoundedRectangle:(NSRect)aRect withRadius:(float)radius;
{
    NSPoint topMid = NSMakePoint(NSMidX(aRect), NSMaxY(aRect));
    NSPoint topLeft = NSMakePoint(NSMinX(aRect), NSMaxY(aRect));
    NSPoint topRight = NSMakePoint(NSMaxX(aRect), NSMaxY(aRect));
    NSPoint bottomRight = NSMakePoint(NSMaxX(aRect), NSMinY(aRect));

    [self moveToPoint:topMid];
    [self appendBezierPathWithArcFromPoint:topLeft toPoint:aRect.origin radius:radius];
    [self appendBezierPathWithArcFromPoint:aRect.origin toPoint:bottomRight radius:radius];
    [self appendBezierPathWithArcFromPoint:bottomRight toPoint:topRight radius:radius];
    [self appendBezierPathWithArcFromPoint:topRight toPoint:topLeft radius:radius];
    [self closePath];
}

//

- (NSPoint)getPointForPosition:(float)position andOffset:(float)offset {
    NSPoint coefficients[4];
    NSPoint points[3];
    int segment;
    float segmentPosition;
    int segmentCount = [self elementCount] - 1;
    NSPoint startPoint;
    int element;

    if (position < 0)
        position = 0;
    if (position > 1)
        position = 1;
    if (position == 1) {
        segment = segmentCount-1;
        segmentPosition = 1;
    } else {
        segment = (int) floor(position*segmentCount);
        segmentPosition = position * segmentCount - segment;
    }

    startPoint = [self _endPointForSegment:segment];
    element = [self elementAtIndex:segment+1 associatedPoints:points];
    switch(element) {
        case NSClosePathBezierPathElement:
        {
            int past = segment;
            [self elementAtIndex:0 associatedPoints:points];
            NSPoint bezierEndPoint = points[0];
            while(past--) {
                // Back up until we find the last closepath
                // then step forward to hopefully find a moveto
                element = [self elementAtIndex:past associatedPoints:points];
                if (element == NSClosePathBezierPathElement) {
                    element = [self elementAtIndex:past+1 associatedPoints:points];
                    if (element == NSMoveToBezierPathElement)
                        bezierEndPoint = points[0];
                    break;
                }
            }
            _parameterizeLine(coefficients,startPoint,bezierEndPoint);
            return _getLinePoint(coefficients, segmentPosition, offset);
        }
        case NSMoveToBezierPathElement:// PENDING: should probably skip this one
        case NSLineToBezierPathElement: {
            _parameterizeLine(coefficients,startPoint,points[0]);
            return _getLinePoint(coefficients, segmentPosition, offset);
        }
        case NSCurveToBezierPathElement: {
            _parameterizeCurve(coefficients, startPoint, points[2], points[0], points[1]);
            return _getCurvePoint(coefficients, segmentPosition, offset);
        }
    }
    return startPoint; // ack
}

- (float)getPositionForPoint:(NSPoint)point {
    float position =0;
    int segment = [self _segmentHitByPoint:point position:&position padding:5.0];
    if (segment) {
        position = position + (segment - 1);
        position /= ([self elementCount] - 1);
        return (position);
    }
    return 0.5; // EEK!
}

- (float)getNormalForPosition:(float)position {
    // PENDING: could be made vastly more efficient
    NSPoint point = [self getPointForPosition:position andOffset:0];
    NSPoint normalPoint = [self getPointForPosition:position andOffset:100];
    NSPoint delta;
    delta.x = normalPoint.x - point.x;
    delta.y = normalPoint.y - point.y;
    return atan2(delta.y, delta.x) * 180.0/M_PI;
}


// load and save

- (NSMutableDictionary *)propertyListRepresentation;
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSMutableArray *segments = [NSMutableArray array];
    NSPoint points[3];
    NSBezierPathElement element;
    int count = [self elementCount];
    int i;

    for(i=0;i<count;i++) {
        NSMutableDictionary *segment = [NSMutableDictionary dictionary];
        element = [self elementAtIndex:i associatedPoints:points];
        
        switch(element) {
            case NSMoveToBezierPathElement:
                [segment setObject:NSStringFromPoint(points[0]) forKey:@"point"];
                [segment setObject:@"MOVETO" forKey:@"element"];
                break;
            case NSClosePathBezierPathElement:
                [segment setObject:@"CLOSE" forKey:@"element"];
                break;
            case NSLineToBezierPathElement:
                [segment setObject:NSStringFromPoint(points[0]) forKey:@"point"];
                [segment setObject:@"LINETO" forKey:@"element"];
                break;
            case NSCurveToBezierPathElement:
                [segment setObject:NSStringFromPoint(points[2]) forKey:@"point"];
                [segment setObject:NSStringFromPoint(points[0]) forKey:@"control1"];
                [segment setObject:NSStringFromPoint(points[1]) forKey:@"control2"];
                [segment setObject:@"CURVETO" forKey:@"element"];
                break;
        }
        [segments addObject:segment];
    }
    [dict setObject:segments forKey:@"elements"];
    
    return dict;
}

- (void)loadPropertyListRepresentation:(NSDictionary *)dict {
    NSArray *segments = [dict objectForKey:@"elements"];
    int count = [segments count];
    int i;
    for(i=0;i<count;i++) {
        NSDictionary *segment = [segments objectAtIndex:i];
        NSString *element = [segment objectForKey:@"element"];
        if ([element isEqualToString:@"CURVETO"]) {
            NSString *pointString = [segment objectForKey:@"point"];
            NSString *control1String = [segment objectForKey:@"control1"];
            NSString *control2String = [segment objectForKey:@"control2"];
            if (pointString && control1String && control2String) {
                [self curveToPoint:NSPointFromString(pointString) 
                       controlPoint1:NSPointFromString(control1String)
                       controlPoint2:NSPointFromString(control2String)];
            }
        } else if ([element isEqualToString:@"LINETO"]) {
            NSString *pointString = [segment objectForKey:@"point"];
            if (pointString) {
                [self lineToPoint:NSPointFromString(pointString)];
            }
        } else if ([element isEqualToString:@"MOVETO"]) {
            NSString *pointString = [segment objectForKey:@"point"];
            if (pointString) {
                [self moveToPoint:NSPointFromString(pointString)];
            }
        } else if ([element isEqualToString:@"CLOSE"]) {
            [self closePath];
        }
    }
}


// NSObject overrides

- (BOOL)isEqual:(NSBezierPath *)otherBezierPath;
{
    unsigned int elementIndex, elementCount = [self elementCount];

    if (self == otherBezierPath)
        return YES;
    
    if (![otherBezierPath isMemberOfClass:[self class]])
        return NO;

    if ((unsigned)[otherBezierPath elementCount] != elementCount)
        return NO;
    
    for(elementIndex=0; elementIndex<elementCount; elementIndex++) {
        NSPoint points[3];
        NSBezierPathElement element = [self elementAtIndex:elementIndex associatedPoints:points];
        NSPoint otherPoints[3];
        NSBezierPathElement otherElement = [otherBezierPath elementAtIndex:elementIndex associatedPoints:otherPoints];

        if (element != otherElement)
            return NO;
        
        switch (element) {
            case NSMoveToBezierPathElement:
                if (!NSEqualPoints(points[0], otherPoints[0]))
                     return NO;
                break;
            case NSLineToBezierPathElement:
                if (!NSEqualPoints(points[0], otherPoints[0]))
                    return NO;
                break;
            case NSCurveToBezierPathElement:
                if (!NSEqualPoints(points[0], otherPoints[0]) || !NSEqualPoints(points[1], otherPoints[1]) || !NSEqualPoints(points[2], otherPoints[2]))
                    return NO;
                break;
            case NSClosePathBezierPathElement:
                break;
        }
    }

    return YES;
}

static inline unsigned int _spinLeft(unsigned int number, unsigned int spinLeftBitCount)
{
    const unsigned int bitsPerUnsignedInt = sizeof(unsigned int) * 8;
    unsigned int leftmostBits = number >> (bitsPerUnsignedInt - spinLeftBitCount);
    return (number << spinLeftBitCount) | leftmostBits;
}

static inline unsigned int _threeBitsForPoint(NSPoint point)
{
    float bothAxes = ABS(point.x) + ABS(point.y);
    return ((unsigned int)(bothAxes / pow(10.0, floor(log10(bothAxes))))) & 0x7;
}

- (unsigned int)hash;
{
    unsigned int hashValue = 0;
    unsigned int elementIndex, elementCount = [self elementCount];

    for(elementIndex=0; elementIndex<elementCount; elementIndex++) {
        NSPoint points[3];
        NSBezierPathElement element = [self elementAtIndex:elementIndex associatedPoints:points];

        switch (element) {
            case NSMoveToBezierPathElement:
                hashValue = _spinLeft(hashValue, 2);
                hashValue ^= 0;
                hashValue = _spinLeft(hashValue, 3);
                hashValue ^= _threeBitsForPoint(points[0]);
                break;
            case NSLineToBezierPathElement:
                hashValue = _spinLeft(hashValue, 2);
                hashValue ^= 1;
                hashValue = _spinLeft(hashValue, 3);
                hashValue ^= _threeBitsForPoint(points[0]);
                break;
            case NSCurveToBezierPathElement:
                hashValue = _spinLeft(hashValue, 2);
                hashValue ^= 2;
                hashValue = _spinLeft(hashValue, 3);
                hashValue ^= _threeBitsForPoint(points[0]);
                hashValue = _spinLeft(hashValue, 3);
                hashValue ^= _threeBitsForPoint(points[1]);
                hashValue = _spinLeft(hashValue, 3);
                hashValue ^= _threeBitsForPoint(points[2]);
                break;
            case NSClosePathBezierPathElement:
                hashValue = _spinLeft(hashValue, 2);
                hashValue ^= 3;
                break;
        }
    }
    return hashValue;
}


@end



@implementation NSBezierPath (PrivateOAExtensions)

NSString *_roundedStringForPoint(NSPoint point)
{
    return [NSString stringWithFormat:@"{%.5f,%.5f}", point.x, point.y];
}


//

NSPoint _getCurvePoint(NSPoint*c, float u, float offset) {
    // Coefficients c[4]
    // Position u
    NSPoint p;

    p.x = c[0].x + u * (c[1].x + u * (c[2].x + u * c[3].x));
    p.y = c[0].y + u * (c[1].y + u * (c[2].y + u * c[3].y));
    if (offset) {
        NSPoint tangent;
        NSPoint normal;  // we use a normal that is always "up"
        float length;

        tangent.x = c[1].x + u * (2.0 * c[2].x  + u * 3.0 * c[3].x);
        tangent.y = c[1].y + u * (2.0 * c[2].y  + u * 3.0 * c[3].y);

        if (tangent.x == 0) {
            normal.x = 1;
            normal.y = 0;
        } else {
            normal.y = 1;
            normal.x = - tangent.y/tangent.x;
            length = sqrt(normal.x * normal.x + normal.y * normal.y);
            normal.x /= length;
            normal.y /= length;
        }
        p.x += -offset * normal.x;  // fudged
        p.y += -offset * normal.y;
    }
    return p;
}

NSPoint _getLinePoint(NSPoint*a, float position, float offset) {
    // Coefficients a[2]
    NSPoint p;

    if (a[1].x == 0 && a[1].y == 0) {
        return a[0];
    }

    p = a[0];
    p.x += position * a[1].x;
    p.y += position * a[1].y;

    if (offset) {
        NSPoint normal;  // we use a normal that is always "up"
        float length;

        if (a[1].x == 0) {
            normal.x = 1;
            normal.y = 0;
        } else {
            normal.y = 1;
            normal.x = - a[1].y/a[1].x;
            length = sqrt(normal.x * normal.x + normal.y * normal.y);
            normal.x /= length;
            normal.y /= length;
        }
        p.x += -offset * normal.x;  // fudged
        p.y += -offset * normal.y;
    }

    return p;
}

//

NSRect _curveBounds(NSPoint *curve) {
    float minX = curve[0].x;
    float maxX = curve[0].x;
    float minY = curve[0].y;
    float maxY = curve[0].y;
    NSRect rect;
    NSPoint points[3];
    int i;

    points[0].x = curve[0].x + 0.3333* curve[1].x;
    points[0].y = curve[0].y + 0.3333* curve[1].y;
    points[1].x = curve[0].x + 0.3333* curve[2].x + 0.6666* curve[1].x;
    points[1].y = curve[0].y + 0.3333* curve[2].y + 0.6666* curve[1].y;
    points[2].x = curve[3].x + curve[2].x + curve[1].x + curve[0].x;
    points[2].y = curve[3].y + curve[2].y + curve[1].y + curve[0].y;
    
    for(i=0;i<3;i++) {
        NSPoint p = points[i];
        if (p.x > maxX) {
            maxX = p.x;
        } else if (p.x < minX) {
            minX = p.x;
        }
        if (p.y > maxY) {
            maxY = p.y;
        } else if (p.y < minY) {
            minY = p.y;
        }
    }
    rect.origin.x = minX;
    rect.origin.y = minY;
    rect.size.width = maxX - minX;
    if (rect.size.width < 1) {
        rect.size.width = 1;
    }
    rect.size.height = maxY - minY;
    if (rect.size.height < 1) {
        rect.size.height = 1;
    }
    return rect;
}

// wants 4 coefficients and 3 roots
// returns the number of solutions
int _solveCubic(double *c, double *roots) {
    // From Graphic Gems 1
    int i, num = 0;
    double sub;
    double A,B,C;
    double sq_A, p, q;
    double cb_p, D;

    if (c[3] == 0) {
        if (c[2] == 0) {
            if (c[1] == 0) {
                num = 0;
            } else {
                num = 1;
                roots[0] = -c[0]/c[1];
            }
        } else {
            double temp;
            
            A = c[2];
            B = c[1];
            C = c[0];
            
            temp = B*B - 4*A*C;
            if(temp < 0) {
                num = 0;
            } else {
                temp = sqrt(temp);
                roots[0] = (-B-temp)/(2*A);
                roots[1] = (-B+temp)/(2*A);
                num = 2;
            }
        }
        return num;
    } else {
    // Normal form: x^3 + Ax^2 + Bx + C
        A = c[2] / c[3];
        B = c[1] / c[3];
        C = c[0] / c[3];
    }
    
    // Substitute x = y - A/3 to eliminate the quadric term
    // x^3 + px + q
    sq_A = A * A;
    p = 1.0/3 * (-1.0/3 * sq_A + B);
    q = 1.0/2 * (2.0/27.0 * A * sq_A - 1.0/3 * A * B + C);
    cb_p = p * p * p;
    D = q * q + cb_p;

    if (D==0) {
        if (q==0) {  // one triple solution
            roots[0] = 0;
            num = 1;
        } else {     // one single and one double solution
            double u = cbrt(-q);
            roots[0] = 2 * u;
            roots[1] = -u;
            num = 2;
        }
    } else if (D < 0) { // Casus irreducibilis: three real solutions
        double phi = 1.0/3 * acos(-q / sqrt(-cb_p));
        double t = 2 * sqrt(-p);

        roots[0] = t * cos(phi);
        roots[1] = -t * cos(phi + M_PI / 3);
        roots[2] = -t * cos(phi - M_PI / 3);
        num = 3;
    } else {  // One real solution
        double sqrt_D = sqrt(D);
        double u = cbrt(sqrt_D - q);
        double v = -cbrt(sqrt_D + q);
        roots[0] = u + v;
        num = 1;
    }

    // resubstitute

    sub = 1.0/3 * A;
    for(i=0;i<num;i++) {
        roots[i] -= sub;
    }

    return num;
}

void _parameterizeLine(NSPoint *coefficients, NSPoint startPoint, NSPoint endPoint) {
    coefficients[0] = startPoint;
    coefficients[1].x = endPoint.x - startPoint.x;
    coefficients[1].y = endPoint.y - startPoint.y;
}

void _parameterizeCurve(NSPoint *coefficients, NSPoint startPoint, NSPoint endPoint, NSPoint controlPoint1, NSPoint controlPoint2) {
    NSPoint tangent2;
    tangent2.x = 3.0 * (endPoint.x - controlPoint2.x);
    tangent2.y = 3.0 * (endPoint.y - controlPoint2.y);

    coefficients[0] = startPoint;
    coefficients[1].x = 3.0 * (controlPoint1.x - startPoint.x);  // 1st tangent
    coefficients[1].y = 3.0 * (controlPoint1.y - startPoint.y);  // 1st tangent
    coefficients[2].x = 3.0 * (endPoint.x - startPoint.x) - 2.0 * coefficients[1].x - tangent2.x;
    coefficients[2].y = 3.0 * (endPoint.y - startPoint.y) - 2.0 * coefficients[1].y - tangent2.y;
    coefficients[3].x = 2.0 * (startPoint.x - endPoint.x) + coefficients[1].x + tangent2.x;
    coefficients[3].y = 2.0 * (startPoint.y - endPoint.y) + coefficients[1].y + tangent2.y;
}

- (BOOL)_curvedIntersection:(float *)length time:(float *)time curve:(NSPoint *)c line:(NSPoint *)a {
    int i;
    double cubic[4];
    double roots[3];
    int count;
    float minT = 1.1;
    BOOL foundOne = NO;

    for(i=0;i<4;i++) {
        cubic[i] = c[i].x * a[1].y - c[i].y * a[1].x;
    }
    cubic[0] -= (a[0].x * a[1].y - a[0].y * a[1].x);

    count = _solveCubic(cubic, roots);

    for(i=0;i<count;i++) {
        float u = roots[i];
        float t;
        
        if (u < -0.0001 || u > 1.0001) {
            continue;
        }
        if (isnan(u)) {
            continue;
        }

        // Used to be (a[1].x == 0), but that caused problems if a[1].x was very close to zero.
        // Instead we use whichever is larger.
        if (fabs(a[1].x) < fabs(a[1].y)) {
            t = c[0].y + u * (c[1].y + u * (c[2].y + u * c[3].y));
            t -= a[0].y;
            t /= a[1].y;
        } else {
            t = c[0].x + u * (c[1].x + u * (c[2].x + u * c[3].x));
            t -= a[0].x;
            t /= a[1].x;
        }
        if (t < -0.0001 || t > 1.0001) {
            continue;
        }

        if (t < minT) {
            foundOne = YES;
            minT = t;
            *time = u;
        }
    }

    if (foundOne) {
        if (minT < 0)
            minT = 0;
        else if (minT > 1)
            minT = 1;
        *length = minT;
        return YES;
    }

    return NO;
}

BOOL _straightLineIntersectsRect(NSPoint *a, NSRect rect) {
    // PENDING: needs some work...
    if (NSPointInRect(a[0], rect)) {
        return YES;
    }
    if (a[1].x != 0) {
        float t = (NSMinX(rect) - a[0].x)/a[1].x;
        float y;
        if (t >= 0 && t <= 1) {
            y = t * a[1].y + a[0].y;
            if (y >= NSMinY(rect) && y < NSMaxY(rect)) {
                return YES;
            }
        }
        t = (NSMaxX(rect) - a[0].x)/a[1].x;
        if (t >= 0 && t <= 1) {
            y = t * a[1].y + a[0].y;
            if (y >= NSMinY(rect) && y < NSMaxY(rect)) {
                return YES;
            }
        }
    }
    if (a[1].y != 0) {
        float t = (NSMinY(rect) - a[0].y)/a[1].y;
        float x;
        if (t >= 0 && t <= 1) {
            x = t * a[1].x + a[0].x;
            if (x >= NSMinX(rect) && x < NSMaxX(rect)) {
                return YES;
            }
        }
        t = (NSMaxY(rect) - a[0].y)/a[1].y;
        if (t >= 0 && t <= 1) {
            x = t * a[1].x + a[0].x;
            if (x >= NSMinX(rect) && x < NSMaxX(rect)) {
                return YES;
            }
        }
    }
//    } else {
//        if (a[0].x < NSMinX(rect) || a[0].x > NSMaxX(rect)) {
//            return NO;
//        }
//        if (a[0].y < NSMinY(rect)) {
//            if ((a[0].y + a[1].y) >= NSMinY(rect)) {
//                return YES;
//            }
//        } else if (a[0].y <= NSMaxY(rect)) {
//            return YES;
//        }
//    }
    return NO;
} 

void _splitCurve(NSPoint*c, NSPoint*left, NSPoint*right) {
    left[0] = c[0];
    left[1].x = 0.5 * c[1].x;
    left[1].y = 0.5 * c[1].y;
    left[2].x = 0.25 * c[2].x;
    left[2].y = 0.25 * c[2].y;
    left[3].x = 0.125 * c[3].x;
    left[3].y = 0.125 * c[3].y;

    right[0].x = left[0].x + left[1].x + left[2].x + left[3].x;
    right[0].y = left[0].y + left[1].y + left[2].y + left[3].y;
    right[1].x = 3 * left[3].x + 2 * left[2].x + left[1].x;
    right[1].y = 3 * left[3].y + 2 * left[2].y + left[1].y;
    right[2].x = 3 * left[3].x + left[2].x;
    right[2].y = 3 * left[3].y + left[2].y;
    right[3] = left[3];
}

BOOL _curvedLineIntersectsRect(NSPoint *c, NSRect rect, float tolerance) {
    NSRect bounds = _curveBounds(c);
    if (NSIntersectsRect(rect, bounds)) {
        if (bounds.size.width <= tolerance ||
            bounds.size.height <= tolerance) {
                return YES;
        } else {
            NSPoint left[4], right[4];
            _splitCurve(c, left, right);
            if (_curvedLineIntersectsRect(left, rect, tolerance) ||
                _curvedLineIntersectsRect(right, rect, tolerance)) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)_curvedLineHit:(NSPoint)point startPoint:(NSPoint)startPoint endPoint:(NSPoint)endPoint controlPoint1:(NSPoint)controlPoint1 controlPoint2:(NSPoint)controlPoint2 position:(float *)position padding:(float)padding
{
    // find the square of the distance between the point and a point
    // on the curve (u).
    // use newtons method to approach the minumum u.
    NSPoint a[4];     // our regular coefficients
    double c[7];  // a cubic squared gives us 7 coefficients
    double u, bestU;

    double tolerance = padding + [self lineWidth] / 2;
    double delta, minDelta;
    int i;
        
//    if (tolerance < 3) {
//        tolerance = 3;
//    }
    
    tolerance *= tolerance;

    _parameterizeCurve(a, startPoint, endPoint, controlPoint1, controlPoint2);
    
    delta = a[0].x - point.x;
    c[0] = delta * delta;
    delta = a[0].y - point.y;
    c[0] += delta * delta;
    c[1] = 2 * ((a[0].x - point.x) * a[1].x + (a[0].y - point.y) * a[1].y);
    c[2] = a[1].x * a[1].x + a[1].y * a[1].y +
        2 * (a[2].x * (a[0].x - point.x) + a[2].y * (a[0].y - point.y));
    c[3] = 2 * (a[1].x * a[2].x + (a[0].x - point.x) * a[3].x +
                a[1].y * a[2].y + (a[0].y - point.y) * a[3].y);
    c[4] = a[2].x * a[2].x + a[2].y * a[2].y +
      2 * (a[1].x * a[3].x + a[1].y * a[3].y);
    c[5] = 2.0 * (a[2].x * a[3].x + a[2].y * a[3].y);
    c[6] = a[3].x * a[3].x + a[3].y * a[3].y;


    // Estimate a starting U
    if (endPoint.x < startPoint.x) {
        u = point.x - endPoint.x;
    } else {
        u = point.x - startPoint.x;
        delta = endPoint.x - startPoint.x;
    }
    
    delta = fabs(startPoint.x - point.x) + fabs(endPoint.x - point.x);
    delta += fabs(startPoint.y - point.y) + fabs(endPoint.y - point.y);

    if (endPoint.y < startPoint.y) {
        u += point.y - endPoint.y;
        delta += startPoint.y - endPoint.y;
    } else {
        u += point.y - startPoint.y;
        delta += endPoint.y - startPoint.y;
    }

    u /= delta;
    if (u < 0) {
        u = 0;
    } else if (u > 1) {
        u = 1;
    }

    // Iterate while adjust U with our error function

    // NOTE: Sadly, Newton's method becomes unstable as we approach the solution.  Also, the farther away from the curve, the wider the oscillation will be.
    // To get around this, we're keeping track of our best result, adding a few more iterations, and damping our approach.
    minDelta = 100000;
    bestU = u;
    
    for(i=0;i< 12;i++) {
        delta = (((((c[6] * u + c[5]) * u + c[4]) * u + c[3]) * u + c[2]) * u + c[1]) * u + c[0];
        if (delta < minDelta) {
            minDelta = delta;
            *position = u;
        }

        if (i==11 && minDelta <= tolerance) {
            return YES;
        } else {
            double slope = ((((( 6 * c[6] * u + 5 * c[5]) * u + 4 * c[4]) * u + 3 * c[3]) * u + 2 * c[2]) * u + c[1]);
            double deltaU = delta/slope;

            if ((u==0 && delta > 0) || (u==1 && delta < 0)) {
                return minDelta <= tolerance;
            }
            u -= 0.75 * deltaU; // Used to be just deltaU, but we're damping it a bit
            if (u<0.0) {
                u = 0.0;
            }
            if (u>1.0) {
                u = 1.0;
            }
        }
    }

    return NO;
}

- (BOOL)_straightLineIntersection:(float *)length time:(float *)time segment:(NSPoint *)s line:(NSPoint *)l {
    // PENDING: should optimize this for the most common cases (s[1] == 0);
    float u;
    float t;
    
    if (ABS(s[1].x) < 0.001) {
        if (ABS(s[1].y) < 0.001) {
            // This is a zero length line, currently generated by rounded rectangles
            // NOTE: should fix rounded rectangles
            return NO;
        }
        if (ABS(l[1].x) < 0.001) {
            return NO;
        }
		s[1].x = 0;
    } else if (ABS(s[1].y) < 0.001) {
        if (ABS(l[1].y) < 0.001) {
            return NO;
        }
		s[1].y = 0;
    } 
    
    u = (s[1].y * s[0].x - s[1].x * s[0].y) - (s[1].y * l[0].x - s[1].x * l[0].y);
    u /= (s[1].y * l[1].x - s[1].x * l[1].y);
    if (u < -0.0001 || u > 1.0001) {
        return NO;
    }
    if (s[1].x == 0) {
        t = (l[1].y * u + (l[0].y - s[0].y)) / s[1].y;
    } else {
        t = (l[1].x * u + (l[0].x - s[0].x)) / s[1].x;
    }
    if (t < -0.0001 || t > 1.0001 || isnan(t)) {
        return NO;
    }
    
    *length = u;
    *time = t;
    return YES;
}

- (BOOL)_straightLineHit:(NSPoint)startPoint :(NSPoint)endPoint :(NSPoint)point  :(float *)position padding:(float)padding {
    NSPoint delta;
    NSPoint vector;
    NSPoint linePoint;
    float length;
    float dotProduct;
    float distance;
    float tolerance = padding + [self lineWidth]/2;
    
//    if (tolerance < 3) {
//        tolerance = 3;
//    }
    
    delta.x = endPoint.x - startPoint.x;
    delta.y = endPoint.y - startPoint.y;
    length = sqrt(delta.x * delta.x + delta.y * delta.y);
    delta.x /=length;
    delta.y /=length;

    vector.x = point.x - startPoint.x;
    vector.y = point.y - startPoint.y;

    dotProduct = vector.x * delta.x + vector.y * delta.y;

    linePoint.x = startPoint.x + delta.x * dotProduct;
    linePoint.y = startPoint.y + delta.y * dotProduct;

    delta.x = point.x - linePoint.x;
    delta.y = point.y - linePoint.y;

    // really the distance squared
    distance = delta.x * delta.x + delta.y * delta.y;
    
    if (distance < (tolerance * tolerance)) {
        *position = dotProduct/length;
        if (*position >= 0 && *position <=1) {
            return YES;
        }
    }
    
    return NO;
}

- (int)_segmentHitByPoint:(NSPoint)point position:(float *)position padding:(float)padding
{
    int count = [self elementCount];
    int i;
    NSPoint points[3];
    NSPoint startPoint;
    NSPoint currentPoint;
    int element;
    BOOL needANewStartPoint;

    if (count == 0)
        return 0;

    element = [self elementAtIndex:0 associatedPoints:points];
    if (element != NSMoveToBezierPathElement) {
        return 0;  // must start with a moveTo
    }

    startPoint = currentPoint = points[0];
    needANewStartPoint = NO;
    
    for(i=1;i<count;i++) {
        element = [self elementAtIndex:i associatedPoints:points];
        if (NSEqualPoints(points[0], point)) {
            if (i==0) {
                i = 1;
            }
            return i;
        }
        switch(element) {
            case NSMoveToBezierPathElement:
                currentPoint = points[0];
                if (needANewStartPoint) {
                    startPoint = currentPoint;
                    needANewStartPoint = NO;
                }
                break;
            case NSClosePathBezierPathElement:
                if ([self _straightLineHit:currentPoint :startPoint :point :position padding:padding]){
                    return i;
                }
                currentPoint = startPoint;
                needANewStartPoint = YES;
                break;
            case NSLineToBezierPathElement:
                if ([self _straightLineHit:currentPoint :points[0] :point :position padding:padding]){
                    return i;
                }
                currentPoint = points[0];
                break;
            case NSCurveToBezierPathElement:
                if ([self _curvedLineHit:point startPoint:currentPoint endPoint:points[2] controlPoint1:points[0] controlPoint2:points[1] position:position padding:padding]) {
                    return i;
                }
                currentPoint = points[2];
                break;
        }
    }
    return 0;
}

- (NSPoint)_endPointForSegment:(int)i {
    NSPoint points[3];
    int element = [self elementAtIndex:i associatedPoints:points];
    switch(element) {
        case NSCurveToBezierPathElement:
            return points[2];
        case NSClosePathBezierPathElement:
            element = [self elementAtIndex:0 associatedPoints:points];
        case NSMoveToBezierPathElement:
        case NSLineToBezierPathElement:
            return points[0];
    }
    return NSZeroPoint;
}


@end
