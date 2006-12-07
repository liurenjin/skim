//
//  BibDocument_Search.m
//  Bibdesk
//
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

#import "BibDocument_Search.h"
#import "BibDocument.h"
#import "BibTypeManager.h"
#import <AGRegex/AGRegex.h>
#import "BibItem.h"

static NSString *BDSKFileContentLocalizedString = nil;

@implementation BibDocument (Search)

+ (void)didLoad{
    
    BDSKFileContentLocalizedString = [NSLocalizedString(@"File Content", @"") copy];
}

- (IBAction)makeSearchFieldKey:(id)sender{
	[documentWindow makeFirstResponder:searchField];
}

- (NSMenu *)searchFieldMenu{
	NSMenu *cellMenu = [[[NSMenu allocWithZone:[NSMenu menuZone]] initWithTitle:@"Search Menu"] autorelease];
	NSMenuItem *anItem;
	int curIndex = 0;
	
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Recent Searches",@"Recent Searches menu item") action:NULL keyEquivalent:@""];
	[anItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
	[cellMenu insertItem:anItem atIndex:curIndex++];
	[anItem release];
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"" action:NULL keyEquivalent:@""];
	[anItem setTag:NSSearchFieldRecentsMenuItemTag];
	[cellMenu insertItem:anItem atIndex:curIndex++];
	[anItem release];
    
    // this tag conditionally inserts a separator if there are recent searches (is it safe to set a tag on the separator item?)
    anItem = [NSMenuItem separatorItem];
	[anItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
	[cellMenu insertItem:anItem atIndex:curIndex++];
    
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Clear Recent Searches",@"Clear menu item") action:NULL keyEquivalent:@""];
	[anItem setTag:NSSearchFieldClearRecentsMenuItemTag];
	[cellMenu insertItem:anItem atIndex:curIndex++];
	[anItem release];
    
	// another conditional separator item, this one without the line
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"" action:NULL keyEquivalent:@""];
	[anItem setTag:NSSearchFieldRecentsTitleMenuItemTag];
	[cellMenu insertItem:anItem atIndex:curIndex++];
	[anItem release];
    
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"Search Fields",@"Search Fields menu item") action:nil keyEquivalent:@""];
	[cellMenu insertItem:anItem atIndex:curIndex++];
	[anItem release];
	
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Add Field",@"Add Field... menu item") stringByAppendingString:[NSString horizontalEllipsisString]] action:@selector(quickSearchAddField:) keyEquivalent:@""];
	[cellMenu insertItem:anItem atIndex:curIndex++];
	[anItem release];
	
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:[NSLocalizedString(@"Remove Field",@"Remove Field... menu item") stringByAppendingString:[NSString horizontalEllipsisString]] action:@selector(quickSearchRemoveField:) keyEquivalent:@""];
	[cellMenu insertItem:anItem atIndex:curIndex++];
	[anItem release];
	
	[cellMenu insertItem:[NSMenuItem separatorItem] atIndex:curIndex++];
	
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:NSLocalizedString(@"All Fields",@"All Fields menu item") action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
	[cellMenu insertItem:anItem atIndex:curIndex++];
	[anItem release];

    if(floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_3){
        anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:BDSKFileContentLocalizedString action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
        [cellMenu insertItem:anItem atIndex:curIndex++];
        [anItem release];
        [cellMenu insertItem:[NSMenuItem separatorItem] atIndex:curIndex++];
    }
        
    NSMutableArray *itemArray = [NSMutableArray arrayWithCapacity:5];
    
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:BDSKTitleString action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
	[itemArray addObject:anItem];
	[anItem release];
	
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:BDSKAuthorString action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
	[itemArray addObject:anItem];
	[anItem release];
	
	anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:BDSKDateString action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
	[itemArray addObject:anItem];
	[anItem release];
    	
	NSArray *prefsQuickSearchKeysArray = [[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys];
    NSString *aKey = nil;
    NSEnumerator *quickSearchKeyE = [prefsQuickSearchKeysArray objectEnumerator];
	
    while(aKey = [quickSearchKeyE nextObject]){
		
		anItem = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:aKey 
											action:@selector(searchFieldChangeKey:)
									 keyEquivalent:@""]; 
        [itemArray addObject:anItem];
		[anItem release];
    }
    
    NSSortDescriptor *sort = [[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES] autorelease];
    [itemArray sortUsingDescriptors:[NSArray arrayWithObject:sort]];
    
    unsigned idx, itemCount = [itemArray count];
    for(idx = 0; idx < itemCount; idx++)
        [cellMenu addItem:[itemArray objectAtIndex:idx]];
    
	return cellMenu;
}

