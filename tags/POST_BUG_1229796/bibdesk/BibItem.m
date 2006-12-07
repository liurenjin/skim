//  BibItem.m
//  Created by Michael McCracken on Tue Dec 18 2001.
/*
 This software is Copyright (c) 2001,2002,2003,2004,2005
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "BibItem.h"

#define addkey(s) if([pubFields objectForKey: s] == nil){[pubFields setObject:[NSString stringWithString:@""] forKey: s];} [removeKeys removeObject: s];


#define isEmptyField(s) ([[[pubFields objectForKey:s] stringValue] isEqualToString:@""])

/* Fonts and paragraph styles cached for efficiency. */
static NSParagraphStyle* keyParagraphStyle = nil;
static NSParagraphStyle* bodyParagraphStyle = nil;
static BOOL paragraphStyleIsSetup = NO;

setupParagraphStyle()
{
    if(paragraphStyleIsSetup == NO){
        NSMutableParagraphStyle *defaultStyle = [[NSMutableParagraphStyle alloc] init];
        [defaultStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
        // ?        [defaultStyle setAlignment:NSLeftTextAlignment];
        keyParagraphStyle = [defaultStyle copy];
        [defaultStyle setHeadIndent:50];
        [defaultStyle setFirstLineHeadIndent:50];
        [defaultStyle setTailIndent:-30];
        bodyParagraphStyle = [defaultStyle copy];
        paragraphStyleIsSetup = YES;
    }
}

@implementation BibItem

- (id)init
{
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
	self = [self initWithType:[pw stringForKey:BDSKPubTypeStringKey]
									  fileType:BDSKBibtexString // Not Sure if this is good.
									 pubFields:nil
									   authors:nil
								   createdDate:[NSCalendarDate calendarDate]];
	if (self) {
        [self setHasBeenEdited:NO]; // set this here, since makeType: and updateMetadataForKey set it to YES
	}
	return self;
}

- (id)initWithType:(NSString *)type fileType:(NSString *)inFileType pubFields:(NSDictionary *)fieldsDict authors:(NSMutableArray *)authArray createdDate:(NSCalendarDate *)date{ // this is the designated initializer.
    if (self = [super init]){
		bibLock = [[NSLock alloc] init];
		[bibLock lock];
		if(fieldsDict){
			pubFields = [fieldsDict mutableCopy];
		}else{
			pubFields = [[NSMutableDictionary alloc] initWithCapacity:7];
		}
		if (date){
			NSString *nowStr = [date description];
			[pubFields setObject:nowStr forKey:BDSKDateCreatedString];
			[pubFields setObject:nowStr forKey:BDSKDateModifiedString];
        }
		if(authArray){
			pubAuthors = [authArray mutableCopy];     // copy, it's mutable
		}else{
			pubAuthors = [[NSMutableArray alloc] initWithCapacity:1];
		}
        document = nil;
        editorObj = nil;
        [bibLock unlock];
        [self setFileType:inFileType];
        [self makeType:type];
        [self setCiteKeyString: @"cite-key"];
        [self setDate: nil];
        [self setDateCreated: date];
        [self setDateModified: date];
		[self setNeedsToBeFiled:NO];
		[self updateMetadataForKey:nil];
        setupParagraphStyle();
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(typeInfoDidChange:)
													 name:BDSKBibTypeInfoChangedNotification
												   object:[BibTypeManager sharedManager]];
    }

    //NSLog(@"bibitem init");
    return self;
}

- (id)copyWithZone:(NSZone *)zone{
    BibItem *theCopy = [[[self class] allocWithZone: zone] initWithType:pubType
                                                               fileType:fileType
															  pubFields:pubFields
                                                                authors:pubAuthors
															createdDate:[NSCalendarDate calendarDate]];
    [theCopy setCiteKeyString: citeKey];
    [theCopy setDate: pubDate];
	
	[theCopy copyComplexStringValues];
	
    return theCopy;
}

- (id)initWithCoder:(NSCoder *)coder{
    self = [super init];
    [self setFileType:[coder decodeObjectForKey:@"fileType"]];
    [self setCiteKeyString:[coder decodeObjectForKey:@"citeKey"]];
    [self setDate:[coder decodeObjectForKey:@"pubDate"]];
    [self setDateCreated:[coder decodeObjectForKey:@"dateCreated"]];
    [self setDateModified:[coder decodeObjectForKey:@"dateModified"]];
    [self setType:[coder decodeObjectForKey:@"pubType"]];
    pubFields = [[coder decodeObjectForKey:@"pubFields"] retain];
    pubAuthors = [[coder decodeObjectForKey:@"pubAuthors"] retain];
    // set by the document, which we don't archive
    document = nil;
    editorObj = nil;
    setupParagraphStyle();
    hasBeenEdited = NO;
    bibLock = [[NSLock alloc] init]; // not encoded
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(typeInfoDidChange:)
												 name:BDSKBibTypeInfoChangedNotification
											   object:[BibTypeManager sharedManager]];
    
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
    [coder encodeObject:fileType forKey:@"fileType"];
    [coder encodeObject:citeKey forKey:@"citeKey"];
    [coder encodeObject:pubDate forKey:@"pubDate"];
    [coder encodeObject:dateCreated forKey:@"dateCreated"];
    [coder encodeObject:dateModified forKey:@"dateModified"];
    [coder encodeObject:pubType forKey:@"pubType"];
    [coder encodeObject:pubFields forKey:@"pubFields"];
    [coder encodeObject:pubAuthors forKey:@"pubAuthors"];
}

- (void)makeType:(NSString *)type{
    NSString *fieldString;
    NSEnumerator *e;
    NSString *tmp;
    BibTypeManager *typeMan = [BibTypeManager sharedManager];
    NSEnumerator *reqFieldsE = [[typeMan requiredFieldsForType:type] objectEnumerator];
    NSEnumerator *optFieldsE = [[typeMan optionalFieldsForType:type] objectEnumerator];
    NSEnumerator *defFieldsE = [[typeMan userDefaultFieldsForType:type] objectEnumerator];
    NSMutableArray *removeKeys = [[pubFields allKeysForObject:@""] mutableCopy];
  
    while(fieldString = [reqFieldsE nextObject]){
        addkey(fieldString)
    }
    while(fieldString = [optFieldsE nextObject]){
        addkey(fieldString)
    }
    while(fieldString = [defFieldsE nextObject]){
        addkey(fieldString)
    }    
    
    //I don't enforce Keywords, but since there's GUI depending on them, I will enforce these others:
    addkey(BDSKUrlString) addkey(BDSKLocalUrlString) addkey(BDSKAnnoteString) addkey(BDSKAbstractString) addkey(BDSKRssDescriptionString)

    // now remove everything that's left in remove keys from pubfields
    [pubFields removeObjectsForKeys:removeKeys usingLock:bibLock];
    [removeKeys release];
    // and don't forget to set what we say our type is:
    [self setType:type];
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#ifdef DEBUG
    NSLog([NSString stringWithFormat:@"bibitem Dealloc, rt: %d", [self retainCount]]);
#endif
    [[self undoManager] removeAllActionsWithTarget:self];
    [pubFields release];
    [pubAuthors release];

    [pubType release];
    [fileType release];
    [citeKey release];
    [pubDate release];
    [dateCreated release];
    [dateModified release];
    [bibLock release];
    [super dealloc];
}

