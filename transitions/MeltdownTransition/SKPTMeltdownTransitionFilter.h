//
//  SKPTMeltdownTransitionFilter.h
//  MeltdownTransition
//
//  Created by Christiaan on 10/6/09.
//  Copyright Christiaan Hofman 2009. All rights reserved.

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>


@interface SKPTMeltdownTransitionFilter : CIFilter
{
    CIImage     *inputImage;
    CIImage     *inputTargetImage;
    CIImage     *inputMaskImage;
    CIVector    *inputExtent;
    NSNumber    *inputAmount;
    NSNumber    *inputTime;
}

@end
