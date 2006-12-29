//
//  BDSKSearchGroupSheetController.m
//  Bibdesk
//
//  Created by Adam Maxwell on 12/26/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "BDSKSearchGroupSheetController.h"
#import "BDSKSearchGroup.h"

static NSArray *searchGroupServers = nil;

@implementation BDSKSearchGroupSheetController

+ (void)initialize {
    searchGroupServers = [[NSArray alloc] initWithContentsOfFile:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"SearchGroupServers.plist"]];
}

- (id)init {
    return [self initWithGroup:nil];
}

- (id)initWithGroup:(BDSKSearchGroup *)aGroup;
{
    if (self = [super init]) {
        group = [aGroup retain];
        editors = CFArrayCreateMutable(kCFAllocatorMallocZone, 0, NULL);
        undoManager = nil;
        
        NSDictionary *info = group ? [group serverInfo] : [[searchGroupServers objectAtIndex:BDSKSearchGroupEntrez] objectAtIndex:0];
        type = [group type];
        address = [[info objectForKey:@"host"] copy];
        port = [[info objectForKey:@"port"] copy];
        database = [[info objectForKey:@"database"] copy];
        username = [[info objectForKey:@"username"] copy];
        password = [[info objectForKey:@"password"] copy];
    }
    return self;
}

- (void)dealloc
{
    [group release];
    [undoManager release];
    [address release];
    [port release];
    [database release];
    [username release];
    [password release];
    CFRelease(editors);    
    [super dealloc];
}

- (NSString *)windowNibName { return @"BDSKSearchGroupSheet"; }

- (void)awakeFromNib
{
    BOOL isCustom = [serverPopup indexOfSelectedItem] == [serverPopup numberOfItems] - 1;
    BOOL isZoom = type == BDSKSearchGroupZoom;
    NSArray *servers = [searchGroupServers objectAtIndex:type];
    
    [addressField setEnabled:isCustom && isZoom];
    [portField setEnabled:isCustom && isZoom];
    [databaseField setEnabled:isCustom];
    [userField setEnabled:isCustom && isZoom];
    [passwordField setEnabled:isCustom && isZoom];
    
    [serverPopup removeAllItems];
    [serverPopup addItemsWithTitles:[servers valueForKey:@"name"]];
    [[serverPopup menu] addItem:[NSMenuItem separatorItem]];
    [serverPopup addItemWithTitle:NSLocalizedString(@"Other", @"Popup menu item name for other search group server")];
    [serverPopup selectItemAtIndex:0];
}

- (void)setDefaultValues{
    NSArray *servers = [searchGroupServers objectAtIndex:type];
    [serverPopup removeAllItems];
    [serverPopup addItemsWithTitles:[servers valueForKey:@"name"]];
    [[serverPopup menu] addItem:[NSMenuItem separatorItem]];
    [serverPopup addItemWithTitle:NSLocalizedString(@"Other", @"Popup menu item name for other search group server")];
    [serverPopup selectItemAtIndex:0];
    
    NSDictionary *host = [servers objectAtIndex:0];
    
    [self setAddress:[host objectForKey:@"host"]];
    [self setPort:[host objectForKey:@"port"]];
    [self setDatabase:[host objectForKey:@"database"]];
    [self setUsername:nil];
    [self setPassword:nil];
    
    [addressField setEnabled:NO];
    [portField setEnabled:NO];
    [databaseField setEnabled:NO];
    
    [userField setEnabled:NO];
    [passwordField setEnabled:NO];
}

- (BDSKSearchGroup *)group { return group; }

- (IBAction)dismiss:(id)sender {
    if ([sender tag] == NSOKButton) {
        
        if ([self commitEditing] == NO) {
            NSBeep();
            return;
        }
                
        NSMutableDictionary *serverInfo = [NSMutableDictionary dictionaryWithCapacity:6];
        [serverInfo setValue:[NSNumber numberWithInt:type] forKey:@"type"];
        [serverInfo setValue:[self database] forKey:@"database"];
        if(type == BDSKSearchGroupZoom){
            [serverInfo setValue:[self address] forKey:@"host"];
            [serverInfo setValue:[self database] forKey:@"database"];
            [serverInfo setValue:[self port] forKey:@"port"];
            [serverInfo setValue:[self password] forKey:@"password"];
            [serverInfo setValue:[self username] forKey:@"username"];
        }
        
        // we don't have a group, so create  a new one
        if(group == nil){
            group = [[BDSKSearchGroup alloc] initWithType:type serverInfo:serverInfo searchTerm:nil];
        }else{
            [group setServerInfo:serverInfo];
            [[group undoManager] setActionName:NSLocalizedString(@"Edit Search Group", @"Undo action name")];
        }
    }
    
    [super dismiss:sender];
}