- (void)setupSearchField{
	
	NSSearchFieldCell *searchCell = [searchField cell];
	[searchCell setSearchMenuTemplate:[self searchFieldMenu]];
	[searchCell setPlaceholderString:[NSString stringWithFormat:NSLocalizedString(@"Search by %@",@""),quickSearchKey]];
	[searchCell setRecentsAutosaveName:[NSString stringWithFormat:NSLocalizedString(@"%@ recent searches autosave ",@""),[self fileName]]];
	
	// set the search key's menuitem to NSOnState
	[self setSelectedSearchFieldKey:quickSearchKey];
}

-(NSString*) filterField {
	return [searchField stringValue];
}

- (void)setFilterField:(NSString*) filterterm {
    NSParameterAssert(filterterm != nil);
    
    NSResponder * oldFirstResponder = [documentWindow firstResponder];
    [documentWindow makeFirstResponder:searchField];
    
    [searchField setObjectValue:filterterm];
    [self searchFieldAction:searchField];
    
    [documentWindow makeFirstResponder:oldFirstResponder];
}

- (IBAction)searchFieldChangeKey:(id)sender{
	if([sender isKindOfClass:[NSPopUpButton class]]){
		[self setSelectedSearchFieldKey:[sender titleOfSelectedItem]];
	}else{
		[self setSelectedSearchFieldKey:[sender title]];
	}
}

- (void)setSelectedSearchFieldKey:(NSString *)newKey{
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:newKey
                                                      forKey:BDSKCurrentQuickSearchKey];
	
	NSSearchFieldCell *searchCell = [searchField cell];
	[searchCell setPlaceholderString:[NSString stringWithFormat:NSLocalizedString(@"Search by %@",@""),newKey]];

	NSMenu *templateMenu = [searchCell searchMenuTemplate];
	if(![quickSearchKey isEqualToString:newKey]){
		// find current key's menuitem and set it to NSOffState
		NSMenuItem *oldItem = [templateMenu itemWithTitle:quickSearchKey];
		[oldItem setState:NSOffState];
		if ([searchField target] != self && [quickSearchKey isEqualToString:BDSKFileContentLocalizedString])
			[fileSearchController restoreDocumentState:nil];
	}
	
	// set new key's menuitem to NSOnState
	NSMenuItem *newItem = [templateMenu itemWithTitle:newKey];
	[newItem setState:NSOnState];
    
    // @@ weird...this is required or else the checkmark doesn't show up
	[searchCell setSearchMenuTemplate:templateMenu];
    
	if(newKey != quickSearchKey){
		[quickSearchKey release];
		quickSearchKey = [newKey copy];
	}

	if([newKey isEqualToString:BDSKFileContentLocalizedString])
		[self searchByContent:searchField];
 
	[self hidePublicationsWithoutSubstring:[searchField stringValue] //newQueryString
								   inField:quickSearchKey];
		
}

