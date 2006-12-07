//  BibDocument+Menus.h
//  BibDesk
//
//  Created by Sven-S. Porst on Fri Jul 30 2004.
/*
 This software is Copyright (c) 2004,2005
 Sven-S. Porst. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Sven-S. Porst nor the names of any
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


@interface BibDocument (Menus)


- (BOOL) validateMenuItem:(NSMenuItem*)menuItem;

- (BOOL) validateCutMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateCopyMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateCopyAsTeXMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateCopyAsBibTeXMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateCopyAsPublicBibTeXMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateCopyAsPDFMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateCopyAsRTFMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateCopyAsLaTeXMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateCopyAsRISMenuItem:(NSMenuItem *)menuItem;
- (BOOL) validateEditSelectionMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateOpenLinkedFileMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateRevealLinkedFileMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateDuplicateTitleToBooktitleMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateGenerateCiteKeyMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateConsolidateLinkedFilesMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateDeleteSelectionMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validatePrintDocumentMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateToggleStatusBarMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateNewPubFromPasteboardMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateNewPubFromFileMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateNewPubFromWebMenuItem:(NSMenuItem*) menuItem;
- (BOOL) validateSelectCrossrefParentMenuItem:(NSMenuItem *)menuItem;
- (BOOL) validateCreateNewPubUsingCrossrefMenuItem:(NSMenuItem *)menuItem;
- (BOOL) validateDuplicateMenuItem:(NSMenuItem *)menuItem;
- (BOOL) validateSortGroupsByGroupMenuItem:(NSMenuItem *)menuItem;
- (BOOL) validateSortGroupsByCountMenuItem:(NSMenuItem *)menuItem;
- (BOOL) validateChangeGroupFieldMenuItem:(NSMenuItem *)menuItem;
- (IBAction) clear:(id) sender;
@end