- (BibDocument *)document {
    return document;
}

- (void)setDocument:(BibDocument *)newDocument {
    if (document != newDocument) {
		document = newDocument;
		[self updateComplexStringValues];
	}
}

- (NSUndoManager *)undoManager { // this may be nil
    return [document undoManager];
}

- (BibEditor *)editorObj{
    return editorObj; // if we haven't been given an editor object yet this should be nil.
}

- (void)setEditorObj:(BibEditor *)editor{
    editorObj = editor; // don't retain it- that will create a cycle!
}

- (NSString *)description{
    return [NSString stringWithFormat:@"%@ %@", [self citeKey], [pubFields description]];
}


- (BOOL)isEqual:(BibItem *)aBI{
    return [[self bibTeXStringUnexpandedAndDeTeXifiedWithoutInternalFields] isEqualToString:[aBI bibTeXStringUnexpandedAndDeTeXifiedWithoutInternalFields]];
}

- (unsigned)hash{
    return [citeKey hash];
}

#pragma mark Comparison functions
- (NSComparisonResult)pubTypeCompare:(BibItem *)aBI{
	return [[self type] localizedCaseInsensitiveCompare:[aBI type]];
}

- (NSComparisonResult)keyCompare:(BibItem *)aBI{
    return [citeKey localizedCaseInsensitiveNumericCompare:[aBI citeKey]];
}

- (NSComparisonResult)titleCompare:(BibItem *)aBI{
    return [[self title] localizedCaseInsensitiveCompare:[aBI title]];
}

- (NSComparisonResult)titleWithoutTeXCompare:(BibItem *)aBI{
    NSString *titleNoBraces = [[self title] stringByRemovingTeXForSorting];
    NSString *aBITitleNoBraces = [[aBI title] stringByRemovingTeXForSorting];
    return [titleNoBraces localizedCaseInsensitiveCompare:aBITitleNoBraces];
}

- (NSComparisonResult)containerWithoutTeXCompare:(BibItem *)aBI{
    NSString *containerNoBraces = [[self container] stringByRemovingTeXForSorting];
    NSString *aBIContainerNoBraces = [[aBI container] stringByRemovingTeXForSorting];
	
	//Handle special case of no container. - is a good display but we want it to sort to the bottom
	if ([containerNoBraces isEqualTo:@"-"]) {
		return NSOrderedDescending;
	} else if ([aBIContainerNoBraces isEqualTo:@"-"]) {
	    return NSOrderedAscending;
	}
    return [containerNoBraces localizedCaseInsensitiveCompare:aBIContainerNoBraces];
}

/* Helper method that treats all the special cases of nil values properly, by making them smaller than all other dates.	It is used by the comparison methods for creation, modification and publication date.
*/	
- (NSComparisonResult) compareCalendarDate:(NSCalendarDate*) myDate with:(NSCalendarDate*) otherDate {
	if (myDate) {
		// myDate is not nil
		if (otherDate) {
			// otherDate is not nil either => return standard date comparison result
			return [myDate compare:otherDate];
		}
		else {
			// i.e. otherDate is nil => otherDate is smaller than myDate
			return NSOrderedDescending;
		}
	}
	else {
		// i.e. myDate is nil
		if (otherDate) {
			// otherDate is not nil => otherDate is larger than myDate
			return NSOrderedAscending;
		}
		else {
				// i.e. both dates are nil, thus the same
			return NSOrderedSame;
		}
	}
}

	
- (NSComparisonResult)dateCompare:(BibItem *)aBI{
	return [self compareCalendarDate:[self date] with:[aBI date]];
}

- (NSComparisonResult)createdDateCompare:(BibItem *)aBI{
	return [self compareCalendarDate:dateCreated with:[aBI dateCreated]];
}

- (NSComparisonResult)modDateCompare:(BibItem *)aBI{
	return [self compareCalendarDate:dateModified with:[aBI dateModified]];
}



- (NSComparisonResult)auth1Compare:(BibItem *)aBI{
    if([[self pubAuthors] count] > 0){
        if([aBI numberOfAuthors] > 0){
            return [[self authorAtIndex:0] sortCompare:
                [aBI authorAtIndex:0]];
        }
        return NSOrderedAscending;
    }else{
        return NSOrderedDescending;
    }
}
- (NSComparisonResult)auth2Compare:(BibItem *)aBI{
    if([[self pubAuthors] count] > 1){
        if([aBI numberOfAuthors] > 1){
            return [[self authorAtIndex:1] sortCompare:
                [aBI authorAtIndex:1]];
        }
        return NSOrderedAscending;
    }else{
        return NSOrderedDescending;
    }
}
- (NSComparisonResult)auth3Compare:(BibItem *)aBI{
    if([[self pubAuthors] count] > 2){
        if([aBI numberOfAuthors] > 2){
            return [[self authorAtIndex:2] sortCompare:
                [aBI authorAtIndex:2]];
        }
        return NSOrderedAscending;
    }else{
        return NSOrderedDescending;
    }
}
- (NSComparisonResult)authorCompare:(BibItem *)aBI{
    return [[self bibTeXAuthorStringNormalized:YES] compare: [aBI bibTeXAuthorStringNormalized:YES]];
}

- (NSComparisonResult)fileOrderCompare:(BibItem *)aBI{
    int aBIOrd = [aBI fileOrder];
    int myFileOrder = [self fileOrder];
    if (myFileOrder == 0) return NSOrderedDescending; //@@ file order for crossrefs - here is where we would change to accommodate new pubs in crossrefs...
    if (myFileOrder < aBIOrd) {
        return NSOrderedAscending;
    }
    if (myFileOrder > aBIOrd){
        return NSOrderedDescending;
    }else{
        return NSOrderedSame;
    }
}

// accessors for fileorder
- (int)fileOrder{
    return [[document publications] indexOfObjectIdenticalTo:self] + 1;
}

- (NSString *)fileType { return fileType; }

- (void)setFileType:(NSString *)someFileType {
    [bibLock lock];
    [someFileType retain];
    [fileType release];
    fileType = someFileType;
    [bibLock unlock];
}

#pragma mark Author Handling code

- (int)numberOfAuthors{
	return [self numberOfAuthorsInheriting:YES];
}

- (int)numberOfAuthorsInheriting:(BOOL)inherit{
    return [[self pubAuthorsInheriting:inherit] count];
}

- (void)addAuthorWithName:(NSString *)newAuthorName{
    NSEnumerator *presentAuthE = nil;
    BibAuthor *bibAuthor = nil;
    BibAuthor *existingAuthor = nil;
  
    presentAuthE = [[[pubAuthors copy] autorelease] objectEnumerator];
    while(bibAuthor = [presentAuthE nextObject]){
        if([[bibAuthor name] isEqualToString:newAuthorName]){ // @@ TODO: fuzzy author handling
            [bibLock lock];
            existingAuthor = bibAuthor;
            [bibLock unlock];
        }
    }
    if(!existingAuthor){
        existingAuthor =  [BibAuthor authorWithName:newAuthorName andPub:self]; //@@author - why was andPub:nil before?!
        [pubAuthors addObject:existingAuthor usingLock:bibLock];
    }
    return;
}

- (NSArray *)pubAuthors{
	return [self pubAuthorsInheriting:YES];
}