- (IBAction)quickSearchAddField:(id)sender{
    // first we fill the popup
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSArray *prefsQuickSearchKeysArray = [pw arrayForKey:BDSKQuickSearchKeys];
	BibTypeManager *typeMan = [BibTypeManager sharedManager];
	NSMutableSet *fieldNameSet = [NSMutableSet setWithSet:[typeMan allFieldNames]];
	[fieldNameSet unionSet:[NSSet setWithObjects:BDSKCiteKeyString, BDSKDateString, @"Added", @"Modified", nil]];
	NSMutableArray *colNames = [[fieldNameSet allObjects] mutableCopy];
	[colNames removeObjectsInArray:prefsQuickSearchKeysArray];
	[colNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
	
	[addFieldComboBox removeAllItems];
	[addFieldComboBox addItemsWithObjectValues:colNames];
    [addFieldPrompt setStringValue:NSLocalizedString(@"Name of field to search:",@"")];
	
	[colNames release];
    
	[NSApp beginSheet:addFieldSheet
       modalForWindow:documentWindow
        modalDelegate:self
       didEndSelector:@selector(quickSearchAddFieldSheetDidEnd:returnCode:contextInfo:)
          contextInfo:nil];
}

- (void)quickSearchAddFieldSheetDidEnd:(NSWindow *)sheet
							returnCode:(int) returnCode
						   contextInfo:(void *)contextInfo{
	
    NSMutableArray *searchKeys = nil;
	NSSearchFieldCell *searchFieldCell = [searchField cell];
	NSString *newFieldTitle = nil;
	
    if(returnCode == 1){
        newFieldTitle = [[addFieldComboBox stringValue] capitalizedString];
		searchKeys = [NSMutableArray arrayWithCapacity:10];
        [searchKeys addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys]];
        [searchKeys addObject:newFieldTitle];
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:searchKeys
                                                          forKey:BDSKQuickSearchKeys];
        
        // this will sort the menu items for us
        [searchFieldCell setSearchMenuTemplate:[self searchFieldMenu]];
		[self setSelectedSearchFieldKey:newFieldTitle];
    }else{
        // cancel. we don't have to do anything..?
		
    }
}

- (IBAction)quickSearchRemoveField:(id)sender{
    [delFieldPrompt setStringValue:NSLocalizedString(@"Name of search field to remove:",@"")];
    NSMutableArray *searchKeys = [NSMutableArray arrayWithCapacity:10];
    [searchKeys addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys]];
    [searchKeys sortUsingSelector:@selector(caseInsensitiveCompare:)];

	[delFieldPopupButton removeAllItems];
	[delFieldPopupButton addItemsWithTitles:searchKeys];
	
	[NSApp beginSheet:delFieldSheet
       modalForWindow:documentWindow
        modalDelegate:self
       didEndSelector:@selector(quickSearchDelFieldSheetDidEnd:returnCode:contextInfo:)
          contextInfo:NULL];
}

- (IBAction)dismissDelFieldSheet:(id)sender{
    [delFieldSheet orderOut:sender];
    [NSApp endSheet:delFieldSheet returnCode:[sender tag]];
}

- (void)quickSearchDelFieldSheetDidEnd:(NSWindow *)sheet
							returnCode:(int) returnCode
						   contextInfo:(void *)contextInfo{
   
    if(returnCode == 1){
        NSMutableArray *searchKeys = [NSMutableArray arrayWithCapacity:10];
        [searchKeys addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys]];

        [searchKeys removeObject:[[delFieldPopupButton selectedItem] title]];
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:searchKeys
                                                          forKey:BDSKQuickSearchKeys];

		[[searchField cell] setSearchMenuTemplate:[self searchFieldMenu]];
        if([quickSearchKey isEqualToString:[[delFieldPopupButton selectedItem] title]])
            [self setSelectedSearchFieldKey:NSLocalizedString(@"All Fields",@"")];
    }else{
        // cancel. we don't have to do anything..?
       
    }
}

- (IBAction)searchFieldAction:(id)sender{
    NSParameterAssert(sender != nil);
    NSParameterAssert([sender stringValue] != nil);
    
    if([quickSearchKey isEqualToString:BDSKFileContentLocalizedString]){
        OBASSERT((floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3) == NO);
        [self searchByContent:sender];
    } else {
        [self hidePublicationsWithoutSubstring:[sender stringValue] inField:quickSearchKey];
    }
}

#pragma mark -

- (void)hidePublicationsWithoutSubstring:(NSString *)substring inField:(NSString *)field{
	NSArray *pubsToSelect = [self selectedPublications];

    if([NSString isEmptyString:substring]){
        [shownPublications setArray:groupedPublications];
    }else{
		[shownPublications setArray:[self publicationsWithSubstring:substring
															inField:field
														   forArray:groupedPublications]];
		if([shownPublications count] == 1)
			pubsToSelect = [NSMutableArray arrayWithObject:[shownPublications lastObject]];
	}
	
	[tableView deselectAll:nil];
	[self sortPubsByColumn:nil]; // resort
	[self updateUI];
	if(pubsToSelect)
		[self highlightBibs:pubsToSelect];
}

