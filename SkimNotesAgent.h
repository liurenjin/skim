/*
 *  SkimNotesAgent.h
 *  SkimNotesAgent
 *
 *  Created by Adam Maxwell on 04/10/07.
 *  Copyright 2007 __MyCompanyName__. All rights reserved.
 *
 */

@protocol ListenerProtocol

- (bycopy NSData *)RTFNotesAtPath:(in bycopy NSString *)aFile;
- (bycopy NSString *)textNotesAtPath:(in bycopy NSString *)aFile;

@end