- (NSArray *)pubAuthorsInheriting:(BOOL)inherit{
	BibItem *parent;
	
	if (inherit && [pubAuthors count] == 0 && 
		(parent = [self crossrefParent])) {
		return [parent pubAuthorsInheriting:NO];
	}
    return pubAuthors;
}

- (BibAuthor *)authorAtIndex:(int)index{ 
    return [self authorAtIndex:index inherit:YES];
}

- (BibAuthor *)authorAtIndex:(int)index inherit:(BOOL)inherit{ 
	NSMutableArray *auths = (NSMutableArray *)[self pubAuthorsInheriting:inherit];
	if ([auths count] > index)
        return [auths objectAtIndex:index usingLock:bibLock]; // not too nice. Is the lock necessary?
    else
        return nil;
}

- (void)setAuthorsFromBibtexString:(NSString *)aString{
    if ([self document])
		[[NSApp delegate] setDocumentForErrors:[self document]];
                
    char *str = nil;

    if (aString == nil) return;
    
    // we're supposed to collapse whitespace before using bt_split_name, and author names with surrounding whitespace don't display in the table (probably for that reason)
    aString = [aString stringByCollapsingWhitespaceAndRemovingSurroundingWhitespace];

    str = (char *)[aString UTF8String];
    
    bt_stringlist *sl = nil;
    int i=0;
#warning - Exception - might want to add an exception handler that notifies the user of the warning...
    [pubAuthors removeAllObjects];
    NSString *s;
    NSString *shortDescription = [NSString stringWithFormat:NSLocalizedString(@"reading authors string %@", @"need an string format specifier"), aString];
    sl = bt_split_list(str, "and", "BibTex Name", 0, (char *)[shortDescription UTF8String]);
    if (sl != nil) {
        for(i=0; i < sl->num_items; i++){
            if(sl->items[i] != nil){
                s = [NSString stringWithBytes:sl->items[i] encoding:NSUTF8StringEncoding];
                [self addAuthorWithName:s];
                
            }
        }
        bt_free_list(sl); // hey! got to free the memory!
    }
      //  NSLog(@"%@", pubAuthors);
}

- (NSString *)bibTeXAuthorString{
    return [self bibTeXAuthorStringNormalized:NO inherit:YES];
}

- (NSString *)bibTeXAuthorStringNormalized:(BOOL)normalized{ // used for save operations; returns names as "von Last, Jr., First" if normalized is YES
	return [self bibTeXAuthorStringNormalized:normalized inherit:YES];
}

- (NSString *)bibTeXAuthorStringNormalized:(BOOL)normalized inherit:(BOOL)inherit{ // used for save operations; returns names as "von Last, Jr., First" if normalized is YES
	NSArray *auths = [self pubAuthorsInheriting:inherit];
    
	if([auths count] == 0) return [NSString stringWithString:@""];
	
	NSEnumerator *authE = [auths objectEnumerator];
    BibAuthor *author;
	NSMutableArray *authNames = [NSMutableArray arrayWithCapacity:[auths count]];
	
	while(author = [authE nextObject]){
		[authNames addObject:(normalized ? [author normalizedName] : [author name])];
	}
	
	return [authNames componentsJoinedByString:@" and "];
}

- (BibItem *)crossrefParent{
	NSString *key = [pubFields objectForKey:BDSKCrossrefString];
	
	if (key == nil || [key isEqualToString:@""])
		return nil;
	
	return [document publicationForCiteKey:key];
}

// Container is an aspect of the BibItem that depends on the type of the item
// It is used only to have one column to show all these containers.
- (NSString *)container{
	NSString *c;
	
	if ( [[self type] isEqualToString:@"inbook"]) {
	    c = [self valueOfField:BDSKTitleString];
	} else if ( [[self type] isEqualToString:@"article"] ) {
		c = [self valueOfField:BDSKJournalString];
	} else if ( [[self type] isEqualToString:@"incollection"] || 
				[[self type] isEqualToString:@"inproceedings"] ||
				[[self type] isEqualToString:@"conference"] ) {
		c = [self valueOfField:BDSKBooktitleString];
	} else if ( [[self type] isEqualToString:@"commented"] ){
		c = [self valueOfField:BDSKVolumetitleString];
	} else if ( [[self type] isEqualToString:@"book"] ){
		c = [self valueOfField:BDSKSeriesString];
	} else {
		c = @"-"; //Container is empty for non-container types
	}
	// Check to see if the field for Container was empty
	// They are optional for some types
	if ([c isEqualToString:@""]) {
		c = @"-";
	}
	
	return c;
}

// this is used for the main table and lower pane and for various window titles
- (NSString *)title{
    NSString *title = [self valueOfField:BDSKTitleString];
	if (title == nil || [title isEqualToString:@""]) 
		title = @"Empty Title";
	if ([[self type] isEqualToString:@"inbook"]) {
		NSString *chapter = [self valueOfField:BDSKChapterString];
		if (![@"" isEqualToString:chapter] ) {
			return [NSString stringWithFormat:NSLocalizedString(@"%@ (chapter of %@)", @"Chapter of inbook (chapter of Title)"), chapter, title];
		}
		NSString *pages = [self valueOfField:BDSKPagesString];
		if (![@"" isEqualToString:pages]) {
			return [NSString stringWithFormat:NSLocalizedString(@"%@ (pp %@)", @"Title of inbook (pp Pages)"), title, pages];
		}
	}
	return title;
}

- (void)setDate: (NSCalendarDate *)newDate{
    [bibLock lock];
    [pubDate autorelease];
    pubDate = [newDate copy];
    [bibLock unlock];
    
}

- (NSCalendarDate *)date{
    return [self dateInheriting:YES];
}

- (NSCalendarDate *)dateInheriting:(BOOL)inherit{
    BibItem *parent;
	
	if(inherit && pubDate == nil && (parent = [self crossrefParent])) {
		return [parent dateInheriting:NO];
	}
	return pubDate;
}

- (NSCalendarDate *)dateCreated {
    return [[dateCreated retain] autorelease];
}

- (void)setDateCreated:(NSCalendarDate *)newDateCreated {
    [bibLock lock];
    if (dateCreated != newDateCreated) {
        [dateCreated release];
        dateCreated = [newDateCreated copy];
    }
    [bibLock unlock];
}

- (NSCalendarDate *)dateModified {
    return [[dateModified retain] autorelease];
}

- (void)setDateModified:(NSCalendarDate *)newDateModified {
    [bibLock lock];
    if (dateModified != newDateModified) {
        [dateModified release];
        dateModified = [newDateModified copy];
    }
    [bibLock unlock];
}

- (NSString *)calendarDateDescription{
	return [[self date] descriptionWithCalendarFormat:@"%B %Y"];
}

