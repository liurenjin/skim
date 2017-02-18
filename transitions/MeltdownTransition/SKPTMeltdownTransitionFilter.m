//
//  SKPTMeltdownTransitionFilter.m
//  MeltdownTransition
//
//  Created by Christiaan on 10/6/09.
//  Copyright Christiaan Hofman 2009. All rights reserved.
//

#import "SKPTMeltdownTransitionFilter.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

@implementation SKPTMeltdownTransitionFilter

static CIKernel *_SKPTMeltdownTransitionFilterKernel = nil;

- (id)init
{
    if(_SKPTMeltdownTransitionFilterKernel == nil)
    {
		NSBundle    *bundle = [NSBundle bundleForClass:NSClassFromString(@"SKPTMeltdownTransitionFilter")];
		NSStringEncoding encoding = NSUTF8StringEncoding;
		NSError     *error = nil;
		NSString    *code = [NSString stringWithContentsOfFile:[bundle pathForResource:@"SKPTMeltdownTransitionFilterKernel" ofType:@"cikernel"] encoding:encoding error:&error];
		NSArray     *kernels = [CIKernel kernelsWithString:code];

		_SKPTMeltdownTransitionFilterKernel = [[kernels objectAtIndex:0] retain];
    }
    return [super init];
}

- (NSDictionary *)customAttributes
{
    return [NSDictionary dictionaryWithObjectsAndKeys:

        [NSDictionary dictionaryWithObjectsAndKeys:
            [CIVector vectorWithX:0.0 Y:0.0 Z:300.0 W:300.0], kCIAttributeDefault,
            kCIAttributeTypeRectangle,          kCIAttributeType,
            nil],                               @"inputExtent",
 
        [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithDouble:  0.0], kCIAttributeMin,
            [NSNumber numberWithDouble:  1.0], kCIAttributeMax,
            [NSNumber numberWithDouble:  0.0], kCIAttributeSliderMin,
            [NSNumber numberWithDouble:  500.0], kCIAttributeSliderMax,
            [NSNumber numberWithDouble:  200.0], kCIAttributeDefault,
            [NSNumber numberWithDouble:  0.0], kCIAttributeIdentity,
            kCIAttributeTypeDistance,          kCIAttributeType,
            nil],                              @"inputAmount",
 
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

- (CGRect)regionOf:(int)sampler destRect:(CGRect)R userInfo:(NSArray *)array {
    float amount = [[array objectAtIndex:2] floatValue];
    float radius = [[array objectAtIndex:3] floatValue];
    if (sampler == 0) {
        CGRect extent = [[array objectAtIndex:0] extent];
        R.origin.y += radius;
        R.size.height += amount;
        R = CGRectIntersection(R, extent);
    } else if (sampler == 2) {
        CGRect extent = [[array objectAtIndex:1] extent];
        R.origin.y += radius;
        R = CGRectIntersection(R, extent);
    }
    
    return R;
}

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
    CISampler *src = [CISampler samplerWithImage:inputImage];
    CISampler *trgt = [CISampler samplerWithImage:inputTargetImage];
    CISampler *mask = [CISampler samplerWithImage:inputMaskImage];
    float x = [inputExtent X];
    float y = [inputExtent Y];
    float width = [inputExtent Z];
    float height = [inputExtent W];
    float t = [inputTime floatValue];
    NSNumber *radius = [NSNumber numberWithFloat:height * t];
    NSNumber *amount = [NSNumber numberWithFloat:[inputAmount floatValue] * t];
    
    NSArray *extent = [NSArray arrayWithObjects:[NSNumber numberWithFloat:x], [NSNumber numberWithFloat:y], [NSNumber numberWithFloat:width], [NSNumber numberWithFloat:height], nil];
    NSArray *arguments = [NSArray arrayWithObjects:src, trgt, mask, amount, radius, nil];
    NSArray *userInfo = [NSArray arrayWithObjects:src, mask, amount, radius, nil];
    NSDictionary *options  = [NSDictionary dictionaryWithObjectsAndKeys:extent, kCIApplyOptionDefinition, extent, kCIApplyOptionExtent, userInfo, kCIApplyOptionUserInfo, nil];
    
    [_SKPTMeltdownTransitionFilterKernel setROISelector:@selector(regionOf:destRect:userInfo:)];
    
    return [self apply:_SKPTMeltdownTransitionFilterKernel arguments:arguments options:options];
}

@end
