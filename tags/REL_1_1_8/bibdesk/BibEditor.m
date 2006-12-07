//  BibEditor.m

//  Created by Michael McCracken on Mon Dec 24 2001.
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


#import "BibEditor.h"
#import "BibEditor_Toolbar.h"
#import "BibDocument.h"
#import <OmniAppKit/NSScrollView-OAExtensions.h>
#import <OmniFoundation/NSString-OFExtensions.h>
#import "BDAlias.h"
#import "NSImage+Toolbox.h"
#import "BDSKComplexString.h"
#import "BDSKScriptHookManager.h"
#import "BDSKZoomablePDFView.h"

#import "KFAppleScriptHandlerAdditionsCore.h"
#import "BDSKScriptHookManager.h"

NSString *BDSKWeblocFilePboardType = @"CorePasteboardFlavorType 0x75726C20";

enum{
	BDSKDrawerUnknownState = -1,
	BDSKDrawerStateOpenMask = 1,
	BDSKDrawerStateRightMask = 2,
	BDSKDrawerStateWebMask = 4,
	BDSKDrawerStateTextMask = 8
};

@implementation BibEditor

- (NSString *)windowNibName{
    return @"BibEditor";
}


- (id)initWithBibItem:(BibItem *)aBib document:(BibDocument *)doc{
    self = [super initWithWindowNibName:@"BibEditor"];
    fieldNumbers = [[NSMutableDictionary dictionaryWithCapacity:1] retain];
    citeKeyFormatter = [[BDSKCiteKeyFormatter alloc] init];
    fieldNameFormatter = [[BDSKFieldNameFormatter alloc] init];
	
    theBib = aBib;
    [theBib setEditorObj:self];
    currentType = [[theBib type] retain];    // do this once in init so it's right at the start.
                                    // has to be before we call [self window] because that calls windowDidLoad:.
    theDocument = doc; // don't retain - it retains us.
	pdfSnoopViewLoaded = NO;
	textSnoopViewLoaded = NO;
	webSnoopViewLoaded = NO;
	drawerState = BDSKDrawerUnknownState;
	
	showStatus = YES;
	
	forceEndEditing = NO;
    didSetupForm = NO;
	
    // this should probably be moved around.
    [[self window] setTitle:[theBib displayTitle]];
    [[self window] setDelegate:self];
    [[self window] registerForDraggedTypes:[NSArray arrayWithObjects:BDSKBibTeXStringPboardType, 
            NSStringPboardType, nil]];					
    macroTextFieldWC = [[MacroTextFieldWindowController alloc] init];
    
    notesViewUndoManager = [[NSUndoManager alloc] init];
    abstractViewUndoManager = [[NSUndoManager alloc] init];
    rssDescriptionViewUndoManager = [[NSUndoManager alloc] init];

#if DEBUG
    NSLog(@"BibEditor alloc");
#endif
    return self;
}

- (void)windowDidLoad{
	[self setCiteKeyDuplicateWarning:![self citeKeyIsValid:[theBib citeKey]]];
    [self fixURLs];
}

- (BibItem *)currentBib{
    return theBib;
}

- (void)setupForm{
    static NSFont *requiredFont = nil;
    if(!requiredFont){
        requiredFont = [NSFont systemFontOfSize:13.0];
        [[NSFontManager sharedFontManager] convertFont:requiredFont
                                           toHaveTrait:NSBoldFontMask];
    }
    
	// if we were editing in the form, we will restore the selected cell and the selection
	NSResponder *firstResponder = [[self window] firstResponder];
	NSText *fieldEditor = nil;
	NSString *editedTitle = nil;
	int editedRow = -1;
	NSRange selection;
	if([firstResponder isKindOfClass:[NSText class]] && [(NSText *)firstResponder delegate] == bibFields){
		fieldEditor = (NSText *)firstResponder;
		selection = [fieldEditor selectedRange];
		editedTitle = [(NSFormCell *)[bibFields selectedCell] title];
		forceEndEditing = YES;
		if (![[self window] makeFirstResponder:[self window]])
			[[self window] endEditingFor:nil];
		forceEndEditing = NO;
	}
	
    BibAppController *appController = (BibAppController *)[NSApp delegate];
    NSString *tmp;
    NSFormCell *entry;
    NSArray *sKeys;
    int i=0;
    int numRows;
    NSRect rect = [bibFields frame];
    NSPoint origin = rect.origin;
	NSEnumerator *e;

	NSMutableSet *keysNotInForm = [[NSMutableSet alloc] initWithObjects: BDSKAnnoteString, BDSKAbstractString, BDSKRssDescriptionString, BDSKDateCreatedString, BDSKDateModifiedString, nil];
    [keysNotInForm addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKBooleanFieldsKey]];
    [keysNotInForm addObjectsFromArray:[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRatingFieldsKey]];

    NSDictionary *reqAtt = [[NSDictionary alloc] initWithObjects:[NSArray arrayWithObjects:[NSColor redColor],nil]
                                                         forKeys:[NSArray arrayWithObjects:NSForegroundColorAttributeName,nil]];
	
	// set up for adding all items 
    // remove all items in the NSForm
    [bibFields removeAllEntries];

    // make two passes to get the required entries at top.
    i=0;
    sKeys = [[[theBib pubFields] allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    NSMutableSet *addedFields = [[NSMutableSet alloc] initWithCapacity:5];
    e = [[[BibTypeManager sharedManager] requiredFieldsForType:[theBib type]] objectEnumerator];

    while(tmp = [e nextObject]){
        if (![keysNotInForm containsObject:tmp]){
            entry = [bibFields insertEntry:tmp usingTitleFont:requiredFont attributesForTitle:reqAtt indexAndTag:i objectValue:[theBib valueOfField:tmp]];
            
            // Autocompletion stuff
            [entry setFormatter:[appController formatterForEntry:tmp]];

            if([editedTitle isEqualToString:tmp])
				editedRow = i;
            i++;

            [addedFields addObject:tmp];
        }
    }

    // now, we add the optional fields in the order they came in the config file.
    
    e = [[[BibTypeManager sharedManager] optionalFieldsForType:[theBib type]] objectEnumerator];
    
    while(tmp = [e nextObject]){
        if(![keysNotInForm containsObject:tmp]){
            entry = [bibFields insertEntry:tmp usingTitleFont:nil attributesForTitle:nil indexAndTag:i objectValue:[theBib valueOfField:tmp]];
            
            [entry setTitleAlignment:NSLeftTextAlignment];
            
            // Autocompletion stuff
			[entry setFormatter:[appController formatterForEntry:tmp]];

            if([editedTitle isEqualToString:tmp])
				editedRow = i;
            i++;
            [addedFields addObject:tmp];
        }
        
    }
    
    // now add any remaining fields at the end. 
    // (Note: should we add remaining fields after required fields on 
    // the assumption that they're important since the user added them?)
    
    e = [sKeys objectEnumerator];
    while(tmp = [e nextObject]){
        if(![addedFields containsObject:tmp] && ![keysNotInForm containsObject:tmp]){
            
            entry = [bibFields insertEntry:tmp usingTitleFont:nil attributesForTitle:nil indexAndTag:i objectValue:[theBib valueOfField:tmp]];

            [entry setTitleAlignment:NSLeftTextAlignment];
            
			[entry setFormatter:[appController formatterForEntry:tmp]]; // for autocompletion

            if([editedTitle isEqualToString:tmp])
				editedRow = i;
            i++;
        }
    }
    
    [keysNotInForm release];
    [reqAtt release];
    [addedFields release];
    
    [bibFields sizeToFit];
    
    [bibFields setFrameOrigin:origin];
    [bibFields setNeedsDisplay:YES];
	
	// restore the edited cell and its selection
	if(fieldEditor && editedRow != -1){
		[[self window] makeFirstResponder:bibFields];
		[bibFields selectTextAtRow:editedRow column:0];
		[fieldEditor setSelectedRange:selection];
    }
	didSetupForm = YES;
    
	[extraBibFields setPrototype:[[[NSCell alloc] initTextCell:@""] autorelease]];
	rect = [extraBibFields frame];
	origin = rect.origin;
	
    while ([extraBibFields numberOfRows])
		[extraBibFields removeRow:0];
	
	NSButtonCell *buttonCell;
	int nc = [extraBibFields numberOfColumns];
	int j;
	
	j = nc;
	i = -1;
    e = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRatingFieldsKey] objectEnumerator];
    while(tmp = [e nextObject]){
		if (++j >= nc) {
			j = 0;
			i++;
			[extraBibFields addRow];
		}
		buttonCell = [[BDSKRatingButtonCell alloc] initWithMaxRating:5];
		[buttonCell setTitle:tmp];
		[buttonCell setImagePosition:NSImageLeft];
		[buttonCell setTarget:self];
		[buttonCell setAction:@selector(changeRating:)];
		[(BDSKRatingButtonCell *)buttonCell setRating:[theBib ratingValueOfField:tmp]];
		[extraBibFields putCell:buttonCell atRow:i column:j];
		[buttonCell release];
    }
	
	j = nc;
    e = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKBooleanFieldsKey] objectEnumerator];
    while(tmp = [e nextObject]){
		if (++j >= nc) {
			j = 0;
			i++;
			[extraBibFields addRow];
		}
		buttonCell = [[NSButtonCell alloc] initTextCell:tmp];
		[buttonCell setButtonType:NSSwitchButton];
		[buttonCell setState:[theBib boolValueOfField:tmp] ? NSOnState : NSOffState];
		[buttonCell setTarget:self];
		[buttonCell setAction:@selector(changeFlag:)];
		[extraBibFields putCell:buttonCell atRow:i column:j];
		[buttonCell release];
    }
	
	[extraBibFields sizeToFit];
    
    [extraBibFields setFrameOrigin:origin];
    [extraBibFields setNeedsDisplay:YES];
}

- (void)setupTypePopUp{
    NSEnumerator *typeNamesE = [[[BibTypeManager sharedManager] bibTypesForFileType:[theBib fileType]] objectEnumerator];
    NSString *typeName = nil;

    [bibTypeButton removeAllItems];
    while(typeName = [typeNamesE nextObject]){
        [bibTypeButton addItemWithTitle:typeName];
    }

    [bibTypeButton selectItemWithTitle:currentType];
}

