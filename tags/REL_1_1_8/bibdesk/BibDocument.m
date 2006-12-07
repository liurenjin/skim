//  BibDocument.m

//  Created by Michael McCracken on Mon Dec 17 2001.
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

#import "BibDocument.h"
#import "BibItem.h"
#import "BibAuthor.h"
#import "BibEditor.h"
#import "BibDocument_DataSource.h"
#import "BibDocumentView_Toolbar.h"
#import "BibAppController.h"
#import "BDSKUndoManager.h"
#import "RYZImagePopUpButtonCell.h"
#import "MultiplePageView.h"
#import <OmniAppKit/OAInternetConfig.h>
#import <OmniFoundation/CFDictionary-OFExtensions.h>
#import "BDSKPrintableView.h"
#import "NSWorkspace_BDSKExtensions.h"
#import "BDSKHeaderPopUpButtonCell.h"
#import "BDSKGroupCell.h"
#import "BDSKScriptHookManager.h"

#include <stdio.h>

NSString *BDSKBibTeXStringPboardType = @"edu.ucsd.mmccrack.bibdesk BibTeX string pboard type";
NSString *BDSKReferenceMinerStringPboardType = @"CorePasteboardFlavorType 0x57454253";
NSString *BDSKBibItemIndexPboardType = @"edu.ucsd.mmccrack.bibdesk shownPublications index type";
NSString *BDSKBibItemPboardType = @"edu.ucsd.mmccrack.bibdesk BibItem pboard type";

static NSString *BDSKAllPublicationsLocalizedString = nil;
static NSString *BDSKFileContentLocalizedString = nil;

#import <BTParse/btparse.h>

@implementation BibDocument

+ (void)initialize{
    
    OBINITIALIZE;
    
    BDSKAllPublicationsLocalizedString = [NSLocalizedString(@"All Publications", @"group name for all pubs") copy];
    BDSKFileContentLocalizedString = [NSLocalizedString(@"File Content", @"") copy];
}

- (id)init{
    if(self = [super init]){
        publications = [[NSMutableArray alloc] initWithCapacity:1];
        shownPublications = [[NSMutableArray alloc] initWithCapacity:1];
        groupedPublications = [[NSMutableArray alloc] initWithCapacity:1];
        groups = [[NSMutableArray alloc] initWithCapacity:1];
        
        pubsLock = [[NSLock alloc] init];
        
        frontMatter = [[NSMutableString alloc] initWithString:@""];
		
        currentGroupField = [[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKCurrentGroupFieldKey] retain];

        quickSearchKey = [[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKCurrentQuickSearchKey] retain];
        if(!quickSearchKey){
            quickSearchKey = [[NSString alloc] initWithString:BDSKTitleString];
        }
		
		texTask = [[BDSKTeXTask alloc] initWithFileName:@"bibcopy"];
		[texTask setDelegate:self];
		
        BD_windowControllers = [[NSMutableArray alloc] initWithCapacity:1];
        
        macroDefinitions = OFCreateCaseInsensitiveKeyMutableDictionary();
        
        BDSKUndoManager *newUndoManager = [[[BDSKUndoManager alloc] init] autorelease];
        [newUndoManager setDelegate:self];
        [self setUndoManager:newUndoManager];
		
		itemsForCiteKeys = [[OFMultiValueDictionary alloc] initWithCaseInsensitiveKeys:YES];
		
        // Register as observer of font change events.
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleFontChangedNotification:)
													 name:BDSKTableViewFontChangedNotification
												   object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handlePreviewDisplayChangedNotification:)
													 name:BDSKPreviewDisplayChangedNotification
												   object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleGroupFieldChangedNotification:)
													 name:BDSKGroupFieldChangedNotification
												   object:nil];

		// register for selection changes notifications:
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleTableSelectionChangedNotification:)
													 name:BDSKTableSelectionChangedNotification
												   object:self];

		// register for tablecolumn changes notifications:
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleTableColumnChangedNotification:)
													 name:BDSKTableColumnChangedNotification
												   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleResortDocumentNotification:)
													 name:BDSKResortDocumentNotification
												   object:nil];        

		//  register to observe for item change notifications here.
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleBibItemChangedNotification:)
													 name:BDSKBibItemChangedNotification
												   object:nil];

		// register to observe for add/delete items.
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleBibItemAddDelNotification:)
													 name:BDSKDocSetPublicationsNotification
												   object:self];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleBibItemAddDelNotification:)
													 name:BDSKDocAddItemNotification
												   object:self];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(handleBibItemAddDelNotification:)
													 name:BDSKDocDelItemNotification
                                                   object:self];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMacroChangedNotification:)
                                                     name:BDSKBibDocMacroKeyChangedNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMacroChangedNotification:)
                                                     name:BDSKBibDocMacroDefinitionChangedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationWillTerminateNotification:)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
        
		customStringArray = [[NSMutableArray arrayWithCapacity:6] retain];
		[customStringArray setArray:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKCustomCiteStringsKey]];
        
        [self setDocumentStringEncoding:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKDefaultStringEncodingKey]]; // need to set this for new documents

		sortDescending = NO;
		sortGroupsDescending = NO;
		sortGroupsKey = [BDSKGroupCellStringKey retain];
		showStatus = YES;
                
        [self cacheQuickSearchRegexes];

    }
    return self;
}


- (void)awakeFromNib{
    NSSize drawerSize;
    //NSString *viewByKey = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKViewByKey];
	
	[self setupSearchField];
   
    [tableView setDoubleAction:@selector(editPubCmd:)];
    NSMutableArray *dragTypes = [NSMutableArray arrayWithObjects:BDSKBibItemPboardType, NSStringPboardType, NSFilenamesPboardType, BDSKReferenceMinerStringPboardType, nil];
    [tableView registerForDraggedTypes:[[dragTypes copy] autorelease]];
    [dragTypes addObject:BDSKBibItemIndexPboardType];
    [groupTableView registerForDraggedTypes:dragTypes];

    NSString *filename = [[self fileName] lastPathComponent];
	if (filename == nil) filename = @"";
	[splitView setPositionAutosaveName:[NSString stringWithFormat:@"OASplitView Position Main %@", filename]];
    [groupSplitView setPositionAutosaveName:[NSString stringWithFormat:@"OASplitView Position Group %@", filename]];
    
	[infoLine retain]; // we need to retain, as we might remove it from the window
	if (![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShowStatusBarKey]) {
		[self toggleStatusBar:nil];
	}

    // workaround for IB flakiness...
    drawerSize = [customCiteDrawer contentSize];
    [customCiteDrawer setContentSize:NSMakeSize(100,drawerSize.height)];

	showingCustomCiteDrawer = NO;
	
    // finally, make sure the font is correct initially:
	[self setTableFont];
	
	// unfortunately we cannot set this in IB
	[actionMenuButton setArrowImage:[NSImage imageNamed:@"ArrowPointingDown"]];
	[actionMenuButton setShowsMenuWhenIconClicked:YES];
	[[actionMenuButton cell] setAltersStateOfSelectedItem:NO];
	[[actionMenuButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[actionMenuButton cell] setUsesItemFromMenu:NO];
	[[actionMenuButton cell] setRefreshesMenu:NO];
	
	[self updateActionMenus:nil];
	
	RYZImagePopUpButton *cornerViewButton = (RYZImagePopUpButton*)[tableView cornerView];
	[cornerViewButton setAlternateImage:[NSImage imageNamed:@"cornerColumns_Pressed"]];
	[cornerViewButton setShowsMenuWhenIconClicked:YES];
	[[cornerViewButton cell] setAltersStateOfSelectedItem:NO];
	[[cornerViewButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[cornerViewButton cell] setUsesItemFromMenu:NO];
	[[cornerViewButton cell] setRefreshesMenu:NO];
    
	[cornerViewButton setMenu:[[[NSApp delegate] columnsMenuItem] submenu]];
    
	BDSKGroupTableHeaderView *headerView = (BDSKGroupTableHeaderView *)[groupTableView headerView];
	NSPopUpButtonCell *headerCell = [headerView popUpHeaderCell];
	[headerCell setAction:@selector(changeGroupFieldAction:)];
	[headerCell setTarget:self];
	[headerCell setMenu:[self groupFieldsMenu]];
	[(BDSKHeaderPopUpButtonCell *)headerCell setIndicatorImage:[NSImage imageNamed:sortGroupsDescending ? @"sort-down" : @"sort-up"]];
	[headerCell selectItemWithTitle:currentGroupField];
	
    [saveTextEncodingPopupButton removeAllItems];
    [saveTextEncodingPopupButton addItemsWithTitles:[[BDSKStringEncodingManager sharedEncodingManager] availableEncodingDisplayedNames]];
    
	[addFieldComboBox setFormatter:[[[BDSKFieldNameFormatter alloc] init] autorelease]];
        
    if([documentWindow respondsToSelector:@selector(setAutorecalculatesKeyViewLoop:)])
        [documentWindow setAutorecalculatesKeyViewLoop:YES];
    
    // hold onto this until we dealloc, or else we can get crashes when messaging the tableview in dealloc if dealloc is delayed at all
    [documentWindow retain];
    
    // NSTextField set up with a gray color, as in Xcode 2.x, for the bottom of the document window.  Use pinstripe background on pre-Tiger OS versions.
    if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3){
        [infoLineBackground removeFromSuperview];
        infoLineBackground = nil;
    }
	// is this necessary?
	[self updateGroupsPreservingSelection:NO];
}

- (void)dealloc{
#if DEBUG
    NSLog(@"bibdoc dealloc");
#endif
    [tableView setDelegate:nil];
    [tableView setDataSource:nil];
    [fileSearchController release];
    [documentWindow release]; // retained in awakeFromNib
    if ([self undoManager]) {
        [[self undoManager] removeAllActionsWithTarget:self];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[[BDSKErrorObjectController sharedErrorObjectController] removeErrorObjsForDocument:self];
    [macroDefinitions release];
    [itemsForCiteKeys release];
    // set pub document ivars to nil, or we get a crash when they message the undo manager in dealloc (only happens if you edit, click to close the doc, then save)
    [publications makeObjectsPerformSelector:@selector(setDocument:) withObject:nil];
    [publications release];
    [shownPublications release];
    [groupedPublications release];
    [groups release];
    [pubsLock release];
    [frontMatter release];
    [quickSearchKey release];
    [customStringArray release];
    [toolbarItems release];
	[infoLine release];
    [BD_windowControllers release];
	[texTask release];
    [macroWC release];
    [tipRegex release];
    [andRegex release];
    [orRegex release];
    [promiseDragColumnIdentifier release];
    [lastSelectedColumnForSort release];
    [sortGroupsKey release];
    [super dealloc];
}

- (void) updateActionMenus:(id) aNotification {
	// this does nothing for now
}


- (BOOL)undoManagerShouldUndoChange:(id)sender{
	if (![self isDocumentEdited]) {
		[NSApp beginSheet:undoAlertSheet
		   modalForWindow:documentWindow
						  modalDelegate:self
		   didEndSelector:NULL
							contextInfo:nil];
		int rv = [NSApp runModalForWindow:undoAlertSheet];
		[NSApp endSheet:undoAlertSheet];
		[undoAlertSheet orderOut:self];
		if (rv == NSAlertAlternateReturn)
			return NO;
	}
	return YES;
}

- (IBAction)dismissUndoAlertSheet:(id)sender{
	[NSApp stopModalWithCode:[sender tag]];
}

- (void)setPublications:(NSArray *)newPubs{
	if(newPubs != publications){
		NSUndoManager *undoManager = [self undoManager];
		[[undoManager prepareWithInvocationTarget:self] setPublications:publications];
		
		[publications autorelease];
		publications = [newPubs mutableCopy];
		
		NSEnumerator *pubEnum = [publications objectEnumerator];
		BibItem *pub;
		while (pub = [pubEnum nextObject]) {
			[pub setDocument:self];
		}
		
		NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:newPubs, @"pubs",  @"YES", @"lastRequest", nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocSetPublicationsNotification
															object:self
														  userInfo:notifInfo];
    }
}

- (NSMutableArray *) publications{
    return publications;
}

- (void)insertPublication:(BibItem *)pub atIndex:(unsigned int)index {
	[self insertPublication:pub atIndex:index lastRequest:YES];
}

- (void)insertPublication:(BibItem *)pub atIndex:(unsigned int)index lastRequest:(BOOL)last{
	NSUndoManager *undoManager = [self undoManager];
	[[undoManager prepareWithInvocationTarget:self] removePublication:pub];
	
    [publications insertObject:pub atIndex:index usingLock:pubsLock]; 
	[pub setDocument:self];
    
    [itemsForCiteKeys addObject:pub forKey:[pub citeKey]];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:pub, @"pub",
		(last ? @"YES" : @"NO"), @"lastRequest", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocAddItemNotification //should change this
														object:self
													  userInfo:notifInfo];
}

- (void)addPublication:(BibItem *)pub{
	[self addPublication:pub lastRequest:YES];
}

- (void)addPublication:(BibItem *)pub lastRequest:(BOOL)last{
    [self insertPublication:pub atIndex:0 lastRequest:last]; // insert new pubs at the beginning, so item number is handled properly
}


- (void)addPublications:(NSArray *)pubArray{
	int i = [pubArray count];
	
	// pubs are added at the beginning, so we add them in opposite order
	while(i--){
		[self addPublication:[pubArray objectAtIndex:i] lastRequest:(i == 0)];
	}
}

- (void)removePublication:(BibItem *)pub{
	[self removePublication:pub lastRequest:YES];
}

- (void)removePublication:(BibItem *)pub lastRequest:(BOOL)last{
	int index = [publications indexOfObjectIdenticalTo:pub];
	NSUndoManager *undoManager = [self undoManager];
	[[undoManager prepareWithInvocationTarget:self] insertPublication:pub atIndex:index];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:self, @"Sender", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocWillRemoveItemNotification
														object:pub
													  userInfo:notifInfo];	
	
    [itemsForCiteKeys removeObject:pub forKey:[pub citeKey]];

    if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3){}
    else
        [[NSFileManager defaultManager] removeSpotlightCacheForItemNamed:[pub citeKey]];
    
	[pub setDocument:nil];
	[publications removeObjectIdenticalTo:pub usingLock:pubsLock];
	[shownPublications removeObjectIdenticalTo:pub usingLock:pubsLock];
	    
	notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:pub, @"pub",
		(last ? @"YES" : @"NO"), @"lastRequest", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocDelItemNotification
														object:self
													  userInfo:notifInfo];	
}

- (NSArray *)publicationsForAuthor:(BibAuthor *)anAuthor{
    NSMutableSet *auths = [NSMutableSet set];
    NSEnumerator *pubEnum = [publications objectEnumerator];
    BibItem *bi;
    NSMutableArray *anAuthorPubs = [NSMutableArray array];
    
    while(bi = [pubEnum nextObject]){
        [auths addObjectsFromArray:[bi pubAuthors]];
        if([auths member:anAuthor] != nil){
            [anAuthorPubs addObject:bi];
        }
        [auths removeAllObjects];
    }
    return anAuthorPubs;
}

- (BOOL)citeKeyIsUsed:(NSString *)aCiteKey byItemOtherThan:(BibItem *)anItem{
    NSArray *items = [[self itemsForCiteKeys] arrayForKey:aCiteKey];
    
	if ([items count] > 1)
		return YES;
	if ([items count] == 1 && [items objectAtIndex:0] != anItem)	
		return YES;
	return NO;
}

- (IBAction)generateCiteKey:(id)sender
{
    unsigned int numberOfSelectedPubs = [self numberOfSelectedPubs];
	if (numberOfSelectedPubs == 0) return;
	
	NSEnumerator *selEnum = [self selectedPubEnumerator];
	NSNumber *row;
	BibItem *aPub;
    NSMutableArray *arrayOfPubs = [NSMutableArray arrayWithCapacity:numberOfSelectedPubs];
    NSMutableArray *arrayOfOldValues = [NSMutableArray arrayWithCapacity:numberOfSelectedPubs];
    NSMutableArray *arrayOfNewValues = [NSMutableArray arrayWithCapacity:numberOfSelectedPubs];
	BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKWillGenerateCiteKeyScriptHookName];
	
    // first we make sure all edits are committed
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFinalizeChangesNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
	
    // put these pubs into an array, since the indices can change after we set the cite key, due to sorting or searching
	while (row = [selEnum nextObject]) {
		aPub = [shownPublications objectAtIndex:[row intValue] usingLock:pubsLock];
        [arrayOfPubs addObject:aPub];
		if(scriptHook){
			[arrayOfOldValues addObject:[aPub citeKey]];
			[arrayOfNewValues addObject:[aPub suggestedCiteKey]];
		}
	}
	
	if (scriptHook) {
		[scriptHook setField:BDSKCiteKeyString];
		[scriptHook setOldValues:arrayOfOldValues];
		[scriptHook setNewValues:arrayOfNewValues];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:arrayOfPubs];
	}
    
	scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKDidGenerateCiteKeyScriptHookName];
	[arrayOfOldValues removeAllObjects];
	[arrayOfNewValues removeAllObjects];
    selEnum = [arrayOfPubs objectEnumerator];
	
    while(aPub = [selEnum nextObject]){
		NSString *newKey = [aPub suggestedCiteKey];
        [aPub setCiteKey:newKey];
		if(scriptHook){
			[arrayOfOldValues addObject:[aPub citeKey]];
			[arrayOfNewValues addObject:newKey];
		}
	}

	if (scriptHook) {
		[scriptHook setField:BDSKCiteKeyString];
		[scriptHook setOldValues:arrayOfOldValues];
		[scriptHook setNewValues:arrayOfNewValues];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:arrayOfPubs];
	}
	
	[[self undoManager] setActionName:(numberOfSelectedPubs > 1 ? NSLocalizedString(@"Generate Cite Keys",@"") : NSLocalizedString(@"Generate Cite Key",@""))];
}

- (NSString *)windowNibName{
        return @"BibDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    // NSLog(@"windowcontroller didloadnib");
    [super windowControllerDidLoadNib:aController];
    [self setupToolbar];
    [[aController window] setFrameAutosaveName:[self displayName]];
    [documentWindow makeFirstResponder:tableView];	
    [tableView removeAllTableColumns];
	[self setupTableColumns]; // calling it here mostly just makes sure that the menu is set up.
    [self sortPubsByDefaultColumn];
    [self setTableFont];
    [self updateUI];
	[self updatePreviews:nil]; // just to be sure
}

- (void)addWindowController:(NSWindowController *)windowController{
    // ARM:  if the window controller being added to the document's list only has a weak reference to the document (i.e. it doesn't retain its document/data), it needs to be added to the private BD_windowControllers ivar,
    // rather than using the NSDocument implementation.  NSDocument assumes that your windowcontrollers retain the document, and this causes problems when we close a doc window while an auxiliary windowcontroller (e.g. BibEditor)
    // is open, since we close those in doc windowWillClose:.  The AppKit allows the document to close, even if it's dirty, since it thinks your other windowcontroller is still hanging around with the data!
    if([windowController isKindOfClass:[BibEditor class]] ||
       [windowController isKindOfClass:[BibPersonController class]]){
        [BD_windowControllers addObject:windowController];
    } else {
        [super addWindowController:windowController];
    }
}

- (void)removeWindowController:(NSWindowController *)windowController{
    // see note in addWindowController: override
    if([windowController isKindOfClass:[BibEditor class]] ||
       [windowController isKindOfClass:[BibPersonController class]]){
        [BD_windowControllers removeObject:windowController];
    } else {
        [super removeWindowController:windowController];
    }
}

// select duplicates, then allow user to delete/copy/whatever
- (IBAction)selectDuplicates:(id)sender{
    
	[self setFilterField:@""]; // make sure we can see everything
    
    [documentWindow makeFirstResponder:tableView]; // make sure tableview has the focus
    [tableView deselectAll:nil];

    NSMutableArray *pubsToRemove = [[self publications] mutableCopy];
    CFIndex countOfItems = [pubsToRemove count];
    BibItem **pubs = NSZoneMalloc([self zone], sizeof(BibItem *) * countOfItems);
    [pubsToRemove getObjects:pubs];
    
    NSSet *uniquePubs = (NSSet *)CFSetCreate(CFAllocatorGetDefault(), (const void **)pubs, countOfItems, &BDSKBibItemDuplicationTestCallbacks);
    [pubsToRemove removeIdenticalObjectsFromArray:[uniquePubs allObjects]]; // remove all unique ones based on pointer equality, not isEqual
    [uniquePubs release];
    NSZoneFree([self zone], pubs);
    
    NSEnumerator *e = [pubsToRemove objectEnumerator];
    BibItem *anItem;

    while(anItem = [e nextObject])
        [tableView selectRow:[shownPublications indexOfObjectIdenticalTo:anItem usingLock:pubsLock] byExtendingSelection:YES];

    if([pubsToRemove count])
        [tableView scrollRowToVisible:[tableView selectedRow]];  // make sure at least one item is visible
    else
        NSBeep();

    // update status line after the updateUI notification, or else it gets overwritten
    [self setStatus:[NSString stringWithFormat:@"%i %@", [pubsToRemove count], NSLocalizedString(@"duplicate publications found.", @"")] immediate:NO];
    [pubsToRemove release];
}

