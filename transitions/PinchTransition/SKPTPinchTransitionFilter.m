//
//  SKPTPinchTransitionFilter.m
//  PinchTransition
//
//  Created by Christiaan on 10/6/09.
//  Copyright Christiaan Hofman 2009. All rights reserved.
//

#import "SKPTPinchTransitionFilter.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

@implementation SKPTPinchTransitionFilter

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

// called when setting up for fragment program and also calls fragment program
- (CIImage *)outputImage
{
    float t = [inputTime floatValue];
    float width = [inputExtent Z];
    float height = [inputExtent W];
    float scale = 1.0 - fabs(2.0 * t - 1.0);
    float radius = 10.0 * scale * fmax(width, height);
    
    CIFilter *pinchFilter = [CIFilter filterWithName:@"CIPinchDistortion"];
    [pinchFilter setValue:t < 0.5 ? inputImage : inputTargetImage forKey:@"inputImage"];
    [pinchFilter setValue:inputCenter forKey:@"inputCenter"];
    [pinchFilter setValue:[NSNumber numberWithFloat:radius] forKey:@"inputRadius"];
    [pinchFilter setValue:[NSNumber numberWithFloat:scale] forKey:@"inputScale"];
    
    return [pinchFilter valueForKey:@"outputImage"];
}

@end