- (void)awakeFromNib{
	[self setupToolbar];
    
	[splitView setPositionAutosaveName:@"OASplitView Position BibEditor"];
    
    [citeKeyField setFormatter:citeKeyFormatter];
    [newFieldName setFormatter:fieldNameFormatter];

    [self setupTypePopUp];
    [self setupForm]; // gets called in window will load...?
    [bibFields registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, BDSKWeblocFilePboardType, nil]];
	
	[ratingButton setRating:[theBib rating]];
	[ratingButton setTitle:BDSKRatingString];
	
	[statusLine retain]; // we need to retain, as we might remove it from the window
	if (![[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKShowEditorStatusBarKey]) {
		[self toggleStatusBar:nil];
	}
    
	// The popupbutton needs to be set before fixURLs is called, and -windowDidLoad gets sent after awakeFromNib.

	// Set the properties of viewLocalButton that cannot be set in IB
	[viewLocalButton setArrowImage:[NSImage imageNamed:@"ArrowPointingDown"]];
	[viewLocalButton setShowsMenuWhenIconClicked:NO];
	[[viewLocalButton cell] setAltersStateOfSelectedItem:NO];
	[[viewLocalButton cell] setAlwaysUsesFirstItemAsSelected:YES];
	[[viewLocalButton cell] setUsesItemFromMenu:NO];
	[[viewLocalButton cell] setRefreshesMenu:YES];
	[[viewLocalButton cell] setDelegate:self];
    [viewLocalButton registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil]];
		
	[viewLocalButton setMenu:[self menuForImagePopUpButtonCell:[viewLocalButton cell]]];

	// Set the properties of viewRemoteButton that cannot be set in IB
	[viewRemoteButton setArrowImage:[NSImage imageNamed:@"ArrowPointingDown"]];
	[viewRemoteButton setShowsMenuWhenIconClicked:NO];
	[[viewRemoteButton cell] setAltersStateOfSelectedItem:NO];
	[[viewRemoteButton cell] setAlwaysUsesFirstItemAsSelected:YES];
	[[viewRemoteButton cell] setUsesItemFromMenu:NO];
	[[viewRemoteButton cell] setRefreshesMenu:YES];
	[[viewRemoteButton cell] setDelegate:self];
    [viewRemoteButton registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, BDSKWeblocFilePboardType, nil]];
		
	[viewRemoteButton setMenu:[self menuForImagePopUpButtonCell:[viewRemoteButton cell]]];

	// Set the properties of documentSnoopButton that cannot be set in IB
	[documentSnoopButton setArrowImage:[NSImage imageNamed:@"ArrowPointingDown"]];
	[documentSnoopButton setShowsMenuWhenIconClicked:NO];
	[[documentSnoopButton cell] setAltersStateOfSelectedItem:YES];
	[[documentSnoopButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[documentSnoopButton cell] setUsesItemFromMenu:NO];
	[[documentSnoopButton cell] setRefreshesMenu:NO];
	
	[documentSnoopButton setMenu:[self menuForImagePopUpButtonCell:[documentSnoopButton cell]]];
	[documentSnoopButton selectItemAtIndex:[[OFPreferenceWrapper sharedPreferenceWrapper] integerForKey:BDSKSnoopDrawerContentKey]];
		
    [notesView setString:[theBib valueOfField:BDSKAnnoteString inherit:NO]];
    [abstractView setString:[theBib valueOfField:BDSKAbstractString inherit:NO]];
    [rssDescriptionView setString:[theBib valueOfField:BDSKRssDescriptionString inherit:NO]];
	currentEditedView = nil;
    
    // set up identifiers for the tab view items, since we receive delegate messages from it
    NSArray *tabViewItems = [tabView tabViewItems];
    [[tabViewItems objectAtIndex:0] setIdentifier:BDSKBibtexString];
    [[tabViewItems objectAtIndex:1] setIdentifier:BDSKAnnoteString];
    [[tabViewItems objectAtIndex:2] setIdentifier:BDSKAbstractString];
    [[tabViewItems objectAtIndex:3] setIdentifier:BDSKRssDescriptionString];

    if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3){
    } else {
        NSSize drawerContentSize = [documentSnoopDrawer contentSize];
        id pdfView = [[NSClassFromString(@"BDSKZoomablePDFView") alloc] initWithFrame:NSMakeRect(0, 0, drawerContentSize.width, drawerContentSize.height)];
        
        // release the old scrollview/PDFImageView combination and replace with the PDFView
        [pdfSnoopContainerView replaceSubview:documentSnoopScrollView with:pdfView];
        [pdfView release];
        [pdfView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
        
        [pdfView setScrollerSize:NSSmallControlSize];
        documentSnoopScrollView = nil;
    }
    
	[fieldsScrollView setDrawsBackground:NO];
	
	[citeKeyField setStringValue:[theBib citeKey]];
	
	[theBib setEditorObj:self];	
	
	// Set the properties of actionMenuButton that cannot be set in IB
	[actionMenuButton setAlternateImage:[NSImage imageNamed:@"Action_Pressed"]];
	[actionMenuButton setArrowImage:nil];
	[actionMenuButton setShowsMenuWhenIconClicked:YES];
	[[actionMenuButton cell] setAltersStateOfSelectedItem:NO];
	[[actionMenuButton cell] setAlwaysUsesFirstItemAsSelected:NO];
	[[actionMenuButton cell] setUsesItemFromMenu:NO];
	[[actionMenuButton cell] setRefreshesMenu:NO];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibDidChange:)
												 name:BDSKBibItemChangedNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibWasAddedOrRemoved:)
												 name:BDSKDocAddItemNotification
											   object:theDocument];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibWasAddedOrRemoved:)
												 name:BDSKDocDelItemNotification
											   object:theDocument];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(bibWillBeRemoved:)
												 name:BDSKDocWillRemoveItemNotification
											   object:theBib];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(finalizeChanges:)
												 name:BDSKFinalizeChangesNotification
											   object:theDocument];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(docWindowWillClose:)
												 name:BDSKDocumentWindowWillCloseNotification
											   object:theDocument];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(typeInfoDidChange:)
												 name:BDSKBibTypeInfoChangedNotification
											   object:[BibTypeManager sharedManager]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(customFieldsDidChange:)
												 name:BDSKCustomFieldsChangedNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(macrosDidChange:)
												 name:BDSKBibDocMacroDefinitionChangedNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(macrosDidChange:)
												 name:BDSKBibDocMacroKeyChangedNotification
											   object:nil];

	[authorTableView setDoubleAction:@selector(showPersonDetailCmd:)];

    [bibFields setDelegate:self];
    
    // Only cascade editor windows if we have multiple editors open; bug #1299305
    if([[self window] setFrameAutosaveName:@"BibEditor window autosave name"])
        [self setShouldCascadeWindows:NO];

}

- (void)dealloc{
#if DEBUG
    NSLog(@"BibEditor dealloc");
#endif
    // release theBib? no...
    
    // This fixes some seriously weird issues with Jaguar, and possibly 10.3.  The tableview messages its datasource/delegate (BibEditor) after the editor is dealloced, which causes a crash.
    // See http://www.cocoabuilder.com/search/archive?words=crash+%22setDataSource:nil%22 for similar problems.
    [authorTableView setDelegate:nil];
    [authorTableView setDataSource:nil];
    [notesViewUndoManager release];
    [abstractViewUndoManager release];
    [rssDescriptionViewUndoManager release];   
    [currentType release];
    [citeKeyFormatter release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [fieldNumbers release];
    [fieldNameFormatter release];
    [theBib setEditorObj:nil];
	[viewLocalToolbarItem release];
	[viewRemoteToolbarItem release];
	[documentSnoopToolbarItem release];
	[statusLine release];
	[toolbarItems release];
	[macroTextFieldWC release];
    [super dealloc];
}

- (void)show{
    [self showWindow:self];
}

// note that we don't want the - document accessor! It messes us up by getting called for other stuff.

- (void)finalizeChangesPreservingSelection:(BOOL)shouldPreserveSelection{

    NSResponder *firstResponder = [[self window] firstResponder];
    
	// need to finalize text field cells being edited or the abstract/annote text views, since the text views bypass the normal undo mechanism for speed, and won't cause the doc to be marked dirty on subsequent edits
	if([firstResponder isKindOfClass:[NSText class]]){
		NSText *textView = (NSText *)firstResponder;
		NSRange selection = [textView selectedRange];
		id textDelegate = [textView delegate];
        if(textDelegate == bibFields || textDelegate == citeKeyField)
            firstResponder = textDelegate; // the text field or the form (textView is the field editor)

		forceEndEditing = YES; // make sure the validation will always allow the end of the edit
		didSetupForm = NO; // if we we rebuild the form, the selection will become meaningless
        
		// now make sure we submit the edit
		if (![[self window] makeFirstResponder:[self window]]){
            // this will remove the field editor from the view, set its delegate to nil, and empty it of text
			[[self window] endEditingFor:nil];
            forceEndEditing = NO;
            return;
        }
        
		forceEndEditing = NO;
        
        if(shouldPreserveSelection == NO)
            return;
        
        // for inherited fields, we should do something here to make sure the user doesn't have to go through the warning sheet
		
		if([[self window] makeFirstResponder:firstResponder] &&
		   !(firstResponder == bibFields && didSetupForm)){
            if([[textView string] length] < NSMaxRange(selection)) // check range for safety
                selection = NSMakeRange([[textView string] length],0);
            [textView setSelectedRange:selection];
        }
            
	}
}

- (void)finalizeChanges:(NSNotification *)aNotification{
    [self finalizeChangesPreservingSelection:YES];
}

- (IBAction)toggleStatusBar:(id)sender{
	NSRect tabViewFrame = [tabView frame];
	NSRect contentRect = [[[self window] contentView] frame];
	NSRect infoRect = [statusLine frame];
	if (showStatus) {
		showStatus = NO;
		tabViewFrame.size.height += 20.0;
		[statusLine removeFromSuperview];
	} else {
		showStatus = YES;
		tabViewFrame.size.height -= 20.0;
		infoRect.origin.y = contentRect.size.height - 16.0;
		infoRect.size.width = contentRect.size.width - 16.0;
		[statusLine setFrame:infoRect];
		[[[self window] contentView]  addSubview:statusLine];
	}
	[tabView setFrame:tabViewFrame];
	[[[self window] contentView] setNeedsDisplayInRect:contentRect];
	[[OFPreferenceWrapper sharedPreferenceWrapper] setBool:showStatus forKey:BDSKShowEditorStatusBarKey];
}

- (IBAction)revealLocal:(id)sender{
    NSWorkspace *sw = [NSWorkspace sharedWorkspace];
	NSString *field = [sender representedObject];
	NSString *path = [theBib localFilePathForField:field];
	[sw selectFile:path inFileViewerRootedAtPath:nil];
}

- (IBAction)viewLocal:(id)sender{
    NSWorkspace *sw = [NSWorkspace sharedWorkspace];
	NSString *field = [sender representedObject];
    
    volatile BOOL err = NO;

    NS_DURING

        if(![sw openFile:[theBib localFilePathForField:field]]){
                err = YES;
        }

        NS_HANDLER
            err=YES;
        NS_ENDHANDLER
        
        if(err)
            NSBeginAlertSheet(NSLocalizedString(@"Can't open local file", @"can't open local file"),
                              NSLocalizedString(@"OK", @"OK"),
                              nil,nil, [self window],self, NULL, NULL, NULL,
                              NSLocalizedString(@"Sorry, the contents of the Local-Url Field are neither a valid file path nor a valid URL.",
                                                @"explanation of why the local-url failed to open"), nil);

}

- (NSMenu *)submenuForMenuItem:(NSMenuItem *)menuItem{
	if (menuItem == [viewLocalToolbarItem menuFormRepresentation]) {
		return [self menuForImagePopUpButtonCell:[viewLocalButton cell]];
	} 
	else if (menuItem == [viewRemoteToolbarItem menuFormRepresentation]) {
		return [self menuForImagePopUpButtonCell:[viewRemoteButton cell]];
	} 
	else if (menuItem == [documentSnoopToolbarItem menuFormRepresentation]) {
		return [self menuForImagePopUpButtonCell:[documentSnoopButton cell]];
	} 
	return nil;
}

- (NSMenu *)menuForImagePopUpButtonCell:(RYZImagePopUpButtonCell *)cell{
	NSMenu *menu = [[NSMenu alloc] init];
	NSMenu *submenu;
	NSMenuItem *item;
	
	if (cell == [viewLocalButton cell]) {
		NSEnumerator *e = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey] objectEnumerator];
		NSString *field = nil;
		
		// the first one has to be view Local-Url file, since it's also the button's action when you're clicking on the icon.
		while (field = [e nextObject]) {
			item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"View %@ File",@"View Local-Url file"), field]
											  action:@selector(viewLocal:)
									   keyEquivalent:@""];
			[item setRepresentedObject:field];
			[menu addItem:item];
			[item release];
			item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Reveal %@ in Finder",@"Reveal Local-Url in finder"), field]
											  action:@selector(revealLocal:)
									   keyEquivalent:@""];
			[item setRepresentedObject:field];
			[menu addItem:item];
			[item release];
		}
		
		[menu addItem:[NSMenuItem separatorItem]];
		
		[menu addItemWithTitle:[NSString stringWithFormat:@"%@%C",NSLocalizedString(@"Choose File",@"Choose File..."),0x2026]
						action:@selector(chooseLocalURL:)
				 keyEquivalent:@""];
		
		// get Safari recent downloads
		if (submenu = [self getSafariRecentDownloadsMenu]) {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Link to Download URL",@"Link to Download URL")
											  action:NULL
									   keyEquivalent:@""];
			[item setSubmenu:submenu];
			[menu addItem:item];
			[item release];
		}
		
		// get Preview recent documents
		if (submenu = [self getPreviewRecentDocumentsMenu]) {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Link to Recently Opened File",@"Link to Recently Opened File")
											  action:NULL
									   keyEquivalent:@""];
			[item setSubmenu:submenu];
			[menu addItem:item];
			[item release];
		}
	}
	else if (cell == [viewRemoteButton cell]) {
		NSEnumerator *e = [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey] objectEnumerator];
		NSString *field = nil;
		
		// the first one has to be view Url in web brower, since it's also the button's action when you're clicking on the icon.
		while (field = [e nextObject]) {
			item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"View %@ in Web Browser",@"View Url in web browser"), field]
											  action:@selector(viewRemote:)
									   keyEquivalent:@""];
			[item setRepresentedObject:field];
			[menu addItem:item];
			[item release];
		}
		
		// get Safari recent URLs
		if (submenu = [self getSafariRecentURLsMenu]) {
			[menu addItem:[NSMenuItem separatorItem]];
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Link to Download URL",@"Link to Download URL")
										 	  action:NULL
									   keyEquivalent:@""];
			[item setSubmenu:submenu];
			[menu addItem:item];
			[item release];
		}
	}
	else if (cell == [documentSnoopButton cell]) {
		
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"View File in Drawer",@"View file in drawer")
										  action:@selector(toggleSnoopDrawer:)
								   keyEquivalent:@""];
		[item setRepresentedObject:pdfSnoopContainerView];
		[menu addItem:item];
		[item release];
		
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"View File as Text in Drawer",@"View file as text in drawer")
										  action:@selector(toggleSnoopDrawer:)
								   keyEquivalent:@""];
		[item setRepresentedObject:textSnoopContainerView];
		[menu addItem:item];
		[item release];
		
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"View Remote URL in Drawer",@"View remote URL in drawer")
										  action:@selector(toggleSnoopDrawer:)
								   keyEquivalent:@""];
		[item setRepresentedObject:webSnoopContainerView];
		[menu addItem:item];
		[item release];
	}
	
	return [menu autorelease];
}