#pragma mark -
#pragma mark  Document Saving and Reading

// if the user is saving in one of our plain text formats, give them an encoding option as well
// this also requires overriding saveToFile:saveOperation:delegate:didSaveSelector:contextInfo:
// to set the document's encoding before writing to the file
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel{
    if([super prepareSavePanel:savePanel]){
        if([[self fileType] isEqualToString:@"bibTeX database"] || [[self fileType] isEqualToString:@"RIS/Medline File"]){
            NSArray *oldViews = [[[savePanel accessoryView] subviews] retain]; // this should give us the file types popup from super and its label text field
            [savePanel setAccessoryView:SaveEncodingAccessoryView]; // use our accessory view, since we've set the size appropriately in IB
            NSEnumerator *e = [oldViews objectEnumerator];
            NSView *aView = nil;
            while(aView = [e nextObject]){ // now add in the subviews, excluding boxes (the old accessoryView box shouldn't be in the array)
                if(![aView isKindOfClass:[NSBox class]])
                    [[savePanel accessoryView] addSubview:aView];
            }
            if([[savePanel accessoryView] respondsToSelector:@selector(sizeToFit)])
                [(NSBox *)[savePanel accessoryView] sizeToFit]; // this keeps us from truncating the file types popup
            [oldViews release];
            // set the popup to reflect the document's present string encoding
            NSString *defaultEncName = [[BDSKStringEncodingManager sharedEncodingManager] displayedNameForStringEncoding:[self documentStringEncoding]];
            [saveTextEncodingPopupButton selectItemWithTitle:defaultEncName];
            [[savePanel accessoryView] setNeedsDisplay:YES];
        } return YES;
    } else return NO; // if super failed
}

// overriden in order to set the string encoding before writing out to disk, in case it was changed in the save-as panel
- (void)saveToFile:(NSString *)fileName 
     saveOperation:(NSSaveOperationType)saveOperation 
          delegate:(id)delegate 
   didSaveSelector:(SEL)didSaveSelector 
       contextInfo:(void *)contextInfo{
    // set the string encoding according to the popup if it's a plain text type
    if([[self fileType] isEqualToString:@"bibTeX database"] || [[self fileType] isEqualToString:@"RIS/Medline File"])
        [self setDocumentStringEncoding:[[BDSKStringEncodingManager sharedEncodingManager] 
                                            stringEncodingForDisplayedName:[saveTextEncodingPopupButton titleOfSelectedItem]]];
    [super saveToFile:fileName saveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

// we override this method only to catch exceptions raised during TeXification of BibItems
// returning NO keeps the document window from closing if the save was initiated by a close
// action, so the user gets a second chance at fixing the problem
- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)docType{
    volatile BOOL success;
    NS_DURING
        success = [super writeToFile:fileName ofType:docType];
    NS_HANDLER
        if([[localException name] isEqualToString:BDSKTeXifyException]){
            NSBeginCriticalAlertSheet(NSLocalizedString(@"Unable to save file completely.", @""),
                                      nil, nil, nil,
                                      documentWindow,
                                      nil, NULL, NULL, NULL,
                                      NSLocalizedString(@"If you are unable to correct the problem, you must save your file in a non-lossy encoding such as UTF-8, with accented character conversion disabled in BibDesk's preferences.", @""));
            success = NO;
        } else {
            [localException raise];
        }
    NS_ENDHANDLER
    
    if([self fileName]){
        // don't pass the fileName parameter, since it's likely a temp file somewhere due to the atomic save operation
        NSDictionary *infoDict = [[NSDictionary alloc] initWithObjectsAndKeys:[self publications], @"publications", [self fileName], @"fileName", nil];
        [[NSApp delegate] rebuildMetadataCache:infoDict];
        [infoDict release];
    }
        
    return success;
}

- (IBAction)saveDocument:(id)sender{
    [super saveDocument:sender];
    if([[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKAutoSaveAsRSSKey] == NSOnState
       && ![[self fileType] isEqualToString:@"Rich Site Summary file"]){
        // also save doc as RSS
#if DEBUG
        //NSLog(@"also save as RSS in saveDoc");
#endif
        [self exportAsRSS:nil];
    }
	// needed because of finalize changes
	[self performSelector:@selector(clearChangeCount) withObject:nil afterDelay:0.01];
}

- (IBAction)saveDocumentAs:(id)sender{
    [super saveDocumentAs:sender];
	// needed because of finalize changes
	[self performSelector:@selector(clearChangeCount) withObject:nil afterDelay:0.01];
}

- (void)clearChangeCount{
	[self updateChangeCount:NSChangeCleared];
}

- (IBAction)exportAsAtom:(id)sender{
    [self exportAsFileType:@"atom" selected:NO droppingInternal:NO];
}

- (IBAction)exportAsMODS:(id)sender{
    [self exportAsFileType:@"mods" selected:NO droppingInternal:NO];
}

- (IBAction)exportAsHTML:(id)sender{
    [self exportAsFileType:@"html" selected:NO droppingInternal:NO];
}

- (IBAction)exportAsRSS:(id)sender{
    [self exportAsFileType:@"rss" selected:NO droppingInternal:NO];
}

- (IBAction)exportAsEncodedBib:(id)sender{
    [self exportAsFileType:@"bib" selected:NO droppingInternal:NO];
}

- (IBAction)exportAsEncodedPublicBib:(id)sender{
    [self exportAsFileType:@"bib" selected:NO droppingInternal:YES];
}

- (IBAction)exportAsRIS:(id)sender{
    [self exportAsFileType:@"ris" selected:NO droppingInternal:NO];
}

- (IBAction)exportSelectionAsAtom:(id)sender{
    [self exportAsFileType:@"atom" selected:YES droppingInternal:NO];
}

- (IBAction)exportSelectionAsMODS:(id)sender{
    [self exportAsFileType:@"mods" selected:YES droppingInternal:NO];
}

- (IBAction)exportSelectionAsHTML:(id)sender{
    [self exportAsFileType:@"html" selected:YES droppingInternal:NO];
}

- (IBAction)exportSelectionAsRSS:(id)sender{
    [self exportAsFileType:@"rss" selected:YES droppingInternal:NO];
}

- (IBAction)exportSelectionAsEncodedBib:(id)sender{
    [self exportAsFileType:@"bib" selected:YES droppingInternal:NO];
}

- (IBAction)exportSelectionAsEncodedPublicBib:(id)sender{
    [self exportAsFileType:@"bib" selected:YES droppingInternal:YES];
}

- (IBAction)exportSelectionAsRIS:(id)sender{
    [self exportAsFileType:@"ris" selected:YES droppingInternal:NO];
}

- (void)exportAsFileType:(NSString *)fileType selected:(BOOL)selected droppingInternal:(BOOL)drop{
    NSSavePanel *sp = [NSSavePanel savePanel];
    [sp setRequiredFileType:fileType];
    [sp setDelegate:self];
    if([fileType isEqualToString:@"rss"]){
        [sp setAccessoryView:rssExportAccessoryView];
        // should call a [self setupRSSExportView]; to populate those with saved userdefaults!
    } else {
        if([fileType isEqualToString:@"bib"] || [fileType isEqualToString:@"ris"]){ // this is for exporting bib files with alternate text encodings
            [sp setAccessoryView:SaveEncodingAccessoryView];
        }
    }
    NSDictionary *contextInfo = [[NSDictionary dictionaryWithObjectsAndKeys:
		fileType, @"fileType", [NSNumber numberWithBool:drop], @"dropInternal", [NSNumber numberWithBool:selected], @"selected", nil] retain];
	[sp beginSheetForDirectory:nil
                          file:( [self fileName] == nil ? nil : [[NSString stringWithString:[[self fileName] stringByDeletingPathExtension]] lastPathComponent])
                modalForWindow:documentWindow
                 modalDelegate:self
                didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
                   contextInfo:contextInfo];

}

// this is only called by export actions, and isn't part of the regular save process
- (void)savePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    NSData *fileData = nil;
    NSString *fileName = nil;
    NSSavePanel *sp = (NSSavePanel *)sheet;
    NSDictionary *dict = (NSDictionary *)contextInfo;
	NSString *fileType = [dict objectForKey:@"fileType"];
    BOOL drop = [[dict objectForKey:@"dropInternal"] boolValue];
    BOOL selected = [[dict objectForKey:@"selected"] boolValue];
    NSArray *items = (selected ? [self selectedPublications] : publications);
	
	// first we make sure all edits are committed
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFinalizeChangesNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
	
    if(returnCode == NSOKButton){
        fileName = [sp filename];
        if([fileType isEqualToString:@"rss"]){
            fileData = [self rssDataForPublications:items];
        }else if([fileType isEqualToString:@"html"]){
            fileData = [self htmlDataForSelection:selected];
        }else if([fileType isEqualToString:@"mods"]){
            fileData = [self MODSDataForPublications:items];
        }else if([fileType isEqualToString:@"atom"]){
            fileData = [self atomDataForPublications:items];
        }else if([fileType isEqualToString:@"bib"]){            
            NSStringEncoding encoding = [[BDSKStringEncodingManager sharedEncodingManager] stringEncodingForDisplayedName:[saveTextEncodingPopupButton titleOfSelectedItem]];
            fileData = [self bibTeXDataForPublications:items encoding:encoding droppingInternal:drop];
        }else if([fileType isEqualToString:@"ris"]){
            NSStringEncoding encoding = [[BDSKStringEncodingManager sharedEncodingManager] stringEncodingForDisplayedName:[saveTextEncodingPopupButton titleOfSelectedItem]];
            fileData = [self RISDataForPublications:items encoding:encoding];
        }
        [fileData writeToFile:fileName atomically:YES];
    }
    [sp setRequiredFileType:@"bib"]; // just in case...
    [sp setAccessoryView:nil];
	[dict release];
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    // first we make sure all edits are committed
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFinalizeChangesNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
	
    if ([aType isEqualToString:@"bibTeX database"]){
		if([self documentStringEncoding] == 0)
			[NSException raise:@"String encoding exception" format:@"Document does not have a specified string encoding."];
		return [self bibTeXDataForPublications:publications encoding:[self documentStringEncoding] droppingInternal:NO];
    }else if ([aType isEqualToString:@"Rich Site Summary file"]){
        return [self rssDataForPublications:publications];
    }else if ([aType isEqualToString:@"HTML"]){
        return [self htmlDataForSelection:NO];
    }else if ([aType isEqualToString:@"MODS"]){
        return [self MODSDataForPublications:publications];
    }else if ([aType isEqualToString:@"ATOM"]){
        return [self atomDataForPublications:publications];
    }else if ([aType isEqualToString:@"RIS/Medline File"]){
        return [self RISDataForPublications:publications];
    }else
        return nil;
}

#define AddDataFromString(s) [d appendData:[s dataUsingEncoding:NSASCIIStringEncoding]]
#define AddDataFromFormCellWithTag(n) [d appendData:[[[rssExportForm cellAtIndex:[rssExportForm indexOfCellWithTag:n]] stringValue] dataUsingEncoding:NSASCIIStringEncoding]]

- (NSData *)rssDataForPublications:(NSArray *)items{
    NSEnumerator *e = [items objectEnumerator];
    id tmp = nil;
	BibItem *pub = nil;
    NSMutableData *d = [NSMutableData data];

    //  NSString *RSSTemplateFileName = [applicationSupportPath stringByAppendingPathComponent:@"rssTemplate.txt"];
    
    // add boilerplate RSS
    //    AddDataFromString(@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<rdf:RDF\nxmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"\nxmlns:bt=\"http://purl.org/rss/1.0/modules/bibtex/\"\nxmlns=\"http://purl.org/rss/1.0/\">\n<channel>\n");
    AddDataFromString(@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<rss version=\"0.92\">\n<channel>\n");
    AddDataFromString(@"<title>");
    AddDataFromFormCellWithTag(0);
    AddDataFromString(@"</title>\n");
    AddDataFromString(@"<link>");
    AddDataFromFormCellWithTag(1);
    AddDataFromString(@"</link>\n");
    AddDataFromString(@"<description>");
    [d appendData:[[rssExportTextField stringValue] dataUsingEncoding:NSASCIIStringEncoding]];
    AddDataFromString(@"</description>\n");
    AddDataFromString(@"<language>");
    AddDataFromFormCellWithTag(2);
    AddDataFromString(@"</language>\n");
    AddDataFromString(@"<copyright>");
    AddDataFromFormCellWithTag(3);
    AddDataFromString(@"</copyright>\n");
    AddDataFromString(@"<editor>");
    AddDataFromFormCellWithTag(4);
    AddDataFromString(@"</editor>\n");
    AddDataFromString(@"<lastBuildDate>");
    [d appendData:[[[NSCalendarDate calendarDate] descriptionWithCalendarFormat:@"%a, %d %b %Y %H:%M:%S %Z"] dataUsingEncoding:NSASCIIStringEncoding]];
    AddDataFromString(@"</lastBuildDate>\n");
    
	while(tmp = [e nextObject]){
		if ([tmp isKindOfClass:[BibItem class]])
			pub = (BibItem *)tmp;
		else
			pub = [shownPublications objectAtIndex:[tmp intValue] usingLock:pubsLock]; 
		[d appendData:[[NSString stringWithString:@"\n\n"] dataUsingEncoding:NSASCIIStringEncoding  allowLossyConversion:YES]];
        NS_DURING
			[d appendData:[[[BDSKConverter sharedConverter] stringByTeXifyingString:[tmp RSSValue]] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
        NS_HANDLER
			if([[localException name] isEqualToString:BDSKTeXifyException]){
				int i = NSRunAlertPanel(NSLocalizedString(@"Character Conversion Error", @"Title of alert when an error happens"),
										[NSString stringWithFormat: NSLocalizedString(@"An unrecognized character in \"%@\" could not be converted to TeX.", @"Informative alert text when the error happens."), [tmp RSSValue]],
										nil, nil, nil, nil);
			} else {
				[localException raise];
			}
        NS_ENDHANDLER
    }
	
    [d appendData:[@"</channel>\n</rss>" dataUsingEncoding:NSASCIIStringEncoding  allowLossyConversion:YES]];
    //    [d appendData:[@"</channel>\n</rdf:RDF>" dataUsingEncoding:NSASCIIStringEncoding  allowLossyConversion:YES]];
    return d;
}

- (NSData *)htmlDataForSelection:(BOOL)selected{
    NSString *applicationSupportPath = [[[NSFileManager defaultManager] applicationSupportDirectory:kUserDomain] stringByAppendingPathComponent:@"BibDesk"]; 


    
	NSString *fileTemplate = nil;
    if (selected) {
		NSMutableString *tmpString = [NSMutableString stringWithContentsOfFile:[applicationSupportPath stringByAppendingPathComponent:@"htmlExportTemplate"]];
		[tmpString replaceOccurrencesOfString:@"<$publicationsAsHTML/>" withString:@"<$selectionAsHTML/>" options:0 range:NSMakeRange(0,[fileTemplate length])];
		fileTemplate = tmpString;
	} else {
		fileTemplate = [NSMutableString stringWithContentsOfFile:[applicationSupportPath stringByAppendingPathComponent:@"htmlExportTemplate"]];
	}
	fileTemplate = [fileTemplate stringByParsingTagsWithStartDelimeter:@"<$"
                                                          endDelimeter:@"/>" 
                                                           usingObject:self];
    return [fileTemplate dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];    
}

- (NSString *)publicationsAsHTML{
	return [self HTMLStringForPublications:publications];
}

- (NSString *)selectionAsHTML{
	return [self HTMLStringForPublications:[self selectedPublications]];
}

- (NSString *)HTMLStringForPublications:(NSArray *)items{
    NSMutableString *s = [NSMutableString stringWithString:@""];
    NSString *applicationSupportPath = [[[NSFileManager defaultManager] applicationSupportDirectory:kUserDomain] stringByAppendingPathComponent:@"BibDesk"]; 
    NSString *defaultItemTemplate = [NSString stringWithContentsOfFile:[applicationSupportPath stringByAppendingPathComponent:@"htmlItemExportTemplate"]];
    NSString *itemTemplatePath;
    NSString *itemTemplate;
    NSEnumerator *e = [items objectEnumerator];
    id tmp = nil;
    BibItem *pub = nil;
    NSMutableData *d = [NSMutableData data];
    
	while(tmp = [e nextObject]){
		if ([tmp isKindOfClass:[BibItem class]])
			pub = (BibItem *)tmp;
		else
			pub = [shownPublications objectAtIndex:[tmp intValue] usingLock:pubsLock]; 
		itemTemplatePath = [applicationSupportPath stringByAppendingFormat:@"/htmlItemExportTemplate-%@", [pub type]];
		if ([[NSFileManager defaultManager] fileExistsAtPath:itemTemplatePath]) {
			itemTemplate = [NSString stringWithContentsOfFile:itemTemplatePath];
		} else {
			itemTemplate = defaultItemTemplate;
        }
		[s appendString:[NSString stringWithString:@"\n\n"]];
        [s appendString:[pub HTMLValueUsingTemplateString:itemTemplate]];
    }
    return s;
}

- (NSData *)atomDataForPublications:(NSArray *)items{
    NSEnumerator *e = [items objectEnumerator];
    id tmp = nil;
	BibItem *pub = nil;
    NSMutableData *d = [NSMutableData data];
    
    AddDataFromString(@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><feed xmlns=\"http://purl.org/atom/ns#\">");
    
    // TODO: output general feed info
    
	while(tmp = [e nextObject]){
		if ([tmp isKindOfClass:[BibItem class]])
			pub = (BibItem *)tmp;
		else
			pub = [shownPublications objectAtIndex:[tmp intValue] usingLock:pubsLock]; 
        AddDataFromString(@"<entry><title>foo</title><description>foo-2</description>");
        AddDataFromString(@"<content type=\"application/xml+mods\">");
        AddDataFromString([pub MODSString]);
        AddDataFromString(@"</content>");
        AddDataFromString(@"</entry>\n");
    }
    AddDataFromString(@"</feed>");
    
    return d;    
}

- (NSData *)MODSDataForPublications:(NSArray *)items{
    NSEnumerator *e = [items objectEnumerator];
    id tmp = nil;
	BibItem *pub = nil;
    NSMutableData *d = [NSMutableData data];

    AddDataFromString(@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><modsCollection xmlns=\"http://www.loc.gov/mods/v3\">");
	while(tmp = [e nextObject]){
		if ([tmp isKindOfClass:[BibItem class]])
			pub = (BibItem *)tmp;
		else
			pub = [shownPublications objectAtIndex:[tmp intValue] usingLock:pubsLock]; 
        AddDataFromString([pub MODSString]);
        AddDataFromString(@"\n");
    }
    AddDataFromString(@"</modsCollection>");
    
    return d;
}

- (NSData *)bibTeXDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding droppingInternal:(BOOL)drop{
    NSEnumerator *e = [items objectEnumerator];
    id tmp = nil;
	BibItem *pub = nil;
    NSMutableData *d = [NSMutableData data];
    
    if(encoding == 0)
        [NSException raise:@"String encoding exception" format:@"Sender did not specify an encoding to %@.", NSStringFromSelector(_cmd)];
    
	if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKAutoSortForCrossrefsKey])
		[self performSortForCrossrefs];
    
    BOOL shouldAppendFrontMatter = YES;
	
    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldUseTemplateFile]){
        NSMutableString *templateFile = [NSMutableString stringWithContentsOfFile:[[[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath]];
        
        [templateFile appendFormat:@"\n%%%% Created for %@ at %@ \n\n", NSFullUserName(), [NSCalendarDate calendarDate]];

        NSString *encodingName = [[BDSKStringEncodingManager sharedEncodingManager] displayedNameForStringEncoding:encoding];

        [templateFile appendFormat:@"\n%%%% Saved with string encoding %@ \n\n", encodingName];
        
        // remove all whitespace so we can make a comparison; just collapsing isn't quite good enough, unfortunately
        NSString *collapsedTemplate = [templateFile stringByRemovingWhitespace];
        NSString *collapsedFrontMatter = [frontMatter stringByRemovingWhitespace];
        if([NSString isEmptyString:collapsedFrontMatter]){
            shouldAppendFrontMatter = NO;
		}else if([collapsedTemplate containsString:collapsedFrontMatter]){
            NSLog(@"*** WARNING! *** Found duplicate preamble %@.  Using template from preferences.", frontMatter);
            shouldAppendFrontMatter = NO;
        }
        
        [d appendData:[templateFile dataUsingEncoding:encoding allowLossyConversion:YES]];
    }
    
    // only append this if it wasn't redundant (this assumes that the original frontmatter is either a subset of the necessary frontmatter, or that the user's preferences should override in case of a conflict)
    if(shouldAppendFrontMatter){
        [d appendData:[frontMatter dataUsingEncoding:encoding allowLossyConversion:YES]];
        [d appendData:[@"\n\n" dataUsingEncoding:encoding allowLossyConversion:YES]];
    }
        
    
    // output the document's macros:
	[d appendData:[[self bibTeXMacroString] dataUsingEncoding:encoding allowLossyConversion:YES]];
    
    // output the bibs

	while(tmp = [e nextObject]){
		if ([tmp isKindOfClass:[BibItem class]])
			pub = (BibItem *)tmp;
		else
			pub = [shownPublications objectAtIndex:[tmp intValue] usingLock:pubsLock]; 
        [d appendData:[[NSString stringWithString:@"\n\n"] dataUsingEncoding:encoding  allowLossyConversion:YES]];
        [d appendData:[[pub bibTeXStringDroppingInternal:drop] dataUsingEncoding:encoding allowLossyConversion:YES]];

    }
    return d;
        
}

- (NSData *)RISDataForPublications:(NSArray *)items encoding:(NSStringEncoding)encoding{
    NSEnumerator *e = [items objectEnumerator];
    id tmp = nil;
	BibItem *pub = nil;
    NSMutableData *d = [NSMutableData data];
    
    if(encoding == 0)
        [NSException raise:@"String encoding exception" format:@"Sender did not specify an encoding to %@.", NSStringFromSelector(_cmd)];
    
	while(tmp = [e nextObject]){
		if ([tmp isKindOfClass:[BibItem class]])
			pub = (BibItem *)tmp;
		else
			pub = [shownPublications objectAtIndex:[tmp intValue] usingLock:pubsLock]; 
        [d appendData:[[NSString stringWithString:@"\n\n"] dataUsingEncoding:encoding  allowLossyConversion:YES]];
        [d appendData:[[pub RISStringValue] dataUsingEncoding:encoding allowLossyConversion:YES]];
    }
        return d;
        
}

- (NSData *)RISDataForPublications:(NSArray *)items{
    
    if([self documentStringEncoding] == 0)
        [NSException raise:@"String encoding exception" format:@"Document does not have a specified string encoding."];
    
    return [self RISDataForPublications:items encoding:[self documentStringEncoding]];
    
}

#pragma mark -
#pragma mark Opening and Loading Files

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)docType{
    if([super readFromFile:fileName ofType:docType]){
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *newName = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"bib"];
        int i = 0;
        NSArray *writableTypesArray = [[self class] writableTypes];
        NSString *finalName = [NSString stringWithString:newName];
        
        if(![writableTypesArray containsObject:[self fileType]]){
            int rv = NSRunAlertPanel(NSLocalizedString(@"File Imported",
                                                       @"alert title"),
                                     NSLocalizedString(@"To re-read the file as BibTeX and see if the import was successful, use the \"Validate\" button.",
                                                       @"Validate file or skip."),
                                     NSLocalizedString(@"Validate", @"Validate"),
									 NSLocalizedString(@"Skip", @"Skip"), 
									 nil, nil);
            // let NSDocument name it
            [self setFileName:nil];
            [self setFileType:@"bibTeX database"];  // this is the only type we support via the save command
            if(rv == NSAlertDefaultReturn){
                // per user feedback, give an option to run the file through the BibTeX parser to see if we can open our own BibTeX representation
                // it is necessary to write the data to a file in order to use the error panel to jump to the offending line
				NSString * tempFilePath = [[NSApp delegate] temporaryFilePath:[[self fileName] lastPathComponent] createDirectory:NO];
                [[self bibTeXDataForPublications:publications encoding:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKDefaultStringEncodingKey] droppingInternal:NO] writeToFile:tempFilePath atomically:YES];
                [[NSApp delegate] openBibTeXFile:tempFilePath withEncoding:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKDefaultStringEncodingKey]];
                // [self performSelector:@selector(close) withObject:nil afterDelay:0]; // closes the window, but it's weird to have it open, then close
            }
            
        } return YES;
        
    } else return NO;  // if super failed
    
}