- (NSString *)calendarDateModifiedDescription{
	NSString *shortDateFormatString = [[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString];
    return [[self dateModified] descriptionWithCalendarFormat:shortDateFormatString];
}

- (NSString *)calendarDateCreatedDescription{
	NSString *shortDateFormatString = [[NSUserDefaults standardUserDefaults] stringForKey:NSShortDateFormatString];
	return [[self dateCreated] descriptionWithCalendarFormat:shortDateFormatString];
}

- (void)setType: (NSString *)newType{
    [bibLock lock];
    [pubType autorelease];
    pubType = [[newType lowercaseString] retain];
    [self setHasBeenEdited:YES];
    [bibLock unlock];
}
- (NSString *)type{
    return pubType;
}

- (void)setHasBeenEdited:(BOOL)yn{
    //NSLog(@"set has been edited %@", (yn)?@"YES":@"NO");
    hasBeenEdited = yn;
}

- (BOOL)hasBeenEdited{
    return hasBeenEdited;
}

- (NSString *)suggestedCiteKey
{
	NSString *citeKeyFormat = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKCiteKeyFormatKey];
	NSString *ck = [[BDSKFormatParser sharedParser] parseFormat:citeKeyFormat forField:BDSKCiteKeyString ofItem:self];
	if ([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKCiteKeyLowercaseKey]) {
		ck = [ck lowercaseString];
	}
	return ck;
}

- (BOOL)canSetCiteKey
{
	if ([[NSApp delegate] requiredFieldsForCiteKey] == nil)
		return NO;
	
	NSEnumerator *fEnum = [[[NSApp delegate] requiredFieldsForCiteKey] objectEnumerator];
	NSString *fieldName;
	NSString *fieldValue = [self citeKey];
	
	if (fieldValue != nil && ![fieldValue isEqualToString:@""] && ![fieldValue isEqualToString:@"cite-key"]) {
		return NO;
	}
	while (fieldName = [fEnum nextObject]) {
		fieldValue = [self valueOfField:fieldName];
		if (fieldValue == nil || [fieldValue isEqualToString:@""]) {
			return NO;
		}
	}
	return YES;
}

- (void)setCiteKey:(NSString *)newCiteKey{
    [self setCiteKey:newCiteKey withModDate:[NSCalendarDate date]];
}

- (void)setCiteKey:(NSString *)newCiteKey withModDate:(NSCalendarDate *)date{
    if ([self undoManager]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setCiteKey:citeKey 
															  withModDate:[self dateModified]];
    }
    NSString *oldCiteKey = [citeKey copy];
	
    [self setCiteKeyString:newCiteKey];
	if (date != nil) {
		[pubFields setObject:[date description] forKey:BDSKDateModifiedString usingLock:bibLock];
	} else {
		[pubFields removeObjectForKey:BDSKDateModifiedString usingLock:bibLock];
	}
	[self updateMetadataForKey:BDSKCiteKeyString];
		
    NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:citeKey, @"value", BDSKCiteKeyString, @"key", document, @"document", oldCiteKey, @"oldCiteKey", nil];
    [oldCiteKey release];
    NSNotification *aNotification = [NSNotification notificationWithName:BDSKBibItemChangedNotification
                                                                  object:self
                                                                userInfo:notifInfo];
    // Queue the notification, since this can be expensive when opening large files
    [[NSNotificationQueue defaultQueue] enqueueNotification:aNotification
                                               postingStyle:NSPostWhenIdle
                                               coalesceMask:NSNotificationCoalescingOnName
                                                   forModes:nil];
}

- (void)setCiteKeyString:(NSString *)newCiteKey{
    [bibLock lock];
    [citeKey autorelease];
    citeKey = [newCiteKey copy];
    [bibLock unlock];
}

- (NSString *)citeKey{
    if(!citeKey){
        [self setCiteKeyString:@""]; 
    }
    return citeKey;
}

- (void)setPubFields: (NSDictionary *)newFields{
    if(newFields != pubFields){
        [bibLock lock];
        [pubFields release];
        pubFields = [newFields mutableCopy];
        [bibLock unlock];
        [self updateMetadataForKey:nil];
    }
}

- (void)setFields: (NSDictionary *)newFields{
	if(![newFields isEqualToDictionary:pubFields]){
		if ([self undoManager]) {
			[[[self undoManager] prepareWithInvocationTarget:self] setFields:pubFields];
		}
		
		[self setPubFields:newFields];
		
		NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Add/Del Fields", @"type", document, @"document", nil]; // cmh: maybe not the best info, but handled correctly
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
															object:self
														  userInfo:notifInfo];
    }
}

- (void)copyComplexStringValues{
	NSEnumerator *fEnum = [pubFields keyEnumerator];
	NSString *field;
	NSString *value;
	BDSKComplexString *complexValue;
	
	while (field = [fEnum nextObject]) {
		value = [pubFields objectForKey:field];
		if ([value isComplex]) {
			complexValue = [[(BDSKComplexString*)value copy] autorelease];
			[complexValue setMacroResolver:[self document]];
			[pubFields setObject:complexValue forKey:field];
		}
	}
}

- (void)updateComplexStringValues{
	NSEnumerator *fEnum = [pubFields keyEnumerator];
	NSString *field;
	NSString *value;
	
	while (field = [fEnum nextObject]) {
		value = [pubFields objectForKey:field];
		if ([value isComplex]) {
			[(BDSKComplexString*)value setMacroResolver:[self document]];
		}
	}
}

- (void)updateMetadataForKey:(NSString *)key{
    
    [self setHasBeenEdited:YES];

    if (key == nil || [BDSKAuthorString isEqualToString:key] || [BDSKEditorString isEqualToString:key]) {
		if((![@"" isEqualToString:[pubFields objectForKey: BDSKAuthorString usingLock:bibLock]]) && 
		   ([pubFields objectForKey: BDSKAuthorString usingLock:bibLock] != nil))
		{
			[self setAuthorsFromBibtexString:[pubFields objectForKey: BDSKAuthorString usingLock:bibLock]];
		}else{
			[self setAuthorsFromBibtexString:[pubFields objectForKey: BDSKEditorString usingLock:bibLock]]; // or what else?
		}
	}
	
	if([BDSKLocalUrlString isEqualToString:key]){
		[self setNeedsToBeFiled:NO];
	}
	
	if([BDSKTitleString isEqualToString:key] &&
	   [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKDuplicateBooktitleKey] &&
	   [[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKTypesForDuplicateBooktitleKey] containsObject:[self type]]){
		NSString *title = [pubFields objectForKey:BDSKTitleString];
		
		if((title && ![title isEqualToString:@""])){
			NSString *booktitle = [pubFields objectForKey:BDSKBooktitleString];
			if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKForceDuplicateBooktitleKey] ||
			   (booktitle == nil || [booktitle isEqualToString:@""])){
				if(booktitle == nil)
					[self addField:BDSKBooktitleString];
				[self setField:BDSKBooktitleString toValue:title];
			}
		}
	}
	
    // re-call make type to make sure we still have all the appropriate bibtex defined fields...
    // but only if we have set the full pubFields array, as we should not be able to remove necessary fields.
	//@@ 3/5/2004: moved why is this here? 
	if(key == nil){
		[self makeType:[self type]];
	}

    static NSDictionary *locale = nil;
    if(locale = nil)
        locale = [[NSDictionary alloc] initWithObjectsAndKeys:@"MDYH", NSDateTimeOrdering, 
                                    [NSArray arrayWithObjects:@"January", @"February", @"March", @"April", @"May", @"June", @"July", @"August", @"September", @"October", @"November", @"December", nil], NSMonthNameArray,
                                    [NSArray arrayWithObjects:@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun", @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec", nil], NSShortMonthNameArray, nil];
    
    if (key == nil || [BDSKYearString isEqualToString:key] || [BDSKMonthString isEqualToString:key]) {
		NSString *yearValue = [pubFields objectForKey:BDSKYearString usingLock:bibLock];
		if (yearValue && ![yearValue isEqualToString:@""]) {
			NSString *monthValue = [pubFields objectForKey:BDSKMonthString usingLock:bibLock];
			if([monthValue isComplex])
				monthValue = [[(BDSKComplexString *)monthValue nodes] objectAtIndex:0];
			if (!monthValue) monthValue = @"";
			NSString *dateStr = [NSString stringWithFormat:@"%@ 1 %@", monthValue, [pubFields objectForKey:BDSKYearString usingLock:bibLock]];
			[self setDate:[NSCalendarDate dateWithNaturalLanguageString:dateStr locale:locale]];
		}else{
			[self setDate:nil];    // nil means we don't have a good date.
		}
	}
	
    if (key == nil || [BDSKDateCreatedString isEqualToString:key]) {
		NSString *dateCreatedValue = [pubFields objectForKey:BDSKDateCreatedString usingLock:bibLock];
		if (dateCreatedValue && ![dateCreatedValue isEqualToString:@""]) {
			[self setDateCreated:[NSCalendarDate dateWithNaturalLanguageString:dateCreatedValue]];
		}else{
			[self setDateCreated:nil];
		}
	}
	
    // we shouldn't check for the key here, as the DateModified can be set with any key
	NSString *dateModValue = [pubFields objectForKey:BDSKDateModifiedString usingLock:bibLock];
    if (dateModValue && ![dateModValue isEqualToString:@""]) {
		// NSLog(@"updating date %@", dateModValue);
		[self setDateModified:[NSCalendarDate dateWithNaturalLanguageString:dateModValue]];
	}else{
		[self setDateModified:nil];
	}
    	
}