- (NSMenu *)getSafariRecentDownloadsMenu{
	NSString *downloadPlistFileName = [NSHomeDirectory()  stringByAppendingPathComponent:@"Library"];
	downloadPlistFileName = [downloadPlistFileName stringByAppendingPathComponent:@"Safari"];
	downloadPlistFileName = [downloadPlistFileName stringByAppendingPathComponent:@"downloads.plist"];
	
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:downloadPlistFileName];
	NSArray *historyArray = [dict objectForKey:@"DownloadHistory"];
	
	if (![historyArray count])
		return nil;
	
	NSMenu *menu = [[NSMenu alloc] init];
	int i = 0;
	
	for (i = 0; i < [historyArray count]; i ++){
		NSDictionary *itemDict = [historyArray objectAtIndex:i];
		NSString *filePath = [itemDict objectForKey:@"DownloadEntryPath"];
		filePath = [filePath stringByExpandingTildeInPath];
		if([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
			NSString *fileName = [filePath lastPathComponent];
			NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:filePath];
			[image setSize: NSMakeSize(16, 16)];
			
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:fileName
														  action:@selector(setLocalURLPathFromMenuItem:)
												   keyEquivalent:@""];
			[item setRepresentedObject:filePath];
			[item setImage:image];
			[menu addItem:item];
			[item release];
		}
	}
	
	if ([menu numberOfItems] > 0)
		return [menu autorelease];
	
	[menu release];
	return nil;
}


- (NSMenu *)getSafariRecentURLsMenu{
	NSString *downloadPlistFileName = [NSHomeDirectory()  stringByAppendingPathComponent:@"Library"];
	downloadPlistFileName = [downloadPlistFileName stringByAppendingPathComponent:@"Safari"];
	downloadPlistFileName = [downloadPlistFileName stringByAppendingPathComponent:@"downloads.plist"];
	
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:downloadPlistFileName];
	NSArray *historyArray = [dict objectForKey:@"DownloadHistory"];
	
	if (![historyArray count])
		return nil;
	
	NSMenu *menu = [[NSMenu alloc] init];
	int i = 0;
	
	for (i = 0; i < [historyArray count]; i ++){
		NSDictionary *itemDict = [historyArray objectAtIndex:i];
		NSString *URLString = [itemDict objectForKey:@"DownloadEntryURL"];
		if (![NSString isEmptyString:URLString] && [NSURL URLWithString:URLString]) {
			NSImage *image = [NSImage smallGenericInternetLocationImage];
			[image setSize: NSMakeSize(16, 16)];
			
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:URLString
														  action:@selector(setRemoteURLFromMenuItem:)
												   keyEquivalent:@""];
			[item setRepresentedObject:URLString];
			[item setImage:image];
			[menu addItem:item];
			[item release];
		}
	}

	if ([menu numberOfItems] > 0)
		return [menu autorelease];
	
	[menu release];
	return nil;
}

- (NSMenu *)getPreviewRecentDocumentsMenu{
	BOOL success = CFPreferencesSynchronize(CFSTR("com.apple.Preview"),
									   kCFPreferencesCurrentUser,
									   kCFPreferencesCurrentHost);
	
	if(!success){
		NSLog(@"error syncing preview's prefs!");
	}

    // get all of the items from the Apple menu (works on 10.4, anyway), and build a set of the file paths for easy comparison as strings
    NSMutableSet *globalRecentPaths = [[NSMutableSet alloc] initWithCapacity:10];
    CFDictionaryRef globalRecentDictionary = CFPreferencesCopyAppValue(CFSTR("Documents"), CFSTR("com.apple.recentitems"));
    NSArray *globalItems = [(NSDictionary *)globalRecentDictionary objectForKey:@"CustomListItems"];
    if(globalRecentDictionary) CFRelease(globalRecentDictionary);
    
    NSEnumerator *e = [globalItems objectEnumerator];
    NSDictionary *itemDict = nil;
    NSData *aliasData = nil;
    NSString *filePath = nil;
    BDAlias *alias = nil;
    
    while(itemDict = [e nextObject]){
        aliasData = [itemDict objectForKey:@"Alias"];
        alias = [[BDAlias alloc] initWithData:aliasData];
        filePath = [alias fullPathNoUI];
        if(filePath)
            [globalRecentPaths addObject:filePath];
        [alias release];
    }
    
    // now get all of the recent items from Preview.app; this does not include items opened since Preview's last launch, unfortunately, regardless of the call to CFPreferencesSynchronize
	NSArray *historyArray = (NSArray *) CFPreferencesCopyAppValue(CFSTR("NSRecentDocumentRecords"), CFSTR("com.apple.Preview"));
    NSMutableSet *previewRecentPaths = [[NSMutableSet alloc] initWithCapacity:10];
	
	int i = 0;
	
	for (i = 0; i < [(NSArray *)historyArray count]; i ++){
		itemDict = [(NSArray *)historyArray objectAtIndex:i];
		aliasData = [[itemDict objectForKey:@"_NSLocator"] objectForKey:@"_NSAlias"];
		
        alias = [[BDAlias alloc] initWithData:aliasData];
        filePath = [alias fullPathNoUI];
        if(filePath)
            [previewRecentPaths addObject:filePath];
        [alias release];
	}
	
	if(historyArray) CFRelease(historyArray);
    
    NSMenu *menu = [[NSMenu alloc] init];

    // now add all of the items from Preview, which are most likely what we want
    e = [previewRecentPaths objectEnumerator];
    while(filePath = [e nextObject]){
        if([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
            NSString *fileName = [filePath lastPathComponent];
            NSImage *image = [NSImage smallImageForFile:filePath];
            
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:fileName
                                                          action:@selector(setLocalURLPathFromMenuItem:)
                                                   keyEquivalent:@""];
            [item setRepresentedObject:filePath];
            [item setImage:image];
            [menu addItem:item];
            [item release];
        }
    }
    
    // add a separator between Preview and global recent items, unless Preview has never been used
    if([previewRecentPaths count])
        [menu addItem:[NSMenuItem separatorItem]];

    // now add all of the items that /were not/ in Preview's recent items path; this works for files opened from Preview's open panel, as well as from the Finder
    e = [globalRecentPaths objectEnumerator];
    while(filePath = [e nextObject]){
        
        if(![previewRecentPaths containsObject:filePath] && [[NSFileManager defaultManager] fileExistsAtPath:filePath]){
            NSString *fileName = [filePath lastPathComponent];
            NSImage *image = [NSImage smallImageForFile:filePath];
            
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:fileName
                                                          action:@selector(setLocalURLPathFromMenuItem:)
                                                   keyEquivalent:@""];
            [item setRepresentedObject:filePath];
            [item setImage:image];
            [menu addItem:item];
            [item release];
        }
    }  
    [globalRecentPaths release];
    [previewRecentPaths release];
	
	if ([menu numberOfItems] > 0)
		return [menu autorelease];
	
	[menu release];
	return nil;
}


- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem{
	if ([menuItem action] == nil ||
		[menuItem action] == @selector(dummy:)){ // Unused selector for disabled items. Needed to avoid the popupbutton to insert its own
		return NO;
	}
	else if ([menuItem action] == @selector(generateCiteKey:)) {
		// need to set the title, as the document can change it in the main menu
		[menuItem setTitle: NSLocalizedString(@"Generate Cite Key", @"Generate Cite Key")];
		return YES;
	}
	else if ([menuItem action] == @selector(generateLocalUrl:)) {
		NSString *lurl = [theBib localURLPath];
		return (lurl && [[NSFileManager defaultManager] fileExistsAtPath:lurl]);
	}
	else if ([menuItem action] == @selector(duplicateTitleToBooktitle:)) {
		// need to set the title, as the document can change it in the main menu
		[menuItem setTitle: NSLocalizedString(@"Duplicate Title to Booktitle", @"Duplicate Title to Booktitle")];
		return (![NSString isEmptyString:[theBib valueOfField:BDSKTitleString]]);
	}
	else if ([menuItem action] == @selector(viewLocal:) ||
			 [menuItem action] == @selector(revealLocal:)) {
		NSString *field = (NSString *)[menuItem representedObject];
		NSString *path = [theBib localFilePathForField:field];
		return (path && [[NSFileManager defaultManager] fileExistsAtPath:path]);
	}
	else if ([menuItem action] == @selector(toggleSnoopDrawer:)) {
		NSView *requiredSnoopContainerView = (NSView *)[menuItem representedObject];
		BOOL isCloseItem = [documentSnoopDrawer contentView] == requiredSnoopContainerView &&
							( [documentSnoopDrawer state] == NSDrawerOpenState ||
							  [documentSnoopDrawer state] == NSDrawerOpeningState);
		if (isCloseItem) {
			[menuItem setTitle:NSLocalizedString(@"Close Drawer", @"Close drawer")];
		} else if (requiredSnoopContainerView == pdfSnoopContainerView){
			[menuItem setTitle:NSLocalizedString(@"View File in Drawer", @"View file in drawer")];
		} else if (requiredSnoopContainerView == textSnoopContainerView) {
			[menuItem setTitle:NSLocalizedString(@"View File as Text in Drawer", @"View file as text in drawer")];
		} else if (requiredSnoopContainerView == webSnoopContainerView) {
			[menuItem setTitle:NSLocalizedString(@"View Remote URL in Drawer", @"View remote URL in drawer")];
		}
		if (isCloseItem) {
			// always enable the close item
			return YES;
		} else if (requiredSnoopContainerView == webSnoopContainerView) {
			return ([theBib remoteURL] != nil);
		} else {
			NSString *lurl = [theBib localURLPath];
			return (lurl && [[NSFileManager defaultManager] fileExistsAtPath:lurl]);
		}
	}
	else if ([menuItem action] == @selector(viewRemote:)) {
		NSString *field = (NSString *)[menuItem representedObject];
		return ([theBib remoteURLForField:field] != nil);
	}
	else if ([menuItem action] == @selector(saveFileAsLocalUrl:)) {
		return ![[[remoteSnoopWebView mainFrame] dataSource] isLoading];
	}
	else if ([menuItem action] == @selector(downloadLinkedFileAsLocalUrl:)) {
		return NO;
	}
    else if ([menuItem action] == @selector(editSelectedFieldAsRawBibTeX:)) {
        return ([bibFields selectedCell] != nil && [bibFields currentEditor] != nil &&
				![[macroTextFieldWC window] isVisible]);
    }
    else if ([menuItem action] == @selector(toggleStatusBar:)) {
		if (showStatus) {
			[menuItem setTitle:NSLocalizedString(@"Hide Status Bar", @"Hide Status Bar")];
		} else {
			[menuItem setTitle:NSLocalizedString(@"Show Status Bar", @"Show Status Bar")];
		}
		return YES;
    }
	return YES;
}

- (IBAction)viewRemote:(id)sender{
    NSWorkspace *sw = [NSWorkspace sharedWorkspace];
	NSString *field = [sender representedObject];
    NSURL *url = [theBib remoteURLForField:field];
    if(url == nil){
        NSString *rurl = [theBib valueOfField:field];
        
        if([rurl isEqualToString:@""])
            return;
    
        if([rurl rangeOfString:@"://"].location == NSNotFound)
            rurl = [@"http://" stringByAppendingString:rurl];

        url = [NSURL URLWithString:rurl];
    }
    
    if(url != nil)
        [sw openURL:url];
    else
        NSBeginAlertSheet(NSLocalizedString(@"Error!", @"Error!"),
                          nil, nil, nil, [self window], nil, nil, nil, nil,
                          NSLocalizedString(@"Mac OS X does not recognize this as a valid URL.  Please check the URL field and try again.",
                                            @"Unrecognized URL, edit it and try again.") );
    
}

