//
//  SKPTPinchTransitionFilter.h
//  PinchTransition
//
//  Created by Christiaan on 10/6/09.
//  Copyright Christiaan Hofman 2009. All rights reserved.

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>


@interface SKPTPinchTransitionFilter : CIFilter
{
    CIImage     *inputImage;
    CIImage     *inputTargetImage;
    CIVector    *inputCenter;
    CIVector    *inputExtent;
    NSNumber    *inputTime;
}

@end
