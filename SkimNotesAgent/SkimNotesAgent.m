#import <AppKit/AppKit.h>
#import "NSFileManager_ExtendedAttributes.h"
#import "SkimNotesAgent.h"

@interface Listener : NSObject
{
    NSConnection *_connection;
}
- (id)initWithServerName:(NSString *)serverName;
- (void)_destroyConnection;
@end

@implementation Listener

- (id)initWithServerName:(NSString *)serverName;
{
    self = [super init];
    if (self) {
        _connection = [[NSConnection alloc] initWithReceivePort:[NSPort port] sendPort:nil];
        NSProtocolChecker *checker = [NSProtocolChecker protocolCheckerWithTarget:self protocol:@protocol(ListenerProtocol)];
        [_connection setRootObject:checker];
        [_connection setDelegate:self];
        
        // user can pass nil, in which case we generate a server name to be read from standard output
        if (nil == serverName)
            serverName = [[NSProcessInfo processInfo] globallyUniqueString];

        if ([_connection registerName:serverName] == NO) {
            NSLog(@"failed to register connection; another agent process must be running");
            [self _destroyConnection];
            [self release];
            self = nil;
        }
        NSFileHandle *fh = [NSFileHandle fileHandleWithStandardOutput];
        [fh writeData:[serverName dataUsingEncoding:NSUTF8StringEncoding]];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (bycopy NSData *)RTFNotesAtPath:(in bycopy NSString *)aFile;
{
    NSError *error;
    NSData *data = [[NSFileManager defaultManager] extendedAttributeNamed:@"net_sourceforge_skim-app_rtf_notes" atPath:[aFile stringByStandardizingPath] traverseLink:YES error:&error];
    if (nil == data && [error code] != ENOATTR)
        NSLog(@"%@", error);
    return data;
}

- (bycopy NSString *)textNotesAtPath:(in bycopy NSString *)aFile;
{
    NSError *error;
    NSString *string = nil;
    NSData *data = [[NSFileManager defaultManager] extendedAttributeNamed:@"net_sourceforge_skim-app_text_notes" atPath:[aFile stringByStandardizingPath] traverseLink:YES error:&error];
    if (nil == data && [error code] != ENOATTR)
        NSLog(@"%@", error);
    else
        string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    return string;
}

- (void)_destroyConnection;
{
    [_connection registerName:nil];
    [[_connection receivePort] invalidate];
    [[_connection sendPort] invalidate];
    [_connection invalidate];
    [_connection release];
    _connection = nil;
}

- (void)portDied:(id)obj
{
    [self _destroyConnection];
    exit(0);
}

// first app to connect will be the owner of this instance of the program; when the connection dies, so do we
- (BOOL)makeNewConnection:(NSConnection *)newConnection sender:(NSConnection *)parentConnection
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(portDied:) name:NSPortDidBecomeInvalidNotification object:[newConnection sendPort]];
    return YES;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification;
{
    [self _destroyConnection];
}

@end

int main (int argc, const char * argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    NSString *serverName = [args count] > 1 ? [args lastObject] : nil;
    Listener *listener = [[Listener alloc] initWithServerName:serverName];

    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    BOOL didRun;
    NSDate *distantFuture = [NSDate distantFuture];
    NSAutoreleasePool *__pool = [NSAutoreleasePool new];
    
    do {
        [__pool release];
        __pool = [NSAutoreleasePool new];
        didRun = [rl runMode:NSDefaultRunLoopMode beforeDate:distantFuture];
    } while (listener && didRun);
    [__pool release];
    
    [listener release];
    [pool release];
    return 0;
}