- (void)setField: (NSString *)key toValue: (NSString *)value{
	[self setField:key toValue:value withModDate:[NSCalendarDate date]];
}

- (void)setField:(NSString *)key toValue:(NSString *)value withModDate:(NSCalendarDate *)date{
    
	if ([self undoManager]) {
		id oldValue = [pubFields objectForKey:key usingLock:bibLock];
		NSCalendarDate *oldModDate = [self dateModified];
		
		[[[self undoManager] prepareWithInvocationTarget:self] setField:key 
														 toValue:oldValue
													 withModDate:oldModDate];
	}
	
    [pubFields setObject:value forKey:key usingLock:bibLock];
	if (date != nil) {
		[pubFields setObject:[date description] forKey:BDSKDateModifiedString usingLock:bibLock];
	} else {
		[pubFields removeObjectForKey:BDSKDateModifiedString usingLock:bibLock];
	}
	[self updateMetadataForKey:key];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:value, @"value", key, @"key", @"Change", @"type",document, @"document",nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
														object:self
													  userInfo:notifInfo];
    // to allow autocomplete:
	[[NSApp delegate] addString:value forCompletionEntry:key];
}

// for 10.2
- (id)handleQueryWithUnboundKey:(NSString *)key{
    return [self valueForUndefinedKey:key];
}

- (id)valueForUndefinedKey:(NSString *)key{
    id obj = [pubFields objectForKey:key usingLock:bibLock];
    if (obj != nil){
        return obj;
    }else{
        // handle 10.2
        if ([super respondsToSelector:@selector(valueForUndefinedKey:)]){
            return [super valueForUndefinedKey:key];
        }else{
            return [super handleQueryWithUnboundKey:key];
        }
    }
}

- (NSString *)valueOfField: (NSString *)key{
	return [self valueOfField:key inherit:YES];
}

- (NSString *)valueOfField: (NSString *)key inherit: (BOOL)inherit{
    NSString* value = [pubFields objectForKey:key usingLock:bibLock];
	
	if (inherit && (value == nil || [value isEqualToString:@""])) {
		BibItem *parent = [self crossrefParent];
		if (parent) {
			NSString *parentValue = [parent valueOfField:key inherit:NO];
			if (parentValue && ![parentValue isEqualToString:@""])
				return [NSString stringWithInheritedValue:parentValue];
		}
	}
	
	return [[value retain] autorelease];
}

- (NSString *)acronymValueOfField:(NSString *)key{
    NSMutableString *result = [NSMutableString string];
    NSArray *allComponents = [[self valueOfField:key] componentsSeparatedByString:@" "]; // single whitespace
    NSEnumerator *e = [allComponents objectEnumerator];
    NSString *component = nil;
    
    while(component = [e nextObject]){
        if(![component isEqualToString:@""]) // stringByTrimmingCharactersInSet will choke on an empty string
            component = [component stringByTrimmingCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
        if([component length] > 3){
            [result appendString:[[component substringToIndex:1] uppercaseString]];
        }
    }
    return result;
}

- (void)addField:(NSString *)key{
	[self addField:key withModDate:[NSCalendarDate date]];
}

- (void)addField:(NSString *)key withModDate:(NSCalendarDate *)date{
	if ([self undoManager]) {
		[[[self undoManager] prepareWithInvocationTarget:self] removeField:key
														withModDate:[self dateModified]];
	}
	
	NSString *msg = [NSString stringWithFormat:@"%@ %@",
		NSLocalizedString(@"Add data for field:", @""), key];
	[pubFields setObject:msg forKey:key usingLock:bibLock];
	
	if (date != nil) {
		[pubFields setObject:[date description] forKey:BDSKDateModifiedString usingLock:bibLock];
	} else {
		[pubFields removeObjectForKey:BDSKDateModifiedString usingLock:bibLock];
	}
	[self updateMetadataForKey:key];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Add/Del Field", @"type",document, @"document", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
														object:self
													  userInfo:notifInfo];

}

- (void)removeField: (NSString *)key{
	[self removeField:key withModDate:[NSCalendarDate date]];
}

- (void)removeField: (NSString *)key withModDate:(NSCalendarDate *)date{
	
	if ([self undoManager]) {
		[[[self undoManager] prepareWithInvocationTarget:self] addField:key
													 withModDate:[self dateModified]];
	}
	
    [pubFields removeObjectForKey:key usingLock:bibLock];
	
	if (date != nil) {
		[pubFields setObject:[date description] forKey:BDSKDateModifiedString usingLock:bibLock];
	} else {
		[pubFields removeObjectForKey:BDSKDateModifiedString usingLock:bibLock];
	}
	[self updateMetadataForKey:key];

	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Add/Del Field", @"type",document, @"document", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification
														object:self
													  userInfo:notifInfo];
	
}

- (NSMutableDictionary *)pubFields{
    return [[pubFields retain] autorelease];
}

- (NSData *)PDFValue{
    // Obtain the PDF of a bibtex formatted version of the bibtex entry as is.
    //* we won't be doing this on a per-item basis. this is deprecated. */
    return [[self title] dataUsingEncoding:NSUnicodeStringEncoding allowLossyConversion:YES];
}

- (NSData *)RTFValue{
    NSAttributedString *aStr = [self attributedStringValue];
    return [aStr RTFFromRange:NSMakeRange(0,[aStr length]) documentAttributes:nil];
}

