//
//  SKPTHoleTransitionFilter.m
//  HoleTransition
//
//  Created by Christiaan on 10/6/09.
//  Copyright Christiaan Hofman 2009. All rights reserved.
//

#import "SKPTHoleTransitionFilter.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

@implementation SKPTHoleTransitionFilter

static CIKernel *_SKPTHoleTransitionFilterKernel = nil;

- (id)init
{
    if(_SKPTHoleTransitionFilterKernel == nil)
    {
		NSBundle    *bundle = [NSBundle bundleForClass:NSClassFromString(@"SKPTHoleTransitionFilter")];
		NSStringEncoding encoding = NSUTF8StringEncoding;
		NSError     *error = nil;
		NSString    *code = [NSString stringWithContentsOfFile:[bundle pathForResource:@"SKPTHoleTransitionFilterKernel" ofType:@"cikernel"] encoding:encoding error:&error];
		NSArray     *kernels = [CIKernel kernelsWithString:code];

		_SKPTHoleTransitionFilterKernel = [[kernels objectAtIndex:0] retain];
    }
    return [super init];
}

- (NSDictionary *)customAttributes
{
    return [NSDictionary dictionaryWithObjectsAndKeys:

        [NSDictionary dictionaryWithObjectsAndKeys:
            [CIVector vectorWithX:150.0 Y:150.0], kCIAttributeDefault,
            kCIAttributeTypePosition,          kCIAttributeType,
            nil],                              @"inputCenter",
 
        [NSDictionary dictionaryWithObjectsAndKeys:
            [CIVector vectorWithX:0.0 Y:0.0 Z:300.0 W:300.0], kCIAttributeDefault,
            kCIAttributeTypeRectangle,          kCIAttributeType,
            nil],                               @"inputExtent",
 
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithDouble:  0.0], kCIAttributeMin,
            [NSNumber numberWithDouble:  1.0], kCIAttributeMax,
            [NSNumber numberWithDouble:  0.0], kCIAttributeSliderMin,
            [NSNumber numberWithDouble:  1.0], kCIAttributeSliderMax,
            [NSNumber numberWithDouble:  0.0], kCIAttributeDefault,
            [NSNumber numberWithDouble:  0.0], kCIAttributeIdentity,
            kCIAttributeTypeTime,              kCIAttributeType,
            nil],                              @"inputTime",

        nil];
}

- (CGRect)regionOf:(int)sampler destRect:(CGRect)R userInfo:(CIVector *)center {
    float x = [center X];
    float y = [center Y];
    
    if (sampler == 0) {
        if (x < R.origin.x) {
            R.size.width += R.origin.x - x;
            R.origin.x = x;
        } else if (x > R.origin.x + R.size.width) {
            R.size.width = x - R.origin.x;
        }
        if (y < R.origin.y) {
            R.size.height += R.origin.y - y;
            R.origin.y = y;
        } else if (y > R.origin.y + R.size.height) {
            R.size.height = y - R.origin.y;
        }
    }
        
    return R;
}

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
    CISampler *src = [CISampler samplerWithImage:inputImage];
    CISampler *trgt = [CISampler samplerWithImage:inputTargetImage];
    float x = [inputExtent X];
    float y = [inputExtent Y];
    float width = [inputExtent Z];
    float height = [inputExtent W];
    float dx = x - [inputCenter X];
    float dy = y - [inputCenter Y];
    float radius;
    
    dx = fmax(fabs(dx), fabs(dx + width));
    dy = fmax(fabs(dy), fabs(dy + height));
    radius = ceilf(sqrt(dx * dx + dy * dy)) * [inputTime floatValue];
    
    NSArray *extent = [NSArray arrayWithObjects:[NSNumber numberWithFloat:x], [NSNumber numberWithFloat:y], [NSNumber numberWithFloat:width], [NSNumber numberWithFloat:height], nil];
    NSArray *arguments = [NSArray arrayWithObjects:src, trgt, inputCenter, [NSNumber numberWithFloat:radius], nil];
    NSDictionary *options  = [NSDictionary dictionaryWithObjectsAndKeys:extent, kCIApplyOptionDefinition, extent, kCIApplyOptionExtent, inputCenter, kCIApplyOptionUserInfo, nil];
    
    [_SKPTHoleTransitionFilterKernel setROISelector:@selector(regionOf:destRect:userInfo:)];
    
    return [self apply:_SKPTHoleTransitionFilterKernel arguments:arguments options:options];
}

@end
