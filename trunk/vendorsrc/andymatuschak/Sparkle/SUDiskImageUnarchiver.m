//
//  SUDiskImageUnarchiver.m
//  Sparkle
//
//  Created by Andy Matuschak on 6/16/08.
//  Copyright 2008 Andy Matuschak. All rights reserved.
//

#import "SUDiskImageUnarchiver.h"
#import "SUUnarchiver_Private.h"
#import "NTSynchronousTask.h"

@implementation SUDiskImageUnarchiver

+ (BOOL)_canUnarchivePath:(NSString *)path
{
	return [[path pathExtension] isEqualToString:@"dmg"];
}

- (void)start
{
	[NSThread detachNewThreadSelector:@selector(_extractDMG) toTarget:self withObject:nil];
}

- (void)_extractDMG
{		
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL mountedSuccessfully = NO;
	
    // get a local copy of NSFileManager because this is running from a secondary thread
    NSFileManager *fm = [[[NSFileManager alloc] init] autorelease];
    
	// get a unique mount point path
	NSString *mountPointName = nil;
	NSString *mountPoint = nil;
	do
	{
		CFUUIDRef uuid = CFUUIDCreate(NULL);
		mountPointName = (NSString *)CFUUIDCreateString(NULL, uuid);
		CFRelease(uuid);
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4
		[NSMakeCollectable((CFStringRef)mountPointName) autorelease];
#else
		[mountPointName autorelease];
#endif
		mountPoint = [@"/Volumes" stringByAppendingPathComponent:mountPointName];
	}
	while ([fm fileExistsAtPath:mountPoint]);
	
	NSArray* arguments = [NSArray arrayWithObjects:@"attach", archivePath, @"-mountpoint", mountPoint, @"-noverify", @"-nobrowse", @"-noautoopen", nil];
	// set up a pipe and push "yes" (y works too), this will accept any license agreement crap
	// not every .dmg needs this, but this will make sure it works with everyone
	NSData* yesData = [[[NSData alloc] initWithBytes:"yes\n" length:4] autorelease];
	
	NSData *result = [NTSynchronousTask task:@"/usr/bin/hdiutil" directory:@"/" withArgs:arguments input:yesData];
	if (!result) goto reportError;
	mountedSuccessfully = YES;
	
	// Now that we've mounted it, we need to copy out its contents.
    NSString *targetPath = [[archivePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:mountPointName];
    if (![fm createDirectoryAtPath:targetPath withIntermediateDirectories:YES attributes:nil error:NULL]) goto reportError;
    
    // We can't just copyPath: from the volume root because that always fails. Seems to be a bug.
    
    id subpathEnumerator = [[fm contentsOfDirectoryAtPath:mountPoint error:NULL] objectEnumerator], currentSubpath;
    while ((currentSubpath = [subpathEnumerator nextObject])) 	 
    { 	 
        NSString *currentFullPath = [mountPoint stringByAppendingPathComponent:currentSubpath]; 	 
        // Don't bother trying (and failing) to copy out files we can't read. That's not going to be the app anyway. 	 
        if (![fm isReadableFileAtPath:currentFullPath]) continue; 	 
        if (![fm copyItemAtPath:currentFullPath toPath:[targetPath stringByAppendingPathComponent:currentSubpath] error:NULL]) 	 
            goto reportError; 	 
    }
	
	[self performSelectorOnMainThread:@selector(_notifyDelegateOfSuccess) withObject:nil waitUntilDone:NO];
	goto finally;
	
reportError:
	[self performSelectorOnMainThread:@selector(_notifyDelegateOfFailure) withObject:nil waitUntilDone:NO];

finally:
	if (mountedSuccessfully)
		[NSTask launchedTaskWithLaunchPath:@"/usr/bin/hdiutil" arguments:[NSArray arrayWithObjects:@"detach", mountPoint, @"-force", nil]];
	[pool drain];
}

+ (void)load
{
	[self _registerImplementation:self];
}

@end