- (BOOL)revertToSavedFromFile:(NSString *)fileName ofType:(NSString *)type{
	if([super revertToSavedFromFile:fileName ofType:type]){
		[tableView deselectAll:self]; // clear before resorting
		[self searchFieldAction:searchField]; // redo the search
        [self sortPubsByColumn:nil]; // resort
		return YES;
	}
	return NO;
}

- (BOOL)revertToSavedFromURL:(NSURL *)aURL ofType:(NSString *)type{
	if([super revertToSavedFromURL:aURL ofType:type]){
        [tableView deselectAll:self]; // clear before resorting
		[self searchFieldAction:searchField]; // redo the search
        [self sortPubsByColumn:nil]; // resort
		return YES;
	}
	return NO;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
    if ([aType isEqualToString:@"bibTeX database"]){
        return [self loadBibTeXDataRepresentation:data encoding:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKDefaultStringEncodingKey]];
    }else if([aType isEqualToString:@"Rich Site Summary File"]){
        return [self loadRSSDataRepresentation:data];
    }else if([aType isEqualToString:@"RIS/Medline File"]){
        return [self loadRISDataRepresentation:data encoding:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKDefaultStringEncodingKey]];
    }else
        return NO;
}


- (BOOL)loadRISDataRepresentation:(NSData *)data encoding:(NSStringEncoding)encoding{
    int rv = 0;
    BOOL hadProblems = NO;
    NSMutableDictionary *dictionary = nil;
    NSString *tempFileName = nil;
    NSString *dataString = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
    NSString* filePath = [self fileName];
    NSMutableArray *newPubs = nil;
    
    if(dataString == nil){
        NSString *encStr = [[BDSKStringEncodingManager sharedEncodingManager] displayedNameForStringEncoding:encoding];
        [NSException raise:BDSKStringEncodingException 
                    format:NSLocalizedString(@"Unable to interpret data as %@.  Try a different encoding.", 
                                             @"need a single NSString format specifier"), encStr];
    }
    
    if(!filePath){
        filePath = @"Untitled Document";
    }
    dictionary = [NSMutableDictionary dictionaryWithCapacity:10];
    
    [[BDSKErrorObjectController sharedErrorObjectController] setDocumentForErrors:self];
	newPubs = [PubMedParser itemsFromString:dataString
                                      error:&hadProblems
                                frontMatter:frontMatter
                                   filePath:filePath];
    
    if(hadProblems){
        // run a modal dialog asking if we want to use partial data or give up
        rv = NSRunAlertPanel(NSLocalizedString(@"Error reading file!",@""),
                             NSLocalizedString(@"There was a problem reading the file. Do you want to use everything that did work (\"Keep Going\"), edit the file to correct the errors, or give up?\n(If you choose \"Keep Going\" and then save the file, you will probably lose data.)",@""),
                             NSLocalizedString(@"Give up",@""),
                             NSLocalizedString(@"Keep going",@""),
                             NSLocalizedString(@"Edit file", @""));
        if (rv == NSAlertDefaultReturn) {
            // the user said to give up
			[[BDSKErrorObjectController sharedErrorObjectController] removeErrorObjsForDocument:nil]; // this removes errors from a previous failed load
			[[BDSKErrorObjectController sharedErrorObjectController] handoverErrorObjsForDocument:self]; // this dereferences the doc from the errors, so they won't be removed when the document is deallocated
            return NO;
        }else if (rv == NSAlertAlternateReturn){
            // the user said to keep going, so if they save, they might clobber data...
        }else if(rv == NSAlertOtherReturn){
            // they said to edit the file.
            [[BDSKErrorObjectController sharedErrorObjectController] openEditWindowForDocument:self];
            [[BDSKErrorObjectController sharedErrorObjectController] showErrorPanel:self];
            return NO;
        }
    }
    
	[publications autorelease];
    publications = [newPubs retain];
		
	NSEnumerator *pubEnum = [publications objectEnumerator];
	BibItem *pub;
	while (pub = [pubEnum nextObject]) {
		[pub setDocument:self];
	}
	
	[self rebuildItemsForCiteKeys];
    
    [groupedPublications setArray:publications];
    // since we can't save pubmed files as pubmed files:
    [self updateChangeCount:NSChangeDone];
    return YES;
}

- (BOOL)loadRSSDataRepresentation:(NSData *)data{
    //stub
    return NO;
}

- (void)setDocumentStringEncoding:(NSStringEncoding)encoding{
    documentStringEncoding = encoding;
}

- (NSStringEncoding)documentStringEncoding{
    return documentStringEncoding;
}

- (BOOL)loadBibTeXDataRepresentation:(NSData *)data encoding:(NSStringEncoding)encoding{
    int rv = 0;
    BOOL hadProblems = NO;
    NSMutableDictionary *dictionary = nil;
    NSString *tempFileName = nil;
    NSString* filePath = [self fileName];
    NSMutableArray *newPubs;

    if(!filePath){
        filePath = @"Untitled Document";
    }
    dictionary = [NSMutableDictionary dictionaryWithCapacity:10];
    
    [self setDocumentStringEncoding:encoding];

    // to enable some cheapo timing, uncomment these:
//    NSDate *start = [NSDate date];
//    NSLog(@"start: %@", [start description]);
        
    [[BDSKErrorObjectController sharedErrorObjectController] setDocumentForErrors:self];
	
	newPubs = [BibTeXParser itemsFromData:data
                                    error:&hadProblems
                              frontMatter:frontMatter
                                 filePath:filePath
                                 document:self];

//    NSLog(@"end %@ elapsed: %f", [[NSDate date] description], [start timeIntervalSinceNow]);

    if(hadProblems){
        // run a modal dialog asking if we want to use partial data or give up
        rv = NSRunAlertPanel(NSLocalizedString(@"Error reading file!",@""),
                             NSLocalizedString(@"There was a problem reading the file. Do you want to use everything that did work (\"Keep Going\"), edit the file to correct the errors, or give up?\n(If you choose \"Keep Going\" and then save the file, you will probably lose data.)",@""),
                             NSLocalizedString(@"Give up",@""),
                             NSLocalizedString(@"Keep going",@""),
                             NSLocalizedString(@"Edit file", @""));
        if (rv == NSAlertDefaultReturn) {
            // the user said to give up
			[[BDSKErrorObjectController sharedErrorObjectController] removeErrorObjsForDocument:nil]; // this removes errors from a previous failed load
			[[BDSKErrorObjectController sharedErrorObjectController] handoverErrorObjsForDocument:self]; // this dereferences the doc from the errors, so they won't be removed when the document is deallocated
            return NO;
        }else if (rv == NSAlertAlternateReturn){
            // the user said to keep going, so if they save, they might clobber data...
        }else if(rv == NSAlertOtherReturn){
            // they said to edit the file.
            [[BDSKErrorObjectController sharedErrorObjectController] openEditWindowForDocument:self];
            [[BDSKErrorObjectController sharedErrorObjectController] showErrorPanel:self];
            return NO;
        }
    }
    
	[publications autorelease];
    publications = [newPubs retain];
		
	NSEnumerator *pubEnum = [publications objectEnumerator];
	BibItem *pub;
	while (pub = [pubEnum nextObject]) {
		[pub setDocument:self];
	}
	
	[self rebuildItemsForCiteKeys];
    
	[groupedPublications setArray:publications];
    return YES;
}

- (IBAction)newPub:(id)sender{
    [self createNewBlankPubAndEdit:YES];
}

