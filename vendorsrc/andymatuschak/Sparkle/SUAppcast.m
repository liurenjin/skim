//
//  SUAppcast.m
//  Sparkle
//
//  Created by Andy Matuschak on 3/12/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#import "Sparkle.h"
#import "SUAppcast.h"

@interface SUAppcast (Private)
- (void)reportError:(NSError *)error;
- (NSXMLNode *)bestNodeInNodes:(NSArray *)nodes;
@end

@implementation SUAppcast

- (void)dealloc
{
	[items release];
	[userAgentString release];
	[super dealloc];
}

- (NSArray *)items
{
	return items;
}

- (void)fetchAppcastFromURL:(NSURL *)url
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
    if (userAgentString)
        [request setValue:userAgentString forHTTPHeaderField:@"User-Agent"];
            
    download = [[NSURLDownload alloc] initWithRequest:request delegate:self];
}

- (void)download:(NSURLDownload *)aDownload decideDestinationWithSuggestedFilename:(NSString *)filename
{
    NSString *destinationFilename = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    [aDownload setDestination:destinationFilename allowOverwrite:NO];
}

- (void)download:(NSURLDownload *)aDownload didCreateDestination:(NSString *)path
{
    [downloadFilename release];
    downloadFilename = [path copy];
}

- (void)downloadDidFinish:(NSURLDownload *)aDownload
{
	[download release];
	download = nil;
    
	NSError *error = nil;
    NSXMLDocument *document = nil;
	BOOL failed = NO;
	NSArray *xmlItems = nil;
	NSMutableArray *appcastItems = [NSMutableArray array];
	
	if (downloadFilename)
	{
		document = [[[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:downloadFilename] options:NSXMLNodeLoadExternalEntitiesNever error:&error] autorelease];
	
#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
		[[NSFileManager defaultManager] removeFileAtPath:downloadFilename handler:nil];
#else
		[[NSFileManager defaultManager] removeItemAtPath:downloadFilename error:nil];
#endif
		[downloadFilename release];
		downloadFilename = nil;
	}
	else
	{
		failed = YES;
	}
    
    if (nil == document)
    {
        failed = YES;
    }
    else
    {
        xmlItems = [document nodesForXPath:@"/rss/channel/item" error:&error];
        if (nil == xmlItems)
        {
            failed = YES;
        }
    }
    
	if (failed == NO)
    {
		
		NSEnumerator *nodeEnum = [xmlItems objectEnumerator];
		NSXMLNode *node;
		NSMutableDictionary *nodesDict = [NSMutableDictionary dictionary];
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		
		while (failed == NO && (node = [nodeEnum nextObject]))
        {
			// First, we'll "index" all the first-level children of this appcast item so we can pick them out by language later.
            if ([[node children] count])
            {
                node = [node childAtIndex:0];
                while (nil != node)
                {
                    NSString *name = [node name];
                    if (name)
                    {
                        NSMutableArray *nodes = [nodesDict objectForKey:name];
                        if (nodes == nil)
                        {
                            nodes = [NSMutableArray array];
                            [nodesDict setObject:nodes forKey:name];
                        }
                        [nodes addObject:node];
                    }
                    node = [node nextSibling];
                }
            }
            
            NSEnumerator *nameEnum = [nodesDict keyEnumerator];
            NSString *name;
            while ((name = [nameEnum nextObject]))
            {
                node = [self bestNodeInNodes:[nodesDict objectForKey:name]];
				if ([name isEqualToString:@"enclosure"])
				{
					// enclosure is flattened as a separate dictionary for some reason
					NSEnumerator *attributeEnum = [[(NSXMLElement *)node attributes] objectEnumerator];
					NSXMLNode *attribute;
					NSMutableDictionary *encDict = [NSMutableDictionary dictionary];
					
					while ((attribute = [attributeEnum nextObject]))
						[encDict setObject:[attribute stringValue] forKey:[attribute name]];
					[dict setObject:encDict forKey:@"enclosure"];
					
				}
                else if ([name isEqualToString:@"pubDate"])
                {
					// pubDate is expected to be an NSDate by SUAppcastItem, but the RSS class was returning an NSString
					NSDate *date = [NSDate dateWithNaturalLanguageString:[node stringValue]];
					if (date)
						[dict setObject:date forKey:name];
				}
                else if (name != nil)
                {
					// add all other values as strings
					NSString *string = [[node stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					if (string)
						[dict setObject:string forKey:name];
				}
            }
            
			SUAppcastItem *anItem = [[SUAppcastItem alloc] initWithDictionary:dict];
            if (anItem)
            {
                [appcastItems addObject:anItem];
                [anItem release];
			}
            else
            {
				NSLog(@"Sparkle Updater: Failed to parse appcast item with appcast dictionary %@!", dict);
            }
            [nodesDict removeAllObjects];
            [dict removeAllObjects];
		}
	}
    
	if ([appcastItems count])
    {
		NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO] autorelease];
		[appcastItems sortUsingDescriptors:[NSArray arrayWithObject:sort]];
		items = [appcastItems copy];
	}
	
	if (failed)
    {
        [self reportError:[NSError errorWithDomain:SUSparkleErrorDomain code:SUAppcastParseError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:SULocalizedString(@"An error occurred while parsing the update feed.", nil), NSLocalizedDescriptionKey, nil]]];
	}
    else if ([delegate respondsToSelector:@selector(appcastDidFinishLoading:)])
    {
        [delegate appcastDidFinishLoading:self];
	}
}