#pragma mark Cite Key handling methods

- (IBAction)showCiteKeyWarning:(id)sender{
	int rv;
	rv = NSRunCriticalAlertPanel(NSLocalizedString(@"",@""), 
								 NSLocalizedString(@"The citation key you entered is either already used in this document or is empty. Please provide a unique one.",@""),
								  NSLocalizedString(@"OK",@"OK"), nil, nil, nil);
}

- (IBAction)citeKeyDidChange:(id)sender{
    NSString *proposedCiteKey = [sender stringValue];
	NSString *prevCiteKey = [theBib citeKey];
	
   	if(![proposedCiteKey isEqualToString:prevCiteKey]){
		// if proposedCiteKey is empty or invalid (bad chars only)
		//  this call will set & sanitize citeKey (and invalidate our display)
		[theBib setCiteKey:proposedCiteKey];
		NSString *newKey = [theBib citeKey];
		
		[sender setStringValue:newKey];
		
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Change Cite Key",@"")];
		
		// autofile paper if we have enough information
		if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey] &&
			 [theBib needsToBeFiled] && [theBib canSetLocalUrl] ) {
			[[BibFiler sharedFiler] filePapers:[NSArray arrayWithObject:theBib] fromDocument:[theBib document] ask:NO];
			[theBib setNeedsToBeFiled:NO]; // unset the flag even when we fail, to avoid retrying at every edit
			[self setStatus:NSLocalizedString(@"Autofiled linked file.",@"Autofiled linked file.")];
		}

		// still need to check duplicates ourselves:
		if(![self citeKeyIsValid:newKey]){
			[self setCiteKeyDuplicateWarning:YES];
		}else{
			[self setCiteKeyDuplicateWarning:NO];
		}
		
		BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
		if (scriptHook) {
			[scriptHook setField:BDSKCiteKeyString];
			[scriptHook setOldValues:[NSArray arrayWithObject:prevCiteKey]];
			[scriptHook setNewValues:[NSArray arrayWithObject:newKey]];
			[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
		}
		
	}
}

- (void)setCiteKeyDuplicateWarning:(BOOL)set{
	if(set){
		[citeKeyWarningButton setImage:[NSImage cautionIconImage]];
		[citeKeyWarningButton setToolTip:NSLocalizedString(@"This cite-key is a duplicate",@"")];
	}else{
		[citeKeyWarningButton setImage:nil];
		[citeKeyWarningButton setToolTip:NSLocalizedString(@"",@"")]; // @@ this should be nil?
	}
	[citeKeyWarningButton setEnabled:set];
	[citeKeyField setTextColor:(set ? [NSColor redColor] : [NSColor blackColor])];
}

// @@ should also check validity using citekeyformatter
- (BOOL)citeKeyIsValid:(NSString *)proposedCiteKey{
	
    return !([(BibDocument *)theDocument citeKeyIsUsed:proposedCiteKey byItemOtherThan:theBib] ||
			 [proposedCiteKey isEqualToString:@""]);
}

- (IBAction)generateCiteKey:(id)sender{
	[self finalizeChangesPreservingSelection:YES];
	
	BDSKScriptHook *scriptHook = nil;
	NSString *oldKey = [theBib citeKey];
	NSString *newKey = [theBib suggestedCiteKey];
	
	scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKWillGenerateCiteKeyScriptHookName];
	if (scriptHook) {
		[scriptHook setField:BDSKCiteKeyString];
		[scriptHook setOldValues:[NSArray arrayWithObject:oldKey]];
		[scriptHook setNewValues:[NSArray arrayWithObject:newKey]];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
	}
	
	// get them again, as the script hook might have changed some values
	oldKey = [theBib citeKey];
	newKey = [theBib suggestedCiteKey];
	[theBib setCiteKey:newKey];
	
	scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKDidGenerateCiteKeyScriptHookName];
	if (scriptHook) {
		[scriptHook setField:BDSKCiteKeyString];
		[scriptHook setOldValues:[NSArray arrayWithObject:oldKey]];
		[scriptHook setNewValues:[NSArray arrayWithObject:newKey]];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
	}
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Generate Cite Key",@"")];
	[tabView selectFirstTabViewItem:self];
}