- (IBAction)delPub:(id)sender{
	int numSelectedPubs = [self numberOfSelectedPubs];
	
    if (numSelectedPubs == 0) {
        return;
    }
	
	NSEnumerator *delEnum = [self selectedPubEnumerator]; // this is an array of indices, not pubs
	NSMutableArray *pubsToDelete = [NSMutableArray array];
	NSNumber *row;

	while(row = [delEnum nextObject]){ // make an array of BibItems, since the removePublication: method takes those as args; don't remove based on index, as those change after removal!
		[pubsToDelete addObject:[shownPublications objectAtIndex:[row intValue] usingLock:pubsLock]];
	}
	
	delEnum = [pubsToDelete objectEnumerator];
	BibItem *aBibItem = nil;
	int numDeletedPubs = 0;
	
	while(aBibItem = [delEnum nextObject]){
		numDeletedPubs ++;
		[self removePublication:aBibItem lastRequest:(numDeletedPubs == numSelectedPubs)];
	}
        
	NSString * pubSingularPlural;
	if (numSelectedPubs == 1) {
		pubSingularPlural = NSLocalizedString(@"Publication", @"publication");
	} else {
		pubSingularPlural = NSLocalizedString(@"Publications", @"publications");
	}
	
    [self setStatus:[NSString stringWithFormat:NSLocalizedString(@"Deleted %i %@",@"Deleted %i %@ [i-> number, @-> publication(s)]"),numSelectedPubs, pubSingularPlural] immediate:NO];
	
	[[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Remove %@", @"Remove Publication(s)"),pubSingularPlural]];
}



#pragma mark -
#pragma mark Search Field methods

- (IBAction)makeSearchFieldKey:(id)sender{
	[documentWindow makeFirstResponder:searchField];
}

- (NSMenu *)searchFieldMenu{
	NSMenu *cellMenu = [[[NSMenu alloc] initWithTitle:@"Search Menu"] autorelease];
	NSMenuItem *item1, *item2, *item3, *item4, *anItem;
	int curIndex = 0;
	
	item1 = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recent Searches",@"Recent Searches menu item") action: @selector(limitOne:) keyEquivalent:@""];
	[item1 setTag:NSSearchFieldRecentsTitleMenuItemTag];
	[cellMenu insertItem:item1 atIndex:curIndex++];
	[item1 release];
	item2 = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recents",@"Recents menu item") action:@selector(limitTwo:) keyEquivalent:@""];
	[item2 setTag:NSSearchFieldRecentsMenuItemTag];
	[cellMenu insertItem:item2 atIndex:curIndex++];
	[item2 release];
	item3 = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear",@"Clear menu item") action:@selector(limitThree:) keyEquivalent:@""];
	[item3 setTag:NSSearchFieldClearRecentsMenuItemTag];
	[cellMenu insertItem:item3 atIndex:curIndex++];
	[item3 release];
	// my stuff:
	item4 = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
	[item4 setTag:NSSearchFieldRecentsTitleMenuItemTag]; // makes it go away if there are no recents.
	[cellMenu insertItem:item4 atIndex:curIndex++];
	[item4 release];
	item4 = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Search Fields",@"Search Fields menu item") action:nil keyEquivalent:@""];
	[cellMenu insertItem:item4 atIndex:curIndex++];
	[item4 release];
	
	item4 = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@%C",NSLocalizedString(@"Add Field",@"Add Field... menu item"),0x2026] action:@selector(quickSearchAddField:) keyEquivalent:@""];
	[cellMenu insertItem:item4 atIndex:curIndex++];
	[item4 release];
	
	item4 = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@%C",NSLocalizedString(@"Remove Field",@"Remove Field... menu item"),0x2026] action:@selector(quickSearchRemoveField:) keyEquivalent:@""];
	[cellMenu insertItem:item4 atIndex:curIndex++];
	[item4 release];
	
	[cellMenu insertItem:[NSMenuItem separatorItem] atIndex:curIndex++];
	
	item4 = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"All Fields",@"All Fields menu item") action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
	[cellMenu insertItem:item4 atIndex:curIndex++];
	[item4 release];
	
	item4 = [[NSMenuItem alloc] initWithTitle:BDSKTitleString action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
	[cellMenu insertItem:item4 atIndex:curIndex++];
	[item4 release];
	
	item4 = [[NSMenuItem alloc] initWithTitle:BDSKAuthorString action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
	[cellMenu insertItem:item4 atIndex:curIndex++];
	[item4 release];
	
	item4 = [[NSMenuItem alloc] initWithTitle:BDSKDateString action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
	[cellMenu insertItem:item4 atIndex:curIndex++];
	[item4 release];
    
    if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3){}
    else {
        item4 = [[NSMenuItem alloc] initWithTitle:BDSKFileContentLocalizedString action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
        [cellMenu insertItem:item4 atIndex:curIndex++];
        [item4 release];
    }
	
	NSArray *prefsQuickSearchKeysArray = [[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys];
    NSString *aKey = nil;
    NSEnumerator *quickSearchKeyE = [prefsQuickSearchKeysArray objectEnumerator];
	
    while(aKey = [quickSearchKeyE nextObject]){
		
		anItem = [[NSMenuItem alloc] initWithTitle:aKey 
											action:@selector(searchFieldChangeKey:)
									 keyEquivalent:@""]; 
		[cellMenu insertItem:anItem atIndex:curIndex++];
		[anItem release];
    }
	
	return cellMenu;
}

- (void)setupSearchField{
	if (BDSK_USING_JAGUAR) {
		/* On a 10.2 - 10.2.x system */
		//@@ backwards Compatibility -, and set up the button
		
		NSArray *prefsQuickSearchKeysArray = [[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys];
		
		NSString *aKey = nil;
		NSEnumerator *quickSearchKeyE = [prefsQuickSearchKeysArray objectEnumerator];

		while(aKey = [quickSearchKeyE nextObject]){
			[quickSearchButton insertItemWithTitle:aKey
										   atIndex:0];
		}
		
		[quickSearchClearButton setEnabled:NO];
		[quickSearchClearButton setToolTip:NSLocalizedString(@"Clear the Quicksearch Field",@"")];
		
	} else {
		searchField = [[NSSearchField alloc] initWithFrame:[[searchFieldBox contentView] frame]];
		
		[searchFieldBox setContentView:searchField];
        [searchField release];
		
		NSSearchFieldCell *searchCell = [searchField cell];
		[searchCell setSendsWholeSearchString:NO]; // don't wait for Enter key press.
		[searchCell setSearchMenuTemplate:[self searchFieldMenu]];
		[searchCell setPlaceholderString:[NSString stringWithFormat:NSLocalizedString(@"Search by %@",@""),quickSearchKey]];
		[searchCell setRecentsAutosaveName:[NSString stringWithFormat:NSLocalizedString(@"%@ recent searches autosave ",@""),[self fileName]]];
		
		[searchField setDelegate:self];
		[searchField setAction:@selector(searchFieldAction:)];
        [searchField setTarget:self];
        		
		// set the search key's menuitem to NSOnState
        [self setSelectedSearchFieldKey:quickSearchKey];
		
	}
		
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
	
	if(BDSK_USING_JAGUAR == NO){
		
		NSSearchFieldCell *searchCell = [searchField cell];
		[searchCell setPlaceholderString:[NSString stringWithFormat:NSLocalizedString(@"Search by %@",@""),newKey]];
	
		NSMenu *templateMenu = [searchCell searchMenuTemplate];
		if(![quickSearchKey isEqualToString:newKey]){
			// find current key's menuitem and set it to NSOffState
			NSMenuItem *oldItem = [templateMenu itemWithTitle:quickSearchKey];
			[oldItem setState:NSOffState];	
		}
		
		// set new key's menuitem to NSOnState
		NSMenuItem *newItem = [templateMenu itemWithTitle:newKey];
		[newItem setState:NSOnState];
		[searchCell setSearchMenuTemplate:templateMenu];
		
		if(newKey != quickSearchKey){
			[newKey retain];
			[quickSearchKey release];
			quickSearchKey = newKey;
		}
	
        if([newKey isEqualToString:BDSKFileContentLocalizedString])
            [self searchByContent:searchField];
	}
 
	[self hidePublicationsWithoutSubstring:[searchField stringValue] //newQueryString
								   inField:quickSearchKey];
		
}

- (IBAction)quickSearchAddField:(id)sender{
    // first we fill the popup
	NSArray *prefsQuickSearchKeysArray = [[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys];
	BibTypeManager *typeMan = [BibTypeManager sharedManager];
	NSMutableSet *fieldNameSet = [NSMutableSet setWithSet:[typeMan allFieldNames]];
	[fieldNameSet unionSet:[NSSet setWithObjects:BDSKLocalUrlString, BDSKUrlString, BDSKCiteKeyString, BDSKDateString, @"Added", @"Modified", BDSKRatingString, BDSKReadString, nil]];
	NSMutableArray *colNames = [[fieldNameSet allObjects] mutableCopy];
	[colNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
	[colNames removeObjectsInArray:prefsQuickSearchKeysArray];
	
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
	
    NSMutableArray *prefsQuickSearchKeysMutableArray = nil;
	NSSearchFieldCell *searchFieldCell = [searchField cell];
	NSMenu *searchFieldMenuTemplate = [searchFieldCell searchMenuTemplate];
	NSMenuItem *menuItem = nil;
	NSString *newFieldTitle = nil;
	
    if(returnCode == 1){
        newFieldTitle = [[addFieldComboBox stringValue] capitalizedString];

        if(BDSK_USING_JAGUAR)
            [quickSearchButton insertItemWithTitle:newFieldTitle atIndex:0];
		
        [self setSelectedSearchFieldKey:newFieldTitle];
		
        prefsQuickSearchKeysMutableArray = [[[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys] mutableCopy] autorelease];
		
        if(!prefsQuickSearchKeysMutableArray){
            prefsQuickSearchKeysMutableArray = [NSMutableArray arrayWithCapacity:1];
        }
        [prefsQuickSearchKeysMutableArray addObject:newFieldTitle];
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:prefsQuickSearchKeysMutableArray
                                                          forKey:BDSKQuickSearchKeys];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:newFieldTitle action:@selector(searchFieldChangeKey:) keyEquivalent:@""];
		[searchFieldMenuTemplate insertItem:menuItem atIndex:10];
		[menuItem release];
		[searchFieldCell setSearchMenuTemplate:searchFieldMenuTemplate];
		[self setSelectedSearchFieldKey:newFieldTitle];
    }else{
        // cancel. we don't have to do anything..?
		
    }
}

- (IBAction)quickSearchRemoveField:(id)sender{
    [delFieldPrompt setStringValue:NSLocalizedString(@"Name of search field to remove:",@"")];
	NSMutableArray *prefsQuickSearchKeysMutableArray = [[[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys] mutableCopy] autorelease];
	
	if(!prefsQuickSearchKeysMutableArray){
		prefsQuickSearchKeysMutableArray = [NSMutableArray arrayWithCapacity:1];
	}
	[delFieldPopupButton removeAllItems];
	
	[delFieldPopupButton addItemsWithTitles:prefsQuickSearchKeysMutableArray];
	
	[NSApp beginSheet:delFieldSheet
       modalForWindow:documentWindow
        modalDelegate:self
       didEndSelector:@selector(quickSearchDelFieldSheetDidEnd:returnCode:contextInfo:)
          contextInfo:prefsQuickSearchKeysMutableArray];
}

- (IBAction)dismissDelFieldSheet:(id)sender{
    [delFieldSheet orderOut:sender];
    [NSApp endSheet:delFieldSheet returnCode:[sender tag]];
}

- (void)quickSearchDelFieldSheetDidEnd:(NSWindow *)sheet
							returnCode:(int) returnCode
						   contextInfo:(void *)contextInfo{
   
    NSMutableArray *prefsQuickSearchKeysMutableArray = (NSMutableArray *)contextInfo;
	NSSearchFieldCell *searchFieldCell = [searchField cell];
	NSMenu *searchFieldMenuTemplate = [searchFieldCell searchMenuTemplate];
	// NSMenuItem *menuItem = nil;
	NSString *delFieldTitle = nil;

    if(returnCode == 1){
        delFieldTitle = [[delFieldPopupButton selectedItem] title];

        if(BDSK_USING_JAGUAR)
            [quickSearchButton removeItemWithTitle:delFieldTitle];
		
        // if we were using that key, select another?

        prefsQuickSearchKeysMutableArray = [[[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKQuickSearchKeys] mutableCopy] autorelease];

        if(!prefsQuickSearchKeysMutableArray){
            prefsQuickSearchKeysMutableArray = [NSMutableArray arrayWithCapacity:1];
        }
        [prefsQuickSearchKeysMutableArray removeObject:delFieldTitle];
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:prefsQuickSearchKeysMutableArray
                                                          forKey:BDSKQuickSearchKeys];

		int itemIndex = [searchFieldMenuTemplate indexOfItemWithTitle:delFieldTitle];
		[searchFieldMenuTemplate removeItemAtIndex:itemIndex];

		[searchFieldCell setSearchMenuTemplate:searchFieldMenuTemplate];
		[self setSelectedSearchFieldKey:NSLocalizedString(@"All Fields",@"")];
    }else{
        // cancel. we don't have to do anything..?
       
    }
}

- (IBAction)clearQuickSearch:(id)sender{
    [searchField setStringValue:@""];
	[self searchFieldAction:searchField];
	[quickSearchClearButton setEnabled:NO];
}

- (void)controlTextDidChange:(NSNotification *)notif{
    id sender = [notif object];
	if(sender == searchField && BDSK_USING_JAGUAR){
		if([NSString isEmptyString:[searchField stringValue]]){
			[quickSearchClearButton setEnabled:NO];
		}else{
			[quickSearchClearButton setEnabled:YES];
		}
		[self searchFieldAction:searchField];
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
	NSMutableArray *pubsToSelect = nil;
    
    int numberOfRows = [tableView numberOfSelectedRows];
    // cache the selected BibItems for later selection, so the items remain selected after clearing the field
    if(numberOfRows){
        pubsToSelect = [NSMutableArray arrayWithCapacity:numberOfRows];
        NSEnumerator *selE = [tableView selectedRowEnumerator];
        NSNumber *row;
        // @@ use NSIndexSet
        while(row = [selE nextObject]){ // make an array of BibItems, since indexes change after search
            [pubsToSelect addObject:[shownPublications objectAtIndex:[row intValue] usingLock:pubsLock]];
        }
    }
	
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
    
    NSRange range = {0, NSNotFound};
    
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
    [andResultsArray sortUsingFunction:compareSetLengths context:nil];
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

NSComparisonResult compareSetLengths(NSSet *set1, NSSet *set2, void *context){
    NSNumber *n1 = [NSNumber numberWithInt:[set1 count]];
    NSNumber *n2 = [NSNumber numberWithInt:[set2 count]];
    return [n1 compare:n2];
}

#pragma mark Sorting

- (void) tableView: (NSTableView *) theTableView didClickTableColumn: (NSTableColumn *) tableColumn{
	// check whether this is the right kind of table view and don't re-sort when we have a contextual menu click
    if ([[NSApp currentEvent] type] == NSRightMouseDown) 
        return;
    if (tableView == theTableView){
        [self sortPubsByColumn:tableColumn];
	}else if (groupTableView == theTableView){
        [self sortGroupsByKey:nil];
	}

}

- (void)sortPubsByColumn:(NSTableColumn *)tableColumn{
    
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [tableView setDelegate:nil];
    
    // cache the selection; this works for multiple publications
    NSMutableArray *pubsToSelect = nil;    
    if([tableView numberOfSelectedRows]){
        NSEnumerator *selE = [self selectedPubEnumerator]; // this is an array of indices, not pubs
        pubsToSelect = [NSMutableArray array];
        NSNumber *row;
        
        while(row = [selE nextObject]){ // make an array of BibItems, since indices will change
            [pubsToSelect addObject:[shownPublications objectAtIndex:[row intValue] usingLock:pubsLock]];
        }
        
    }
    
    // a nil argument means resort the current column in the same order
    if(tableColumn == nil){
        if(lastSelectedColumnForSort == nil)
            return;
        tableColumn = lastSelectedColumnForSort; // use the previous one
        sortDescending = !sortDescending; // we'll reverse this again in the next step
    }
    
    if (lastSelectedColumnForSort == tableColumn) {
        // User clicked same column, change sort order
        sortDescending = !sortDescending;
    } else {
        // User clicked new column, change old/new column headers,
        // save new sorting selector, and re-sort the array.
        sortDescending = NO;
        if (lastSelectedColumnForSort) {
            [tableView setIndicatorImage: nil
                           inTableColumn: lastSelectedColumnForSort];
            [lastSelectedColumnForSort release];
        }
        lastSelectedColumnForSort = [tableColumn retain];
        [tableView setHighlightedTableColumn: tableColumn]; 
	}
    
	NSString *tcID = [tableColumn identifier];
	// resorting should happen whenever you click.
	if([tcID isEqualToString:BDSKCiteKeyString]){
		
		[shownPublications sortUsingSelector:@selector(keyCompare:) ascending:!sortDescending usingLock:pubsLock];
	}else if([tcID isEqualToString:BDSKTitleString]){
		
		[shownPublications sortUsingSelector:@selector(titleWithoutTeXCompare:) ascending:!sortDescending usingLock:pubsLock];
		
	}else if([tcID isEqualToString:BDSKContainerString]){
		
		[shownPublications sortUsingSelector:@selector(containerWithoutTeXCompare:) ascending:!sortDescending usingLock:pubsLock];
	}else if([tcID isEqualToString:BDSKDateString]){
		
		[shownPublications sortUsingSelector:@selector(dateCompare:) ascending:!sortDescending usingLock:pubsLock];
	}else if([tcID isEqualToString:BDSKDateCreatedString] ||
			 [tcID isEqualToString:@"Added"] ||
			 [tcID isEqualToString:@"Created"]){
		
		[shownPublications sortUsingSelector:@selector(createdDateCompare:) ascending:!sortDescending usingLock:pubsLock];
	}else if([tcID isEqualToString:BDSKDateModifiedString] ||
			 [tcID isEqualToString:@"Modified"]){
		
		[shownPublications sortUsingSelector:@selector(modDateCompare:) ascending:!sortDescending usingLock:pubsLock];
	}else if([tcID isEqualToString:BDSKFirstAuthorString]){
		
		[shownPublications sortUsingSelector:@selector(auth1Compare:) ascending:!sortDescending usingLock:pubsLock];
	}else if([tcID isEqualToString:BDSKSecondAuthorString]){
		
		[shownPublications sortUsingSelector:@selector(auth2Compare:) ascending:!sortDescending usingLock:pubsLock];
	}else if([tcID isEqualToString:BDSKThirdAuthorString]){
		
		[shownPublications sortUsingSelector:@selector(auth3Compare:) ascending:!sortDescending usingLock:pubsLock];
	}else if([tcID isEqualToString:BDSKAuthorString] ||
			 [tcID isEqualToString:@"Authors"]){
		
		[shownPublications sortUsingSelector:@selector(authorCompare:) ascending:!sortDescending usingLock:pubsLock];
	}else if([tcID isEqualToString:BDSKTypeString]){
		
		[shownPublications sortUsingSelector:@selector(pubTypeCompare:) ascending:!sortDescending usingLock:pubsLock];
    }else if([tcID isEqualToString:BDSKItemNumberString]){
		
		[shownPublications sortUsingSelector:@selector(fileOrderCompare:) ascending:!sortDescending usingLock:pubsLock];
    }else if([tcID isEqualToString:BDSKBooktitleString]){
        
        [shownPublications sortUsingSelector:@selector(booktitleWithoutTeXCompare:) ascending:!sortDescending usingLock:pubsLock];
    }else if([[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRatingFieldsKey] containsObject:tcID]){
        
		[pubsLock lock];
		if(sortDescending)
            [shownPublications sortUsingFunction:reverseGeneralRatingBibItemCompareFunc context:tcID];
        else
            [shownPublications sortUsingFunction:generalRatingBibItemCompareFunc context:tcID];
        [pubsLock unlock];
    }else if([[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKBooleanFieldsKey] containsObject:tcID]){
        
		[pubsLock lock];
		if(sortDescending)
            [shownPublications sortUsingFunction:reverseGeneralBooleanBibItemCompareFunc context:tcID];
        else
            [shownPublications sortUsingFunction:generalBooleanBibItemCompareFunc context:tcID];
        [pubsLock unlock];
    }else{
        
		[pubsLock lock];
		if(sortDescending)
            [shownPublications sortUsingFunction:reverseGeneralBibItemCompareFunc context:tcID];
        else
            [shownPublications sortUsingFunction:generalBibItemCompareFunc context:tcID];
        [pubsLock unlock];
	}
	
	

    // Set the graphic for the new column header
    [tableView setIndicatorImage: (sortDescending ?
                                   [NSImage imageNamed:@"sort-down"] :
                                   [NSImage imageNamed:@"sort-up"])
                   inTableColumn: tableColumn];

    // have to reload so the rows get set up right, but a full updateUI flashes the preview, which is annoying (and the preview won't change if we're maintaining the selection)
    [tableView reloadData];

    // fix the selection
    [self highlightBibs:pubsToSelect];
    [tableView scrollRowToVisible:[tableView selectedRow]]; // just go to the last one

    // reset ourself as delegate
    [tableView setDelegate:self];
}

- (void)sortPubsByDefaultColumn{
    OFPreferenceWrapper *defaults = [OFPreferenceWrapper sharedPreferenceWrapper];
    
    NSString *colName = [defaults objectForKey:BDSKDefaultSortedTableColumnKey];
    if([NSString isEmptyString:colName])
        return;
    
    NSTableColumn *tc = [tableView tableColumnWithIdentifier:colName];
    if(tc == nil)
        return;
    
    lastSelectedColumnForSort = [tc retain];
    sortDescending = [defaults boolForKey:BDSKDefaultSortedTableColumnIsDescendingKey];
    [self sortPubsByColumn:nil];
    [tableView setHighlightedTableColumn:tc];
}

NSComparisonResult reverseGeneralBibItemCompareFunc(id item1, id item2, void *context){
    return generalBibItemCompareFunc(item2, item1, context);
}

NSComparisonResult generalBibItemCompareFunc(id item1, id item2, void *context){
	NSString *tableColumnName = (NSString *)context;

    NSString *value1 = [item1 valueOfField:tableColumnName];
    NSString *value2 = [item2 valueOfField:tableColumnName];

	if ([NSString isEmptyString:value1]) {
		return ([NSString isEmptyString:value2])? NSOrderedSame : NSOrderedDescending;
	} else if ([NSString isEmptyString:value2]) {
		return NSOrderedAscending;
	}
	return [value1 localizedCaseInsensitiveNumericCompare:value2];
}

NSComparisonResult reverseGeneralRatingBibItemCompareFunc(id item1, id item2, void *context){
    return generalRatingBibItemCompareFunc(item2, item1, context);
}

NSComparisonResult generalRatingBibItemCompareFunc(id item1, id item2, void *context){
	NSString *tableColumnName = (NSString *)context;

    int value1 = [item1 ratingValueOfField:tableColumnName];
    int value2 = [item2 ratingValueOfField:tableColumnName];

	if (value1 < value2)
        return NSOrderedAscending;
	if (value1 > value2)
        return NSOrderedDescending;
	return NSOrderedSame;
}

NSComparisonResult reverseGeneralBooleanBibItemCompareFunc(id item1, id item2, void *context){
    return generalBooleanBibItemCompareFunc(item2, item1, context);
}

NSComparisonResult generalBooleanBibItemCompareFunc(id item1, id item2, void *context){
	NSString *tableColumnName = (NSString *)context;

    BOOL value1 = [item1 boolValueOfField:tableColumnName];
    BOOL value2 = [item2 boolValueOfField:tableColumnName];

	if (value1 < value2)
        return NSOrderedAscending;
	if (value1 > value2)
        return NSOrderedDescending;
	return NSOrderedSame;
}

#pragma mark

- (IBAction)emailPubCmd:(id)sender{
    NSEnumerator *e = [self selectedPubEnumerator];
    NSNumber *i;
    BibItem *pub = nil;
    
    NSFileManager *dfm = [NSFileManager defaultManager];
    NSString *pubPath = nil;
    NSMutableString *body = [NSMutableString string];
    NSMutableArray *files = [NSMutableArray array];
    
    while (i = [e nextObject]) {
        pub = [shownPublications objectAtIndex:[i intValue] usingLock:pubsLock];
        pubPath = [pub localURLPath];
        
        if([dfm fileExistsAtPath:pubPath])
            [files addObject:pubPath];
        
        // use the detexified version without internal fields, since TeXification introduces things that 
        // AppleScript can't deal with (OAInternetConfig may end up using AS)
        [body appendString:[pub bibTeXStringUnexpandedAndDeTeXifiedWithoutInternalFields]];
        [body appendString:@"\n\n"];
    }
    
    // ampersands are common in publication names
    [body replaceOccurrencesOfString:@"&" withString:@"\\&" options:NSLiteralSearch range:NSMakeRange(0, [body length])];
    // escape backslashes
    [body replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:NSLiteralSearch range:NSMakeRange(0, [body length])];
    // escape double quotes
    [body replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSLiteralSearch range:NSMakeRange(0, [body length])];

    // OAInternetConfig will use the default mail helper (at least it works with Mail.app and Entourage)
    OAInternetConfig *ic = [OAInternetConfig internetConfig];
    [ic launchMailTo:nil
          carbonCopy:nil
     blindCarbonCopy:nil
             subject:@"BibDesk references"
                body:body
         attachments:files];

}


- (IBAction)editPubCmd:(id)sender{
    NSString *colID = nil;
	NSArray *localFileFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey];
	NSArray *remoteURLFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey];

    if([tableView clickedColumn] != -1){
		colID = [[[tableView tableColumns] objectAtIndex:[tableView clickedColumn]] identifier];
    }
    if(colID && [localFileFields containsObject:colID]){
		[self multipleOpenFileSheetDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[colID retain]];
    }else if(colID && [remoteURLFields containsObject:colID]){
		[self multipleOpenURLSheetDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[colID retain]];
    }else{
		int n = [self numberOfSelectedPubs];
		if (n > 6) {
			// Do we really want a gazillion of editor windows?
			NSBeginAlertSheet(NSLocalizedString(@"Edit publications", @"Edit publications (multiple open warning)"), 
							  NSLocalizedString(@"Cancel", @"Cancel"), 
							  NSLocalizedString(@"Open", @"multiple open warning Open button"), 
							  nil, 
							  documentWindow, self, 
							  @selector(multipleEditSheetDidEnd:returnCode:contextInfo:), NULL, 
							  nil, 
							  NSLocalizedString(@"BibDesk is about to open %i editor windows. Do you want to proceed?" , @"mulitple open warning question"), n);
		} else {
			[self multipleEditSheetDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:nil];
		}
	}
}

- (void)multipleEditSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator *e = [self selectedPubEnumerator];
	NSNumber * i;
	
	if (returnCode == NSAlertAlternateReturn ) {
		// the user said to go ahead
		while (i = [e nextObject]) {
			[self editPub:[shownPublications objectAtIndex:[i intValue] usingLock:pubsLock]];
		}
	}
	// otherwise do nothing
}

//@@ notifications - when adding pub notifications is fully implemented we won't need this.
- (void)editPub:(BibItem *)pub{
    BibEditor *e = [pub editorObj];
    if(e == nil){
        e = [[BibEditor alloc] initWithBibItem:pub document:self];
        [self addWindowController:e];
        [e release];
    }
    [e show];
}

- (IBAction)openLinkedFile:(id)sender{
	int n = [self numberOfSelectedPubs];
	NSString *field = [sender representedObject];
	if (n > 6) {
		// Do we really want a gazillion of files to open?
		NSBeginAlertSheet(NSLocalizedString(@"Open Linked Files", @"Open Linked Files (multiple open warning)"), 
						  NSLocalizedString(@"Cancel", @"Cancel"), 
						  NSLocalizedString(@"Open", @"multiple open warning Open button"), 
						  nil, 
						  documentWindow, self, 
						  @selector(multipleOpenFileSheetDidEnd:returnCode:contextInfo:), NULL, 
						  [field retain], 
						  NSLocalizedString(@"BibDesk is about to open %i linked files. Do you want to proceed?" , @"mulitple open linked files question"), n);
	} else {
		[self multipleOpenFileSheetDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[field retain]];
	}
}

-(void)multipleOpenFileSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator *e = [self selectedPubEnumerator];
	NSNumber * i;
	BibItem *pub;
	NSString *field = (NSString *)contextInfo;
    
    NSString *searchString = [searchField stringValue];
    NSURL *fileURL;
	
	if (returnCode == NSAlertAlternateReturn ) {
		// the user said to go ahead
		while (i = [e nextObject]) {
			pub = [shownPublications objectAtIndex:[i intValue] usingLock:pubsLock];
            fileURL = [pub URLForField:field];
            if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3){
                [[NSWorkspace sharedWorkspace] openURL:fileURL];
            } else {
                [[NSWorkspace sharedWorkspace] openURL:fileURL withSearchString:searchString];
            }
		}
	}
	// otherwise do nothing
	[field release];
}

- (IBAction)revealLinkedFile:(id)sender{
	int n = [self numberOfSelectedPubs];
	NSString *field = [sender representedObject];
	if (n > 6) {
		// Do we really want a gazillion of Finder windows?
		NSBeginAlertSheet(NSLocalizedString(@"Reveal Linked Files", @"Reveal Linked Files (multiple reveal warning)"), 
						  NSLocalizedString(@"Cancel", @"Cancel"), 
						  NSLocalizedString(@"Reveal", @"multiple reveal warning Reveal button"), 
						  nil, 
						  documentWindow, self, 
						  @selector(multipleRevealFileSheetDidEnd:returnCode:contextInfo:), NULL, 
						  [field retain], 
						  NSLocalizedString(@"BibDesk is about to reveal %i linked files. Do you want to proceed?" , @"mulitple reveal linked files question"), n);
	} else {
		[self multipleRevealFileSheetDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[field retain]];
	}
}

- (void)multipleRevealFileSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator *e = [self selectedPubEnumerator];
	NSNumber * i;
	BibItem *pub;
	NSString *field = (NSString *)contextInfo;
	
	if (returnCode == NSAlertAlternateReturn ) {
		// the user said to go ahead
		while (i = [e nextObject]) {
			pub = [shownPublications objectAtIndex:[i intValue] usingLock:pubsLock];
			[[NSWorkspace sharedWorkspace]  selectFile:[pub localFilePathForField:field] inFileViewerRootedAtPath:nil];
		}
	}
	// otherwise do nothing
	[field release];
}

- (IBAction)openRemoteURL:(id)sender{
	int n = [self numberOfSelectedPubs];
	NSString *field = [sender representedObject];
	if (n > 6) {
		// Do we really want a gazillion of Finder windows?
		NSBeginAlertSheet(NSLocalizedString(@"Open Remote URL", @"Open Remote URL (multiple open warning)"), 
						  NSLocalizedString(@"Cancel", @"Cancel"), 
						  NSLocalizedString(@"Open", @"multiple open warning Open button"), 
						  nil, 
						  documentWindow, self, 
						  @selector(multipleOpenURLSheetDidEnd:returnCode:contextInfo:), NULL, 
						  [field retain], 
						  NSLocalizedString(@"BibDesk is about to open %i URLs. Do you want to proceed?" , @"mulitple open URLs question"), n);
	} else {
		[self multipleOpenURLSheetDidEnd:nil returnCode:NSAlertAlternateReturn contextInfo:[field retain]];
	}
}

- (void)multipleOpenURLSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator *e = [self selectedPubEnumerator];
	NSNumber * i;
	BibItem *pub;
	NSString *field = (NSString *)contextInfo;
	
	if (returnCode == NSAlertAlternateReturn ) {
		// the user said to go ahead
		while (i = [e nextObject]) {
			pub = [shownPublications objectAtIndex:[i intValue] usingLock:pubsLock];
			[[NSWorkspace sharedWorkspace] openURL:[pub remoteURLForField:field]];
		}
	}
	// otherwise do nothing
	[field release];
}