- (NSAttributedString *)attributedStringValue{
    NSString *key;
    NSEnumerator *e = [[[pubFields allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] objectEnumerator];
    NSDictionary *cachedFonts = [[BDSKFontManager sharedFontManager] cachedFontsForPreviewPane];

    NSDictionary *titleAttributes =
        [NSDictionary dictionaryWithObjectsAndKeys:[cachedFonts objectForKey:@"Title"], NSFontAttributeName, 
												   keyParagraphStyle, NSParagraphStyleAttributeName, nil];

    NSDictionary *typeAttributes =
        [NSDictionary dictionaryWithObjectsAndKeys:[cachedFonts objectForKey:@"Type"], NSFontAttributeName, 
		                                           [NSColor colorWithCalibratedWhite:0.4 alpha:1.0], NSForegroundColorAttributeName, nil];

    NSDictionary *keyAttributes =
        [NSDictionary dictionaryWithObjectsAndKeys:[cachedFonts objectForKey:@"Key"], NSFontAttributeName, 
												   keyParagraphStyle, NSParagraphStyleAttributeName, nil];

    NSDictionary *bodyAttributes =
        [NSDictionary dictionaryWithObjectsAndKeys:[cachedFonts objectForKey:@"Body"], NSFontAttributeName, 
												   bodyParagraphStyle, NSParagraphStyleAttributeName, nil];

    NSMutableAttributedString* reqStr = [[NSMutableAttributedString alloc] init];
    NSMutableAttributedString* nonReqStr = [[NSMutableAttributedString alloc] init];
	NSAttributedString *valueStr;

	NSSet *reqKeys = [NSSet setWithArray:[[BibTypeManager sharedManager] requiredFieldsForType:[self type]]];

    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] initWithDateFormat:[[NSUserDefaults standardUserDefaults] objectForKey:NSDateFormatString]
															 allowNaturalLanguage:NO] autorelease];
    
    [reqStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",[self citeKey]]
                                                                    attributes:typeAttributes] autorelease]];
    
    [reqStr appendAttributedString:[self attributedStringByParsingTeX:[self title] inField:@"Title" defaultStyle:keyParagraphStyle collapse:YES]];
    
    [reqStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" (%@)\n",[self type]] 
																	attributes:typeAttributes] autorelease]];

    while(key = [e nextObject]){
        if(![[self valueOfField:key] isEqualToString:@""] &&
           ![key isEqualToString:BDSKTitleString]){
			
			if([key isEqualToString:BDSKDateCreatedString] || 
			   [key isEqualToString:BDSKDateModifiedString]){
				NSCalendarDate *date = [NSCalendarDate dateWithNaturalLanguageString:[self valueOfField:key inherit:NO]];

				valueStr = [[NSAttributedString alloc] initWithString:[dateFormatter stringForObjectValue:date]
														   attributes:bodyAttributes];

			}else if([key isEqualToString:BDSKAuthorString]){
				NSString *authors = [[self bibTeXAuthorString] stringByRemovingCurlyBraces];

				valueStr = [[NSAttributedString alloc] initWithString:authors
														   attributes:bodyAttributes];

			}else if([key isEqualToString:BDSKLocalUrlString]){
				NSString *path = [[self localURLPath] stringByAbbreviatingWithTildeInPath];

				valueStr = [[NSAttributedString alloc] initWithString:path
														   attributes:bodyAttributes];

			}else{
				BOOL notAnnoteOrAbstract = !([key isEqualToString:BDSKAnnoteString] || [key isEqualToString:BDSKAbstractString]);
				
				valueStr = [[self attributedStringByParsingTeX:[self valueOfField:key inherit:notAnnoteOrAbstract] inField:@"Body" defaultStyle:bodyParagraphStyle collapse:notAnnoteOrAbstract] retain];
			}
			
            if([reqKeys containsObject:key]){
				
                [reqStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",key]
                                                                                attributes:keyAttributes] autorelease]];
				[reqStr appendAttributedString:valueStr];
				[reqStr appendString:@"\n"];
				
			}else{
				
                [nonReqStr appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n",key]
																				   attributes:keyAttributes] autorelease]];
				[nonReqStr appendAttributedString:valueStr];
				[nonReqStr appendString:@"\n"];
				
            }
			
			[valueStr release];
        }
    }

    // now put them together
	[reqStr appendAttributedString:nonReqStr];
	[reqStr appendAttributedString:[[[NSAttributedString alloc] initWithString:@" "
                                                                  attributes:nil] autorelease]];
	[nonReqStr release];
    return 	[reqStr autorelease];
}

- (NSAttributedString *)attributedStringByParsingTeX:(NSString *)texStr inField:(NSString *)field defaultStyle:(NSParagraphStyle *)defaultStyle collapse:(BOOL)collapse{
    
    // get rid of whitespace if we have to; we can't use this on the attributed string's content store, though
    if(collapse){
        if([texStr isComplex])
            texStr = [NSString stringWithString:texStr];
        texStr = [texStr fastStringByCollapsingWhitespaceAndRemovingSurroundingWhitespace];
    }
    
    NSString *texStyle = nil;    
    BDSKFontManager *fontManager = [BDSKFontManager sharedFontManager];
    NSFont *font = [[fontManager cachedFontsForPreviewPane] objectForKey:field];
    
    // set up the attributed string now, so we can start working with its character contents
    NSDictionary *attrs = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:font, defaultStyle, nil]
                                                      forKeys:[NSArray arrayWithObjects:NSFontAttributeName, NSParagraphStyleAttributeName, nil]];
    NSMutableAttributedString *mas = [[NSMutableAttributedString alloc] initWithString:texStr attributes:attrs]; // set the whole thing up with default attrs

    NSMutableString *mutableString = [mas mutableString];
        
    NSRange searchRange = NSMakeRange(0, [mutableString length]); // starting value; changes as we change the string
    NSRange cmdRange;
    NSRange styleRange;
    unsigned startLoc; // starting character index to apply tex attributes
    unsigned endLoc;   // ending index to apply tex attributes
    
    while( (cmdRange = [mutableString rangeOfTeXCommandInRange:searchRange]).location != NSNotFound){
        
        // find the command
        texStyle = [mutableString substringWithRange:cmdRange];
        //NSLog(@"cmd is %@", texStyle);
        font = [fontManager convertFont:font
                            toHaveTrait:([fontManager fontTraitMaskForTeXStyle:texStyle])];
        //NSLog(@"using font %@", font);
        attrs = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:font, defaultStyle, nil]
                                            forKeys:[NSArray arrayWithObjects:NSFontAttributeName, NSParagraphStyleAttributeName, nil]];
        
        // delete the command, now that we know what it was
        [mutableString deleteCharactersInRange:cmdRange];
        
        // what does the command affect?
        startLoc = cmdRange.location;  // remember, we deleted our command, but not the brace
        if([mutableString characterAtIndex:startLoc] == '{' && (endLoc = [mutableString indexOfRightBraceMatchingLeftBraceAtIndex:startLoc]) != NSNotFound){
            styleRange = NSMakeRange(startLoc + 1, (endLoc - startLoc - 1));
            //NSLog(@"applying to %@", [mutableString substringWithRange:styleRange]);
            [mas setAttributes:attrs range:styleRange];
        }
        // new range, since we've altered the string
        searchRange = NSMakeRange(startLoc, [mutableString length] - startLoc);
    }
    
    static NSCharacterSet *braceSet = nil;
    if(braceSet == nil)
        braceSet = [[NSCharacterSet characterSetWithCharactersInString:@"}{"] retain];

    [mutableString replaceAllOccurrencesOfCharactersInSet:braceSet withString:@""];
        
    return [mas autorelease];
}