- (IBAction)selectPredefinedServer:(id)sender;
{
    int i = [sender indexOfSelectedItem];
    if (i == [sender numberOfItems] - 1) {
        [addressField setEnabled:type == BDSKSearchGroupZoom];
        [portField setEnabled:type == BDSKSearchGroupZoom];
        [databaseField setEnabled:YES];
        [passwordField setEnabled:YES];
        [userField setEnabled:YES];
    } else {
        NSArray *servers = [searchGroupServers objectAtIndex:type];
        NSDictionary *host = [servers objectAtIndex:i];
        [self setAddress:[host objectForKey:@"host"]];
        [self setPort:[host objectForKey:@"port"]];
        [self setDatabase:[host objectForKey:@"database"]];
        [addressField setEnabled:NO];
        [portField setEnabled:NO];
        [databaseField setEnabled:NO];
        [passwordField setEnabled:NO];
        [userField setEnabled:NO];
    }
}

- (NSString *)address {
    return address;
}

- (void)setAddress:(NSString *)newAddress {
    if(address != newAddress){
        [address release];
        address = [newAddress copy];
    }
}

- (BOOL)validateAddress:(id *)value error:(NSError **)error {
    NSString *string = *value;
    NSRange range = [string rangeOfString:@"://"];
    if(range.location != NSNotFound){
        // ZOOM gets confused when the host has a protocol
        string = [string substringFromIndex:NSMaxRange(range)];
    }
    // split address:port/dbase in components
    range = [string rangeOfString:@"/"];
    if(range.location != NSNotFound){
        [self setDatabase:[string substringFromIndex:NSMaxRange(range)]];
        [databaseField setStringValue:database];
        string = [string substringToIndex:range.location];
    }
    range = [string rangeOfString:@":"];
    if(range.location != NSNotFound){
        [self setPort:[string substringFromIndex:NSMaxRange(range)]];
        [portField setStringValue:port];
        string = [string substringToIndex:range.location];
    }
    *value = string;
    return YES;
}

- (NSString *)database {
    return database;
}

- (void)setDatabase:(NSString *)newDb {
    if(database != newDb){
        [database release];
        database = [newDb copy];
    }
}
  
- (NSString *)port {
    return port;
}
  
- (void)setPort:(NSString *)newPort {
    if(port != newPort){
        [port release];
        port = [newPort retain];
    }
}

- (BOOL)validatePort:(id *)value error:(NSError **)error {
    if (nil != *value)
        *value = [NSString stringWithFormat:@"%i", [*value intValue]];
    return YES;
}
  
- (int)type {
    return type;
}
  
- (void)setType:(int)newType {
    if(type != newType) {
        type = newType;
        [self setDefaultValues];
    }
}

- (void)setUsername:(NSString *)user
{
    [username autorelease];
    username = [user copy];
}

- (NSString *)username { return username; }

- (void)setPassword:(NSString *)pw
{
    [password autorelease];
    password = [pw copy];
}

- (NSString *)password { return password; }

#pragma mark NSEditorRegistration

- (void)objectDidBeginEditing:(id)editor {
    if (CFArrayGetFirstIndexOfValue(editors, CFRangeMake(0, CFArrayGetCount(editors)), editor) == -1)
		CFArrayAppendValue((CFMutableArrayRef)editors, editor);		
}

- (void)objectDidEndEditing:(id)editor {
    CFIndex index = CFArrayGetFirstIndexOfValue(editors, CFRangeMake(0, CFArrayGetCount(editors)), editor);
    if (index != -1)
		CFArrayRemoveValueAtIndex((CFMutableArrayRef)editors, index);		
}

- (BOOL)commitEditing {
    CFIndex index = CFArrayGetCount(editors);
    
	while (index--)
		if([(NSObject *)(CFArrayGetValueAtIndex(editors, index)) commitEditing] == NO)
        return NO;
    
    NSString *message = nil;
    
    if (type == 0 && [NSString isEmptyString:database]) {
        message = NSLocalizedString(@"Unable to create a search group with an empty database", @"Informative text in alert dialog when search group is invalid");
    } else if (type == 1 && ([NSString isEmptyString:address] || [NSString isEmptyString:database] || port == 0)) {
        message = NSLocalizedString(@"Unable to create a search group with an empty address, database or port", @"Informative text in alert dialog when search group is invalid");
    }
    if (message) {
        NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Empty value", @"Message in alert dialog when data for a search group is invalid")
                                         defaultButton:nil
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:message];
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:NULL contextInfo:NULL];
        return NO;
    }
    return YES;
}

#pragma mark Undo support

- (NSUndoManager *)undoManager{
    if(undoManager == nil)
        undoManager = [[NSUndoManager alloc] init];
    return undoManager;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender{
    return [self undoManager];
}


@end