#pragma mark Pasteboard || copy

- (IBAction)cut:(id)sender{ // puts the pubs on the pasteboard, using the default implementation, then deletes them
	if ([self numberOfSelectedPubs] == 0) return;
	
    [self copy:self];
    [self delPub:self];
}

- (IBAction)copy:(id)sender{
	if ([self numberOfSelectedPubs] == 0) return;
	
    OFPreferenceWrapper *sud = [OFPreferenceWrapper sharedPreferenceWrapper];
    if([[sud objectForKey:BDSKDragCopyKey] intValue] == 0){
        [self copyAsBibTex:self];
    }else if([[sud objectForKey:BDSKDragCopyKey] intValue] == 1){
        [self copyAsTex:self];
    }else if([[sud objectForKey:BDSKDragCopyKey] intValue] == 2){
        [self copyAsPDF:self];
    }else if([[sud objectForKey:BDSKDragCopyKey] intValue] == 3){
        [self copyAsRTF:self];
    }
}

- (IBAction)copyAsBibTex:(id)sender{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    
    [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pboard setString:[self bibTeXStringForPublications:[self selectedPublications]]
			  forType:NSStringPboardType];
}    

- (IBAction)copyAsPublicBibTex:(id)sender{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    
    [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pboard setString:[self bibTeXStringDroppingInternal:YES forPublications:[self selectedPublications]]
			  forType:NSStringPboardType];
}    

- (IBAction)copyAsTex:(id)sender{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];

    [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, BDSKBibTeXStringPboardType, nil] owner:nil];
    [pboard setString:[self citeStringForSelection] 
			  forType:NSStringPboardType];
    [pboard setString:[self bibTeXStringForPublications:[self selectedPublications]]
			  forType:BDSKBibTeXStringPboardType];
}

- (IBAction)copyAsRIS:(id)sender{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    NSEnumerator *e = [self selectedPubEnumerator];
    NSMutableString *s = [NSMutableString string];
    NSNumber *i;
    [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    while(i=[e nextObject]){
	    [s appendString:@"\n"];
        [s appendString:[[shownPublications objectAtIndex:[i intValue] usingLock:pubsLock] RISStringValue]];
		[s appendString:@"\n"];
    }
    [pboard setString:s forType:NSStringPboardType];
}    

- (IBAction)copyAsPDF:(id)sender{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	NSString *bibString = [self bibTeXStringForPublications:[self selectedPublications]];
	NSData *data = nil;
	
    [pboard declareTypes:[NSArray arrayWithObjects:NSPDFPboardType, BDSKBibTeXStringPboardType, nil] owner:nil];
    [pboard setString:bibString forType:BDSKBibTeXStringPboardType];
	if([[[BDSKPreviewer sharedPreviewer] window] isVisible] && 
	   (data = [[BDSKPreviewer sharedPreviewer] PDFData])){
		// the previewer is up to date, so we reuse it's PDF data
		[pboard setData:data forType:NSPDFPboardType];
	}else if([texTask runWithBibTeXString:bibString generatedTypes:BDSKGeneratePDF] && (data = [texTask PDFData])){
		// we'll generate it ourselves then
		[pboard setData:data forType:NSPDFPboardType];
	}else{
		// we couldn't get the RTF data
		NSBeep();
	}
}

- (IBAction)copyAsRTF:(id)sender{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	NSString *bibString = [self bibTeXStringForPublications:[self selectedPublications]];
	NSData *data = nil;
    
    [pboard declareTypes:[NSArray arrayWithObjects:NSRTFPboardType, BDSKBibTeXStringPboardType, nil] owner:nil];
    [pboard setString:bibString forType:BDSKBibTeXStringPboardType];
	if([[[BDSKPreviewer sharedPreviewer] window] isVisible] && 
	   (data = [[BDSKPreviewer sharedPreviewer] RTFData])){
		// the previewer is up to date, so we reuse it's RTF data
		[pboard setData:data forType:NSRTFPboardType];
	}else if([texTask runWithBibTeXString:bibString generatedTypes:BDSKGenerateRTF] && (data = [texTask RTFData])){
		// we'll generate it ourselves then
		[pboard setData:data forType:NSRTFPboardType];
	}else{
		// we couldn't get the RTF data
		NSBeep();
	}
}

- (IBAction)copyAsLaTeX:(id)sender{
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	NSString *bibString = [self bibTeXStringForPublications:[self selectedPublications]];
	NSString *string = nil;
    
    [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, BDSKBibTeXStringPboardType, nil] owner:nil];
    [pboard setString:bibString forType:BDSKBibTeXStringPboardType];
	if([[[BDSKPreviewer sharedPreviewer] window] isVisible] && 
	   (string = [[BDSKPreviewer sharedPreviewer] LaTeXString])){
		// the previewer is up to date, so we reuse it's RTF data
		[pboard setString:string forType:NSStringPboardType];
	}else if([texTask runWithBibTeXString:bibString generatedTypes:BDSKGenerateLaTeX] && (string = [texTask LaTeXString])){
		// we'll generate it ourselves then
		[pboard setString:string forType:NSStringPboardType];
	}else{
		// we couldn't get the LaTeX data
		NSBeep();
	}
}

- (NSString *)citeStringForSelection{
    return [self citeStringForPublications:[self selectedPublications]
								citeString:[[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKCiteStringKey]];
}

- (NSString *)citeStringForPublications:(NSArray *)items citeString:(NSString *)citeString{
	OFPreferenceWrapper *sud = [OFPreferenceWrapper sharedPreferenceWrapper];
	BOOL prependTilde = [sud boolForKey:BDSKCitePrependTildeKey];
	NSString *startCite = [NSString stringWithFormat:@"%@\\%@%@", (prependTilde? @"~" : @""), citeString, [sud stringForKey:BDSKCiteStartBracketKey]]; 
	NSString *endCite = [sud stringForKey:BDSKCiteEndBracketKey]; 
    NSMutableString *s = [NSMutableString stringWithString:startCite];
	
    BOOL sep = [sud boolForKey:BDSKSeparateCiteKey];
	NSString *separator = (sep)? [NSString stringWithFormat:@"%@%@", endCite, startCite] : @",";
    NSNumber *i;
	BOOL first = YES;
    
    NSEnumerator *e = [items objectEnumerator];
    while(i = [e nextObject]){
		if(first) first = NO;
		else [s appendString:separator];
        [s appendString:[[shownPublications objectAtIndex:[i intValue] usingLock:pubsLock] citeKey]];
    }
	[s appendString:endCite];
	
	return s;
}

- (NSString *)bibTeXStringForPublications:(NSArray *)items{
	return [self bibTeXStringDroppingInternal:NO forPublications:items];
}

- (NSString *)bibTeXStringDroppingInternal:(BOOL)drop forPublications:(NSArray *)items{
    NSMutableString *s = [NSMutableString string];
	NSEnumerator *e = [items objectEnumerator];
    NSNumber *i;
	BibItem *pub;
	
    while(i = [e nextObject]){
		pub = [shownPublications objectAtIndex:[i intValue] usingLock:pubsLock];
		NS_DURING
			[s appendString:@"\n"];
			[s appendString:[pub bibTeXStringDroppingInternal:drop]];
			[s appendString:@"\n"];
		NS_HANDLER
			if([[localException name] isEqualToString:BDSKTeXifyException])
				NSLog(@"Discarding exception raised for item \"%@\"", [pub citeKey]);
			else
				[localException raise];
		NS_ENDHANDLER
    }
	
	return s;
}

#pragma mark Pasteboard || paste

// ----------------------------------------------------------------------------------------
// paste: get text, parse it as bibtex, add the entry to publications and (optionally) edit it.
// ----------------------------------------------------------------------------------------

- (IBAction)paste:(id)sender{
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	NSString * error;

	if (![self addPublicationsFromPasteboard:pasteboard error:&error]) {
			// an error occured
		//Display error message or simply Beep?
		NSBeep();
	}
}

- (IBAction)duplicate:(id)sender{
    NSEnumerator *selPubs = [self selectedPubEnumerator];
    NSNumber *i;
    NSMutableArray *newPubs = [NSMutableArray array];
    BibItem *aPub;
    while(i = [selPubs nextObject]){
        aPub = [[shownPublications objectAtIndex:[i intValue] usingLock:pubsLock] copy];
        [newPubs addObject:aPub];
        [aPub release];
    }
    
    [self addPublications:newPubs]; // notification will take care of clearing the search/sorting
    [self highlightBibs:newPubs];
    
    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKEditOnPasteKey]) {
        [self editPubCmd:nil]; // this will aske the user when there are many pubs
    }
}

- (void)createNewBlankPub{
    [self createNewBlankPubAndEdit:NO];
}

- (void)createNewBlankPubAndEdit:(BOOL)yn{
    BibItem *newBI = [[[BibItem alloc] init] autorelease];
    
    if([groupTableView selectedRow] > 0)
        [newBI addToGroupNamed:[self selectedGroupName] usingField:[self currentGroupField] handleInherited:BDSKOperationSet];
    
    [self addPublication:newBI];
	[[self undoManager] setActionName:NSLocalizedString(@"Add Publication",@"")];
    [self highlightBib:newBI];
    if(yn == YES)
    {
        [self editPub:newBI];
    }
}

- (BOOL)addPublicationsFromPasteboard:(NSPasteboard *)pb error:(NSString **)error{
	// these are the types we support, the order here is important!
    NSString *type = [pb availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibItemPboardType, BDSKReferenceMinerStringPboardType, BDSKBibTeXStringPboardType, NSStringPboardType, NSFilenamesPboardType, nil]];
    NSArray *newPubs = nil;
	
    if([type isEqualToString:BDSKBibItemPboardType]){
        NSData *pbData = [pb dataForType:BDSKBibItemPboardType];
		newPubs = [NSKeyedUnarchiver unarchiveObjectWithData:pbData];
    } else if([type isEqualToString:BDSKReferenceMinerStringPboardType]){ // pasteboard type from Reference Miner, determined using Pasteboard Peeker
        NSString *pbString = [pb stringForType:BDSKReferenceMinerStringPboardType]; 	
        // sniffing the string for RIS is broken because RefMiner puts junk at the beginning
		newPubs = [self newPublicationsForString:pbString isRIS:YES error:error];
    }else if([type isEqualToString:BDSKBibTeXStringPboardType]){
        NSString *pbString = [pb stringForType:BDSKBibTeXStringPboardType]; 	
        newPubs = [self newPublicationsForString:pbString isRIS:NO error:error];
    }else if([type isEqualToString:NSStringPboardType]){
        NSString *pbString = [pb stringForType:NSStringPboardType]; 	
		// sniff the string to see if it is RIS
        newPubs = [self newPublicationsForString:pbString isRIS:[pbString isRISString] error:error];
    }else if([type isEqualToString:NSFilenamesPboardType]){
		NSArray *pbArray = [pb propertyListForType:NSFilenamesPboardType]; // we will get an array
		newPubs = [self newPublicationsForFiles:pbArray error:error];
	}else{
		*error = NSLocalizedString(@"Did not find anything appropriate on the pasteboard", @"BibDesk couldn't find any files or bibliography information in the data it received.");
		return NO;
	}
	
	if (newPubs == nil)
		return NO; // there was an error, the error string should already have been set
	if ([newPubs count] == 0) 
		return YES; // nothing to do
	
    [groupTableView selectRow:0 byExtendingSelection:NO];    
	[self addPublications:newPubs];
	[self highlightBibs:newPubs];
	
	if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKEditOnPasteKey]) {
		[self editPubCmd:nil]; // this will ask the user when there are many pubs
	}
	
	[[self undoManager] setActionName:NSLocalizedString(@"Add Publication",@"")];
    
    return YES;
}

- (NSArray *)newPublicationsForString:(NSString *)string isRIS:(BOOL)isRIS error:(NSString **)error {
    BOOL hadProblems = NO;
    NSArray *newPubs = nil;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    
	[[BDSKErrorObjectController sharedErrorObjectController] setDocumentForErrors:self];
    if(isRIS){
        newPubs = [PubMedParser itemsFromString:string error:&hadProblems];
    } else {
        newPubs = [BibTeXParser itemsFromData:data error:&hadProblems];
    }

	if(hadProblems) {
		// original code follows:
		// run a modal dialog asking if we want to use partial data or give up
		int rv = 0;
		rv = NSRunAlertPanel(NSLocalizedString(@"Error reading file!",@""),
							 NSLocalizedString(@"There was a problem inserting the data. Do you want to keep going and use everything that BibDesk could analyse or open a window containing the data to edit it and remove the errors?\n(It's likely that choosing \"Keep Going\" will lose some data.)",@""),
							 NSLocalizedString(@"Cancel",@""),
							 NSLocalizedString(@"Keep going",@""),
							 NSLocalizedString(@"Edit data", @""));
		if (rv == NSAlertDefaultReturn) {
			// the user said to give up
			*error = NSLocalizedString(@"There were errors analysing string", @"BibDesk had problems parsing bibliography data in the text it received.");
			return nil;
		}else if (rv == NSAlertAlternateReturn){
			// the user said to keep going, so if they save, they might clobber data...
		}else if(rv == NSAlertOtherReturn){
			// they said to edit the file.
			NSString * tempFileName = [[NSApp delegate] temporaryFilePath:[[self fileName] lastPathComponent] createDirectory:NO];
			[data writeToFile:tempFileName atomically:YES];
			[[BDSKErrorObjectController sharedErrorObjectController] openEditWindowWithFile:tempFileName];
			[[BDSKErrorObjectController sharedErrorObjectController] showErrorPanel:self];		
			*error = NSLocalizedString(@"There were errors analysing string", @"BibDesk had problems parsing bibliography data in the text it received.");
			return nil;	
		}		
	}

	if ([newPubs count] == 0) {
		*error = NSLocalizedString(@"Could not analyse string", @"BibDesk couldn't find bibliography data in the text it received.");
		return nil;
	}
	
    return newPubs;
}

/* ssp: 2004-07-18
Broken out of  original drag and drop handling
Takes an array of file paths and adds them to the document if possible.
This method always returns YES. Even if some or many operations fail.
*/
- (NSArray *)newPublicationsForFiles:(NSArray *)filenames error:(NSString **)error {
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];

	NSEnumerator * e = [filenames objectEnumerator];
	NSString * fnStr = nil;
	NSURL * url = nil;
	NSMutableArray *newPubs = [NSMutableArray arrayWithCapacity:1];
	BibItem * newBI;
	
	while(fnStr = [e nextObject]){
		if(url = [NSURL fileURLWithPath:fnStr]){
			newBI = [[BibItem alloc] init];
            
			NSString *newUrl = [[NSURL fileURLWithPath:
				[fnStr stringByExpandingTildeInPath]]absoluteString];

			[newBI setField:BDSKLocalUrlString toValue:newUrl];
			
			[newBI autoFilePaper];
			
			[newPubs addObject:newBI];
            [newBI release];
		}
	}
	
	return newPubs;
}

#pragma mark Table Column Setup

//note - ********** the notification handling method will add NSTableColumn instances to the tableColumns dictionary.
- (void)setupTableColumns{
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
	NSArray *prefsShownColNamesArray = [pw arrayForKey:BDSKShownColsNamesKey];
    NSEnumerator *shownColNamesE = [prefsShownColNamesArray objectEnumerator];
    NSTableColumn *tc;
    NSString *colName;
	NSArray *localFileFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey];
	NSArray *remoteURLFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey];
    NSArray *ratingFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRatingFieldsKey];
    NSArray *booleanFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKBooleanFieldsKey];
    
    NSDictionary *tcWidthsByIdentifier = [[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKColumnWidthsKey];
    NSNumber *tcWidth = nil;
    NSImageCell *imageCell = [[[NSImageCell alloc] init] autorelease];
	
    NSMutableArray *columns = [NSMutableArray arrayWithCapacity:[prefsShownColNamesArray count]];
	
	while(colName = [shownColNamesE nextObject]){
		tc = [tableView tableColumnWithIdentifier:colName];
		
		if(tc == nil){
			// it is a new column, so create it
			tc = [[[NSTableColumn alloc] initWithIdentifier:colName] autorelease];
            if([tc respondsToSelector:@selector(setResizingMask:)])
                [tc setResizingMask:(NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask)];
            else
                [tc setResizable:YES];
			[tc setEditable:NO];
            if([localFileFields containsObject:colName] ||
               [remoteURLFields containsObject:colName]){
                [tc setDataCell:imageCell];
            }else if([ratingFields containsObject:colName]){
				BDSKRatingButtonCell *ratingCell = [[[BDSKRatingButtonCell alloc] initWithMaxRating:5] autorelease];
				[ratingCell setBordered:NO];
				[ratingCell setAlignment:NSCenterTextAlignment];
                [tc setDataCell:ratingCell];
            }else if([booleanFields containsObject:colName]){
				NSButtonCell *readCell = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
				[readCell setButtonType:NSSwitchButton];
				[readCell setImagePosition:NSImageOnly];
				[readCell setControlSize:NSSmallControlSize];
                [tc setDataCell:readCell];
			}
			if([colName isEqualToString:BDSKLocalUrlString]){
				NSImage * pdfImage = [NSImage imageNamed:@"TinyFile"];
				[(NSCell *)[tc headerCell] setImage:pdfImage];
			}else{	
				[[tc headerCell] setStringValue:NSLocalizedStringFromTable(colName, @"BibTeXKeys", @"")];
			}
		}
		
		[columns addObject:tc];
	}
	
    [tableView removeAllTableColumns];
    NSEnumerator *columnsE = [columns objectEnumerator];
	
    while(tc = [columnsE nextObject]){
        if(tcWidthsByIdentifier && 
		  (tcWidth = [tcWidthsByIdentifier objectForKey:[tc identifier]])){
			[tc setWidth:[tcWidth floatValue]];
        }

		[tableView addTableColumn:tc];
    }
    [self setTableFont];
}

- (IBAction)dismissAddFieldSheet:(id)sender{
    [addFieldSheet orderOut:sender];
    [NSApp endSheet:addFieldSheet returnCode:[sender tag]];
}

- (NSMenu *)tableView:(NSTableView *)tv menuForTableHeaderColumn:(NSTableColumn *)tc{
	if(tv != tableView)
		return nil;
	// for now, just returns the same all the time.
	// Could customize menu for details of selected item.
	return [[[NSApp delegate] columnsMenuItem] submenu];
}

- (IBAction)columnsMenuSelectTableColumn:(id)sender{
    NSMutableArray *prefsShownColNamesMutableArray = [[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKShownColsNamesKey] mutableCopy];

    if ([sender state] == NSOnState) {
        [prefsShownColNamesMutableArray removeObject:[sender title]];
        [sender setState:NSOffState];
    }else{
        if(![prefsShownColNamesMutableArray containsObject:[sender title]]){
            [prefsShownColNamesMutableArray addObject:[sender title]];
        }
        [sender setState:NSOnState];
    }
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:prefsShownColNamesMutableArray
                                                      forKey:BDSKShownColsNamesKey];
    [prefsShownColNamesMutableArray release];
    [self setupTableColumns];
    [self updateUI];
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKTableColumnChangedNotification
														object:self];
}