- (IBAction)generateLocalUrl:(id)sender{
	[self finalizeChangesPreservingSelection:YES];
	
	if (![theBib canSetLocalUrl]){
		NSString *message = NSLocalizedString(@"Not all fields needed for generating the file location are set.  Do you want me to file the paper now using the available fields, or cancel autofile for this paper?",@"");
		NSString *otherButton = nil;
		if([[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey]){
			message = NSLocalizedString(@"Not all fields needed for generating the file location are set. Do you want me to file the paper now using the available fields, cancel autofile for this paper, or wait until the necessary fields are set?",@""),
			otherButton = NSLocalizedString(@"Wait",@"Wait");
		}
		int rv = NSRunAlertPanel(NSLocalizedString(@"Warning",@"Warning"),
								 message, 
								 NSLocalizedString(@"File Now",@"File without waiting"),
								 NSLocalizedString(@"Cancel",@"Cancel"),
								 otherButton);
		if (rv == NSAlertAlternateReturn){
			return;
		}else if(rv == NSAlertOtherReturn){
			[theBib setNeedsToBeFiled:YES];
			return;
		}
	}
	
	[[BibFiler sharedFiler] filePapers:[NSArray arrayWithObject:theBib] fromDocument:[theBib document] ask:NO];
	
	[tabView selectFirstTabViewItem:self];
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Move File",@"")];
}

- (IBAction)duplicateTitleToBooktitle:(id)sender{
	[self finalizeChangesPreservingSelection:YES];
	
	[theBib duplicateTitleToBooktitleOverwriting:YES];
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Duplicate Title",@"")];
}

- (IBAction)bibTypeDidChange:(id)sender{
    if (![[self window] makeFirstResponder:[self window]]){
        [[self window] endEditingFor:nil];
    }
    [self setCurrentType:[bibTypeButton titleOfSelectedItem]];
    if(![[theBib type] isEqualToString:currentType]){
        [theBib setType:currentType];
        [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:currentType
                                                           forKey:BDSKPubTypeStringKey];
		
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Change Type",@"")];
    }
}

- (void)updateTypePopup{ // used to update UI after dragging into the editor
    [bibTypeButton selectItemWithTitle:[theBib type]];
}

- (void)setCurrentType:(NSString *)type{
    [currentType release];
    currentType = [type retain];
}

- (IBAction)changeRating:(id)sender{
	BDSKRatingButtonCell *cell = [sender selectedCell];
	NSString *field = [cell title];
	int oldRating = [theBib ratingValueOfField:field];
	int newRating = [cell rating];
		
	if(newRating != oldRating) {
		[theBib setRatingField:field toValue:newRating];
		
		BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
		if (scriptHook) {
			[scriptHook setField:field];
			[scriptHook setOldValues:[NSArray arrayWithObject:[NSString stringWithFormat:@"%i", oldRating]]];
			[scriptHook setNewValues:[NSArray arrayWithObject:[NSString stringWithFormat:@"%i", newRating]]];
			[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
		}
		
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Change Rating",@"")];
	}
}

- (IBAction)changeFlag:(id)sender{
	NSButtonCell *cell = [sender selectedCell];
	NSString *field = [cell title];
	BOOL oldFlag = [theBib boolValueOfField:field];
	BOOL newFlag = [cell state] == NSOnState ? YES : NO;
		
	if(newFlag != oldFlag) {
		[theBib setBooleanField:field toValue:newFlag];
		
		BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
		if (scriptHook) {
			[scriptHook setField:field];
			[scriptHook setOldValues:[NSArray arrayWithObject:[NSString stringWithBool:oldFlag]]];
			[scriptHook setNewValues:[NSArray arrayWithObject:[NSString stringWithBool:newFlag]]];
			[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
		}
		
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Change Flag",@"")];
	}
}

- (void)fixURLs{
    NSString *lurl = [theBib localURLPath];
    NSString *rurl = [theBib valueOfField:BDSKUrlString];
    NSImage *icon;
    BOOL drawerWasOpen = ([documentSnoopDrawer state] == NSDrawerOpenState ||
						  [documentSnoopDrawer state] == NSDrawerOpeningState);
	BOOL drawerShouldReopen = NO;
	
	// we need to reopen with the correct content
    if(drawerWasOpen) [documentSnoopDrawer close];
    
    if (lurl && [[NSFileManager defaultManager] fileExistsAtPath:lurl]){
		icon = [[NSWorkspace sharedWorkspace] iconForFile:lurl];
		[viewLocalButton setIconImage:icon];      
		[viewLocalButton setIconActionEnabled:YES];
		[viewLocalToolbarItem setToolTip:NSLocalizedString(@"View File",@"View file")];
		[[self window] setRepresentedFilename:lurl];
		if([documentSnoopDrawer contentView] != webSnoopContainerView)
			drawerShouldReopen = drawerWasOpen;
    }else{
        [viewLocalButton setIconImage:[NSImage imageNamed:@"QuestionMarkFile"]];
		[viewLocalButton setIconActionEnabled:NO];
        [viewLocalToolbarItem setToolTip:NSLocalizedString(@"Choose a file to link with in the Local-Url Field", @"bad/empty local url field")];
        [[self window] setRepresentedFilename:@""];
    }

    NSURL *remoteURL = [theBib remoteURL];
    if(remoteURL != nil){
        icon = [NSImage imageForURL:remoteURL];
		[viewRemoteButton setIconImage:icon];
        [viewRemoteButton setIconActionEnabled:YES];
        [viewRemoteToolbarItem setToolTip:rurl];
		if([documentSnoopDrawer contentView] == webSnoopContainerView)
			drawerShouldReopen = drawerWasOpen;
    }else{
        [viewRemoteButton setIconImage:[NSImage imageNamed:@"WeblocFile_Disabled"]];
		[viewRemoteButton setIconActionEnabled:NO];
        [viewRemoteToolbarItem setToolTip:NSLocalizedString(@"Choose a URL to link with in the Url Field", @"bad/empty url field")];
    }
	
    drawerState = BDSKDrawerUnknownState; // this makes sure the button will be updated
    if (drawerShouldReopen){
		// this takes care of updating the button and the drawer content
		[documentSnoopDrawer open];
	}else{
		[self updateDocumentSnoopButton];
	}
}

#pragma mark choose local-url or url support

- (IBAction)chooseLocalURL:(id)sender{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setResolvesAliases:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel setPrompt:NSLocalizedString(@"Choose", @"Choose file")];

    [oPanel beginSheetForDirectory:nil 
                              file:nil 
                    modalForWindow:[self window] 
                     modalDelegate:self 
                    didEndSelector:@selector(chooseLocalURLPanelDidEnd:returnCode:contextInfo:) 
                       contextInfo:nil];
  
}

- (void)chooseLocalURLPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{

    if(returnCode == NSOKButton){
        NSString *fileURLString = [[NSURL fileURLWithPath:[[sheet filenames] objectAtIndex:0]] absoluteString];
        
		[theBib setField:BDSKLocalUrlString toValue:fileURLString];
		[theBib autoFilePaper];
		
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
    }        
}

- (void)setLocalURLPathFromMenuItem:(NSMenuItem *)sender{
	NSString *path = [sender representedObject];
	
	[theBib setField:BDSKLocalUrlString toValue:[[NSURL fileURLWithPath:path] absoluteString]];
	[theBib autoFilePaper];
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
}

- (void)setRemoteURLFromMenuItem:(NSMenuItem *)sender{
	[theBib setField:BDSKUrlString toValue:[sender representedObject]];
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
}

// ----------------------------------------------------------------------------------------
#pragma mark add-Field-Sheet Support
// Add field sheet support
// ----------------------------------------------------------------------------------------

// raises the add field sheet
- (IBAction)raiseAddField:(id)sender{
    [newFieldName setStringValue:@""];
    [NSApp beginSheet:newFieldWindow
       modalForWindow:[self window]
        modalDelegate:self
       didEndSelector:@selector(addFieldSheetDidEnd:returnCode:contextInfo:)
          contextInfo:nil];
}
//dismisses it
- (IBAction)dismissAddField:(id)sender{
    [newFieldWindow orderOut:sender];
    [NSApp endSheet:newFieldWindow returnCode:[sender tag]];
}

// tag, and hence return code is 0 for OK and 1 for cancel.
// called upon dismissal
- (void)addFieldSheetDidEnd:(NSWindow *)sheet
                 returnCode:(int) returnCode
                contextInfo:(void *)contextInfo{
    if(returnCode == NSOKButton){
        if(![[[theBib pubFields] allKeys] containsObject:[newFieldName stringValue]]){
		NSString *name = [[newFieldName stringValue] capitalizedString]; // add it as a capitalized string to avoid duplicates

		[theBib addField:name];
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Add Field",@"")];
		[self setupForm];
		[self makeKeyField:name];
        }
    }
    // else, nothing.
}

- (void)makeKeyField:(NSString *)fieldName{
    int sel = -1;
    int i = 0;

    for (i = 0; i < [bibFields numberOfRows]; i++) {
        if ([[[bibFields cellAtIndex:i] title] isEqualToString:fieldName]) {
            sel = i;
        }
    }
    if(sel > -1) [bibFields selectTextAtIndex:sel];
}

// ----------------------------------------------------------------------------------------
#pragma mark ||  delete-Field-Sheet Support
// ----------------------------------------------------------------------------------------

// raises the del field sheet
- (IBAction)raiseDelField:(id)sender{
    // populate the popupbutton
	BibTypeManager *typeMan = [BibTypeManager sharedManager];
	NSMutableArray *removableFields = [[[theBib pubFields] allKeys] mutableCopy];
	[removableFields removeObjectsInArray:[NSArray arrayWithObjects:BDSKLocalUrlString, BDSKUrlString, BDSKAnnoteString, BDSKAbstractString, BDSKRssDescriptionString, nil]];
	[removableFields removeObjectsInArray:[typeMan requiredFieldsForType:currentType]];
	[removableFields removeObjectsInArray:[typeMan optionalFieldsForType:currentType]];
	[removableFields removeObjectsInArray:[typeMan userDefaultFieldsForType:currentType]];
	if ([removableFields count]) {
		[removableFields sortUsingSelector:@selector(caseInsensitiveCompare:)];
		[delFieldPopUp setEnabled:YES];
	} else {
		[removableFields addObject:NSLocalizedString(@"No fields to remove",@"")];
		[delFieldPopUp setEnabled:NO];
	}
    
	[delFieldPopUp removeAllItems];
    [delFieldPopUp addItemsWithTitles:removableFields];
    
    NSString *selectedCellTitle = [[bibFields selectedCell] title];
    if([[delFieldPopUp itemTitles] containsObject:selectedCellTitle]){
        [delFieldPopUp selectItemWithTitle:selectedCellTitle];
        // if we don't deselect this cell, we can't remove it from the form
        [self finalizeChangesPreservingSelection:NO];
    } else {
        [delFieldPopUp selectItemAtIndex:0];
    }
	
	[removableFields release];
	
    [NSApp beginSheet:delFieldWindow
       modalForWindow:[self window]
        modalDelegate:self
       didEndSelector:@selector(delFieldSheetDidEnd:returnCode:contextInfo:)
          contextInfo:nil];
}

//dismisses it
- (IBAction)dismissDelField:(id)sender{
    [delFieldWindow orderOut:sender];
    [NSApp endSheet:delFieldWindow returnCode:[sender tag]];
}

// tag, and hence return code is 0 for delete and 1 for cancel.
// called upon dismissal
- (void)delFieldSheetDidEnd:(NSWindow *)sheet
                 returnCode:(int) returnCode
                contextInfo:(void *)contextInfo{
    if(returnCode == NSOKButton){
        [theBib removeField:[delFieldPopUp titleOfSelectedItem]];
		[[[self window] undoManager] setActionName:NSLocalizedString(@"Remove Field",@"")];
        [self setupForm];
    }
    // else, nothing.
}

#pragma mark Text Change handling

// this is called when the cell is selected for an edit
- (BOOL)control:(NSControl *)control textShouldStartEditing:(NSText *)fieldEditor{

    if (control != bibFields) return YES;
    
    NSFormCell *selectedCell = [bibFields selectedCell];
    
    NSString *value = [theBib valueOfField:[selectedCell title]];
    
	if([value isInherited] &&
	   [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKWarnOnEditInheritedKey]){
		// OK to select, but wait deciding whether we let the user edit
		// we can't call the warning sheet here as this leads to unterminated app modal sessions
		return YES;
	}
	
    if([value isComplex]){
        return [self editSelectedFormCellAsMacro];
    }else{
        // edit it in the usual way.
        return YES;
    }
}

// this is called when the user actually starts editing
- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor{
    if (control != bibFields) return YES;
    
    NSFormCell *selectedCell = [bibFields selectedCell];
    
    NSString *value = [theBib valueOfField:[selectedCell title]];
    
	if([value isInherited] &&
	   [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKWarnOnEditInheritedKey]){
		[dontWarnOnEditInheritedCheckButton setState:NSOffState];
		[NSApp beginSheet:editInheritedWarningSheet
		   modalForWindow:[self window]
			modalDelegate:self
		   didEndSelector:NULL
			  contextInfo:nil];
		int rv = [NSApp runModalForWindow:editInheritedWarningSheet];
		[NSApp endSheet:editInheritedWarningSheet];
		[editInheritedWarningSheet orderOut:self];
		
		if (rv == NSAlertAlternateReturn) {
			return NO;
		} else if (rv == NSAlertOtherReturn) {
			[self openParentItem:self];
			return NO;
		}
	}
	
    if([value isComplex]){
		// if we were already doing this, this delegate method would not be called
        return [self editSelectedFormCellAsMacro];
    }else{
        // edit it in the usual way.
        return YES;
    }
}

- (IBAction)dismissEditInheritedSheet:(id)sender{
	[NSApp stopModalWithCode:[sender tag]];
}

- (IBAction)changeWarnOnEditInherited:(id)sender{
    [[OFPreferenceWrapper sharedPreferenceWrapper] setBool:([sender state] == NSOffState) 
													forKey:BDSKWarnOnEditInheritedKey];
}

- (IBAction)editSelectedFieldAsRawBibTeX:(id)sender{
	if([self control:bibFields textShouldBeginEditing:[bibFields currentEditor]])
		[self editSelectedFormCellAsMacro];
}

- (BOOL)editSelectedFormCellAsMacro{
	NSCell *cell = [bibFields selectedCell];
	NSString *value = [theBib valueOfField:[cell title]];
	NSDictionary *infoDict = [[NSDictionary alloc] initWithObjectsAndKeys:cell, @"cell", nil];
	
	return [macroTextFieldWC editCellOfView:bibFields
									  atRow:[bibFields selectedRow]
									 column:0
								  withValue:value
							  macroResolver:theDocument
								   delegate:self
						  shouldEndSelector:@selector(macroEditorShouldEndEditing:withValue:contextInfo:)
							 didEndSelector:@selector(macroEditorDidEndEditing:withValue:contextInfo:)
								  contextInfo:infoDict];
}

- (BOOL)macroEditorShouldEndEditing:(NSControl *)control withValue:(NSString *)value contextInfo:(void *)contextInfo{
	if (forceEndEditing || value) {
		return YES;
	} else {
		// I don't think we need to show an alert, as the error message should already be displayed
		return NO;
	}
}

- (void)macroEditorDidEndEditing:(NSControl *)control withValue:(NSString *)value contextInfo:(void *)contextInfo{
    NSDictionary *infoDict = (NSDictionary *)contextInfo;
	NSFormCell *cell = [infoDict objectForKey:@"cell"];
	NSString *fieldName = [cell title];
	NSString *prevValue = [theBib valueOfField:fieldName];
    [infoDict release];
	
	if ([prevValue isInherited] && 
		([value isEqualAsComplexString:prevValue] || [value isEqualAsComplexString:@""])) {
		[cell setObjectValue:prevValue];
    } else if(![value isEqualAsComplexString:prevValue]){
		[self recordChangingField:fieldName toValue:value];
	} else {
		[cell setObjectValue:value];
	}
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor{
	if (control == bibFields) {
		
		NSCell *cell = [bibFields cellAtIndex:[bibFields indexOfSelectedItem]];
		NSString *message = nil;
		
		if ([[cell title] isEqualToString:BDSKCrossrefString]) {
			
			if ([[theBib citeKey] caseInsensitiveCompare:[cell stringValue]] == NSOrderedSame) {
				message = NSLocalizedString(@"An item cannot cross reference to itself.", @"");
			} else {
				NSString *parentCr = [[theDocument publicationForCiteKey:[cell stringValue]] valueOfField:BDSKCrossrefString inherit:NO];
				
				if (![NSString isEmptyString:parentCr]) {
					message = NSLocalizedString(@"Cannot cross reference to an item that has the Crossref field set.", @"");
				} else if ([theDocument citeKeyIsCrossreffed:[theBib citeKey]]) {
					message = NSLocalizedString(@"Cannot set the Crossref field, as the current item is cross referenced.", @"");
				}
			}
			
			if (message) {
				NSRunAlertPanel(NSLocalizedString(@"Invalid Crossref Value", @"Invalid Crossref Value"),
								message,
								NSLocalizedString(@"OK", @"OK"), nil, nil);
				[cell setStringValue:@""];
				return NO;
			}
		}
		
		if (![[cell stringValue] isStringTeXQuotingBalancedWithBraces:YES connected:NO]) {
			NSString *cancelButton = nil;
			
			if (forceEndEditing) {
				message = NSLocalizedString(@"The value you entered contains unbalanced braces and cannot be saved.", @"");
			} else {
				message = NSLocalizedString(@"The value you entered contains unbalanced braces and cannot be saved. Do you want to keep editing?", @"");
				cancelButton = NSLocalizedString(@"Cancel", @"Cancel");
			}
			
			int rv = NSRunAlertPanel(NSLocalizedString(@"Invalid Value", @"Invalid Value"),
									 message,
									 NSLocalizedString(@"OK", @"OK"), cancelButton, nil);
			
			if (forceEndEditing || rv == NSAlertAlternateReturn) {
				[cell setStringValue:[theBib valueOfField:[cell title]]];
				return YES;
			} else {
				return NO;
			}
		}
	
	} else if (control == citeKeyField) {
		
		NSCharacterSet *invalidSet = [[BibTypeManager sharedManager] fragileCiteKeyCharacterSet];
		NSRange r = [[control stringValue] rangeOfCharacterFromSet:invalidSet];
		
		if (r.location != NSNotFound) {
			NSString *message = nil;
			NSString *cancelButton = nil;
			
			if (forceEndEditing) {
				message = NSLocalizedString(@"The cite key you entered contains characters that could be invalid in TeX.", @"");
			} else {
				message = NSLocalizedString(@"The cite key you entered contains characters that could be invalid in TeX. Do you want to continue editing with the invalid characters removed?", @"");
				cancelButton = NSLocalizedString(@"Cancel", @"Cancel");
			}
			
			int rv = NSRunAlertPanel(NSLocalizedString(@"Invalid Value", @"Invalid Value"),
									 message,
									 NSLocalizedString(@"OK", @"OK"), 
									 cancelButton, nil);
			
			if (forceEndEditing || rv == NSAlertAlternateReturn) {
				return YES;
			 } else {
				[control setStringValue:[[control stringValue] stringByReplacingCharactersInSet:invalidSet withString:@""]];
				return NO;
			}
		}
		
	}
	
	return YES;
}


- (void)controlTextDidEndEditing:(NSNotification *)aNotification{
	
	id control = [aNotification object];
	if (control != bibFields || [control indexOfSelectedItem] == -1)
		return;
	
    NSCell *sel = [control cellAtIndex: [control indexOfSelectedItem]];
    NSString *title = [sel title];
	NSString *value = [sel stringValue];
	NSString *prevValue = [theBib valueOfField:title];
	
    if(![value isEqualToString:prevValue] &&
	   !([prevValue isInherited] && [value isEqualToString:@""])){
		[self recordChangingField:title toValue:value];
    }
	// make sure we have the correct (complex) string value
	[sel setObjectValue:[theBib valueOfField:title]];
}

- (void)recordChangingField:(NSString *)fieldName toValue:(NSString *)value{

#warning copy and inherit
    NSString *oldValue = [theBib valueOfField:fieldName];
    [theBib setField:fieldName toValue:value];
	
	[[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
    
	NSMutableString *status = [NSMutableString stringWithString:@""];
	
    // autogenerate cite key if we have enough information
    if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKCiteKeyAutogenerateKey] &&
         [theBib canSetCiteKey] ) {
        [self generateCiteKey:nil];
		[status appendString:NSLocalizedString(@"Autogenerated Cite Key.",@"Autogenerated Cite Key.")];
    }
    
    // autofile paper if we have enough information
    if ( [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey] &&
         [theBib needsToBeFiled] && [theBib canSetLocalUrl] ) {
        [[BibFiler sharedFiler] filePapers:[NSArray arrayWithObject:theBib] fromDocument:[theBib document] ask:NO];
        [theBib setNeedsToBeFiled:NO]; // unset the flag even when we fail, to avoid retrying at every edit
		if (![status isEqualToString:@""]) {
			[status appendString:@" "];
		}
		[status appendString:NSLocalizedString(@"Autofiled linked file.",@"Autofiled linked file.")];
    }
    
	if (![status isEqualToString:@""]) {
		[self setStatus:status];
	}
	
	BDSKScriptHook *scriptHook = [[BDSKScriptHookManager sharedManager] makeScriptHookWithName:BDSKChangeFieldScriptHookName];
	if (scriptHook) {
		[scriptHook setField:fieldName];
		[scriptHook setOldValues:[NSArray arrayWithObject:oldValue]];
		[scriptHook setNewValues:[NSArray arrayWithObject:value]];
		[[BDSKScriptHookManager sharedManager] runScriptHook:scriptHook forPublications:[NSArray arrayWithObject:theBib]];
	}
}

- (NSString *)status {
	return [statusLine stringValue];
}

- (void)setStatus:(NSString *)status {
	[statusLine setStringValue:status];
}

- (void)bibDidChange:(NSNotification *)notification{
// unused	BibItem *notifBib = [notification object];
	NSDictionary *userInfo = [notification userInfo];
	NSString *changeType = [userInfo objectForKey:@"type"];
	BibItem *sender = (BibItem *)[notification object];
	NSString *crossref = [theBib valueOfField:BDSKCrossrefString inherit:NO];
	BOOL parentDidChange = (crossref != nil && 
							([crossref caseInsensitiveCompare:[sender citeKey]] == NSOrderedSame || 
							 [crossref caseInsensitiveCompare:[userInfo objectForKey:@"oldCiteKey"]] == NSOrderedSame));
	
    // If it is not our item or his crossref parent, we don't care, but our parent may have changed his cite key
	if (sender != theBib && !parentDidChange)
		return;

	if([changeType isEqualToString:@"Add/Del Field"]){
		[self setupForm];
		[ratingButton setRating:[theBib rating]];
		return;
	}

	NSString *changeKey = [userInfo objectForKey:@"key"];
	NSString *newValue = [userInfo objectForKey:@"value"];
	
    // Rebuild the form if the crossref changed, or our parent's cite key changed.
	if([changeKey isEqualToString:BDSKCrossrefString] || 
	   (parentDidChange && [changeKey isEqualToString:BDSKCiteKeyString])){
		[self setupForm];
		[[self window] setTitle:[theBib displayTitle]];
		[authorTableView reloadData];
		pdfSnoopViewLoaded = NO;
		textSnoopViewLoaded = NO;
		webSnoopViewLoaded = NO;
		[self fixURLs];
		return;
	}

	if([changeKey isEqualToString:BDSKTypeString]){
		[self setupForm];
		[self updateTypePopup];
		return;
	}
	
	if([[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRatingFieldsKey] containsObject:changeKey]){
		NSArray *cells = [extraBibFields cells];
		NSEnumerator *cellE = [cells objectEnumerator];
		NSButtonCell *entry = nil;
		while(entry = [cellE nextObject]){
			if([[entry title] isEqualToString:changeKey])
				break;
		}
		if(entry){
			[(BDSKRatingButtonCell *)entry setRating:[theBib ratingValueOfField:changeKey]];
			[extraBibFields setNeedsDisplay:YES];
		}
		if([changeKey isEqualToString:BDSKRatingString])
			[ratingButton setRating:[theBib rating]];
		return;
	}
	
	if([[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKBooleanFieldsKey] containsObject:changeKey]){
		NSArray *cells = [extraBibFields cells];
		NSEnumerator *cellE = [cells objectEnumerator];
		NSButtonCell *entry = nil;
		while(entry = [cellE nextObject]){
			if([[entry title] isEqualToString:changeKey])
				break;
		}
		if(entry){
			[entry setState:[theBib boolValueOfField:changeKey] ? NSOnState : NSOffState];
			[extraBibFields setNeedsDisplay:YES];
		}
		return;
	}
	
	if([changeKey isEqualToString:BDSKCiteKeyString]){
		[citeKeyField setStringValue:newValue];
		// still need to check duplicates ourselves:
		if(![self citeKeyIsValid:newValue]){
			[self setCiteKeyDuplicateWarning:YES];
		}else{
			[self setCiteKeyDuplicateWarning:NO];
		}
	}else{
		// essentially a cellWithTitle: for NSForm
		NSArray *cells = [bibFields cells];
		NSEnumerator *cellE = [cells objectEnumerator];
		NSFormCell *entry = nil;
		while(entry = [cellE nextObject]){
			if([[entry title] isEqualToString:changeKey])
				break;
		}
		if(entry){
			[entry setObjectValue:[theBib valueOfField:changeKey]];
			[bibFields setNeedsDisplay:YES];
		}
	}
	
	if([changeKey isEqualToString:BDSKLocalUrlString]){
		pdfSnoopViewLoaded = NO;
		textSnoopViewLoaded = NO;
		[self fixURLs];
	}
	else if([changeKey isEqualToString:BDSKUrlString]){
		webSnoopViewLoaded = NO;
		[self fixURLs];
	}
	else if([changeKey isEqualToString:BDSKTitleString]){
		[[self window] setTitle:[theBib displayTitle]];
	}
	else if([changeKey isEqualToString:BDSKAuthorString]){
		[authorTableView reloadData];
	}
    else if([changeKey isEqualToString:BDSKAnnoteString]){
        // make a copy of the current value, so we don't overwrite it when we set the field value to the text storage
        NSString *tmpValue = [[theBib valueOfField:BDSKAnnoteString inherit:NO] copy];
        [notesView setString:(tmpValue == nil ? @"" : tmpValue)];
        [tmpValue release];
        // set this in pubFields directly, so we don't go into an endless loop
        if(currentEditedView == notesView)
            [[theBib pubFields] setValue:[[notesView textStorage] mutableString] forKey:BDSKAnnoteString];
        [notesViewUndoManager removeAllActions];
    }
    else if([changeKey isEqualToString:BDSKAbstractString]){
        NSString *tmpValue = [[theBib valueOfField:BDSKAbstractString inherit:NO] copy];
        [abstractView setString:(tmpValue == nil ? @"" : tmpValue)];
        [tmpValue release];
        if(currentEditedView == abstractView)
            [[theBib pubFields] setValue:[[abstractView textStorage] mutableString] forKey:BDSKAbstractString];
        [abstractViewUndoManager removeAllActions];
    }
    else if([changeKey isEqualToString:BDSKRssDescriptionString]){
        NSString *tmpValue = [[theBib valueOfField:BDSKRssDescriptionString inherit:NO] copy];
        [rssDescriptionView setString:(tmpValue == nil ? @"" : tmpValue)];
        [tmpValue release];
        if(currentEditedView == abstractView)
            [[theBib pubFields] setValue:[[rssDescriptionView textStorage] mutableString] forKey:BDSKRssDescriptionString];
        [rssDescriptionViewUndoManager removeAllActions];
    }
            
}
	
- (void)bibWasAddedOrRemoved:(NSNotification *)notification{
	NSDictionary *userInfo = [notification userInfo];
	BibItem *pub = (BibItem *)[userInfo objectForKey:@"pub"];
	NSString *crossref = [theBib valueOfField:BDSKCrossrefString inherit:NO];
	
	if ([crossref caseInsensitiveCompare:[pub citeKey]] == NSOrderedSame) {
		[self setupForm];
	}
}
 
- (void)typeInfoDidChange:(NSNotification *)aNotification{
	[self setupTypePopUp];
	[theBib makeType]; // make sure this is done now, and not later
	[self setupForm];
}
 
- (void)customFieldsDidChange:(NSNotification *)aNotification{
	[theBib makeType]; // make sure this is done now, and not later
	[self setupForm];
}

- (void)macrosDidChange:(NSNotification *)notification{
	id sender = [notification object];
	if([sender isKindOfClass:[BibDocument class]] && sender != theDocument)
		return; // only macro changes for our own document or the global macros
	
	NSArray *cells = [bibFields cells];
	NSEnumerator *cellE = [cells objectEnumerator];
	NSFormCell *entry = nil;
	NSString *value;
	
	while(entry = [cellE nextObject]){
		value = [theBib valueOfField:[entry title]];
		if([value isComplex]){
            // ARM: the cell must check pointer equality in the setter, or something; since it's the same object, setting the value again is a noop unless we set to nil first.  Fixes bug #1284205.
            [entry setObjectValue:nil];
			[entry setObjectValue:value];
        }
	}    
}

#pragma mark annote/abstract/rss

- (void)textDidBeginEditing:(NSNotification *)aNotification{
    // Add the mutableString of the text storage to the item's pubFields, so changes
    // are automatically tracked.  We still have to update the UI manually.
    // The contents of the text views are initialized with the current contents of the BibItem in windowWillLoad:
	currentEditedView = [aNotification object];
    
    // we need to preserve selection manually; otherwise you end up editing at the end of the string after the call to setField: below
    NSRange selRange = [currentEditedView selectedRange];
    if(currentEditedView == notesView){
        [theBib setField:BDSKAnnoteString toValue:[[notesView textStorage] mutableString]];
        [[theBib undoManager] setActionName:NSLocalizedString(@"Edit Annotation",@"")];
    } else if(currentEditedView == abstractView){
        [theBib setField:BDSKAbstractString toValue:[[abstractView textStorage] mutableString]];
        [[theBib undoManager] setActionName:NSLocalizedString(@"Edit Abstract",@"")];
    }else if(currentEditedView == rssDescriptionView){
        [theBib setField:BDSKRssDescriptionString toValue:[[rssDescriptionView textStorage] mutableString]];
        [[theBib undoManager] setActionName:NSLocalizedString(@"Edit RSS Description",@"")];
    }
    if(selRange.location != NSNotFound && selRange.location < [[currentEditedView string] length])
        [currentEditedView setSelectedRange:selRange];
}

// Clear all the undo actions when changing tab items, just in case; otherwise we
// crash if you edit in one view, switch tabs, switch back to the previous view and hit undo.
// We can't use textDidEndEditing, since just switching tabs doesn't change first responder.
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem{
    [notesViewUndoManager removeAllActions];
    [abstractViewUndoManager removeAllActions];
    [rssDescriptionViewUndoManager removeAllActions];
}

// sent by the notesView and the abstractView
- (void)textDidEndEditing:(NSNotification *)aNotification{
	currentEditedView = nil;
}

// sent by the notesView and the abstractView; this ensures that the annote/abstract preview gets updated
- (void)textDidChange:(NSNotification *)aNotification{
    NSNotification *notif = [NSNotification notificationWithName:BDSKPreviewDisplayChangedNotification object:nil];
    [[NSNotificationQueue defaultQueue] enqueueNotification:notif 
                                               postingStyle:NSPostWhenIdle 
                                               coalesceMask:NSNotificationCoalescingOnName 
                                                   forModes:nil];
}

#pragma mark document interaction
	
- (void)bibWillBeRemoved:(NSNotification *)notification{
	// NSDictionary *userInfo = [notification userInfo];
	
	[self close];
}
	
- (void)docWindowWillClose:(NSNotification *)notification{
	// NSDictionary *userInfo = [notification userInfo];
	
	[[self window] close];
}

- (IBAction)showMacrosWindow:(id)sender{
    [theDocument showMacrosWindow:self];
}

// Note:  implementing setDocument or -document can have strange side effects with our document window controller array at present.
// every window controller subclass managed by the document needs to have this implemented in order for automatic closing/releasing,
// but we're doing it manually at present.
- (void)setDocument:(NSDocument *)d{
}

- (void)saveDocument:(id)sender{
    [theDocument saveDocument:sender];
}

- (void)saveDocumentAs:(id)sender{
    [theDocument saveDocumentAs:sender];
}

// these methods are for crossref interaction with the form
- (void)openParentItem:(id)sender{
    BibItem *parent = [theBib crossrefParent];
    if(parent)
        [theDocument editPub:parent];
}

- (void)arrowClickedInFormCell:(id)cell{
	[self openParentItem:nil];
}

- (void)iconClickedInFormCell:(id)cell{
    [[NSWorkspace sharedWorkspace] openURL:[theBib remoteURLForField:[cell title]]];
}

- (BOOL)formCellHasArrowButton:(id)cell{
	return ([[theBib valueOfField:[cell title]] isInherited] || 
			([[cell title] isEqualToString:BDSKCrossrefString] && [theBib crossrefParent]));
}

- (BOOL)formCellHasFileIcon:(id)cell{
    NSString *title = [cell title];
    if ([[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey] containsObject:title] ||
        [[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey] containsObject:title]) {
		// if we inherit a field, we don't show the file icon but the arrow button
		NSString *url = [theBib valueOfField:title inherit:NO];
		// we could also check for validity here
		if (![NSString isEmptyString:url])
			return YES;
	}
	return NO;
}

- (NSURL *)draggedURLForFormCell:(id)cell{
    NSString *title = [cell title];
    if ([[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey] containsObject:title])
		return [NSURL fileURLWithPath:[theBib localFilePathForField:title]];
	if ([[[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey] containsObject:title])
		return [theBib remoteURLForField:title];
	return nil;
}

- (NSString *)draggedFileNameForFormCell:(id)cell{
    return [theBib displayTitle];
}

#pragma mark dragging delegate methods

- (BOOL)canReceiveDrag:(id <NSDraggingInfo>)sender forField:(NSString *)field{
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *dragType;
	NSArray *types = [pboard types];
	NSArray *localFileFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey];
	NSArray *remoteURLFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey];
	
	// we put webloc types first, as we always want to accept them for remote URLs, but never for local files
	dragType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKWeblocFilePboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
	
	if ([localFileFields containsObject:field]) {
		if ([dragType isEqualToString:NSFilenamesPboardType]) {
			return YES;
		} else if ([dragType isEqualToString:NSURLPboardType]) {
			// a file can put NSURLPboardType on the pasteboard
			// we really only want to receive local files for file URLs
			NSURL *fileURL = [NSURL URLFromPasteboard:pboard];
			if(fileURL && [fileURL isFileURL])
				return YES;
		}
		return NO;
	} else if ([remoteURLFields containsObject:field]){
		if ([dragType isEqualToString:BDSKWeblocFilePboardType]) {
			return YES;
		} else if ([dragType isEqualToString:NSURLPboardType]) {
			// a file puts NSFilenamesPboardType and NSURLPboardType on the pasteboard
			// we really only want to receive webloc files for remote URLs, not file URLs
			NSURL *remoteURL = [NSURL URLFromPasteboard:pboard];
			if(remoteURL && ![remoteURL isFileURL])
				return YES;
		}
        return NO;
	} else {
		// we don't support dropping on a textual field. This is handled by the window
	}
	return NO;
}

- (BOOL)receiveDrag:(id <NSDraggingInfo>)sender forField:(NSString *)field{
	NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *dragType;
	NSArray *localFileFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKLocalFileFieldsKey];
	NSArray *remoteURLFields = [[OFPreferenceWrapper sharedPreferenceWrapper] stringArrayForKey:BDSKRemoteURLFieldsKey];
    	    
	// we put webloc types first, as we always want to accept them for remote URLs, but never for local files
	dragType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKWeblocFilePboardType, NSFilenamesPboardType, NSURLPboardType, nil]];
    
	if ([localFileFields containsObject:field]) {
		// a file, we link the local file field
		NSURL *fileURL = nil;
		
		if ([dragType isEqualToString:NSFilenamesPboardType]) {
			NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
			if ([fileNames count] == 0)
				return NO;
			fileURL = [NSURL fileURLWithPath:[[fileNames objectAtIndex:0] stringByExpandingTildeInPath]];
		} else if ([dragType isEqualToString:NSURLPboardType]) {
			fileURL = [NSURL URLFromPasteboard:pboard];
			if (![fileURL isFileURL])
				return NO;
		} else {
			return NO;
		}
		
		if (fileURL == nil || 
            [fileURL isEqual:[theBib URLForField:field]])
			return NO;
		        
		[theBib setField:field toValue:[fileURL absoluteString]];
		if ([field isEqualToString:BDSKLocalUrlString])
			[theBib autoFilePaper];
		[[theBib undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
        
		return YES;
		
	} else if ([remoteURLFields containsObject:field]){
		// Check first for webloc files because we want to treat them differently    
		if ([dragType isEqualToString:BDSKWeblocFilePboardType]) {
			
			NSString *remoteURLString = [pboard stringForType:BDSKWeblocFilePboardType];
			
			if (remoteURLString == nil ||
				[[NSURL URLWithString:remoteURLString] isEqual:[theBib remoteURLForField:field]])
				return NO;
			
			[theBib setField:field toValue:remoteURLString];
			[[theBib undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];

			return YES;
			
		} else if ([dragType isEqualToString:NSURLPboardType]) {
			// a URL but not a file, we link the remote Url field
			NSURL *remoteURL = [NSURL URLFromPasteboard:pboard];
			
			if (remoteURL == nil || [remoteURL isFileURL] ||
				[remoteURL isEqual:[theBib remoteURLForField:field]])
				return NO;
			
			[theBib setField:field toValue:[remoteURL absoluteString]];
			[[theBib undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
			
			return YES;
			
		}
		
	} else {
		// we don't at the moment support dropping on a textual field
	}
	return NO;
}

- (BOOL)canReceiveDrag:(id <NSDraggingInfo>)sender forView:(id)view{
	NSString *field = nil;
	if (view == viewLocalButton)
		field = BDSKLocalUrlString;
	else if (view == viewRemoteButton)
		field = BDSKUrlString;
	return [self canReceiveDrag:sender forField:field];
}

- (BOOL)receiveDrag:(id <NSDraggingInfo>)sender forView:(id)view{
	NSString *field = nil;
	if (view == viewLocalButton)
		field = BDSKLocalUrlString;
	else if (view == viewRemoteButton)
		field = BDSKUrlString;
	return [self receiveDrag:sender forField:field];
}

- (BOOL)canReceiveDrag:(id <NSDraggingInfo>)sender forFormCell:(id)cell{
	NSString *field = [cell title];
	return [self canReceiveDrag:sender forField:field];
}

- (BOOL)receiveDrag:(id <NSDraggingInfo>)sender forFormCell:(id)cell{
	NSString *field = [cell title];
	return [self receiveDrag:sender forField:field];
}

#pragma mark snoop drawer stuff

// update the arrow image direction when the window changes
- (void)windowDidMove:(NSNotification *)aNotification{
    [self updateDocumentSnoopButton];
}

- (void)windowDidResize:(NSNotification *)notification{
    [self updateDocumentSnoopButton];
}

- (void)updateDocumentSnoopButton
{
	NSView *requiredSnoopContainerView = (NSView *)[[documentSnoopButton selectedItem] representedObject];
    NSString *lurl = [theBib localURLPath];
    NSURL *rurl = [theBib remoteURL];
	int state = 0;
	
	if ([documentSnoopDrawer contentView] == requiredSnoopContainerView &&
		( [documentSnoopDrawer state] == NSDrawerOpenState ||
		  [documentSnoopDrawer state] == NSDrawerOpeningState) )
		state |= BDSKDrawerStateOpenMask;
	if ([documentSnoopDrawer edge] == NSMaxXEdge)
		state |= BDSKDrawerStateRightMask;
	if (requiredSnoopContainerView == webSnoopContainerView)
		state |= BDSKDrawerStateWebMask;
	if (requiredSnoopContainerView == textSnoopContainerView)
		state |= BDSKDrawerStateTextMask;
	
	if (state == drawerState)
		return; // we don't need to change the button
	
	drawerState = state;
	
	if ( (state & BDSKDrawerStateOpenMask) || 
		 ((state & BDSKDrawerStateWebMask) && rurl) ||
		 (!(state & BDSKDrawerStateWebMask) && lurl && [[NSFileManager defaultManager] fileExistsAtPath:lurl]) ) {
		
		NSImage *drawerImage = [NSImage imageNamed:@"drawerRight"];
		NSImage *arrowImage = [NSImage imageNamed:@"drawerArrow"];
		NSImage *badgeImage = nil;
		
		if (state & BDSKDrawerStateWebMask)
			badgeImage = [NSImage smallGenericInternetLocationImage];
		else if (state & BDSKDrawerStateTextMask)
			badgeImage = [NSImage smallImageForFileType:@"txt"];
		else
			badgeImage = [NSImage smallImageForFileType:@"pdf"];
		
		NSRect iconRect = NSMakeRect(0, 0, 32, 32);
		NSSize arrowSize = [arrowImage size];
		NSRect arrowRect = {NSZeroPoint, arrowSize};
		NSRect arrowDrawRect = NSMakeRect(29 - arrowSize.width, ceil((32-arrowSize.height)/2), arrowSize.width, arrowSize.height);
		NSRect badgeRect = {NSZeroPoint, [badgeImage size]};
		NSRect badgeDrawRect = NSMakeRect(15, 0, 16, 16);
		NSImage *image = [[[NSImage alloc] initWithSize:iconRect.size] autorelease];
		
		if (state & BDSKDrawerStateRightMask) {
			if (state & BDSKDrawerStateOpenMask)
				arrowImage = [arrowImage imageFlippedHorizontally];
		} else {
			arrowDrawRect.origin.x = 3;
			badgeDrawRect.origin.x = 1;
			drawerImage = [drawerImage imageFlippedHorizontally];
			if (!(state & BDSKDrawerStateOpenMask))
				arrowImage = [arrowImage imageFlippedHorizontally];
		}
		
		[image lockFocus];
		[drawerImage drawInRect:iconRect fromRect:iconRect  operation:NSCompositeSourceOver  fraction: 1.0];
		[badgeImage drawInRect:badgeDrawRect fromRect:badgeRect  operation:NSCompositeSourceOver  fraction: 1.0];
		[arrowImage drawInRect:arrowDrawRect fromRect:arrowRect  operation:NSCompositeSourceOver  fraction: 1.0];
		[image unlockFocus];
		
        [documentSnoopButton fadeIconImageToImage:image];
		
		if (state & BDSKDrawerStateOpenMask) {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"Close Drawer", @"Close drawer")];
		} else if (state & BDSKDrawerStateWebMask) {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"View Remote URL in Drawer", @"View remote URL in drawer")];
		} else if (state & BDSKDrawerStateTextMask) {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"View File as Text in Drawer", @"View file as text in drawer")];
		} else {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"View File in Drawer", @"View file in drawer")];
		}
		
		[documentSnoopButton setIconActionEnabled:YES];
	}
	else {
        [documentSnoopButton setIconImage:[NSImage imageNamed:@"drawerDisabled"]];
		
		if (state & BDSKDrawerStateOpenMask) {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"Close Drawer", @"Close drawer")];
		} else {
			[documentSnoopToolbarItem setToolTip:NSLocalizedString(@"Choose Content to View in Drawer", @"Choose content to view in drawer")];
		}
		
		[documentSnoopButton setIconActionEnabled:NO];
	}
}

