//  BibEditor.h

//  Created by Michael McCracken on Mon Dec 24 2001.
/*
This software is Copyright (c) 2002, Michael O. McCracken
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-  Neither the name of Michael O. McCracken nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*! @header BibEditor.h
    @discussion The class for editing BibItems. Handles the UI for the fields and notes.
*/ 

#import <Cocoa/Cocoa.h>

#import <OmniFoundation/OmniFoundation.h>

#import "BibItem.h"
#import "BibDocument.h"
#import "BDSKCiteKeyFormatter.h"
#import "BibAppController.h"
#import "PDFImageView.h"
#import "BDSKFieldNameFormatter.h"


extern NSString *BDSKAnnoteString;
extern NSString *BDSKAbstractString;
extern NSString *BDSKRssDescriptionString;
extern NSString *BDSKLocalUrlString;
extern NSString *BDSKUrlString;


/*!
    @class BibEditor
    @abstract WindowController for the edit window
    @discussion Subclass of the NSWindowController class, This handles making, reversing and keeping track of changes to the BibItem, and displaying a nice GUI.
*/
@interface BibEditor : NSWindowController {
    IBOutlet NSPopUpButton *bibTypeButton;
    IBOutlet NSForm *bibFields;
    IBOutlet NSTabView *tabView;
    IBOutlet NSTextView *notesView;
    IBOutlet NSTextView *abstractView;
    IBOutlet NSTextView* rssDescriptionView;
    IBOutlet NSTextField* citeKeyField;
    IBOutlet NSButton* viewLocalButton;
    IBOutlet NSButton* viewRemoteButton;
    IBOutlet NSScrollView* fieldsScrollView;
    // ----------------------------------------------------------------------------------------
    // New-field Sheet stuff:
    IBOutlet NSTextField *newFieldName;
    IBOutlet NSButton* newFieldButtonOK;
    IBOutlet NSButton* newFieldButtonCancel;
    IBOutlet NSWindow* newFieldWindow;
    // ----------------------------------------------------------------------------------------
    // change count stuff:
    int changeCount;
    // ----------------------------------------------------------------------------------------
    // Delete-field Sheet stuff:
    IBOutlet NSPopUpButton *delFieldPopUp;
    IBOutlet NSButton* delFieldButtonOK;
    IBOutlet NSButton* delFieldButtonCancel;
    IBOutlet NSWindow* delFieldWindow;
    // ----------------------------------------------------------------------------------------
    NSString *currentType;
    BibItem *theBib;
    // Killed for write-through:    BibItem *tmpBib;
    BibDocument *theDoc;
    NSEnumerator *e;
    NSMutableDictionary *fieldNumbers;
    // Killed for write-through:    BOOL needsRefresh;
// ----------------------------------------------------------------------------------------
// doc preview stuff
// ----------------------------------------------------------------------------------------
    IBOutlet NSDrawer* documentSnoopDrawer;
    IBOutlet PDFImageView *documentSnoopImageView;
    IBOutlet NSButton* documentSnoopButton;
    IBOutlet NSScrollView* documentSnoopScrollView;
    IBOutlet NSView* pdfSnoopContainerView;
    NSImage *_pdfSnoopImage;
// ----------------------------------------------------------------------------------------
// doc textpreview stuff
// ----------------------------------------------------------------------------------------
    IBOutlet NSButton* documentTextSnoopButton;
    IBOutlet NSTextView *documentSnoopTextView;
    IBOutlet NSView* textSnoopContainerView;
    NSString *_textSnoopString;
    
// Autocompletion stuff
    NSDictionary *completionMatcherDict;
// cite string formatter
    BDSKCiteKeyFormatter *citeKeyFormatter;
// new field formatter
    BDSKFieldNameFormatter *fieldNameFormatter;
}

/*!
@method initWithBibItem:andBibDocument:
    @abstract designated Initializer
    @discussion
 @param aBib gives us a bib to edit
 @param aDoc the document to notify of changes
*/
- (id)initWithBibItem:(BibItem *)aBib andBibDocument:(BibDocument *)aDoc;

/*!
    @method setupForm
    @abstract handles making the NSForm
    @discussion <ul> <li>This method is kind of hairy.
 <li>could be more efficient, maybe.
 <li>And is probably being called in the wrong place (windowDidBecomeMain).
 </ul>
    
*/

- (BibItem *)currentBib;
- (void)setupForm;
- (void)show;

- (void)fixURLs;


// ----------------------------------------------------------------------------------------
// Add-field sheet support
// ----------------------------------------------------------------------------------------
- (IBAction)raiseAddField:(id)sender;
- (IBAction)dismissAddField:(id)sender;
- (void)addFieldSheetDidEnd:(NSWindow *)sheet
                 returnCode:(int) returnCode
                contextInfo:(void *)contextInfo;

// ----------------------------------------------------------------------------------------
// Delete-field sheet support
// ----------------------------------------------------------------------------------------
- (IBAction)raiseDelField:(id)sender;
- (IBAction)dismissDelField:(id)sender;
- (void)delFieldSheetDidEnd:(NSWindow *)sheet
                 returnCode:(int) returnCode
                contextInfo:(void *)contextInfo;

// deprecated - (IBAction)revert:(id)sender;
//- (IBAction)saveDocument:(id)sender;
//- (IBAction)save:(id)sender;
//- (IBAction)cancel:(id)sender;
- (void)finalizeChanges;

- (IBAction)viewLocal:(id)sender;
- (IBAction)viewRemote:(id)sender;
- (IBAction)citeKeyDidChange:(id)sender;

- (IBAction)bibTypeDidChange:(id)sender;
//- (IBAction)textFieldDidChange:(id)sender;
- (IBAction)textFieldDidEndEditing:(id)sender;
- (void)noteChange;
//- (void)closeSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo;

- (void)toggleSnoopDrawer:(id)sender;
- (BOOL)citeKeyIsValid:(NSString *)proposedCiteKey;
- (void)makeKeyField:(NSString *)fieldName;
@end