- (IBAction)columnsMenuAddTableColumn:(id)sender{
    // first we fill the popup
	NSArray *prefsShownColNamesArray = [[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKShownColsNamesKey];
	BibTypeManager *typeMan = [BibTypeManager sharedManager];
	NSMutableSet *fieldNameSet = [NSMutableSet setWithSet:[typeMan allFieldNames]];
	[fieldNameSet unionSet:[NSSet setWithObjects:BDSKLocalUrlString, BDSKUrlString, BDSKCiteKeyString, BDSKDateString, @"Added", @"Modified", BDSKFirstAuthorString, BDSKSecondAuthorString, BDSKThirdAuthorString, BDSKItemNumberString, BDSKContainerString, BDSKRatingString, BDSKReadString, nil]];
	NSMutableArray *colNames = [[fieldNameSet allObjects] mutableCopy];
	[colNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
	[colNames removeObjectsInArray:prefsShownColNamesArray];
	
	[addFieldComboBox removeAllItems];
	[addFieldComboBox addItemsWithObjectValues:colNames];
    [addFieldPrompt setStringValue:NSLocalizedString(@"Name of column to add:",@"")];
	
	[colNames release];
    
	[NSApp beginSheet:addFieldSheet
       modalForWindow:documentWindow
        modalDelegate:self
       didEndSelector:@selector(addTableColumnSheetDidEnd:returnCode:contextInfo:)
          contextInfo:nil];
    
}

- (void)addTableColumnSheetDidEnd:(NSWindow *)sheet
                       returnCode:(int) returnCode
                      contextInfo:(void *)contextInfo{

    if(returnCode == 1){
		NSMutableArray *prefsShownColNamesMutableArray = [[[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKShownColsNamesKey] mutableCopy] autorelease];
        NSString *newColumnName = [addFieldComboBox stringValue];

		// Check if an object already exists in the tableview, bail without notification if it does
		// This means we can't have a column more than once.
		if ([prefsShownColNamesMutableArray containsObject:newColumnName])
			return;

		// Store the new column in the preferences
        [prefsShownColNamesMutableArray addObject:newColumnName];
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:prefsShownColNamesMutableArray
                                                          forKey:BDSKShownColsNamesKey];
        
		// Actually redraw the view now with the new column.
		[self setupTableColumns];
        [self updateUI];
        [[NSNotificationCenter defaultCenter] postNotificationName:BDSKTableColumnChangedNotification
                                                            object:self];
    }else{
        //do nothing (because nothing was entered or selected)
    }
}

/*
 Returns action/contextual menu that contains items appropriate for the current selection.
 The code may need to be revised if the menu's contents are changed.
*/
- (NSMenu *)tableView:tv menuForTableColumn:(NSTableColumn *)tc row:(int)row {
    if(tv != tableView)
		return nil;
	
	NSMenu *myMenu = nil;
	NSString *tcId = [tc identifier];
	NSArray *localFileFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey];
	NSArray *remoteURLFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey];
	
	if([localFileFields containsObject:tcId]){
		myMenu = [[fileMenu copy] autorelease];
		[[myMenu itemAtIndex:0] setRepresentedObject:tcId];
		[[myMenu itemAtIndex:1] setRepresentedObject:tcId];
	}else if([remoteURLFields containsObject:tcId]){
		myMenu = [[URLMenu copy] autorelease];
		[[myMenu itemAtIndex:0] setRepresentedObject:tcId];
	}else{
		myMenu = [[actionMenu copy] autorelease];
	}
	
	// kick out every item we won't need:
	NSMenuItem *theItem = nil;
	int i = [myMenu numberOfItems];
	
	while (--i >= 0) {
		theItem = (NSMenuItem*)[myMenu itemAtIndex:i];
		if (![self validateMenuItem:theItem] ||
			((i == [myMenu numberOfItems] - 1 || i == 0) && [theItem isSeparatorItem])) {
			[myMenu removeItem:theItem];
		}
	}
	
	if([myMenu numberOfItems] == 0)
		return nil;
	
	return myMenu;
}

#pragma mark Notification handlers

- (void)handleTableColumnChangedNotification:(NSNotification *)notification{
    // don't pay attention to notifications I send (infinite loop might result)
    if([notification object] == self)
        return;
	
    [self setupTableColumns];
	[self updateUI];
}

- (void)handlePreviewDisplayChangedNotification:(NSNotification *)notification{
    // note: this is only supposed to handle the pretty-printed preview, /not/ the TeX preview
    [self displayPreviewForItems:[self selectedPublications]];
}

- (void)handleFontChangedNotification:(NSNotification *)notification{
	[self setTableFont];
}

- (void)handleBibItemAddDelNotification:(NSNotification *)notification{
	NSDictionary *userInfo = [notification userInfo];
	BOOL wasLastRequest = [[userInfo objectForKey:@"lastRequest"] isEqualToString:@"YES"];

	if(wasLastRequest){
        if([[notification name] isEqualToString:BDSKDocDelItemNotification] == NO){ // this method gets called for setPublications: also
            [tableView deselectAll:self]; // clear before resorting
            [self setFilterField:@""]; // clear the search
            [self sortPubsByColumn:nil]; // resort
        } else {
            // just need to reload the table after removing a pub
            [self updateUI];
            [self updatePreviews:nil];
        }
        [self updateGroupsPreservingSelection:YES];
	}
}

- (void)handleBibItemChangedNotification:(NSNotification *)notification{
	// dead simple for now
	// NSLog(@"got handleBibItemChangedNotification with userinfo %@", [notification userInfo]);
	NSDictionary *userInfo = [notification userInfo];
    
    // see if it's ours
	if([userInfo objectForKey:@"document"] != self || [userInfo objectForKey:@"document"] == nil)
        return;
    //NSLog(@"got handleBibItemChangedNotification in %@", [[self fileName] lastPathComponent]);

	NSString *changedKey = [userInfo objectForKey:@"key"];
        
    if([changedKey isEqualToString:BDSKCiteKeyString]){
        BibItem *pub = [notification object];
        NSString *oldKey = [userInfo objectForKey:@"oldCiteKey"];
        [itemsForCiteKeys removeObjectIdenticalTo:pub forKey:oldKey];
        [itemsForCiteKeys addObject:pub forKey:[pub citeKey]];
    }
    
    if([[self currentGroupField] isEqualToString:changedKey]){
        [self updateGroupsPreservingSelection:YES];
    }
    
    // don't perform a search if the search field is empty
	if(![[searchField stringValue] isEqualToString:@""] && 
       ([quickSearchKey isEqualToString:changedKey] || [quickSearchKey isEqualToString:@"All Fields"]) ){
		[self searchFieldAction:searchField];
	} else { // quicksearch won't update it for us
        if([[lastSelectedColumnForSort identifier] isEqualToString:changedKey])
            [self sortPubsByColumn:nil]; // resort if the changed value was in the currently sorted column
        [self updateUI];
        [self updatePreviews:nil];
    }	
}

- (void)handleMacroChangedNotification:(NSNotification *)aNotification{
	id sender = [aNotification object];
	if([sender isKindOfClass:[BibDocument class]] && sender != self)
		return; // only macro changes for ourselves or the global macros
	
    [tableView reloadData];
    [self updatePreviews:nil];
}

- (void)handleGroupFieldChangedNotification:(NSNotification *)notification{
	NSPopUpButtonCell *headerCell = [(BDSKGroupTableHeaderView *)[groupTableView headerView] popUpHeaderCell];
	
    [self setCurrentGroupField:[[OFPreferenceWrapper sharedPreferenceWrapper] stringForKey:BDSKCurrentGroupFieldKey]];
	[self updateGroupsPreservingSelection:NO];
	[headerCell selectItemWithTitle:currentGroupField];
}

- (void)handleTableSelectionChangedNotification:(NSNotification *)notification{
    [self updatePreviews:nil];
    [self updateActionMenus:nil];
    [groupTableView updateHighlights];
}

- (void)handleResortDocumentNotification:(NSNotification *)notification{
    [self sortPubsByColumn:nil];
}

- (void)handleApplicationWillTerminateNotification:(NSNotification *)notification{
    [self saveSortOrder];
}

#pragma mark UI updating

- (void)updatePreviews:(NSNotification *)aNotification{
    // Coalesce these notifications here, since something like select all -> generate cite keys will force a preview update for every
    // changed key, so we have to update all the previews each time.  This should be safer than using cancelPrevious... since those
    // don't get performed on the main thread (apparently), and can lead to problems.
    [self queueSelectorOnce:@selector(handlePrivateUpdatePreviews)];
}

- (void)handlePrivateUpdatePreviews{

    OBASSERT([NSThread inMainThread]);
            
    NSArray *selPubs = [self selectedPublications];
    
    //take care of the preview field (NSTextView below the pub table); if the enumerator is nil, the view will get cleared out
    [self displayPreviewForItems:selPubs];

    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKUsesTeXKey] &&
	   [[[BDSKPreviewer sharedPreviewer] window] isVisible]){

		if(!selPubs){
			// clear the previews
			[[BDSKPreviewer sharedPreviewer] updateWithBibTeXString:nil];
			return;
		}

        unsigned numberOfPubs = [selPubs count];
        
        NSMutableString *bibString = [[NSMutableString alloc] initWithCapacity:(numberOfPubs * 100)];

        // in case there are @preambles in it
        [bibString appendString:frontMatter];
        [bibString appendString:@"\n"];
        
        [bibString appendString:[self bibTeXMacroString]];
        
        NSEnumerator *e = [selPubs objectEnumerator];
        NSNumber *i;
        BibItem *aPub = nil;
		NSMutableArray *selItems = [[NSMutableArray alloc] initWithCapacity:numberOfPubs];
		NSMutableSet *parentItems = [[NSMutableSet alloc] initWithCapacity:numberOfPubs];
		NSMutableArray *selParentItems = [[NSMutableArray alloc] initWithCapacity:numberOfPubs];
        
		while(i = [e nextObject]){
            aPub = [shownPublications objectAtIndex:[i intValue] usingLock:pubsLock];
			[selItems addObject:aPub];

            if([aPub crossrefParent])
                [parentItems addObject:[aPub crossrefParent]];
            
        }// while i is num of selected row 
		
		e = [selItems objectEnumerator];
		while(aPub = [e nextObject]){
			if([parentItems containsObject:aPub]){
				[parentItems removeObject:aPub];
				[selParentItems addObject:aPub];
			}else{
                NS_DURING
                    [bibString appendString:[aPub bibTeXString]];
                NS_HANDLER
                    if([[localException name] isEqualToString:BDSKTeXifyException])
                        NSLog(@"Discarding exception raised for item \"%@\"", [aPub citeKey]);
                    else
                        [localException raise];
                NS_ENDHANDLER
			}
		}
        
		e = [selParentItems objectEnumerator];
		while(aPub = [e nextObject]){
            NS_DURING
                [bibString appendString:[aPub bibTeXString]];
            NS_HANDLER
                if([[localException name] isEqualToString:BDSKTeXifyException])
                    NSLog(@"Discarding exception raised for item \"%@\"", [aPub citeKey]);
                else
                    [localException raise];
            NS_ENDHANDLER
        }
        
        e = [parentItems objectEnumerator];        
		while(aPub = [e nextObject]){
            NS_DURING
                [bibString appendString:[aPub bibTeXString]];
            NS_HANDLER
                if([[localException name] isEqualToString:BDSKTeXifyException])
                    NSLog(@"Discarding exception raised for item \"%@\"", [aPub citeKey]);
            else
                [localException raise];
            NS_ENDHANDLER
        }
                        
        [selItems release];
        [parentItems release];
        [selParentItems release];
        
        [[BDSKPreviewer sharedPreviewer] updateWithBibTeXString:bibString];
        [bibString release];
    }
}

- (void)displayPreviewForItems:(NSArray *)itemIndexes{

    if(NSIsEmptyRect([previewField visibleRect]))
        return;
        
    static NSDictionary *titleAttributes;
    if(titleAttributes == nil)
        titleAttributes = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:1], nil]
                                                        forKeys:[NSArray arrayWithObjects:NSUnderlineStyleAttributeName,  nil]];
    static NSAttributedString *noAttrDoubleLineFeed;
    if(noAttrDoubleLineFeed == nil)
        noAttrDoubleLineFeed = [[NSAttributedString alloc] initWithString:@"\n\n" attributes:nil];
    
    NSMutableAttributedString *s;
    NSNumber *i;
  
    int maxItems = [[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKPreviewMaxNumberKey];
    int itemCount = 0;
    
    NSTextStorage *textStorage = [previewField textStorage];

    // do this _before_ messing with the text storage; otherwise you can have a leftover selection that ends up being out of range
    NSRange zeroRange = NSMakeRange(0, 0);
    if([previewField respondsToSelector:@selector(setSelectedRanges:)]){
        static NSArray *zeroRanges = nil;
        if(!zeroRanges) zeroRanges = [[NSArray alloc] initWithObjects:[NSValue valueWithRange:zeroRange], nil];
        [previewField setSelectedRanges:zeroRanges];
    } else {
        [previewField setSelectedRange:zeroRange];
    }
            
    NSLayoutManager *layoutManager = [[textStorage layoutManagers] lastObject];
    [layoutManager retain];
    [textStorage removeLayoutManager:layoutManager]; // optimization: make sure the layout manager doesn't do any work while we're loading

    [textStorage beginEditing];
    [[textStorage mutableString] setString:@""];
    
    NSEnumerator *enumerator = [itemIndexes objectEnumerator];
    
    unsigned int numberOfSelectedPubs = [itemIndexes count];

    while((i = [enumerator nextObject]) && (maxItems == 0 || itemCount < maxItems)){
                
		itemCount++;
        NSString *fieldValue;

        switch([[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKPreviewDisplayKey]){
            case 0:                
                if(itemCount > 1)
                    [[textStorage mutableString] appendCharacter:NSFormFeedCharacter]; // page break for printing; doesn't display
                [textStorage appendAttributedString:[[shownPublications objectAtIndex:[i intValue] usingLock:pubsLock] attributedStringValue]];
                break;
            case 1:
                // special handling for annote-only
                // Write out the title
                if(numberOfSelectedPubs > 1){
                    s = [[[NSMutableAttributedString alloc] initWithString:[[shownPublications objectAtIndex:[i intValue] usingLock:pubsLock] displayTitle]
                                                               attributes:titleAttributes] autorelease];
                    [s appendAttributedString:noAttrDoubleLineFeed];
                    [textStorage appendAttributedString:s];
                }
                fieldValue = [[shownPublications objectAtIndex:[i intValue] usingLock:pubsLock] valueOfField:BDSKAnnoteString inherit:NO];
                if([fieldValue isEqualToString:@""]){
                    [[textStorage mutableString] appendString:NSLocalizedString(@"No notes.",@"")];
                }else{
                    [[textStorage mutableString] appendString:fieldValue];
                }
                break;
            case 2:
                // special handling for abstract-only
                // Write out the title
                if(numberOfSelectedPubs > 1){
                    s = [[[NSMutableAttributedString alloc] initWithString:[[shownPublications objectAtIndex:[i intValue] usingLock:pubsLock] displayTitle]
                                                                attributes:titleAttributes] autorelease];
                    [s appendAttributedString:noAttrDoubleLineFeed];
                    [textStorage appendAttributedString:s];
                }
                fieldValue = [[shownPublications objectAtIndex:[i intValue] usingLock:pubsLock] valueOfField:BDSKAbstractString inherit:NO];
                if([fieldValue isEqualToString:@""]){
                    [[textStorage mutableString] appendString:NSLocalizedString(@"No abstract.",@"")];
                }else{
                    [[textStorage mutableString] appendString:fieldValue];
                }
                break;                
        }
        [[textStorage mutableString] appendString:@"\n\n"];
        
    }
    [textStorage endEditing];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager release];
}

- (void)updateUI{
	[tableView reloadData];
    
	int shownPubsCount = [shownPublications count];
	int totalPubsCount = [groupedPublications count];
    // show the singular form correctly
    NSString *totalStr = (totalPubsCount == 1) ? NSLocalizedString(@"Publication", @"Publication") : NSLocalizedString(@"Publications", @"Publications");

	if (shownPubsCount != totalPubsCount) { 
		// inform people
        NSString *ofStr = NSLocalizedString(@"of", @"of");
		[self setStatus: [NSString stringWithFormat:@"%d %@ %d %@", shownPubsCount, ofStr, totalPubsCount, totalStr]];
	}
	else {
		[self setStatus:[NSString stringWithFormat:@"%d %@", totalPubsCount, totalStr]];
	}
}

- (void)setTableFont{
    // The font we're using now
    NSFont *font = [NSFont fontWithName:[[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKTableViewFontKey]
                                   size:[[OFPreferenceWrapper sharedPreferenceWrapper] floatForKey:BDSKTableViewFontSizeKey]];
	
	[tableView setFont:font];
    [tableView setRowHeight:[font defaultLineHeightForFont]+2];
	[tableView tile];
    [tableView reloadData]; // othewise the change isn't immediately visible
}

- (BOOL)highlightItemForPartialItem:(NSDictionary *)partialItem{
    
    [tableView deselectAll:self];
    [self setFilterField:@""];
    
    NSString *itemKey = [partialItem objectForKey:@"net_sourceforge_bibdesk_citekey"];
    if(itemKey == nil)
        itemKey = [partialItem objectForKey:BDSKCiteKeyString];
    
    OBPOSTCONDITION(itemKey != nil);
    
    NSEnumerator *pubEnum = [shownPublications objectEnumerator];
    BibItem *anItem;
    BOOL matchFound = NO;
    
    while(anItem = [pubEnum nextObject]){
        if([[anItem citeKey] isEqualToString:itemKey]){
            [self highlightBib:anItem];
            matchFound = YES;
        }
    }
    return matchFound;
}

- (void)highlightBib:(BibItem *)bib{
    [self highlightBib:bib byExtendingSelection:NO];
}

- (void)highlightBib:(BibItem *)bib byExtendingSelection:(BOOL)yn{
 
    int i = [shownPublications indexOfObjectIdenticalTo:bib usingLock:pubsLock];    

    if(i != NSNotFound && i != -1){
        [tableView selectRow:i byExtendingSelection:yn];
        [tableView scrollRowToVisible:i];
    }
}

- (void)highlightBibs:(NSArray *)bibArray{
	NSEnumerator *pubEnum = [bibArray objectEnumerator];
	BibItem *bib;
	
	[tableView deselectAll:nil];
	
	while(bib = [pubEnum nextObject]){
		[self highlightBib:bib byExtendingSelection:YES];
	}
}

- (IBAction)toggleStatusBar:(id)sender{
	NSRect splitViewFrame = [splitView frame];
	NSRect statusRect = [[documentWindow contentView] frame];
	NSRect infoRect = [infoLine frame];
	if (showStatus) {
		showStatus = NO;
		splitViewFrame.size.height += 20.0;
		splitViewFrame.origin.y -= 20.0;
		statusRect.size.height = 0.0;
		[infoLine removeFromSuperview];
	} else {
		showStatus = YES;
		splitViewFrame.size.height -= 20.0;
		splitViewFrame.origin.y += 20.0;
		statusRect.size.height = 20.0;
		infoRect.size.width = splitViewFrame.size.width - 16.0;
		[infoLine setFrame:infoRect];
		[[documentWindow contentView]  addSubview:infoLine];
	}
	[splitView setFrame:splitViewFrame];
	[[documentWindow contentView] setNeedsDisplayInRect:statusRect];
	[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:showStatus forKey:BDSKShowStatusBarKey];
}

- (void)setStatus:(NSString *)status {
	[self setStatus:status immediate:YES];
}

- (void)setStatus:(NSString *)status immediate:(BOOL)now {
	if(now)
		[infoLine setStringValue:status];
	else
		[infoLine performSelector:@selector(setStringValue:) withObject:status afterDelay:0.01];
}

#pragma mark TeXTask delegate

- (BOOL)texTaskShouldStartRunning:(BDSKTeXTask *)aTexTask{
	[self setStatus:[NSString stringWithFormat:@"%@%C",NSLocalizedString(@"Generating data. Please wait", @"Generating data. Please wait..."), 0x2026]];
	return YES;
}

- (void)texTask:(BDSKTeXTask *)aTexTask finishedWithResult:(BOOL)success{
	[self updateUI];
}

#pragma mark Custom cite drawer stuff

- (IBAction)toggleShowingCustomCiteDrawer:(id)sender{
    [customCiteDrawer toggle:sender];
	if(showingCustomCiteDrawer){
		showingCustomCiteDrawer = NO;
	}else{
		showingCustomCiteDrawer = YES;
	}
}

- (IBAction)addCustomCiteString:(id)sender{
    int row = [customStringArray count];
	[customStringArray addObject:@"citeCommand"];
    [ccTableView reloadData];
	[ccTableView selectRow:row byExtendingSelection:NO];
	[ccTableView editColumn:0 row:row withEvent:nil select:YES];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:customStringArray forKey:BDSKCustomCiteStringsKey];
}

- (IBAction)removeCustomCiteString:(id)sender{
    if([ccTableView numberOfSelectedRows] == 0)
		return;
	
	if ([ccTableView editedRow] != -1)
		[documentWindow makeFirstResponder:ccTableView];
	[customStringArray removeObjectAtIndex:[ccTableView selectedRow]];
	[ccTableView reloadData];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:customStringArray forKey:BDSKCustomCiteStringsKey];
}

- (int)numberOfSelectedPubs{
    return [tableView numberOfSelectedRows];
}

- (NSEnumerator *)selectedPubEnumerator{
    return [[self selectedPublications] objectEnumerator];
}

- (NSArray *)selectedPublications{

    if([tableView selectedRow] == -1)
        return nil;
    
    return [[tableView selectedRowEnumerator] allObjects];
}

#pragma mark Main window stuff

- (void)saveSortOrder{ 
    // @@ if we switch to NSArrayController, we should just archive the sort descriptors (see BDSKFileContentSearchController)
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:[lastSelectedColumnForSort identifier] forKey:BDSKDefaultSortedTableColumnKey];
    [[OFPreferenceWrapper sharedPreferenceWrapper] setBool:sortDescending forKey:BDSKDefaultSortedTableColumnIsDescendingKey];
}    

