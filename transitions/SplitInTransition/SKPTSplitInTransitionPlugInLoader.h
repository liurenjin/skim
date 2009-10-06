//
//  SKPTSplitInTransitionPlugInLoader.h
//  SplitInTransition
//
//  Created by Christiaan on 10/6/09.
//  Copyright Christiaan Hofman 2009. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CoreImage.h>


@interface SKPTSplitInTransitionPlugInLoader : NSObject <CIPlugInRegistration>
{

}

-(BOOL)load:(void*)host;

@end
