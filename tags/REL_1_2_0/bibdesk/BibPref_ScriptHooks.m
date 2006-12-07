//
//  BibPref_ScriptHooks.m
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/10/05.
/*
 This software is Copyright (c) 2005
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

#import "BibPref_ScriptHooks.h"
#import "BDSKScriptHookManager.h"
#import "NSFileManager_BDSKExtensions.h"
#import <OmniFoundation/NSString-OFExtensions.h>
#import <OmniAppKit/NSTableView-OAExtensions.h>


@implementation BibPref_ScriptHooks

- (id)initWithTitle:(NSString *)newTitle defaultsArray:(NSArray *)newDefaultsArray controller:(OAPreferenceController *)controller{
	if(self = [super initWithTitle:newTitle defaultsArray:newDefaultsArray controller:controller]){
		scriptHookNames = [[NSArray alloc] initWithObjects:BDSKChangeFieldScriptHookName, 
														   BDSKCloseEditorWindowScriptHookName, 
														   BDSKWillAutoFileScriptHookName, 
														   BDSKDidAutoFileScriptHookName, 
														   BDSKWillGenerateCiteKeyScriptHookName, 
														   BDSKDidGenerateCiteKeyScriptHookName, nil];
	}
	return self;
}

- (void)dealloc{
	[scriptHookNames release];
	[super dealloc];
}

- (void)awakeFromNib{
    [super awakeFromNib];
	[tableView setTarget:self];
	[tableView setDoubleAction:@selector(showOrChooseScriptFile:)];
	[self tableViewSelectionDidChange:nil];
}

- (void)updateUI{
	[tableView reloadData];
}

- (IBAction)addScriptHook:(id)sender{
	if([tableView selectedRow] == -1) 
		return;
	
	NSString *directory = [[NSFileManager defaultManager] currentApplicationSupportPathForCurrentUser];
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setPrompt:NSLocalizedString(@"Choose", @"Choose")];
	[openPanel setAllowsMultipleSelection:NO];
    [openPanel beginSheetForDirectory:directory 
								 file:nil
								types:[NSArray arrayWithObject:@"scpt"] 
					   modalForWindow:[[OAPreferenceController sharedPreferenceController] window] 
						modalDelegate:self 
					   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) 
						  contextInfo:NULL];
}

- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSCancelButton)
        return;
    
	NSString *path = [[sheet filenames] objectAtIndex: 0];
	if (path == nil)
		return;

	int row = [tableView selectedRow]; // cannot be -1
	NSString *name = [scriptHookNames objectAtIndex:row];
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:BDSKScriptHooksKey]];
	[dict setObject:path forKey:name];
	[defaults setObject:dict forKey:BDSKScriptHooksKey];
	[self updateUI];
}

- (IBAction)removeScriptHook:(id)sender{
	int row = [tableView selectedRow];
	if (row == -1) return;
	
	NSString *name = [scriptHookNames objectAtIndex:row];
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults dictionaryForKey:BDSKScriptHooksKey]];
	[dict removeObjectForKey:name];
	[defaults setObject:dict forKey:BDSKScriptHooksKey];
	[self updateUI];
}

- (void)showOrChooseScriptFile:(id)sender {
	int row = [tableView clickedRow];
	
	if (row == -1)
		return;
	
	NSString *name = [scriptHookNames objectAtIndex:row];
	NSString *path = [[defaults dictionaryForKey:BDSKScriptHooksKey] objectForKey:name];
	
	if ([NSString isEmptyString:path]) {
		[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[self addScriptHook:sender];
	} else {
		NSURL *url = [NSURL fileURLWithPath:path];
		if (url)
			[[NSWorkspace sharedWorkspace] openURL:url];
		else 
			NSBeep();
	}
}

#pragma mark TableView DataSource methods

- (int)numberOfRowsInTableView:(NSTableView *)tv{
	return [scriptHookNames count];
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
	NSString *colID = [tableColumn identifier];
	NSString *name = [scriptHookNames objectAtIndex:row];
	
	if([colID isEqualToString:@"name"]){
		return name;
	}else{
		return [[[defaults dictionaryForKey:BDSKScriptHooksKey] objectForKey:name] stringByAbbreviatingWithTildeInPath];
	}
}

- (NSString *)tableView:(NSTableView *)tv tooltipForRow:(int)row column:(int)column{
	NSString *colID = [[[tv tableColumns] objectAtIndex:column] identifier];
	
	if([colID isEqualToString:@"name"])
		return nil;
	
	NSString *name = [scriptHookNames objectAtIndex:row];
	NSString *path = [[defaults dictionaryForKey:BDSKScriptHooksKey] objectForKey:name];
	
	if ([NSString isEmptyString:path])
		return NSLocalizedString(@"No script hook associated with this action. Doubleclick or use the \"+\" button to add one.", @"");
	else
		return [[defaults dictionaryForKey:BDSKScriptHooksKey] objectForKey:name];
}

#pragma mark TableView Delegate methods

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification{
	int row = [tableView selectedRow];
	[addButton setEnabled:(row != -1)];
	[removeButton setEnabled:(row != -1)];
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(int)row{
	return NO;
}

@end