- (void)windowWillClose:(NSNotification *)notification{
    if([notification object] != documentWindow) // this is critical; 
        return;
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKDocumentWindowWillCloseNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
    [[BDSKErrorObjectController sharedErrorObjectController] removeErrorObjsForDocument:self];
    [customCiteDrawer close];
    [self saveSortOrder];
    
    // reset the previewer; don't send [self updatePreviews:] here, as the tableview will be gone by the time the queue posts the notification
    if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKUsesTeXKey] &&
       [[[BDSKPreviewer sharedPreviewer] window] isVisible] &&
       [tableView selectedRow] != -1 )
        [[BDSKPreviewer sharedPreviewer] updateWithBibTeXString:nil];    
}

- (void)pageDownInPreview:(id)sender{
    NSPoint p = [previewField scrollPositionAsPercentage];
    
    float pageheight = NSHeight([[[previewField enclosingScrollView] documentView] bounds]);
    float viewheight = NSHeight([[previewField enclosingScrollView] documentVisibleRect]);
    
    if(p.y > 0.99 || viewheight >= pageheight){ // select next row if the last scroll put us at the end
        [tableView selectRow:([tableView selectedRow] + 1) byExtendingSelection:NO];
        [tableView scrollRowToVisible:[tableView selectedRow]];
        return; // adjust page next time
    }
    [previewField pageDown:sender];
}

- (void)pageUpInPreview:(id)sender{
    NSPoint p = [previewField scrollPositionAsPercentage];
    
    if(p.y < 0.01){ // select previous row if we're already at the top
        [tableView selectRow:([tableView selectedRow] - 1) byExtendingSelection:NO];
        [tableView scrollRowToVisible:[tableView selectedRow]];
        return; // adjust page next time
    }
    [previewField pageUp:sender];
}

- (void)splitViewDoubleClick:(OASplitView *)sender{
	NSView *firstView = [[sender subviews] objectAtIndex:0];
	NSView *secondView = [[sender subviews] objectAtIndex:1];
	NSRect firstFrame = [firstView frame];
	NSRect secondFrame = [secondView frame];
	
	if (sender == splitView) {
		// first = table, second = preview
		if(NSHeight([secondView frame]) != 0){ // not sure what the criteria for isSubviewCollapsed, but it doesn't work
			lastPreviewHeight = NSHeight(secondFrame); // cache this
			firstFrame.size.height += lastPreviewHeight;
			secondFrame.size.height = 0;
		} else {
			if(lastPreviewHeight == 0)
				lastPreviewHeight = NSHeight([sender frame]) / 3; // a reasonable value for uncollapsing the first time
			secondFrame.size.height = lastPreviewHeight;
			firstFrame.size.height = NSHeight([sender frame]) - lastPreviewHeight - [sender dividerThickness];
		}
	} else {
		// first = group, second = table+preview
		if(NSWidth([firstView frame]) != 0){
			lastGroupViewWidth = NSWidth(firstFrame); // cache this
			secondFrame.size.width += lastGroupViewWidth;
			firstFrame.size.width = 0;
		} else {
			if(lastGroupViewWidth == 0)
				lastGroupViewWidth = 120; // a reasonable value for uncollapsing the first time
			firstFrame.size.width = lastGroupViewWidth;
			secondFrame.size.width = NSWidth([sender frame]) - lastGroupViewWidth - [sender dividerThickness];
		}
	}
	
	[firstView setFrame:firstFrame];
	[secondView setFrame:secondFrame];
    [sender adjustSubviews];
}


#pragma mark macro stuff

- (NSDictionary *)macroDefinitions {
    return macroDefinitions;
}

- (void)setMacroDefinitions:(NSDictionary *)newMacroDefinitions {
    if (macroDefinitions != newMacroDefinitions) {
        [macroDefinitions release];
        macroDefinitions = OFCreateCaseInsensitiveKeyMutableDictionary();
        [macroDefinitions setDictionary:newMacroDefinitions];
    }
}

- (void)addMacroDefinitionWithoutUndo:(NSString *)macroString forMacro:(NSString *)macroKey{
    [macroDefinitions setObject:macroString forKey:macroKey];
}

- (void)changeMacroKey:(NSString *)oldKey to:(NSString *)newKey{
    if([macroDefinitions objectForKey:oldKey] == nil)
        [NSException raise:NSInvalidArgumentException
                    format:@"tried to change the value of a macro key that doesn't exist"];
    [[[self undoManager] prepareWithInvocationTarget:self]
        changeMacroKey:newKey to:oldKey];
    NSString *val = [macroDefinitions valueForKey:oldKey];
    [val retain]; // so the next line doesn't kill it
    [macroDefinitions removeObjectForKey:oldKey];
    [macroDefinitions setObject:[val autorelease] forKey:newKey];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:newKey, @"newKey", oldKey, @"oldKey", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibDocMacroKeyChangedNotification
														object:self
													  userInfo:notifInfo];    
}

- (void)addMacroDefinition:(NSString *)macroString forMacro:(NSString *)macroKey{
    // we're adding a new one, so to undo, we remove.
    [[[self undoManager] prepareWithInvocationTarget:self]
            removeMacro:macroKey];

    [macroDefinitions setObject:macroString forKey:macroKey];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:macroKey, @"macroKey", @"Add macro", @"type", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibDocMacroDefinitionChangedNotification
														object:self
													  userInfo:notifInfo];    
}

- (void)setMacroDefinition:(NSString *)newDefinition forMacro:(NSString *)macroKey{
    NSString *oldDef = [macroDefinitions objectForKey:macroKey];
    // we're just changing an existing one, so to undo, we change back.
    [[[self undoManager] prepareWithInvocationTarget:self]
            setMacroDefinition:oldDef forMacro:macroKey];
    [macroDefinitions setObject:newDefinition forKey:macroKey];

	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:macroKey, @"macroKey", @"Change macro", @"type", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibDocMacroDefinitionChangedNotification
														object:self
													  userInfo:notifInfo];    
}


- (void)removeMacro:(NSString *)macroKey{
    NSString *currentValue = [macroDefinitions objectForKey:macroKey];
    if(!currentValue){
        return;
    }else{
        [[[self undoManager] prepareWithInvocationTarget:self]
        addMacroDefinition:currentValue
                  forMacro:macroKey];
    }
    [macroDefinitions removeObjectForKey:macroKey];
	
	NSDictionary *notifInfo = [NSDictionary dictionaryWithObjectsAndKeys:macroKey, @"macroKey", @"Remove macro", @"type", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibDocMacroDefinitionChangedNotification
														object:self
													  userInfo:notifInfo];    
}

- (NSString *)valueOfMacro:(NSString *)macroString{
    // Note we treat upper and lowercase values the same, 
    // because that's how btparse gives the string constants to us.
    // It is not quite correct because bibtex does discriminate,
    // but this is the best we can do.  The OFCreateCaseInsensitiveKeyMutableDictionary()
    // is used to create a dictionary with case-insensitive keys.
    return [macroDefinitions objectForKey:macroString];
}

- (NSString *)bibTeXMacroString{
    BOOL shouldTeXify = [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShouldTeXifyWhenSavingAndCopyingKey];
	NSMutableString *macroString = [NSMutableString string];
    NSString *value;
    NSArray *macros = [[macroDefinitions allKeys] sortedArrayUsingSelector:@selector(compare:)];
    
    foreach(macro, macros){
		value = [macroDefinitions objectForKey:macro];
		if(shouldTeXify){
			
			NS_DURING
				value = [[BDSKConverter sharedConverter] stringByTeXifyingString:value];
			NS_HANDLER
				if([[localException name] isEqualToString:BDSKTeXifyException]){
					int i = NSRunAlertPanel(NSLocalizedString(@"Character Conversion Error", @"Title of alert when an error happens"),
											[NSString stringWithFormat: NSLocalizedString(@"An unrecognized character in the \"%@\" macro could not be converted to TeX.", @"Informative alert text when the error happens."), macro],
											nil, nil, nil, nil);
				}
                                [localException raise]; // re-raise; we localized the error, but the sender needs to know we failed
			NS_ENDHANDLER
							
		}                
        [macroString appendFormat:@"\n@STRING{%@ = \"%@\"}\n", macro, value];
    }
	return macroString;
}

- (IBAction)showMacrosWindow:(id)sender{
    if (!macroWC){
        macroWC = [[MacroWindowController alloc] init];
        [macroWC setMacroDataSource:self];
    }
    [macroWC showWindow:self];
}

#pragma mark
#pragma mark Crossref support

- (void)rebuildItemsForCiteKeys{
	[pubsLock lock];
	BibItem *pub;
	NSEnumerator *e = [publications objectEnumerator];
	
	[itemsForCiteKeys release];
	itemsForCiteKeys = [[OFMultiValueDictionary alloc] initWithCaseInsensitiveKeys:YES];
	while(pub = [e nextObject])
		[itemsForCiteKeys addObject:pub forKey:[pub citeKey]];
	[pubsLock unlock];
}

- (OFMultiValueDictionary *)itemsForCiteKeys{
	return itemsForCiteKeys;
}

- (BibItem *)publicationForCiteKey:(NSString *)key{
	if ([NSString isEmptyString:key]) 
		return nil;
    
	NSArray *items = [[self itemsForCiteKeys] arrayForKey:key];
	
	if ([items count] == 0)
		return nil;
    // may have duplicate items for the same key, so just return the first one
    return [items objectAtIndex:0];
}

- (BOOL)citeKeyIsCrossreffed:(NSString *)key{
	if ([NSString isEmptyString:key]) 
		return NO;
    
	NSEnumerator *pubEnum = [publications objectEnumerator];
	BibItem *pub;
	
	while (pub = [pubEnum nextObject]) {
		if ([key caseInsensitiveCompare:[pub valueOfField:BDSKCrossrefString inherit:NO]] == NSOrderedSame) {
			return YES;
        }
	}
	return NO;
}

- (void)performSortForCrossrefs{
	NSEnumerator *pubEnum = [[[publications copy] autorelease] objectEnumerator];
	BibItem *pub = nil;
	BibItem *parent;
	NSString *key;
	NSMutableSet *prevKeys = [NSMutableSet set];
	BOOL moved = NO;
	
	// We only move parents that come after a child.
	while (pub = [pubEnum nextObject]){
		key = [[pub valueOfField:BDSKCrossrefString inherit:NO] lowercaseString];
		if (![NSString isEmptyString:key] && [prevKeys containsObject:key]) {
            [prevKeys removeObject:key];
			parent = [self publicationForCiteKey:key];
			[publications removeObjectIdenticalTo:parent usingLock:pubsLock];
			[publications addObject:parent usingLock:pubsLock];
			moved = YES;
		}
		[prevKeys addObject:[[pub citeKey] lowercaseString]];
	}
	
	if (moved) {
		[self sortPubsByColumn:nil];
		[self setStatus:NSLocalizedString(@"Publications sorted for cross references.", @"")];
	}
}

- (IBAction)sortForCrossrefs:(id)sender{
	NSUndoManager *undoManager = [self undoManager];
	[[undoManager prepareWithInvocationTarget:self] setPublications:publications];
	[undoManager setActionName:NSLocalizedString(@"Sort Publications",@"")];
	
	[self performSortForCrossrefs];
}

- (IBAction)selectCrossrefParentAction:(id)sender{
    BibItem *selectedBI = [shownPublications objectAtIndex:[[[self selectedPublications] lastObject] intValue] usingLock:pubsLock];
    NSString *crossref = [selectedBI valueOfField:BDSKCrossrefString inherit:NO];
    [tableView deselectAll:nil];
    BibItem *parent = [self publicationForCiteKey:crossref];
    if(crossref && parent){
        [self highlightBib:parent];
        [tableView scrollRowToVisible:[tableView selectedRow]];
    } else
        NSBeep(); // if no parent found
}

- (IBAction)createNewPubUsingCrossrefAction:(id)sender{
    BibItem *selectedBI = [shownPublications objectAtIndex:[[[self selectedPublications] lastObject] intValue] usingLock:pubsLock];
    BibItem *newBI = [[BibItem alloc] init];
    [newBI setField:BDSKCrossrefString toValue:[selectedBI citeKey]];
    [self addPublication:newBI];
    [newBI release];
    [self editPub:newBI];
}

- (IBAction)duplicateTitleToBooktitle:(id)sender{
	if ([self numberOfSelectedPubs] == 0) return;
	
	int rv = NSRunAlertPanel(NSLocalizedString(@"Overwrite Booktitle?", @""),
							 NSLocalizedString(@"Do you want me to overwrite the Booktitle field when it was already entered?", @""),
							 NSLocalizedString(@"Don't Overwrite", @"Don't Overwrite"),
							 NSLocalizedString(@"Overwrite", @"Overwrite"),
							 nil, nil);
	BOOL overwrite = (rv == NSAlertAlternateReturn);
	
	NSSet *parentTypes = [NSSet setWithArray:[[OFPreferenceWrapper sharedPreferenceWrapper] arrayForKey:BDSKTypesForDuplicateBooktitleKey]];
	NSEnumerator *selEnum = [self selectedPubEnumerator];
	NSNumber *row;
	BibItem *aPub;
	
    // first we make sure all edits are committed
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFinalizeChangesNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
	
	while (row = [selEnum nextObject]) {
		aPub = [shownPublications objectAtIndex:[row intValue] usingLock:pubsLock];
		if([parentTypes containsObject:[aPub type]])
			[aPub duplicateTitleToBooktitleOverwriting:overwrite];
	}
	[[self undoManager] setActionName:([self numberOfSelectedPubs] > 1 ? NSLocalizedString(@"Duplicate Titles",@"") : NSLocalizedString(@"Duplicate Title",@""))];
}

#pragma mark
#pragma mark Printing support

- (NSView *)printableView{
    BDSKPrintableView *printableView = [[BDSKPrintableView alloc] initForScreenDisplay:NO];
    [printableView setAttributedString:[previewField textStorage]];    
    return [printableView autorelease];
}

- (void)printShowingPrintPanel:(BOOL)showPanels {
    // Obtain a custom view that will be printed
    NSView *printView = [self printableView];
	
    // Construct the print operation and setup Print panel
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:printView
                                                          printInfo:[self printInfo]];
    [op setShowPanels:showPanels];
    [op setCanSpawnSeparateThread:YES];
    if (showPanels) {
        // Add accessory view, if needed
    }
	
    // Run operation, which shows the Print panel if showPanels was YES
    [op runOperationModalForWindow:[self windowForSheet] delegate:nil didRunSelector:NULL contextInfo:NULL];
}

#pragma mark 
#pragma mark AutoFile stuff
- (IBAction)consolidateLinkedFiles:(id)sender{
	NSEnumerator *selEnum = [self selectedPubEnumerator]; // this is an array of indices, not pubs
	NSMutableArray *selPubs = [NSMutableArray array];
	NSNumber *row;

    // first we make sure all edits are committed
	[[NSNotificationCenter defaultCenter] postNotificationName:BDSKFinalizeChangesNotification
                                                        object:self
                                                      userInfo:[NSDictionary dictionary]];
	
	while(row = [selEnum nextObject]){
		[selPubs addObject:[shownPublications objectAtIndex:[row intValue] usingLock:pubsLock]];
	}
	[[BibFiler sharedFiler] filePapers:selPubs fromDocument:self ask:YES];
	
	[[self undoManager] setActionName:NSLocalizedString(@"Consolidate Files",@"")];
}

#pragma mark blog stuff


- (IBAction)postItemToWeblog:(id)sender{
//	NSEnumerator *pubE = [self selectedPubEnumerator];
//	BibItem *pub = [pubE nextObject];

	[NSException raise:BDSKUnimplementedException
				format:@"postItemToWeblog is unimplemented."];
	
	NSString *appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"Blapp"]; // pref
	NSLog(@"%@",appPath);
#if 0	
	AppleEvent *theAE;
	OSERR err = AECreateAppleEvent (NNWEditDataItemAppleEventClass,
									NNWEditDataItemAppleEventID,
									'MMcC', // Blapp
									kAutoGenerateReturnID,
									kAnyTransactionID,
									&theAE);


	
	
	OSErr AESend (
				  const AppleEvent * theAppleEvent,
				  AppleEvent * reply,
				  AESendMode sendMode,
				  AESendPriority sendPriority,
				  SInt32 timeOutInTicks,
				  AEIdleUPP idleProc,
				  AEFilterUPP filterProc
				  );
#endif
}

#pragma mark Text import sheet support

- (IBAction)importFromPasteboardAction:(id)sender{
    
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    NSString *type = [pasteboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKReferenceMinerStringPboardType, BDSKBibTeXStringPboardType, NSStringPboardType, nil]];
    
    if(type != nil){
        NSString *pboardString = [pasteboard stringForType:type];
        NSString *errorString = nil;
		// sniff the string to see if we should add it directly
		BOOL isRIS = ([type isEqualToString:BDSKReferenceMinerStringPboardType] || [pboardString isRISString]);
		BOOL isBibTeX = ([type isEqualToString:BDSKBibTeXStringPboardType] || [pboardString isBibTeXString]);
        
        if(isRIS || isBibTeX){
            [self newPublicationsForString:pboardString isRIS:isRIS error:&errorString];
            
            if(!errorString)
                return; // it worked, so we're done here
        }
    }
    
    BDSKTextImportController *tic = [(BDSKTextImportController *)[BDSKTextImportController alloc] initWithDocument:self];

    [tic beginSheetForPasteboardModalForWindow:documentWindow
								 modalDelegate:self
								didEndSelector:@selector(importFromTextSheetDidEnd:returnCode:contextInfo:)
								   contextInfo:tic];

}

- (IBAction)importFromFileAction:(id)sender{
    BDSKTextImportController *tic = [(BDSKTextImportController *)[BDSKTextImportController alloc] initWithDocument:self];

    [tic beginSheetForFileModalForWindow:documentWindow
						   modalDelegate:self
						  didEndSelector:@selector(importFromTextSheetDidEnd:returnCode:contextInfo:)
							 contextInfo:tic];

}

- (IBAction)importFromWebAction:(id)sender{
    BDSKTextImportController *tic = [(BDSKTextImportController *)[BDSKTextImportController alloc] initWithDocument:self];

    [tic beginSheetForWebModalForWindow:documentWindow
						  modalDelegate:self
						 didEndSelector:@selector(importFromTextSheetDidEnd:returnCode:contextInfo:)
							contextInfo:tic];

}

- (void)importFromTextSheetDidEnd:(NSWindow *)sheet returnCode:(int)rv contextInfo:(void *)contextInfo {
    BDSKTextImportController *tic = (BDSKTextImportController *)contextInfo;
    [tic cleanup];
	[tic autorelease];
}

#pragma mark -
#pragma mark Group stuff

/* 
The groupedPublications array is a subset of the publications array, developed by searching the publications array; shownPublications is now a subset of the groupedPublications array, and searches in the searchfield will search only within groupedPublications (which may include all publications).
*/

- (void)setCurrentGroupField:(NSString *)field{
	if (field != currentGroupField) {
		[currentGroupField release];
		currentGroupField = [field copy];
	}
}	

- (NSString *)currentGroupField{
	return currentGroupField;
}

- (NSString *)selectedGroupName{
	int row = [groupTableView selectedRow];
    if(row == -1)
        return @"";
    else
        return [[groups objectAtIndex:row] objectForKey:BDSKGroupCellStringKey];
}

- (void)updateGroupsPreservingSelection:(BOOL)preserve{
	NSString *groupName = nil;
    
	if (preserve && [groupTableView selectedRow] > 0) 
		groupName = [[self selectedGroupName] copy];
    
	NSCountedSet *countedSet = [[NSCountedSet alloc] initWithCapacity:[publications count]];
    NSEnumerator *pubEnum = [publications objectEnumerator];
    BibItem *pub;
    NSString *groupField = [self currentGroupField];
    
    while(pub = [pubEnum nextObject])
        [countedSet unionSet:[pub groupsForField:groupField]];
    
    NSMutableArray *mutableGroups = [[NSMutableArray alloc] initWithCapacity:[countedSet count] + 1];
    NSEnumerator *groupEnum = [countedSet objectEnumerator];
    NSString *group;
    NSDictionary *dictionary;
    
    NSImage *folderIcon = [NSImage smallImageNamed:@"genericFolderIcon"];
    OBASSERT(folderIcon);
    
    // now add the group names that we found from our BibItems, using a generic folder icon
    // use OATextWithIconCell keys
    while(group = [groupEnum nextObject]){
        dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:group, BDSKGroupCellStringKey, 
						folderIcon, BDSKGroupCellImageKey, 
						[NSNumber numberWithInt:[countedSet countForObject:group]], BDSKGroupCellCountKey, nil];
        [mutableGroups addObject:dictionary];
        [dictionary release];
    }
    
	// now sort using the current column and order
	NSString *key = BDSKGroupCellStringKey;
	if([sortGroupsKey isEqualToString:BDSKGroupCellCountKey])
		key = BDSKGroupCellCountKey;
		
	if(sortGroupsDescending)
		[mutableGroups sortUsingFunction:reverseGroupCompareFunc context:key];
	else
		[mutableGroups sortUsingFunction:groupCompareFunc context:key];
    
    // add an icon and name for all pubs in the document and put it on top
    dictionary = [[NSDictionary alloc] initWithObjectsAndKeys:BDSKAllPublicationsLocalizedString, BDSKGroupCellStringKey, 
					[NSImage smallImageNamed:@"FolderPenIcon"], BDSKGroupCellImageKey, 
					[NSNumber numberWithInt:[publications count]], BDSKGroupCellCountKey, nil];
    [mutableGroups insertObject:dictionary atIndex:0];
    [dictionary release];
	
    [groups setArray:mutableGroups];
    [countedSet release];
    [mutableGroups release];
	
	// select the current group, if still around. Otherwise select All Publications
	CFIndex idx = 0;
	
	if(groupName){
		idx = [groups count];
		while(--idx){
			if([[[groups objectAtIndex:idx] objectForKey:BDSKGroupCellStringKey] isEqualToString:groupName])
				break;
		}
		[groupName release];
	}
	
    [groupTableView reloadData];
	[groupTableView selectRow:idx byExtendingSelection:NO];
	if(preserve)
		[self displaySelectedGroup]; // the selection may not have changed, so we won't get this from the notification
}
	
