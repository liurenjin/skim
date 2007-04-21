/*
 *  SkimNotesAgent.m
 *
 *  Created by Adam Maxwell on 04/10/07.
 *
 This software is Copyright (c) 2007
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
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


#import <AppKit/AppKit.h>
#import "NSFileManager_ExtendedAttributes.h"
#import "SkimNotesAgent.h"

@interface SKAgentListener : NSObject
{
    NSConnection *connection;
}
- (id)initWithServerName:(NSString *)serverName;
- (void)destroyConnection;
@end

@implementation SKAgentListener

- (id)initWithServerName:(NSString *)serverName;
{
    self = [super init];
    if (self) {
        connection = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:nil];
        NSProtocolChecker *checker = [NSProtocolChecker protocolCheckerWithTarget:self protocol:@protocol(SKAgentListenerProtocol)];
        [connection setRootObject:checker];
        [connection setDelegate:self];
        
        // user can pass nil, in which case we generate a server name to be read from standard output
        if (nil == serverName)
            serverName = [[NSProcessInfo processInfo] globallyUniqueString];

        if ([connection registerName:serverName] == NO) {
            fprintf(stderr, "SkimNotesAgent pid %d: unable to register connection name %s; another process must be running\n", getpid(), [serverName UTF8String]);
            [self destroyConnection];
            [self release];
            self = nil;
        }
        NSFileHandle *fh = [NSFileHandle fileHandleWithStandardOutput];
        [fh writeData:[serverName dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self destroyConnection];
    [super dealloc];
}

- (bycopy NSData *)SkimNotesAtPath:(in bycopy NSString *)aFile;
{
    NSError *error;
    NSData *data = [[NSFileManager defaultManager] extendedAttributeNamed:@"net_sourceforge_skim-app_notes" atPath:[aFile stringByStandardizingPath] traverseLink:YES error:&error];
    if (nil == data && [error code] != ENOATTR)
        fprintf(stderr, "SkimNotesAgent pid %d: error getting Skim notes (%s)\n", getpid(), [[error description] UTF8String]);
    return data;
}

- (bycopy NSData *)RTFNotesAtPath:(in bycopy NSString *)aFile;
{
    NSError *error;
    NSData *data = [[NSFileManager defaultManager] extendedAttributeNamed:@"net_sourceforge_skim-app_rtf_notes" atPath:[aFile stringByStandardizingPath] traverseLink:YES error:&error];
    if (nil == data && [error code] != ENOATTR)
        fprintf(stderr, "SkimNotesAgent pid %d: error getting RTF notes (%s)\n", getpid(), [[error description] UTF8String]);
    return data;
}

- (bycopy NSString *)textNotesAtPath:(in bycopy NSString *)aFile;
{
    NSError *error;
    NSString *string = nil;
    NSData *data = [[NSFileManager defaultManager] extendedAttributeNamed:@"net_sourceforge_skim-app_text_notes" atPath:[aFile stringByStandardizingPath] traverseLink:YES error:&error];
    if (nil == data && [error code] != ENOATTR)
        fprintf(stderr, "SkimNotesAgent pid %d: error getting RTF notes (%s)\n", getpid(), [[error description] UTF8String]);
    else
        string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    return string;
}

- (void)destroyConnection;
{
    [connection registerName:nil];
    [[connection receivePort] invalidate];
    [[connection sendPort] invalidate];
    [connection invalidate];
    [connection release];
    connection = nil;
}

- (void)portDied:(NSNotification *)notification
{
    [self destroyConnection];
    fprintf(stderr, "SkimNotesAgent pid %d dying because port %s is invalid\n", getpid(), [[[notification object] description] UTF8String]);
    exit(0);
}

// first app to connect will be the owner of this instance of the program; when the connection dies, so do we
- (BOOL)makeNewConnection:(NSConnection *)newConnection sender:(NSConnection *)parentConnection
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(portDied:) name:NSPortDidBecomeInvalidNotification object:[newConnection sendPort]];
    fprintf(stderr, "SkimNotesAgent pid %d connection registered\n", getpid());
    return YES;
}

@end

int main (int argc, const char * argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    NSString *serverName = [args count] > 1 ? [args lastObject] : nil;
    SKAgentListener *listener = [[SKAgentListener alloc] initWithServerName:serverName];

    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    BOOL didRun;
    NSDate *distantFuture = [NSDate distantFuture];
    NSAutoreleasePool *runpool = [NSAutoreleasePool new];
    
    do {
        [runpool release];
        runpool = [NSAutoreleasePool new];
        didRun = [rl runMode:NSDefaultRunLoopMode beforeDate:distantFuture];
    } while (listener && didRun);
    [runpool release];
    
    [listener release];
    [pool release];
    return 0;
}