- (void)updateSnoopDrawerContent{
	if ([documentSnoopDrawer contentView] == pdfSnoopContainerView) {

		NSString *lurl = [theBib localURLPath];
		if (!lurl || pdfSnoopViewLoaded) return;

        if(floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_3){
            [documentSnoopImageView loadData:[NSData dataWithContentsOfFile:lurl]];
            [documentSnoopScrollView setDocumentViewAlignment:NSImageAlignTopLeft];
        } else {
            id pdfDocument = [[NSClassFromString(@"PDFDocument") alloc] initWithURL:[NSURL fileURLWithPath:lurl]];
            id pdfView = [[pdfSnoopContainerView subviews] objectAtIndex:0];
            [(BDSKZoomablePDFView *)pdfView setDocument:pdfDocument];
            [pdfDocument release];
        }
        pdfSnoopViewLoaded = YES;
	}
	else if ([documentSnoopDrawer contentView] == textSnoopContainerView) {
		NSString *lurl = [theBib localURLPath];
		if (!lurl) return;
        if (!textSnoopViewLoaded) {
			NSString *cmdString = [NSString stringWithFormat:@"%@/pdftotext -f 1 -l 1 \"%@\" -",[[NSBundle mainBundle] resourcePath], lurl, nil];
            NSString *textSnoopString = [[BDSKShellTask shellTask] runShellCommand:cmdString withInputString:nil];
			[documentSnoopTextView setString:textSnoopString];
			textSnoopViewLoaded = YES;
        }
	}
	else if ([documentSnoopDrawer contentView] == webSnoopContainerView) {
		if (!webSnoopViewLoaded) {
			NSURL *rurl = [theBib remoteURL];
			if (rurl == nil) return;
			[[remoteSnoopWebView mainFrame] loadRequest:[NSURLRequest requestWithURL:rurl]];
			webSnoopViewLoaded = YES;
		}
	}
}