- (void)displaySelectedGroup{
	int row = [groupTableView selectedRow];
	OBASSERT(row != -1);
	if(row == -1)
		return;
	
    if(row == 0)
        [groupedPublications setArray:publications];
    else
        [groupedPublications setArray:[self publicationsInCurrentGroup]];
    
    [self searchFieldAction:searchField]; // redo the search to update the table
}

// simplistic search method for static groups; we don't need the features of the standard searching method

- (NSArray *)publicationsInCurrentGroup{
    
    NSMutableArray *array = [publications mutableCopy];

    CFIndex idx = [array count];
    NSSet *containingGroups = nil;
    NSString *groupName = [self selectedGroupName];
    NSString *groupField = [self currentGroupField];
    
    while(idx--){
        
        OBPRECONDITION(idx < [array count]);
        containingGroups = [[array objectAtIndex:idx] groupsForField:groupField];
            
        if([containingGroups containsObject:groupName] == NO)
            [array removeObjectAtIndex:idx]; 
    }
    
    return [array autorelease];
}

- (NSIndexSet *)indexesOfRowsToHighlightInRange:(NSRange)indexRange tableView:(BDSKGroupTableView *)tview{
   
    if([tableView numberOfSelectedRows] == 0)
        return [NSIndexSet indexSet];
    
    // This allows us to be slightly lazy, only putting the visible group rows in the dictionary
    NSIndexSet *visibleIndexes = [NSIndexSet indexSetWithIndexesInRange:indexRange];
    int cnt = [visibleIndexes count];

    // Mutable dictionary with fixed capacity using NSObjects for keys with ints for values; this gives us a fast lookup of row name->index.  Dictionaries can use any pointer-size element for a key or value; see /Developer/Examples/CoreFoundation/Dictionary.
    CFMutableDictionaryRef rowDict = CFDictionaryCreateMutable(CFAllocatorGetDefault(), cnt, &OFNSObjectCopyDictionaryKeyCallbacks, &OFIntegerDictionaryValueCallbacks);
    
    cnt = [visibleIndexes firstIndex];
    
    while(cnt != NSNotFound){
        CFDictionaryAddValue(rowDict, (CFStringRef)[[groups objectAtIndex:cnt] objectForKey:BDSKGroupCellStringKey], (void *)cnt);
        cnt = [visibleIndexes indexGreaterThanIndex:cnt];
    }
    
    // Use this for the indexes we're going to return
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    
    // Unfortunately, we have to check all of the items in the main table, since hidden items may have a visible group
    NSIndexSet *rowIndexes = [tableView selectedRowIndexes];
    unsigned int rowIndex = [rowIndexes firstIndex];
    NSSet *possibleGroups;
    NSString *group;
    BOOL rowExists;
    NSEnumerator *groupEnum;
    NSString *groupField = [self currentGroupField];
        
    while(rowIndex != NSNotFound){ 
        // here are all the groups that this item can be a part of
        possibleGroups = [[shownPublications objectAtIndex:rowIndex] groupsForField:groupField];
        groupEnum = [possibleGroups objectEnumerator];
        
        while(group = [groupEnum nextObject]){
            // The dictionary only has visible group rows, so not all of the keys (potential groups) will exist in the dictionary
            rowExists = CFDictionaryGetValueIfPresent(rowDict, (CFStringRef)group, (const void **)&cnt);
            if(rowExists) [indexSet addIndex:cnt];
        }
        rowIndex = [rowIndexes indexGreaterThanIndex:rowIndex];
    }
    
    CFRelease(rowDict);
    
    // duplicating the highlight looks funny
    [indexSet removeIndex:[groupTableView selectedRow]];
    return indexSet;
}

- (NSMenu *)groupFieldsMenu {
	NSMenu *menu = [[NSMenu alloc] init];
	NSMenuItem *menuItem;
	NSEnumerator *fieldEnum = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey] objectEnumerator];
	NSString *field;
	
	while (field = [fieldEnum nextObject]) {
		[menu addItemWithTitle:field action:NULL keyEquivalent:@""];
	}
    
    [menu addItem:[NSMenuItem separatorItem]];
	
	menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@%@", NSLocalizedString(@"Add Field", @""), [NSString horizontalEllipsisString]]
										  action:@selector(addGroupFieldAction:)
								   keyEquivalent:@""];
	[menuItem setTarget:self];
	[menu addItem:menuItem];
    [menuItem release];
	
	menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@%@", NSLocalizedString(@"Remove Field", @""), [NSString horizontalEllipsisString]]
										  action:@selector(removeGroupFieldAction:)
								   keyEquivalent:@""];
	[menuItem setTarget:self];
	[menu addItem:menuItem];
    [menuItem release];
	
	return [menu autorelease];
}

- (NSMenu *)tableView:(BDSKGroupTableView *)aTableView menuForTableHeaderColumn:(NSTableColumn *)tableColumn onPopUp:(BOOL)flag{
	if ([[tableColumn identifier] isEqualToString:@"group"] && flag == NO) {
		return [[[NSApp delegate] groupSortMenuItem] submenu];
	}
	return nil;
}

- (void)sortGroupsByGroup:(id)sender{
	BDSKGroupTableHeaderView *headerView = (BDSKGroupTableHeaderView *)[groupTableView headerView];
	NSPopUpButtonCell *headerCell = [headerView popUpHeaderCell];
	
	[headerCell selectItemWithTitle:currentGroupField];
	
	[self sortGroupsByKey:BDSKGroupCellStringKey];
}

- (void)sortGroupsByCount:(id)sender{
	BDSKGroupTableHeaderView *headerView = (BDSKGroupTableHeaderView *)[groupTableView headerView];
	NSPopUpButtonCell *headerCell = [headerView popUpHeaderCell];
	
	[headerCell selectItemWithTitle:currentGroupField];
	
	[self sortGroupsByKey:BDSKGroupCellCountKey];
}

- (void)changeGroupFieldAction:(id)sender{
	BDSKGroupTableHeaderView *headerView = (BDSKGroupTableHeaderView *)[groupTableView headerView];
	NSPopUpButtonCell *headerCell = [headerView popUpHeaderCell];
	NSString *field = [headerCell titleOfSelectedItem];
    
	if(![field isEqualToString:currentGroupField]){
		[self setCurrentGroupField:field];
		
		[[OFPreferenceWrapper sharedPreferenceWrapper] setObject:currentGroupField forKey:BDSKCurrentGroupFieldKey];
		[[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldChangedNotification
															object:self
														  userInfo:[NSDictionary dictionary]];
	}
}

// for adding/removing groups, we use the searchfield sheets

- (void)addGroupFieldAction:(id)sender{
	BDSKGroupTableHeaderView *headerView = (BDSKGroupTableHeaderView *)[groupTableView headerView];
	NSPopUpButtonCell *headerCell = [headerView popUpHeaderCell];
	
	[headerCell selectItemWithTitle:currentGroupField];
    
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    NSMutableSet *invalidFields = [NSMutableSet setWithObjects:
		BDSKDateModifiedString, BDSKDateCreatedString, BDSKDateString, 
		BDSKTitleString, BDSKBooktitleString, BDSKVolumetitleString, BDSKContainerString, BDSKChapterString, 
		BDSKVolumeString, BDSKNumberString, BDSKSeriesString, BDSKPagesString, BDSKItemNumberString, 
		BDSKAbstractString, BDSKAnnoteString, BDSKRssDescriptionString, nil];
	[invalidFields addObjectsFromArray:[pw stringArrayForKey:BDSKLocalFileFieldsKey]];
	[invalidFields addObjectsFromArray:[pw stringArrayForKey:BDSKRemoteURLFieldsKey]];
	BibTypeManager *typeMan = [BibTypeManager sharedManager];
	NSMutableSet *fieldNameSet = [NSMutableSet setWithSet:[typeMan allFieldNames]];
	[fieldNameSet addObject:BDSKTypeString];
	[fieldNameSet addObjectsFromArray:[pw stringArrayForKey:BDSKRatingFieldsKey]];
	[fieldNameSet addObjectsFromArray:[pw stringArrayForKey:BDSKBooleanFieldsKey]];
	[fieldNameSet minusSet:invalidFields];
	NSMutableArray *colNames = [[fieldNameSet allObjects] mutableCopy];
	[colNames sortUsingSelector:@selector(caseInsensitiveCompare:)];
	
	[addFieldComboBox removeAllItems];
	[addFieldComboBox addItemsWithObjectValues:colNames];
    [addFieldPrompt setStringValue:NSLocalizedString(@"Name of group field:",@"")];
	
	[colNames release];
    
	[NSApp beginSheet:addFieldSheet
       modalForWindow:documentWindow
        modalDelegate:self
       didEndSelector:@selector(addGroupFieldSheetDidEnd:returnCode:contextInfo:)
          contextInfo:headerCell];

}    
    
- (void)addGroupFieldSheetDidEnd:(NSWindow *)sheet returnCode:(int) returnCode contextInfo:(void *)contextInfo{
	if(returnCode == 0)
		return;
	
	OFPreferenceWrapper *pw = [OFPreferenceWrapper sharedPreferenceWrapper];
    NSMutableSet *invalidFields = [NSMutableSet setWithObjects:
		BDSKDateModifiedString, BDSKDateCreatedString, BDSKDateString, 
		BDSKTitleString, BDSKBooktitleString, BDSKVolumetitleString, BDSKContainerString, BDSKChapterString, 
		BDSKVolumeString, BDSKNumberString, BDSKSeriesString, BDSKPagesString, 
		BDSKAbstractString, BDSKAnnoteString, BDSKRssDescriptionString, nil];
	[invalidFields addObjectsFromArray:[pw stringArrayForKey:BDSKLocalFileFieldsKey]];
	[invalidFields addObjectsFromArray:[pw stringArrayForKey:BDSKRemoteURLFieldsKey]];
    
	NSString *field = [[addFieldComboBox stringValue] capitalizedString];
    
	if([invalidFields containsObject:field]){
        NSBeginAlertSheet(NSLocalizedString(@"Invalid Field", @"Invalid Field"),
                          nil, nil, nil, documentWindow, nil, nil, nil, nil,
                          [NSString stringWithFormat:NSLocalizedString(@"The field \"%@\" can not be used for groups.", @""), field] );
		return;
	}
	
    NSPopUpButtonCell *cell = contextInfo;
	NSMutableArray *array = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey] mutableCopy];
	[array addObject:field];
	[[OFPreferenceWrapper sharedPreferenceWrapper] setObject:array forKey:BDSKGroupFieldsKey];	
    [cell insertItemWithTitle:field atIndex:[array count] - 1];
    [array release];
}

- (void)removeGroupFieldAction:(id)sender{
	BDSKGroupTableHeaderView *headerView = (BDSKGroupTableHeaderView *)[groupTableView headerView];
	NSPopUpButtonCell *headerCell = [headerView popUpHeaderCell];
	
	[headerCell selectItemWithTitle:currentGroupField];

    [delFieldPrompt setStringValue:NSLocalizedString(@"Group field to remove:",@"")];
    [delFieldPopupButton removeAllItems];
    
    [delFieldPopupButton addItemsWithTitles:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey]];
    
    [NSApp beginSheet:delFieldSheet
       modalForWindow:documentWindow
        modalDelegate:self
       didEndSelector:@selector(removeGroupFieldSheetDidEnd:returnCode:contextInfo:)
          contextInfo:headerCell];
}

- (void)removeGroupFieldSheetDidEnd:(NSWindow *)sheet returnCode:(int) returnCode contextInfo:(void *)contextInfo{
    NSMutableArray *prefsQuickSearchKeysMutableArray = nil;
    NSPopUpButtonCell *cell = contextInfo;
    
    if(returnCode == 1){
        NSString *field = [[delFieldPopupButton selectedItem] title];
        NSMutableArray *array = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKGroupFieldsKey] mutableCopy];
        [array removeObject:field];
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:array forKey:BDSKGroupFieldsKey];
        [array release];
        
        [cell removeItemWithTitle:field];
		if([field isEqualToString:currentGroupField]){
			[self setCurrentGroupField:[[cell itemAtIndex:0] title]];
			[cell selectItemWithTitle:currentGroupField];
			
			[[OFPreferenceWrapper sharedPreferenceWrapper] setObject:currentGroupField forKey:BDSKCurrentGroupFieldKey];
			[[NSNotificationCenter defaultCenter] postNotificationName:BDSKGroupFieldChangedNotification
																object:self
															  userInfo:[NSDictionary dictionary]];
		}
    }
}

- (BOOL)addPublications:(NSArray *)pubs toGroup:(NSString *)group{
    NSEnumerator *pubEnum = [pubs objectEnumerator];
    BibItem *pub;
	int count = 0;
	int handleInherited = BDSKOperationAsk;
	int rv;
    
    while(pub = [pubEnum nextObject]){
        OBASSERT([pub isKindOfClass:[BibItem class]]);        
        
		rv = [pub addToGroupNamed:group usingField:[self currentGroupField] handleInherited:handleInherited];
		
		if(rv == BDSKOperationSet || rv == BDSKOperationAppend){
			count++;
		}else if(rv == BDSKOperationAsk){
			NSString *otherButton = nil;
			if([[[BibTypeManager sharedManager] singleValuedGroupFields] containsObject:[self currentGroupField]] == NO)
				otherButton = NSLocalizedString(@"Append", @"Append");
			
            rv = NSRunAlertPanel(NSLocalizedString(@"Inherited Value", @"alert title"),
								 NSLocalizedString(@"One or more items have a value that was inherited from an item linked to by the Crossref field. This operation would break the inheritance for this value. What do you want me to do with inherited values?", @""), 
								 NSLocalizedString(@"Don't Change", @"Don't change"),
								 NSLocalizedString(@"Set", @"Set"),
								 otherButton, 
								 nil);
			handleInherited = rv;
			if(handleInherited != BDSKOperationIgnore){
				[pub addToGroupNamed:group usingField:[self currentGroupField] handleInherited:handleInherited];
			}
		}
    }
	
	if(count > 0)
		[[self undoManager] setActionName:NSLocalizedString(@"Add To Group", @"Add to group")];
    
    return YES;
}

- (void)sortGroupsByKey:(NSString *)key{
    if (key == nil) {
        // clicked the sort arrow in the table header, change sort order
        sortGroupsDescending = !sortGroupsDescending;
    } else if ([key isEqualToString:sortGroupsKey]) {
		// same key, nothing to be done
		return;
    } else {
        // change key
        // save new sorting selector, and re-sort the array.
        if ([key isEqualToString:BDSKGroupCellStringKey])
			sortGroupsDescending = NO;
		else
			sortGroupsDescending = YES; // more appropriate for default count sort
		[sortGroupsKey release];
        sortGroupsKey = [key retain];
	}
    
    // this is a hack to keep us from getting selection change notifications while sorting (which updates the TeX and attributed text previews)
    [groupTableView setDelegate:nil];
	
    // cache the selection
    NSString *groupName = nil;
	if ([groupTableView selectedRow] > 0)
		groupName = [[self selectedGroupName] copy];
	
	// we temporarily remove the All Publications item, as it has to stay on top
	NSDictionary *allPubsItem = [[groups objectAtIndex:0] retain];
	[groups removeObjectAtIndex:0];
	
	if(sortGroupsDescending)
		[groups sortUsingFunction:reverseGroupCompareFunc context:sortGroupsKey];
	else
		[groups sortUsingFunction:groupCompareFunc context:sortGroupsKey];
	
    // Set the graphic for the new column header
	BDSKHeaderPopUpButtonCell *headerPopup = (BDSKHeaderPopUpButtonCell *)[(BDSKGroupTableHeaderView *)[groupTableView headerView] popUpHeaderCell];
	[headerPopup setIndicatorImage:[NSImage imageNamed:sortGroupsDescending ? @"sort-down" : @"sort-up"]];
	// move the All Publications item back on top
	[groups insertObject:allPubsItem atIndex:0];
	[allPubsItem release];

	// select the current group, if still around. Otherwise select All Publications
	CFIndex idx = 0;
	
	if(groupName){
		idx = [groups count];
		while(--idx){
			if([[[groups objectAtIndex:idx] objectForKey:BDSKGroupCellStringKey] isEqualToString:groupName])
				break;
		}
		[groupName release];
	}
	
    [groupTableView reloadData];
	[groupTableView selectRow:idx byExtendingSelection:NO];
	[self displaySelectedGroup];
	
    // reset ourself as delegate
    [groupTableView setDelegate:self];
}

NSComparisonResult reverseGroupCompareFunc(id item1, id item2, void *context){
    return groupCompareFunc(item2, item1, context);
}

NSComparisonResult groupCompareFunc(id item1, id item2, void *context){
	NSString *key = (NSString *)context;

    id value1 = [item1 objectForKey:key];
    id value2 = [item2 objectForKey:key];
	
	if ([value1 isKindOfClass:[NSNumber class]] && [value2 isKindOfClass:[NSNumber class]])
		return [(NSNumber *)value1 compare:(NSNumber *)value2];
	
	OBASSERT([value1 isKindOfClass:[NSString class]] && [value2 isKindOfClass:[NSString class]]);
	 
	if ([NSString isEmptyString:value1]) {
		return ([NSString isEmptyString:value2])? NSOrderedSame : NSOrderedDescending;
	} else if ([NSString isEmptyString:value2]) {
		return NSOrderedAscending;
	}
	return [(NSString *)value1 localizedCaseInsensitiveNumericCompare:(NSString *)value2];
}

#pragma mark - 
#pragma mark File Content Search

- (IBAction)searchByContent:(id)sender
{
    // Normal search if the fileSearchController is not present and the searchstring is empty, since the searchfield target has apparently already been reset (I think).  Fixes bug #1341802.
    OBASSERT(searchField != nil && [searchField target] != nil);
    if([searchField target] == self && [NSString isEmptyString:[searchField stringValue]]){
        [self hidePublicationsWithoutSubstring:[sender stringValue] inField:quickSearchKey];
        return;
    }
    
    if(fileSearchController == nil)
        fileSearchController = [[BDSKFileContentSearchController alloc] initForDocument:self];

    NSView *contentView = [fileSearchController searchContentView];
    [splitView retain];
    NSRect frame = [splitView frame];
    [contentView setFrame:frame];
    [groupSplitView replaceSubview:splitView with:contentView];
    [[documentWindow contentView] setNeedsDisplay:YES];
    
    [searchField setTarget:fileSearchController];
    [searchField setAction:@selector(search:)];
    [searchField setDelegate:fileSearchController];
    
    // use whatever content is in the searchfield; delay it so the progress indicator doesn't show up before the rest of the content is on screen
    [fileSearchController queueSelector:@selector(search:) withObject:searchField];
    
}

// Method required by the BDSKSearchContentView protocol; the implementor is responsible for restoring its state by removing the view passed as an argument and resetting search field target/action.
- (void)restoreDocumentStateByRemovingSearchView:(NSView *)view
{
    NSArray *titlesToSelect = [fileSearchController titlesOfSelectedItems];
    
    NSRect frame = [view frame];
    [splitView setFrame:frame];
    [groupSplitView replaceSubview:view with:splitView];
    [splitView release];
    [[documentWindow contentView] setNeedsDisplay:YES];

    [searchField setTarget:self];
    [searchField setDelegate:self];
    [searchField setAction:@selector(searchFieldAction:)];
    
    if([titlesToSelect count]){
        NSEnumerator *pubEnum = [shownPublications objectEnumerator];
        BibItem *item;
        while(item = [pubEnum nextObject]){
            NSString *title;
            NSEnumerator *titleEnum = [titlesToSelect objectEnumerator];
            while(title = [titleEnum nextObject]){
                if([[item title] isEqualToString:title])
                    [self highlightBib:item byExtendingSelection:YES];
            }
        }
        [tableView scrollRowToVisible:[tableView selectedRow]];
    } 
}

@end
