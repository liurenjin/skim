//
//  SKPTAccelerationTransitionFilter.m
//  AccelerationTransition
//
//  Created by Christiaan on 10/6/09.
//  Copyright Christiaan Hofman 2009. All rights reserved.
//

#import "SKPTAccelerationTransitionFilter.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

@implementation SKPTAccelerationTransitionFilter

- (NSDictionary *)customAttributes
{
    return [NSDictionary dictionaryWithObjectsAndKeys:

        [NSDictionary dictionaryWithObjectsAndKeys:
            [CIVector vectorWithX:150.0 Y:150.0], kCIAttributeDefault,
            kCIAttributeTypePosition,          kCIAttributeType,
            nil],                              @"inputCenter",
 
        [NSDictionary dictionaryWithObjectsAndKeys:
            [CIVector vectorWithX:300.0 Y:300.0], kCIAttributeDefault,
            kCIAttributeTypeRectangle,         kCIAttributeType,
            nil],                              @"inputExtent",
 
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
    CIImage *image = t < 0.5 ? inputImage : inputTargetImage;
    CIFilter *blurFilter = [CIFilter filterWithName:@"CIZoomBlur"];
    
    [blurFilter setDefaults];
    [blurFilter setValue:image forKey:@"inputImage"];
    [blurFilter setValue:inputCenter forKey:@"inputCenter"];
    [blurFilter setValue:[NSNumber numberWithFloat:400.0 * (0.5 - fabs(0.5 - t))] forKey:@"inputAmount"];
    CIFilter *cropFilter = [CIFilter filterWithName:@"CICrop"];
    [cropFilter setValue:[blurFilter valueForKey:@"outputImage"] forKey:@"inputImage"];
    [cropFilter setValue:inputExtent forKey:@"inputRectangle"];
    
    return [cropFilter valueForKey:@"outputImage"];
}

@end
