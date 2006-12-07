/*
This software is Copyright (c) 2002, Michael O. McCracken
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
-  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
-  Neither the name of Michael O. McCracken nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "BibPref_Defaults.h"

@implementation BibPref_Defaults

- (void)awakeFromNib{
    [super awakeFromNib];

    defaultFieldsArray = [[NSMutableArray arrayWithCapacity:6] retain];
    [defaultFieldsArray setArray:[defaults arrayForKey:BDSKDefaultFieldsKey]];
    
}

- (void)updateUI{
    [outputTemplateFileButton setTitle:[[defaults stringForKey:BDSKOutputTemplateFileKey] stringByAbbreviatingWithTildeInPath]];
}


- (void)dealloc{
    [defaultFieldsArray release];
}


#pragma mark ||  Methods to support table view of default fields.

- (int)numberOfRowsInTableView:(NSTableView *)tView{
    return [defaultFieldsArray count];
}
    - (id)tableView:(NSTableView *)tView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row{
    return [defaultFieldsArray objectAtIndex:row];
}
    // defaultFieldStuff
- (IBAction)delSelectedDefaultField:(id)sender{
    if([defaultFieldsTableView numberOfSelectedRows] != 0){
        [defaultFieldsArray removeObjectAtIndex:[defaultFieldsTableView selectedRow]];
        [defaultFieldsTableView reloadData];
        [defaults setObject:defaultFieldsArray
                     forKey:BDSKDefaultFieldsKey];
    }
}
- (IBAction)addDefaultField:(id)sender{
    [defaultFieldsArray addObject:[[addFieldField stringValue] capitalizedString]];  // ARM: force uppercase, otherwise the user will end up with an upper and lower case field
    [defaultFieldsTableView reloadData];
    [defaults setObject:defaultFieldsArray
                 forKey:BDSKDefaultFieldsKey];
    [addFieldField setStringValue:@""];
}
    // changes the template file:
- (IBAction)outputTemplateButtonPressed:(id)sender{
    [[NSWorkspace sharedWorkspace] openFile:
        [[defaults stringForKey:BDSKOutputTemplateFileKey] stringByExpandingTildeInPath]
                            withApplication:@"TextEdit"];
}

@end
