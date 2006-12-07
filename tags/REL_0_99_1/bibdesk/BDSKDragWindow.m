/*
This software is Copyright (c) 2002, Michael O. McCracken
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-  Neither the name of Michael O. McCracken nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


#import "BDSKDragWindow.h"

#import <Carbon/Carbon.h>
#import "BibDocument.h"
#import "BibItem.h"
#import "BibEditor.h"

@implementation BDSKDragWindow

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;

    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];

    if ( [[pboard types] containsObject:NSStringPboardType] ) {
        if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        if (sourceDragMask & NSDragOperationCopy) {
            return NSDragOperationCopy;
        }
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    NSData *pbData; 
    NSArray *fileNames;
    NSArray *draggedPubs;
    NSEnumerator *draggedPubsE;
    BibItem *tempBI;
    NSMutableDictionary *bibDict;
    NSEnumerator *newKeyE;
    NSString *key;
    NSString *value;
    BOOL hadProblems = NO;

    BibItem *editorBib = [[self windowController] currentBib];
    NSArray *oldKeys = [[editorBib pubFields] allKeys];
        
    sourceDragMask = [sender draggingSourceOperationMask];
    if([sender draggingSource]){
        pboard = [NSPasteboard pasteboardWithName:LocalDragPasteboardName];     // it's really local, so use the local pboard.
    }else{
        pboard = [sender draggingPasteboard];
    }


    // Check first for filenames because we want to treat them differently,
    // and every time someone puts a filenames type on a pboard, they put a URL type too...
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        fileNames = [pboard propertyListForType:NSFilenamesPboardType];

        if (sourceDragMask & NSDragOperationCopy) {
			NSString *fileUrlString = [[NSURL fileURLWithPath:
				[[fileNames objectAtIndex:0] stringByExpandingTildeInPath]]absoluteString];
			
            [editorBib setField:BDSKLocalUrlString
                        toValue:fileUrlString];
			[editorBib autoFilePaper];
        }
    }else if([[pboard types] containsObject:NSURLPboardType]){

        fileNames = [pboard propertyListForType:NSURLPboardType];
        
        if(sourceDragMask & NSDragOperationCopy){
            [editorBib setField:BDSKUrlString
                        toValue:[fileNames objectAtIndex:0]];
        }
    }else if ( [[pboard types] containsObject:NSStringPboardType] ) {
        // get the item from the string
        pbData = [pboard dataForType:NSStringPboardType];
        
        // sniff the string to see if it's BibTeX or RIS
        BOOL isRIS = NO;
        NSString *pbString = [[NSString alloc] initWithData:pbData encoding:NSUTF8StringEncoding];
        if([pbString isRISString])
            isRIS = YES;
        
        if(isRIS){
            draggedPubs = [PubMedParser itemsFromString:pbString error:&hadProblems];
        } else {
            // must be BibTeX
            draggedPubs = [BibTeXParser itemsFromData:pbData error:&hadProblems];
        }
        
        if(hadProblems) return NO;
            
        draggedPubsE = [draggedPubs objectEnumerator];
        while(tempBI = [draggedPubsE nextObject]){
            bibDict = [tempBI pubFields];
            newKeyE = [bibDict keyEnumerator];

            // Test a keyboard mask so that sometimes we can override all fields when dragging into the editor window
            // use the Carbon function since [[NSApp currentEvent] modifierFlags] won't work if we're not the front app
            unsigned modifier = GetCurrentKeyModifiers();
            if(modifier == optionKey){
                [editorBib setCiteKeyString:[tempBI citeKey]];
                // just setting the citekey won't update the form, so we have to use a notification
                [[NSNotificationCenter defaultCenter] postNotificationName:BDSKBibItemChangedNotification object:editorBib userInfo:[NSDictionary dictionaryWithObjectsAndKeys:BDSKCiteKeyString, @"key", [tempBI citeKey], @"value", nil]];
            }
            while(key = [newKeyE nextObject]){
                if(modifier == optionKey){
                    [editorBib setField:key toValue:[bibDict objectForKey:key]];
                } else {
                    // only set to the new value if the old one is non-existent
                    value = [[editorBib pubFields] objectForKey:key]; // value is the value of key in the dragged-onto window.
    //                NSLog(@"a key is %@, its value is [%@]", key, value);
                    if (([oldKeys containsObject:key] &&
                         [value isEqualToString:@""]) ||
                        (![oldKeys containsObject:key] &&
                         ![[bibDict objectForKey:key] isEqualToString:@""])){

                        [editorBib setField:key
                                    toValue:[bibDict objectForKey:key]];
                    }
                }
            }
            [editorBib setType:[tempBI type]];
            [[self windowController] updateTypePopup]; // set the popup properly
            [[self windowController] bibTypeDidChange:nil]; // re-setup the form
        }//for each dragged-in pub
    }
    return YES;
}

@end