- (NSString *)RISStringValue{
    NSString *k;
    NSString *v;
    NSMutableString *s = [[[NSMutableString alloc] init] autorelease];
    NSMutableArray *keys = [[pubFields allKeys] mutableCopy];
    [keys sortUsingSelector:@selector(caseInsensitiveCompare:)];
    [keys removeObject:BDSKDateCreatedString];
    [keys removeObject:BDSKDateModifiedString];
    [keys removeObject:BDSKLocalUrlString];

    BibTypeManager *btm = [BibTypeManager sharedManager];
    
    // get the type, which may exist in pubFields if this was originally an RIS import; we must have only _one_ TY field,
    // since they mark the beginning of each entry
    NSString *risType = [pubFields objectForKey:@"TY"];
    if(risType)
        [keys removeObject:@"TY"];
    else
        risType = [btm RISTypeForBibTeXType:[self type]];
    
    // enumerate the remaining keys
    NSEnumerator *e = [keys objectEnumerator];
	[keys release];
    
    [s appendFormat:@"TY  - %@\n", risType];
    
    while(k = [e nextObject]){
        v = [pubFields objectForKey:k];
        NSString *valString;
        
        if([k isEqualToString:BDSKAuthorString]){
            NSArray *auths = [v componentsSeparatedByString:@" and "];
            NSEnumerator *authE = [auths objectEnumerator];
            NSString *auth = nil;
            unsigned  authCount = 1;
            while(auth = [authE nextObject]){
                [s appendFormat:@"A%i  - %@\n", authCount, [auth stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                authCount ++;
            }
        }
        
        if(![v isEqualToString:@""])
            [s appendFormat:@"%@  - %@\n", [btm RISTagForBibTeXFieldName:k], [v stringByRemovingTeX]]; // this won't help with math, but removing $^_ is probably not a good idea
    }
    [s appendString:@"ER  - \n"];
    return s;
}

#pragma mark BibTeX strings

- (NSString *)bibTeXStringByExpandingMacros:(BOOL)expand dropInternal:(BOOL)drop texify:(BOOL)shouldTeXify{
	NSMutableSet *knownKeys = [NSMutableSet set];
	NSString *k;
    NSString *v;
    NSMutableString *s = [[[NSMutableString alloc] init] autorelease];
    NSMutableArray *keys = [[pubFields allKeys] mutableCopy];
	NSEnumerator *e;
	
	[keys sortUsingSelector:@selector(caseInsensitiveCompare:)];
	if ([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKSaveAnnoteAndAbstractAtEndOfItemKey]) {
		NSArray *finalKeys = [NSArray arrayWithObjects:BDSKAbstractString, BDSKAnnoteString, nil];
		[keys removeObjectsInArray:finalKeys]; // make sure these fields are at the end, as they can be long
		[keys addObjectsFromArray:finalKeys];
	}
	if (drop) {
		BibTypeManager *btm = [BibTypeManager sharedManager];
		[knownKeys addObjectsFromArray:[btm requiredFieldsForType:[self type]]];
		[knownKeys addObjectsFromArray:[btm optionalFieldsForType:[self type]]];
		[knownKeys addObjectsFromArray:[btm userDefaultFieldsForType:[self type]]];
	}
	e = [keys objectEnumerator];
	[keys release];

    //build BibTeX entry:
    [s appendString:@"@"];
    
    NSAssert1(pubType != nil, @"Tried to append a nil pubtype in %@.  You will need to quit and relaunch BibDesk after fixing the error manually.", self );
    
    [s appendString:pubType];
    [s appendString:@"{"];
    [s appendString:[self citeKey]];
    while(k = [e nextObject]){
		if (drop && ![knownKeys containsObject:k])
			continue;
		
        v = [pubFields objectForKey:k];
        NSString *valString;
        
		if([k isEqualToString:BDSKAuthorString] && 
		   [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldSaveNormalizedAuthorNamesKey] && 
		   ![v isComplex]){ // only if it's not complex, use the normalized author name
		    if(![v isEqualToString:@""]) // pubAuthors will have an editor if no authors exist, but editors can't be written out as authors
			v = [self bibTeXAuthorStringNormalized:YES inherit:NO];
		}
		
		if(shouldTeXify &&
		   ![k isEqualToString:BDSKLocalUrlString] &&
		   ![k isEqualToString:BDSKUrlString]){
			
			NS_DURING
				v = [[BDSKConverter sharedConverter] stringByTeXifyingString:v];
			NS_HANDLER
				if([[localException name] isEqualToString:BDSKTeXifyException]){
					int i = NSRunAlertPanel(NSLocalizedString(@"Character Conversion Error", @"Title of alert when an error happens"),
											[NSString stringWithFormat: NSLocalizedString(@"An unrecognized character in the \"%@\" field of \"%@\" could not be converted to TeX.", @"Informative alert text when the error happens."), k, [self citeKey]],
											nil, nil, nil, nil);
				}
                                [localException raise]; // re-raise; we localized the error, but the sender needs to know we failed
			NS_ENDHANDLER
							
		}                
		
        if(expand == YES)
            valString = [v stringAsExpandedBibTeXString];
        else
            valString = [v stringAsBibTeXString];
        
        if(![v isEqualToString:@""]){
            [s appendString:@",\n\t"];
            [s appendFormat:@"%@ = ",k];
            [s appendString:valString];
        }
    }
    [s appendString:@"}"];
    return s;
}

- (NSString *)bibTeXStringByExpandingMacros:(BOOL)expand dropInternal:(BOOL)drop{
    BOOL shouldTeXify = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey];
    return [self bibTeXStringByExpandingMacros:expand dropInternal:drop texify:shouldTeXify];
}

- (NSString *)bibTeXString{
	return [self bibTeXStringByExpandingMacros:NO dropInternal:NO];
}

- (NSString *)bibTeXStringDroppingInternal:(BOOL)drop{
	return [self bibTeXStringByExpandingMacros:NO dropInternal:drop];
}

- (NSString *)bibTeXStringByExpandingMacros{
    return [self bibTeXStringByExpandingMacros:YES dropInternal:NO];
}

- (NSString *)bibTeXStringUnexpandedAndDeTeXifiedWithoutInternalFields{
    return [self bibTeXStringByExpandingMacros:NO dropInternal:YES texify:NO];
}

#warning not currently XML entity-escaped !!
- (NSString *)MODSString{
    NSDictionary *genreForTypeDict = [[BibTypeManager sharedManager] MODSGenresForBibTeXType:pubType];
    NSMutableString *s = [NSMutableString stringWithString:@"<mods>"];
    unsigned i = 0;
    
    [s appendFormat:@"<titleInfo> <title>%@ </title>", [self valueOfField:BDSKTitleString]];
    
    // note: may in the future want to output subtitles.

    [s appendString:@"</titleInfo>\n"];
    
    foreach (author, pubAuthors){
        [s appendString:[author MODSStringWithRole:BDSKAuthorString]];
        [s appendString:@"\n"];
    }

    // NOTE: this isn't always text. what are the special case pubtypes?
    [s appendString:@"<typeOfResource>text</typeOfResource>"];
    
    NSArray *genresForSelf = [genreForTypeDict objectForKey:@"self"];
    if(genresForSelf){
        for(i = 0; i < [genresForSelf count]; i++){
            [s appendFormat:@"<genre>%@</genre>", [genresForSelf objectAtIndex:i]];
        }
    }

    // HOST INFO
    NSArray *genresForHost = [genreForTypeDict objectForKey:@"host"];
    if(genresForHost){
        [s appendString:@"<relatedItem type=\"host\">"];
        
        NSString *hostTitle = nil;
        
        if([pubType isEqualToString:@"inproceedings"] || 
           [pubType isEqualToString:@"incollection"]){
            hostTitle = [self valueOfField:BDSKBooktitleString];
        }else if([pubType isEqualToString:@"article"]){
            hostTitle = [self valueOfField:BDSKJournalString];
        }
        [s appendFormat:@"<titleInfo><title>%@</title></titleInfo>", (hostTitle ? hostTitle : @"unknown")];
        
        [s appendString:@"</relatedItem>"];
    }

    [s appendFormat:@"<identifier type=\"citekey\">%@</identifier>", [self citeKey]];
    
    [s appendString:@"</mods>"];
    return [[s copy] autorelease];
}

- (NSString *)RSSValue{
    NSMutableString *s = [[[NSMutableString alloc] init] autorelease];

    NSString *descField = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKRSSDescriptionFieldKey];

    [s appendString:@"<item>\n"];
    [s appendString:@"<description>\n"];
    if([self valueOfField:descField]){
        [s appendString:[[self valueOfField:descField] xmlString]];
    }
    [s appendString:@"</description>\n"];
    [s appendString:@"<link>"];
    [s appendString:[self valueOfField:BDSKUrlString]];
    [s appendString:@"</link>\n"];
    //[s appendString:@"<bt:source><![CDATA[\n"];
    //    [s appendString:[[self bibTeXString] xmlString]];
    //    [s appendString:@"]]></bt:source>\n"];
    [s appendString:@"</item>\n"];
    return s;
}

