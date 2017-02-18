//
//  SKPTStripsTransitionFilter.m
//  StripsTransition
//
//  Created by Christiaan on 10/6/09.
//  Copyright Christiaan Hofman 2009. All rights reserved.
//

#import "SKPTStripsTransitionFilter.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

@implementation SKPTStripsTransitionFilter

static CIKernel *_SKPTStripsTransitionFilterKernel = nil;

- (id)init
{
    if(_SKPTStripsTransitionFilterKernel == nil)
    {
		NSBundle    *bundle = [NSBundle bundleForClass:NSClassFromString(@"SKPTStripsTransitionFilter")];
		NSStringEncoding encoding = NSUTF8StringEncoding;
		NSError     *error = nil;
		NSString    *code = [NSString stringWithContentsOfFile:[bundle pathForResource:@"SKPTStripsTransitionFilterKernel" ofType:@"cikernel"] encoding:encoding error:&error];
		NSArray     *kernels = [CIKernel kernelsWithString:code];

		_SKPTStripsTransitionFilterKernel = [[kernels objectAtIndex:0] retain];
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
            [NSNumber numberWithDouble:  0.0], kCIAttributeMax,
            [NSNumber numberWithDouble:  0.0], kCIAttributeSliderMin,
            [NSNumber numberWithDouble:  100.0], kCIAttributeSliderMax,
            [NSNumber numberWithDouble:  50.0], kCIAttributeDefault,
            [NSNumber numberWithDouble:  0.0], kCIAttributeIdentity,
            kCIAttributeTypeScalar,            kCIAttributeType,
            nil],                              @"inputWidth",
 
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
    if (sampler == 0) {
        CGRect extent = [[array objectAtIndex:0] extent];
        float offset = [[array objectAtIndex:1] floatValue];
        R = CGRectIntersection(extent, CGRectUnion(CGRectOffset(R, offset, 0.0), CGRectOffset(R, -offset, 0.0)));
    }
    return R;
}

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
    CISampler *src = [CISampler samplerWithImage:inputImage];
    CISampler *trgt = [CISampler samplerWithImage:inputTargetImage];
    NSNumber *offset = [NSNumber numberWithFloat:[inputExtent Z] * [inputTime floatValue]];
    NSArray *extent = [NSArray arrayWithObjects:[NSNumber numberWithFloat:[inputExtent X]], [NSNumber numberWithFloat:[inputExtent Y]], [NSNumber numberWithFloat:[inputExtent Z]], [NSNumber numberWithFloat:[inputExtent W]], nil];
    NSArray *arguments = [NSArray arrayWithObjects:src, trgt, inputExtent, inputWidth, inputTime, nil];
    NSArray *userInfo = [NSArray arrayWithObjects:src, offset, nil];
    NSDictionary *options  = [NSDictionary dictionaryWithObjectsAndKeys:extent, kCIApplyOptionDefinition, extent, kCIApplyOptionExtent, userInfo, kCIApplyOptionUserInfo, nil];
    
    [_SKPTStripsTransitionFilterKernel setROISelector:@selector(regionOf:destRect:userInfo:)];
    
    return [self apply:_SKPTStripsTransitionFilterKernel arguments:arguments options:options];
}

@end