- (void)download:(NSURLDownload *)aDownload didFailWithError:(NSError *)error
{
	[download release];
	download = nil;
    
	if (downloadFilename)
	{
#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
		[[NSFileManager defaultManager] removeFileAtPath:downloadFilename handler:nil];
#else
		[[NSFileManager defaultManager] removeItemAtPath:downloadFilename error:NULL];
#endif
	}
    [downloadFilename release];
    downloadFilename = nil;
    
	[self reportError:error];
}

- (NSURLRequest *)download:(NSURLDownload *)aDownload willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
	return request;
}

- (void)reportError:(NSError *)error
{
	if ([delegate respondsToSelector:@selector(appcast:failedToLoadWithError:)])
	{
		[delegate appcast:self failedToLoadWithError:[NSError errorWithDomain:SUSparkleErrorDomain code:SUAppcastError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:SULocalizedString(@"An error occurred in retrieving update information. Please try again later.", nil), NSLocalizedDescriptionKey, [error localizedDescription], NSLocalizedFailureReasonErrorKey, nil]]];
	}
}

- (NSXMLNode *)bestNodeInNodes:(NSArray *)nodes
{
	// We use this method to pick out the localized version of a node when one's available.
    if ([nodes count] == 1)
        return [nodes objectAtIndex:0];
    else if ([nodes count] == 0)
        return nil;
    
    NSEnumerator *nodeEnum = [nodes objectEnumerator];
    NSXMLElement *node;
    NSMutableArray *languages = [NSMutableArray array];
    NSString *lang;
    NSInteger i;
    while ((node = [nodeEnum nextObject]))
    {
        lang = [[node attributeForName:@"xml:lang"] stringValue];
        [languages addObject:(lang ?: @"")];
    }
    lang = [[NSBundle preferredLocalizationsFromArray:languages] objectAtIndex:0];
    i = [languages indexOfObject:([languages containsObject:lang] ? lang : @"")];
    if (i == NSNotFound)
        i = 0;
    return [nodes objectAtIndex:i];
}

- (void)setUserAgentString:(NSString *)uas
{
	if (uas != userAgentString)
	{
		[userAgentString release];
		userAgentString = [uas copy];
	}
}

- (void)setDelegate:del
{
	delegate = del;
}

@end
