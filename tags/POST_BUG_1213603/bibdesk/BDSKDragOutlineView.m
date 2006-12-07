// BDSKDragOutlineView.m 
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

#import "BDSKDragOutlineView.h"
@class BibItem;
@class BibAuthor;
#import <OmniBase/OmniBase.h>
#import "BibDocument.h"

@implementation NSOutlineView (MyExtensions)
- (NSArray*)allSelectedItems {
    NSMutableArray *items = [NSMutableArray array];
    NSEnumerator *selectedRows = [self selectedRowEnumerator];
    NSNumber *selRow = nil;
    while( (selRow = [selectedRows nextObject]) ) {
        if ([self itemAtRow:[selRow intValue]])
            [items addObject: [self itemAtRow:[selRow intValue]]];
    }
    return items;
}

- (void) removeAllTableColumns{
    NSEnumerator *e = [[self tableColumns] objectEnumerator];
    NSTableColumn *tc;

    while (tc = [e nextObject]) {
        if(tc != [self outlineTableColumn])
            [self removeTableColumn:tc];
    }
}

-(NSMenu*)menuForEvent:(NSEvent *)evt {
	id theDelegate = [self delegate];
	NSPoint pt=[self convertPoint:[evt locationInWindow] fromView:nil];
	int column=[self columnAtPoint:pt];
	int row=[self rowAtPoint:pt];
	
	if (column >= 0 && row >= 0 && [theDelegate respondsToSelector:@selector(menuForTableViewSelection:)]) {
		// select the clicked row if it isn't selected yet
		if (![self isRowSelected:row]){
			[self selectRow:row byExtendingSelection:NO];
		}
		return (NSMenu*)[theDelegate menuForTableViewSelection:self];	
	}
	return nil; 
} 

@end

@implementation BDSKDragOutlineView

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
    if (isLocal) return NSDragOperationEvery; // might want more than this later, maybe?
    else return NSDragOperationCopy;
}

@end