- (NSString *)HTMLValueUsingTemplateString:(NSString *)templateString{
    return [templateString stringByParsingTagsWithStartDelimeter:@"<$" endDelimeter:@"/>" usingObject:self];
}

- (NSString *)allFieldsString{
    NSMutableString *result = [[[NSMutableString alloc] init] autorelease];
    
    [result appendString:[self citeKey]];
    [result appendString:@" "];
    
    BibItem *parent = [self crossrefParent];
    // if it has a parent, find all the available keys, and use valueOfField: to get either the
    // child object or parent object value. Inherit only the fields of the parent relevant for the item.
    if(parent){
        NSEnumerator *keyEnum = [pubFields keyEnumerator];
        NSString *key = nil;
        
        while(key = [keyEnum nextObject]){
            [result appendString:[self valueOfField:key inherit:YES]];
            [result appendString:@" "];
        }
        
    } else {
        NSEnumerator *pubFieldsE = [pubFields objectEnumerator];
        NSString *field = nil;
        
        while(field = [pubFieldsE nextObject]){
            [result appendString:field];
            [result appendString:@" "];
        }
    }        
    return result;
}

- (NSString *)localURLPath{
	return [self localURLPathInheriting:YES];
}

- (NSString *)localURLPathInheriting:(BOOL)inherit{
	return [self localURLPathRelativeTo:[[document fileName] stringByDeletingLastPathComponent] inherit:inherit];
}

- (NSString *)localURLPathRelativeTo:(NSString *)base inherit:(BOOL)inherit{
    NSURL *localURL = nil;
    NSString *localURLFieldValue = [self valueOfField:BDSKLocalUrlString inherit:inherit];
    
    if (!localURLFieldValue || [localURLFieldValue isEqualToString:@""]) return nil;
        
    if(![localURLFieldValue containsString:@"file://"]){
        // the local-url isn't already a file: url.
        if(base && 
           ![[localURLFieldValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"/"] &&
           ![[localURLFieldValue substringWithRange:NSMakeRange(0,1)] isEqualToString:@"~"]){
            
            // it's a relative path and we can prepend base to it.
            localURLFieldValue = [base stringByAppendingPathComponent:localURLFieldValue];

        }else{
            // Ignore base if we had a full path to begin with.
            // make sure we remove ~. If the string started with /, this is still OK.
            localURLFieldValue = [localURLFieldValue stringByExpandingTildeInPath];
        }

        localURL = [NSURL fileURLWithPath:localURLFieldValue];
    }else{
        // it's already a file: url and we can just build it 
        localURL = [NSURL URLWithString:localURLFieldValue];
    }

    return [[localURL path] stringByExpandingTildeInPath];
}

- (NSString *)suggestedLocalUrl{
	OFPreferenceWrapper *prefs = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSString *localUrlFormat = [prefs objectForKey:BDSKLocalUrlFormatKey];
	NSString *papersFolderPath = [[prefs stringForKey:BDSKPapersFolderPathKey] stringByExpandingTildeInPath];
	NSString *relativeFile = [[BDSKFormatParser sharedParser] parseFormat:localUrlFormat forField:BDSKLocalUrlString ofItem:self];
	if ([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKCiteKeyLowercaseKey]) {
		relativeFile = [relativeFile lowercaseString];
	}
	NSURL *url = [NSURL fileURLWithPath:[papersFolderPath stringByAppendingPathComponent:relativeFile]];
	
	return [url absoluteString];
}

- (BOOL)canSetLocalUrl
{
	if ([[NSApp delegate] requiredFieldsForLocalUrl] == nil) 
		return NO;
	
	NSEnumerator *fEnum = [[[NSApp delegate] requiredFieldsForLocalUrl] objectEnumerator];
	NSString *fieldName;
	NSString *fieldValue;
	
	while (fieldName = [fEnum nextObject]) {
		if ( [fieldName isEqualToString:BDSKCiteKeyString] ||
			 [fieldName isEqualToString:@"Citekey"] ||
			 [fieldName isEqualToString:@"Cite-Key"]) {
			fieldValue = [self citeKey];
			if ([fieldValue isEqualToString:@""] || [fieldValue isEqualToString:@"cite-key"]) 
				return NO;
		} else {
			fieldValue = [self valueOfField:fieldName];
			if (fieldValue == nil || [fieldValue isEqualToString:@""]) 
				return NO;
		}
	}
	return YES;
}

- (BOOL)needsToBeFiled { 
	return needsToBeFiled; 
}

- (void)setNeedsToBeFiled:(BOOL)flag {
	needsToBeFiled = flag;
	
	if (editorObj) {
		NSString *message = NSLocalizedString(@"Linked file needs to be filed.",@"Linked file needs to be filed.");
		if (flag) {
			[editorObj setStatus:message];
		} else if ([message isEqualToString:[editorObj status]]) {
			[editorObj setStatus:@""];
		}
	}
}

- (void)autoFilePaper
{
	if (![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey])
		return;
	
	if ([self canSetLocalUrl]) {
		[[BibFiler sharedFiler] filePapers:[NSArray arrayWithObject:self]
							  fromDocument:[self document] 
									   ask:NO]; 
		if (editorObj) {
			[editorObj setStatus:NSLocalizedString(@"Autofiled linked file.",@"Autofiled linked file.")];
		}
	} else {
		[self setNeedsToBeFiled:YES];
	}
}

- (void)typeInfoDidChange:(NSNotification *)aNotification{
	[self makeType:[self type]];
}

@end
