// BDSKDragWindow.m
/*
 This software is Copyright (c) 2002,2003,2004,2005
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


#import "BDSKDragWindow.h"

#import <Carbon/Carbon.h>
#import "BibDocument.h"
#import "BibItem.h"
#import "BibEditor.h"

@implementation BDSKDragWindow

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
    // weblocs also put strings on the pboard, so check for that type first so we don't get a false positive on NSStringPboardType
	NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:BDSKBibTeXStringPboardType, NSStringPboardType, nil]];
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	
    // sniff the string to see if it's BibTeX or RIS
    if([pboardType isEqualToString:NSStringPboardType] ||
	   [pboardType isEqualToString:BDSKBibTeXStringPboardType]){
        NSString *pbString = [pboard stringForType:pboardType];    
        if(![pbString isRISString] && ![pbString isBibTeXString])
            return NSDragOperationNone;
    }

    if([pboardType isEqualToString:NSStringPboardType] ||
	   [pboardType isEqualToString:BDSKBibTeXStringPboardType]) {
        unsigned modifier = GetCurrentKeyModifiers();
        if ( (modifier & (optionKey | cmdKey)) == (optionKey | cmdKey) ){ // hack to get the correct cursor
            return NSDragOperationLink;
        }
        if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    return NSDragOperationNone;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	return [self draggingUpdated:sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard = [sender draggingPasteboard];
	NSString *pboardType = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSURLPboardType, BDSKBibTeXStringPboardType, NSStringPboardType, nil]];
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
	NSString *pbString = nil;
    BOOL hadProblems = NO;
    BibItem *editorBib = [[self windowController] currentBib];
	
	if([pboardType isEqualToString:BDSKBibTeXStringPboardType] || 
	   [pboardType isEqualToString:NSStringPboardType]){
		pbString = [pboard stringForType:pboardType];
	}else{
		// we did not find a valid dragtype
		return NO;
	}
	
	// we should have a bibitem either as RIS or BibteX
	// get the item from the string
	NSArray *draggedPubs;
	BibItem *tempBI;
	
	// sniff the string to see if it's BibTeX or RIS
	if([pbString isRISString]){
		draggedPubs = [PubMedParser itemsFromString:pbString error:&hadProblems];
	} else if([pbString isBibTeXString]){
		[[BDSKErrorObjectController sharedErrorObjectController] setDocumentForErrors:[editorBib document]];
		NSData *pbData = [pboard dataForType:pboardType];
		draggedPubs = [BibTeXParser itemsFromData:pbData error:&hadProblems];
	} else {
		OBASSERT_NOT_REACHED("Unsupported data type");
		return NO;
	}
	
	if(hadProblems) return NO;
	
	tempBI = [draggedPubs objectAtIndex:0]; // no point in dealing with multiple pubs for a single editor
	[tempBI setDocument:[editorBib document]]; // this assures that the macroResolver is set for complex strings

	// Test a keyboard mask so that we can override all fields when dragging into the editor window (option)
	// create a crossref (cmd-option), or fill empty fields (no modifiers)
	unsigned modifier = GetCurrentKeyModifiers(); // use the Carbon function since [[NSApp currentEvent] modifierFlags] won't work if we're not the front app
	
	// we always have sourceDragMask & NSDragOperationLink here for some reason, so test the mask manually
	if((modifier & (optionKey | cmdKey)) == (optionKey | cmdKey)){
		
		NSString *crossref = [tempBI citeKey];
		NSString *message = nil;
		
		// first check if we don't create a Crossref chain
		if ([[editorBib citeKey] caseInsensitiveCompare:crossref] == NSOrderedSame) {
			message = NSLocalizedString(@"An item cannot cross reference to itself.", @"");
		} else {
			BibDocument *doc = [editorBib document]; 
			NSString *parentCr = [[doc publicationForCiteKey:crossref] valueOfField:BDSKCrossrefString inherit:NO];
			
			if (![NSString isEmptyString:parentCr]) {
				message = NSLocalizedString(@"Cannot cross reference to an item that has the Crossref field set.", @"");
			} else if ([doc citeKeyIsCrossreffed:[editorBib citeKey]]) {
				message = NSLocalizedString(@"Cannot set the Crossref field, as the current item is cross referenced.", @"");
			}
		}
		
		if (message) {
			NSRunAlertPanel(NSLocalizedString(@"Invalid Crossref Value", @"Invalid Crossref Value"),
							message,
							NSLocalizedString(@"OK", @"OK"), nil, nil);
			return NO;
		}
		// add the crossref field if it doesn't exist, then set it to the citekey of the drag source's bibitem
		if(![[[editorBib pubFields] allKeys] containsObject:BDSKCrossrefString])
			[editorBib addField:BDSKCrossrefString];
		[editorBib setField:BDSKCrossrefString toValue:crossref];
		[[editorBib undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
		return YES;
	}
	
	// we aren't linking, so here we decide which fields to overwrite, and just copy values over
	NSDictionary *bibDict = [tempBI pubFields];
	NSEnumerator *newKeyE = [bibDict keyEnumerator];
	NSString *key;
	NSString *oldValue;
	NSString *newValue;
	
	if(modifier & optionKey){
		[editorBib setCiteKey:[tempBI citeKey]];
	}
	[editorBib setType:[tempBI type]]; // do we want this always?
	
	while(key = [newKeyE nextObject]){
		newValue = [bibDict objectForKey:key];
		if([newValue isEqualToString:@""])
			continue;
		
		oldValue = [[editorBib pubFields] objectForKey:key]; // value is the value of key in the dragged-onto window.
		
		// only set the field if we force or the value was empty
		if((modifier & optionKey) || [NSString isEmptyString:oldValue]){
			if(oldValue == nil)
				[editorBib addField:key];
			[editorBib setField:key toValue:newValue];
		}
	}
	
	[[editorBib undoManager] setActionName:NSLocalizedString(@"Edit Publication",@"")];
	
	return YES;
}

@end