- (void)cacheQuickSearchRegexes{
    // match any words up to but not including AND or OR if they exist (see "Lookahead assertions" and "CONDITIONAL SUBPATTERNS" in pcre docs)
    tipRegex = [[AGRegex regexWithPattern:@"(?(?=^.+(\\+|\\|))(^.+(?=\\+|\\|))|^.++)" options:AGRegexLazy] retain];
    
    andRegex = [[AGRegex regexWithPattern:@"\\+[^+|]+"] retain]; // match the word following an AND; we consider a word boundary to be + or |
    orRegex = [[AGRegex regexWithPattern:@"\\|[^+|]+"] retain]; // match the first word following an OR
}
        
static inline
NSRange rangeOfStringUsingLossyTargetString(NSString *substring, NSString *targetString, unsigned options, BOOL lossy)
{
    
    NSRange range = {NSNotFound, 0};
    
    if(BDIsEmptyString((CFStringRef)targetString))
        return range;
    
    static NSCharacterSet *braceSet = nil;
    
    if(braceSet == nil)
        braceSet = [[NSCharacterSet characterSetWithCharactersInString:@"{}"] retain];
    
    NSMutableString *mutableCopy = [targetString mutableCopy];
    [mutableCopy deleteCharactersInCharacterSet:braceSet];
    
    if(lossy){
        // get ASCII data from the mutable string, and convert it to a new NSString
        NSData *data = [mutableCopy dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        targetString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        range = [targetString rangeOfString:substring options:options];
        [targetString release];
    } else {
        // search directly in the mutable string
        range = [mutableCopy rangeOfString:substring options:options];
    }
    
    [mutableCopy release];
    return range;
}

- (NSArray *)publicationsWithSubstring:(NSString *)substring inField:(NSString *)field forArray:(NSArray *)arrayToSearch{
        
    unsigned searchMask = NSCaseInsensitiveSearch;
    if([substring rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location != NSNotFound)
        searchMask = 0;
    BOOL doLossySearch = YES;
    if(![substring canBeConvertedToEncoding:NSASCIIStringEncoding])
        doLossySearch = NO;
    
    SEL accessor = NULL;
    BOOL isBooleanField = NO;
    BOOL substringBoolValue = NO;
    
    if([field isEqualToString:BDSKTitleString]){
        accessor = NSSelectorFromString(@"title");
    } else if([field isEqualToString:BDSKAuthorString]){
		accessor = NSSelectorFromString(@"bibTeXAuthorString");
	} else if([field isEqualToString:BDSKDateString]){
		accessor = NSSelectorFromString(@"calendarDateDescription");
	} else if([field isEqualToString:BDSKDateModifiedString] ||
			  [field isEqualToString:@"Modified"]){
		accessor = NSSelectorFromString(@"calendarDateModifiedDescription");
	} else if([field isEqualToString:BDSKDateCreatedString] ||
			  [field isEqualToString:@"Added"] ||
			  [field isEqualToString:@"Created"]){
		accessor = NSSelectorFromString(@"calendarDateCreatedDescription");
	} else if([field isEqualToString:@"All Fields"]){
		accessor = NSSelectorFromString(@"allFieldsString");
	} else if([field isEqualToString:BDSKTypeString] || 
			  [field isEqualToString:@"Pub Type"]){
		accessor = NSSelectorFromString(@"type");
	} else if([field isEqualToString:BDSKCiteKeyString]){
		accessor = NSSelectorFromString(@"citeKey");
	} else if([[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKBooleanFieldsKey] containsObject:field]){
        accessor = NULL;
        isBooleanField = YES;
        substringBoolValue = [substring booleanValue];
    }
//    The AGRegexes are now ivars, but I've left them here as comments in the relevant places.
//    I'm also leaving AND/OR in the comments, but the code uses +| to be compatible with Spotlight query syntax; it's harder to see
//    what's going on with all of the escapes, though.
    NSArray *matchArray = [andRegex findAllInString:substring]; // an array of AGRegexMatch objects
    NSMutableArray *andArray = [[NSMutableArray alloc] initWithCapacity:[matchArray count]]; // and array of all the AND terms we're looking for
    
    // get the tip of the search string first (always an AND)
    NSString *tip = [[[tipRegex findInString:substring] group] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if(!tip)
        return [NSArray array];
    else
        [andArray addObject:tip];

    NSEnumerator *e = [matchArray objectEnumerator];
    AGRegexMatch *m;
    static NSCharacterSet *trimSet;
    if(!trimSet)
        trimSet = [[NSCharacterSet characterSetWithCharactersInString:@"+| "] retain]; // leftovers from regex search
    NSString *s;

    while(m = [e nextObject]){ // get the resulting string from the match, and strip the AND from it; there might be a better way, but this works
        s = [[m group] stringByTrimmingCharactersInSet:trimSet];
        if(![NSString isEmptyString:s])
            [andArray addObject:s];
    }
    
    matchArray = [orRegex findAllInString:substring];
    e = [matchArray objectEnumerator];
    
    NSMutableArray *orArray = [[NSMutableArray alloc] initWithCapacity:[matchArray count]]; // an array of all the OR terms we're looking for

    while(m = [e nextObject]){ // now get all of the OR strings and strip the OR from them
        s = [[m group] stringByTrimmingCharactersInSet:trimSet];
        if(![NSString isEmptyString:s])
            [orArray addObject:s];
    }
    
    NSMutableSet *aSet = [NSMutableSet setWithCapacity:10];
    NSEnumerator *andEnum = [andArray objectEnumerator];
    NSEnumerator *orEnum = [orArray objectEnumerator];
    
    NSRange r;
    NSString *componentSubstring = nil;
    BibItem *pub = nil;
    NSEnumerator *pubEnum;
    NSMutableArray *andResultsArray = [[NSMutableArray alloc] initWithCapacity:50];
    NSString *value;

    NSSet *copySet;
    
    // for each AND term, enumerate the entire publications array and search for a match; if we get a match, add it to a mutable set
    while(componentSubstring = [andEnum nextObject]){
        
        pubEnum = [arrayToSearch objectEnumerator];
        while(pub = [pubEnum nextObject]){
            
            value = (accessor == NULL ? [pub valueOfGenericField:field] : [pub performSelector:accessor withObject:nil]);
            
            if(!isBooleanField){
                r = rangeOfStringUsingLossyTargetString(componentSubstring, value, searchMask, doLossySearch);

                if(r.location != NSNotFound)
                    [aSet addObject:pub];
            } else {
                if([pub boolValueOfField:field] == substringBoolValue)
                    [aSet addObject:pub];
            }
        }
        copySet = [aSet copy];
        [andResultsArray addObject:copySet];
        [copySet release];
        [aSet removeAllObjects]; // don't forget this step!
    }
    [andArray release];

    // Get all of the OR matches, each in a separate set added to orResultsArray
    NSMutableArray *orResultsArray = [[NSMutableArray alloc] initWithCapacity:50];
    
    while(componentSubstring = [orEnum nextObject]){
        
        pubEnum = [arrayToSearch objectEnumerator];
        while(pub = [pubEnum nextObject]){
            
            value = (accessor == NULL ? [pub valueOfField:field] : [pub performSelector:accessor withObject:nil]);
            
            if(!isBooleanField){
                r = rangeOfStringUsingLossyTargetString(componentSubstring, value, searchMask, doLossySearch);

                if(r.location != NSNotFound)
                    [aSet addObject:pub];
            } else {
                if([pub boolValueOfField:field] == substringBoolValue)
                    [aSet addObject:pub];
            }
        }
        copySet = [aSet copy];
        [orResultsArray addObject:copySet];
        [copySet release];
        [aSet removeAllObjects]; // don't forget this step!
    }
    
    [orArray release];

    // we need to sort the set so we always start with the shortest one
    static NSArray *setLengthSortDescriptors = nil;
    if(setLengthSortDescriptors == nil){
        NSSortDescriptor *setLengthSort = [[NSSortDescriptor alloc] initWithKey:@"self.@count" ascending:YES selector:@selector(compare:)];
        setLengthSortDescriptors = [[NSArray alloc] initWithObjects:setLengthSort, nil];
        [setLengthSort release];
    }
    
    [andResultsArray sortUsingDescriptors:setLengthSortDescriptors];
    e = [andResultsArray objectEnumerator];
    
    // don't start out by intersecting an empty set
    [aSet setSet:[e nextObject]];

    // now get the intersection of all successive results from the AND terms
    while(copySet = [e nextObject]){
        [aSet intersectSet:copySet];
    }
    [andResultsArray release];
    
    // union the results from the OR search
    e = [orResultsArray objectEnumerator];
    
    while(copySet = [e nextObject]){
        [aSet unionSet:copySet];
    }
    [orResultsArray release];
        
    return [aSet allObjects];
    
}

#pragma mark File Content Search

- (IBAction)searchByContent:(id)sender
{
    // Normal search if the fileSearchController is not present and the searchstring is empty, since the searchfield target has apparently already been reset (I think).  Fixes bug #1341802.
    OBASSERT(searchField != nil && [searchField target] != nil);
    if([searchField target] == self && [NSString isEmptyString:[searchField stringValue]]){
        [self hidePublicationsWithoutSubstring:[sender stringValue] inField:quickSearchKey];
        return;
    }
    
    // @@ File content search isn't really compatible with the group concept yet; this allows us to select publications when the content search is done, and also provides some feedback to the user that all pubs will be searched.  This is ridiculously complicated since we need to avoid calling searchByContent: in a loop.
    [tableView deselectAll:nil];
    [groupTableView updateHighlights];
    
    // here we avoid the table selection change notification that will result in an endless loop
    id tableDelegate = [groupTableView delegate];
    [groupTableView setDelegate:nil];
    [groupTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [groupTableView setDelegate:tableDelegate];
    
    // this is what displaySelectedGroup normally ends up doing
    [shownPublications setArray:publications];
    [tableView reloadData];
    [self sortPubsByColumn:nil];
    
    if(fileSearchController == nil)
        fileSearchController = [[BDSKFileContentSearchController alloc] initForDocument:self];

    NSView *contentView = [fileSearchController searchContentView];
    NSRect frame = [splitView frame];
    [contentView setFrame:frame];
    
    NSViewAnimation *animation;
    NSDictionary *fadeOutDict = [[NSDictionary alloc] initWithObjectsAndKeys:splitView, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
    NSDictionary *fadeInDict = [[NSDictionary alloc] initWithObjectsAndKeys:contentView, NSViewAnimationTargetKey, NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];

    animation = [[[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:fadeOutDict, fadeInDict, nil]] autorelease];
    [animation startAnimation];
    
    [splitView retain];
    [groupSplitView replaceSubview:splitView with:contentView];
    
    [searchField setTarget:fileSearchController];
    [searchField setAction:@selector(search:)];
    [searchField setDelegate:fileSearchController];
    
    // use whatever content is in the searchfield; delay it so the progress indicator doesn't show up before the rest of the content is on screen
    [fileSearchController performSelector:@selector(search:) withObject:searchField afterDelay:0.5];
    
}

// Method required by the BDSKSearchContentView protocol; the implementor is responsible for restoring its state by removing the view passed as an argument and resetting search field target/action.
- (void)_restoreDocumentStateByRemovingSearchView:(NSView *)view
{
    NSArray *titlesToSelect = [fileSearchController titlesOfSelectedItems];
    
    NSRect frame = [view frame];
    [splitView setFrame:frame];
    
    NSViewAnimation *animation;
    NSDictionary *fadeOutDict = [[NSDictionary alloc] initWithObjectsAndKeys:view, NSViewAnimationTargetKey, NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey, nil];
    NSDictionary *fadeInDict = [[NSDictionary alloc] initWithObjectsAndKeys:splitView, NSViewAnimationTargetKey, NSViewAnimationFadeInEffect, NSViewAnimationEffectKey, nil];
    
    animation = [[[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:fadeOutDict, fadeInDict, nil]] autorelease];
    [animation startAnimation];
    
    [groupSplitView replaceSubview:view with:splitView];
    [splitView release];
    
    [searchField setTarget:self];
    [searchField setDelegate:self];
    [searchField setAction:@selector(searchFieldAction:)];
    
    if([titlesToSelect count]){
        
        // clear current selection (just in case)
        [tableView deselectAll:nil];
        
        // we match based on title, since that's all the index knows about the BibItem at present
        NSMutableArray *pubsToSelect = [NSMutableArray array];
		NSEnumerator *pubEnum = [shownPublications objectEnumerator];
        BibItem *item;
        while(item = [pubEnum nextObject])
            if([titlesToSelect containsObject:[item title]]) 
                [pubsToSelect addObject:item];
		[self highlightBibs:pubsToSelect];
        [tableView scrollRowToVisible:[tableView selectedRow]];
    } 
}


@end