- (void)toggleSnoopDrawer:(id)sender{
	NSView *requiredSnoopContainerView = (NSView *)[sender representedObject];
	
	// we force a reload, as the user might have browsed
	if (requiredSnoopContainerView == webSnoopContainerView) 
		webSnoopViewLoaded = NO;
	
	if ([documentSnoopDrawer contentView] == requiredSnoopContainerView) {
		[documentSnoopDrawer toggle:sender];
	} else {
        [documentSnoopDrawer setContentView:requiredSnoopContainerView];
		[documentSnoopDrawer close:sender];
		[documentSnoopDrawer open:sender];
	}
	// we remember the last item that was selected in the preferences, so it sticks between windows
	[[OFPreferenceWrapper sharedPreferenceWrapper] setInteger:[documentSnoopButton indexOfSelectedItem]
													   forKey:BDSKSnoopDrawerContentKey];
}

- (void)drawerWillOpen:(NSNotification *)notification{
	[self updateSnoopDrawerContent];
	
	if([[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSnoopDrawerSavedSizeKey] != nil)
        [documentSnoopDrawer setContentSize:NSSizeFromString([[OFPreferenceWrapper sharedPreferenceWrapper] objectForKey:BDSKSnoopDrawerSavedSizeKey])];
    [documentSnoopScrollView scrollToTop];
}

- (void)drawerDidOpen:(NSNotification *)notification{
	[self updateDocumentSnoopButton];
}

- (void)drawerWillClose:(NSNotification *)notification{
	[[self window] makeFirstResponder:nil]; // this is necessary to avoid a crash after browsing
}

- (void)drawerDidClose:(NSNotification *)notification{
	[self updateDocumentSnoopButton];
}

- (NSSize)drawerWillResizeContents:(NSDrawer *)sender toSize:(NSSize)contentSize{
    [[OFPreferenceWrapper sharedPreferenceWrapper] setObject:NSStringFromSize(contentSize) forKey:BDSKSnoopDrawerSavedSizeKey];
    return contentSize;
}

- (BOOL)windowShouldClose:(id)sender{
    NSString *errMsg = nil;
    NSString *alternateButtonTitle = nil;
    
    // case 1: the item has not been edited
    if(![theBib hasBeenEdited]){
        errMsg = NSLocalizedString(@"The item has not been edited.  Would you like to keep it?", @"");
        // only give the option to discard if the bib has not been edited; otherwise, it's likely that autofile/autogen citekey just hasn't happened yet
        alternateButtonTitle = NSLocalizedString(@"Discard", @"");
    // case 2: cite key hasn't been set, and paper needs to be filed
    }else if([[theBib citeKey] isEqualToString:@"cite-key"] && [theBib needsToBeFiled] && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey]){
        errMsg = NSLocalizedString(@"The cite key for this entry has not been set, and AutoFile did not have enough information to file the paper.  Would you like to cancel and continue editing, or close the window and keep this entry as-is?", @"");
    // case 3: only the paper needs to be filed
    }else if([theBib needsToBeFiled] && [[OFPreferenceWrapper sharedPreferenceWrapper] boolForKey:BDSKFilePapersAutomaticallyKey]){
        errMsg = NSLocalizedString(@"AutoFile did not have enough information to file this paper.  Would you like to cancel and continue editing, or close the window and keep this entry as-is?", @"");
    // case 4: only the cite key needs to be set
    }else if([[theBib citeKey] isEqualToString:@"cite-key"]){
        errMsg = NSLocalizedString(@"The cite key for this entry has not been set.  Would you like to cancel and edit the cite key, or close the window and keep this entry as-is?", @"");
	// case 5: good to go
    }else{
        return YES;
    }
	
    NSBeginAlertSheet(NSLocalizedString(@"Warning!", @""),
                      NSLocalizedString(@"Keep", @""),   //default button NSAlertDefaultReturn
                      alternateButtonTitle,              //far left button NSAlertAlternateReturn
                      NSLocalizedString(@"Cancel", @""), //middle button NSAlertOtherReturn
                      [self window],
                      self, // modal delegate
                      @selector(shouldCloseSheetDidEnd:returnCode:contextInfo:),
                      NULL, // did dismiss sel
                      NULL,
                      errMsg);
    return NO; // this method returns before the callback

}

