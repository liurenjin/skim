//
//  BibItem_CiteKey.m
//  
//
//  Created by Christiaan Hofman on 11/4/04.
/*
 This software is Copyright (c) 2004,2005,2006
 Christiaan Hofman. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Christiaan Hofman nor the names of any
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

#import "BibPref_CiteKey.h"
#import "NSImage+Toolbox.h"
#import "BDSKAlert.h"
#import "BDSKFormatParser.h"
#import "BibAppController.h"

#define MAX_PREVIEW_WIDTH	481
#define MAX_FORMAT_WIDTH	266

@implementation BibPref_CiteKey

// these should correspond to the items in the popups set in IB
static NSString *presetFormatStrings[] = {@"%a1:%Y%u2", @"%a1:%Y%u0", @"%a33%y%m", @"%a1%Y%t15"};
static NSString *repositorySpecifierStrings[] = {@"", @"%a00", @"%A0", @"%t0", @"%T0", @"%Y", @"%y", @"%m", @"%k0", @"%f{}0", @"%c{}", @"%r2", @"%R2", @"%d2", @"%u0", @"%U0", @"%n0", @"%0"};

- (id)initWithTitle:(NSString *)newTitle defaultsArray:(NSArray *)newDefaultsArray controller:(OAPreferenceController *)controller{
	if(self = [super initWithTitle:newTitle defaultsArray:newDefaultsArray controller:controller]){
		// use a BibItem with some data to build the preview cite key
		NSDictionary *previewFields = [NSDictionary dictionaryWithObjectsAndKeys:
			@"BibDesk, a great application to manage your bibliographies", BDSKTitleString, 
			@"McCracken, M. and Maxwell, A. and Howison, J. and Routley, M. and Spiegel, S.  and Porst, S. S. and Hofman, C. M.", BDSKAuthorString, 
			@"2004", BDSKYearString, @"11", BDSKMonthString, 
			@"SourceForge", BDSKJournalString, @"1", BDSKVolumeString, @"96", BDSKPagesString, 
			@"Keyword1,Keyword2", BDSKKeywordsString, nil];
		previewItem = [[BibItem alloc] initWithType:[defaults stringForKey:BDSKPubTypeStringKey]
										   fileType:BDSKBibtexString
										  pubFields:previewFields
											authors:nil
										createdDate:[NSCalendarDate calendarDate]];
	}
	return self;
}

- (void)dealloc{
	[previewItem release];
    [coloringEditor release];
	[formatSheet release];
	[super dealloc];
}

- (void)awakeFromNib{
    [super awakeFromNib];
	BDSKFormatStringFormatter *formatter = [[BDSKFormatStringFormatter alloc] initWithField:BDSKCiteKeyString fileType:BDSKBibtexString];
    [formatSheetField setFormatter:formatter];
	[formatter release];
	coloringEditor = [[BDSKFormatStringFieldEditor alloc] initWithFrame:[formatSheetField frame] parseField:BDSKCiteKeyString fileType:BDSKBibtexString];
}

// sheet's delegate must be connected to file's owner in IB
- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject{
    return (anObject == formatSheetField ? coloringEditor : nil);
}

- (void)updateUI{
    NSString *citeKeyFormat = [defaults stringForKey:BDSKCiteKeyFormatKey];
	NSAttributedString *attrFormat = nil;
    int citeKeyPresetChoice = [defaults integerForKey:BDSKCiteKeyFormatPresetKey];
	BOOL custom = (citeKeyPresetChoice == 0);
	NSString *error = nil;
	NSRect frame;
	
	// update the UI elements
    [citeKeyAutogenerateCheckButton setState:[defaults boolForKey:BDSKCiteKeyAutogenerateKey] ? NSOnState : NSOffState];
    [citeKeyLowercaseCheckButton setState:[defaults boolForKey:BDSKCiteKeyLowercaseKey] ? NSOnState : NSOffState];
    [formatCleanRadio selectCellWithTag:[defaults integerForKey:BDSKCiteKeyCleanOptionKey]];
	
	if ([BDSKFormatParser validateFormat:&citeKeyFormat attributedFormat:&attrFormat forField:BDSKCiteKeyString inFileType:BDSKBibtexString error:&error]) {
		[self setCiteKeyFormatInvalidWarning:NO message:nil];
		
		[citeKeyLine setStringValue:[previewItem suggestedCiteKey]];
		[citeKeyLine sizeToFit];
		frame = [citeKeyLine frame];
		if (frame.size.width > MAX_PREVIEW_WIDTH) {
			frame.size.width = MAX_PREVIEW_WIDTH;
			[citeKeyLine setFrame:frame];
		}
		[controlBox setNeedsDisplay:YES];
	} else {
		[self setCiteKeyFormatInvalidWarning:YES message:error];
		[citeKeyLine setStringValue:NSLocalizedString(@"Invalid Format", @"Cite key preview for invalid format")];
		if (![formatSheet isVisible])
			[self showFormatSheet:self];
	}
	[formatPresetPopUp selectItemAtIndex:[formatPresetPopUp indexOfItemWithTag:citeKeyPresetChoice]];
	[formatPresetSheetPopUp selectItemAtIndex:[formatPresetPopUp indexOfItemWithTag:citeKeyPresetChoice]];
	[formatField setAttributedStringValue:attrFormat];
	[formatField sizeToFit];
	frame = [formatField frame];
	if (frame.size.width > MAX_FORMAT_WIDTH) {
		frame.size.width = MAX_FORMAT_WIDTH;
		[formatField setFrame:frame];
	}
	[formatSheetField setAttributedStringValue:attrFormat];
	[formatSheetField setEnabled:custom];
	[formatRepositoryPopUp setHidden:!custom];
}

- (IBAction)citeKeyHelp:(id)sender{
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"Citation-Keys" inBook:@"BibDesk Help"];
}

- (IBAction)formatHelp:(id)sender{
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"Autogeneration-Format-Syntax" inBook:@"BibDesk Help"];
}

- (IBAction)changeCiteKeyAutogenerate:(id)sender{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKCiteKeyAutogenerateKey];
	[self updateUI];
}

- (IBAction)changeCiteKeyLowercase:(id)sender{
    [defaults setBool:([sender state] == NSOnState) forKey:BDSKCiteKeyLowercaseKey];
	[self updateUI];
}

- (IBAction)setFormatCleanOption:(id)sender{
	[defaults setInteger:[[sender selectedCell] tag] forKey:BDSKCiteKeyCleanOptionKey];
}

- (IBAction)citeKeyFormatAdd:(id)sender{
	int index = [formatRepositoryPopUp indexOfSelectedItem];
	NSString *newSpecifier = repositorySpecifierStrings[index];
    NSText *fieldEditor = [formatSheetField currentEditor];
	NSRange selRange;
	
	if ([NSString isEmptyString:newSpecifier])
		return;
	
    if (fieldEditor) {
		selRange = NSMakeRange([fieldEditor selectedRange].location + 2, [newSpecifier length] - 2);
		[fieldEditor insertText:newSpecifier];
	} else {
		NSString *formatString = [formatSheetField stringValue];
		selRange = NSMakeRange([formatString length] + 2, [newSpecifier length] - 2);
		[formatSheetField setStringValue:[formatString stringByAppendingString:newSpecifier]];
	}
	
	// this handles the new defaults and the UI update
	[self citeKeyFormatChanged:sender];
	
	// select the 'arbitrary' numbers
	if ([newSpecifier isEqualToString:@"%0"]) {
		selRange.location -= 1;
		selRange.length = 1;
	}
	else if ([newSpecifier isEqualToString:@"%f{}0"] || [newSpecifier isEqualToString:@"%c{}"]) {
        selRange.location += 1;
		selRange.length = 0;
	}
	[formatSheetField selectText:self];
	[[formatSheetField currentEditor] setSelectedRange:selRange];
}

- (IBAction)citeKeyFormatChanged:(id)sender{
	int presetChoice = 0;
	NSString *formatString;
	
	if (sender == formatPresetPopUp || sender == formatPresetSheetPopUp) {
		presetChoice = [[sender selectedItem] tag];
		if (presetChoice == [defaults integerForKey:BDSKCiteKeyFormatPresetKey]) 
			return; // nothing changed
		[defaults setInteger:presetChoice forKey:BDSKCiteKeyFormatPresetKey];
		if (presetChoice > 0) {
			formatString = presetFormatStrings[presetChoice - 1];
		} else if (presetChoice == 0) {
			formatString = [formatSheetField stringValue];
			if (sender == formatPresetPopUp)
				[self showFormatSheet:self];
		} else {
			return;
		}
		// this one is always valid
		[defaults setObject:formatString forKey:BDSKCiteKeyFormatKey];
	}
	else { //changed the text field or added from the repository
		NSString *error = nil;
		NSAttributedString *attrFormat = nil;
		formatString = [formatSheetField stringValue];
		//if ([formatString isEqualToString:[defaults stringForKey:BDSKCiteKeyFormatKey]]) return; // nothing changed
		if ([BDSKFormatParser validateFormat:&formatString attributedFormat:&attrFormat forField:BDSKCiteKeyString inFileType:BDSKBibtexString error:&error]) {
			[defaults setObject:formatString forKey:BDSKCiteKeyFormatKey];
		}
		else {
			[self setCiteKeyFormatInvalidWarning:YES message:error];
			[formatSheetField setAttributedStringValue:attrFormat];
			return;
		}
	}
	[[NSApp delegate] setRequiredFieldsForCiteKey: [BDSKFormatParser requiredFieldsForFormat:formatString]];
	[self updateUI];
}

#pragma mark Format sheet stuff

- (IBAction)showFormatSheet:(id)sender{
	
    [NSApp beginSheet:formatSheet
       modalForWindow:[[self controlBox] window]
        modalDelegate:self
       didEndSelector:NULL
          contextInfo:nil];
}

- (BOOL)canCloseFormatSheet{
	NSString *formatString = [formatSheetField stringValue];
	NSString *error = nil;
	NSString *otherButton = nil;
	
	if ([formatSheet makeFirstResponder:nil])
		[formatSheet endEditingFor:nil];
	
	if ([BDSKFormatParser validateFormat:&formatString forField:BDSKCiteKeyString inFileType:BDSKBibtexString error:&error]) 
		return YES;
	
	formatString = [defaults stringForKey:BDSKCiteKeyFormatKey];
	if ([BDSKFormatParser validateFormat:&formatString forField:BDSKCiteKeyString inFileType:BDSKBibtexString error:NULL]) {
		// The currently set cite-key format is valid, so we can keep it 
		otherButton = NSLocalizedString(@"Revert to Last", @"Revert to Last Valid Cite Key Format");
	}
	
	BDSKAlert *alert = [BDSKAlert alertWithMessageText:NSLocalizedString(@"Invalid Cite Key Format",@"") 
										 defaultButton:NSLocalizedString(@"Keep Editing", @"Keep Editing") 
									   alternateButton:NSLocalizedString(@"Revert to Default", @"Revert to Default Cite Key Format") 
										   otherButton:otherButton
							 informativeTextWithFormat:@"%@", error];
	int rv = [alert runSheetModalForWindow:formatSheet
							 modalDelegate:nil
							didEndSelector:NULL 
						didDismissSelector:NULL 
							   contextInfo:NULL];
	
	if (rv == NSAlertDefaultReturn){
		[formatSheetField selectText:self];
		return NO;
	} else if (rv == NSAlertAlternateReturn){
		formatString = [[[OFPreferenceWrapper sharedPreferenceWrapper] preferenceForKey:BDSKCiteKeyFormatKey] defaultObjectValue];
		[[OFPreferenceWrapper sharedPreferenceWrapper] setObject:formatString forKey:BDSKCiteKeyFormatKey];
		[[NSApp delegate] setRequiredFieldsForCiteKey: [BDSKFormatParser requiredFieldsForFormat:formatString]];
	}
	[self updateUI];
	return YES;
}

- (IBAction)closeFormatSheet:(id)sender{
	if (![self canCloseFormatSheet])
		return;
    [formatSheet orderOut:sender];
    [NSApp endSheet:formatSheet];
}

#pragma mark Invalid format warning stuff

- (IBAction)showCiteKeyFormatWarning:(id)sender{
	NSString *msg = [sender toolTip];
	
	if ([NSString isEmptyString:msg]) {
		msg = NSLocalizedString(@"The format string you entered contains invalid format specifiers.",@"");
	}
	
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Invalid Cite Key Format",@"") 
									 defaultButton:NSLocalizedString(@"OK",@"OK") 
								   alternateButton:nil 
									   otherButton:nil 
						 informativeTextWithFormat:@"%@", msg];
	[alert beginSheetModalForWindow:formatSheet 
					  modalDelegate:nil
					 didEndSelector:NULL 
						contextInfo:NULL];
}

- (void)setCiteKeyFormatInvalidWarning:(BOOL)set message:(NSString *)message{
	if(set){
		[formatWarningButton setImage:[NSImage cautionIconImage]];
		[formatWarningButton setToolTip:message];
	}else{
		[formatWarningButton setImage:nil];
		[formatWarningButton setToolTip:NSLocalizedString(@"",@"")]; // @@ this should be nil?
	}
	[formatWarningButton setEnabled:set];
	[formatSheetField setTextColor:(set ? [NSColor redColor] : [NSColor blackColor])]; // overdone?
}

@end