- (void)shouldCloseSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo{
    switch (returnCode){
        case NSAlertOtherReturn:
            break; // do nothing
        case NSAlertAlternateReturn:
            [[theBib retain] autorelease]; // make sure it stays around till we're closed
            [[theBib document] removePublication:theBib]; // now fall through to default
        default:
            [sheet orderOut:nil];
            [self close];
    }
}

- (void)windowWillClose:(NSNotification *)notification{
 //@@citekey   [[self window] makeFirstResponder:citeKeyField]; // makes the field check if there is a duplicate field.
	[self finalizeChangesPreservingSelection:NO];
    [macroTextFieldWC close]; // close so it's not hanging around by itself; this works if the doc window closes, also
    [documentSnoopDrawer close];
	// this can give errors when the application quits when an editor window is open
	[[BDSKScriptHookManager sharedManager] runScriptHookWithName:BDSKCloseEditorWindowScriptHookName 
												 forPublications:[NSArray arrayWithObject:theBib]];
	
    [theDocument removeWindowController:self];
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems{
	NSMutableArray *menuItems = [NSMutableArray arrayWithCapacity:8];
	NSMenuItem *item;
	
	NSEnumerator *iEnum = [defaultMenuItems objectEnumerator];
	while (item = [iEnum nextObject]) { 
		if ([item tag] == WebMenuItemTagCopy ||
			[item tag] == WebMenuItemTagCopyLinkToClipboard ||
			[item tag] == WebMenuItemTagCopyImageToClipboard) {
			
			[menuItems addObject:item];
		}
	}
	if ([menuItems count] > 0) 
		[menuItems addObject:[NSMenuItem separatorItem]];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Back",@"Back")
									  action:@selector(goBack:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Forward",@"Forward")
									  action:@selector(goForward:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reload",@"Reload")
									  action:@selector(reload:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Stop",@"Stop")
									  action:@selector(stopLoading:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Increase Text Size",@"Increase Text Size")
									  action:@selector(makeTextLarger:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Decrease Text Size",@"Increase Text Size")
									  action:@selector(makeTextSmaller:)
							   keyEquivalent:@""];
	[menuItems addObject:[item autorelease]];
	
	[menuItems addObject:[NSMenuItem separatorItem]];
	
	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Save as Local File",@"Save as local file")
									  action:@selector(saveFileAsLocalUrl:)
							   keyEquivalent:@""];
	[item setTarget:self];
	[menuItems addObject:[item autorelease]];
	
	return menuItems;
}

- (void)saveFileAsLocalUrl:(id)sender{
	WebDataSource *dataSource = [[remoteSnoopWebView mainFrame] dataSource];
	if (!dataSource || [dataSource isLoading]) 
		return;
	
	NSString *fileName = [[[[dataSource request] URL] relativePath] lastPathComponent];
	NSString *extension = [fileName pathExtension];
   
	NSSavePanel *sPanel = [NSSavePanel savePanel];
    if (![extension isEqualToString:@""]) 
		[sPanel setRequiredFileType:extension];
    int result = [sPanel runModalForDirectory:nil file:fileName];
    if (result == NSOKButton) {
		if ([[dataSource data] writeToFile:[sPanel filename] atomically:YES]) {
			NSString *fileURLString = [[NSURL fileURLWithPath:[sPanel filename]] absoluteString];
			
			[theBib setField:BDSKLocalUrlString toValue:fileURLString];
			[theBib autoFilePaper];
			
			[[[self window] undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
		} else {
			NSLog(@"Could not write downloaded file.");
		}
    }
}

- (void)downloadLinkedFileAsLocalUrl:(id)sender{
	NSURL *linkURL = (NSURL *)[sender representedObject];
	// not yet implemented 
}

#pragma mark undo manager

// we want to have the same undoManager as our document, so we use this 
// NSWindow delegate method to return the doc's undomanager, except for
// the abstract/annote/rss text views.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
    // work around for a bug(?) in Panther, as the main menu appears to use this method rather than -undoManagerForTextView:
	id firstResponder = [sender firstResponder];
	if(firstResponder == notesView)
        return notesViewUndoManager;
    else if(firstResponder == abstractView)
        return abstractViewUndoManager;
    else if(firstResponder == rssDescriptionView)
        return rssDescriptionViewUndoManager;
	
	return [theDocument undoManager];
}


#pragma mark author table view datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)tableView{
	return [theBib numberOfAuthors];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn 
			row:(int)row{
	NSString *tcid = [tableColumn identifier];
	
	if([tcid isEqualToString:@"name"]){
		return [[theBib authorAtIndex:row] name];
	}else{
		return @"";
	}
}


- (IBAction)showPersonDetailCmd:(id)sender{
	if (sender != authorTableView)
		[authorTableView selectAll:self];
	// find selected author
    NSEnumerator *e = [authorTableView selectedRowEnumerator]; //@@ 10.3 deprecated for IndexSets
	NSNumber *idx = nil;
	while (idx = [e nextObject]){
		int i = [idx intValue];
		BibAuthor *auth = [theBib authorAtIndex:i];
		[self showPersonDetail:auth];
	}
}

- (void)showPersonDetail:(BibAuthor *)person{
	BibPersonController *pc = [person personController];
	if(pc == nil){
            pc = [[BibPersonController alloc] initWithPerson:person document:theDocument];
            [theDocument addWindowController:pc];
            [pc release];
	}
	[pc show];
}


- (IBAction)addAuthors:(id)sender{
	[NSApp beginSheet:addAuthorSheet
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(addAuthorSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

- (IBAction)dismissAddAuthorSheet:(id)sender{
    [addAuthorSheet orderOut:sender];
    [NSApp endSheet:addAuthorSheet returnCode:[sender tag]];
}

// tag, and hence return code is 0 for OK and 1 for cancel.
// called upon dismissal
- (void)addAuthorSheetDidEnd:(NSWindow *)sheet
                 returnCode:(int) returnCode
                contextInfo:(void *)contextInfo{
	NSString *str = [addAuthorTextView string];
	if(returnCode == NSOKButton){
		
		NSArray *lines = [str componentsSeparatedByString:@"\n"];
		NSLog(@"lines are [%@] on add authors", lines);
	}else{
		// do nothing, user cancelled
	}
	[addAuthorTextView setString:@""];
}

#pragma mark Splitview delegate methods

- (void)splitViewDoubleClick:(OASplitView *)sender{
    NSView *form = [[splitView subviews] objectAtIndex:0]; // form
    NSView *matrix = [[splitView subviews] objectAtIndex:1]; // matrix
    NSRect formFrame = [form frame];
    NSRect matrixFrame = [matrix frame];
    
    if(NSHeight([matrix frame]) != 0){ // not sure what the criteria for isSubviewCollapsed, but it doesn't work
        lastMatrixHeight = NSHeight(matrixFrame); // cache this
        formFrame.size.height += lastMatrixHeight;
        matrixFrame.size.height = 0;
    } else {
        if(lastMatrixHeight == 0)
            lastMatrixHeight = NSHeight([extraBibFields frame]); // a reasonable value to start
		matrixFrame.size.height = lastMatrixHeight;
        formFrame.size.height = NSHeight([splitView frame]) - lastMatrixHeight - [splitView dividerThickness];
    }
    [form setFrame:formFrame];
    [matrix setFrame:matrixFrame];
    [splitView adjustSubviews];
}


@end