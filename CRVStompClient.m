//
//  CRVStompClient.h
//  Objc-Stomp
//
//
//  Implements the Stomp Protocol v1.0
//  See: http://stomp.codehaus.org/Protocol
// 
//  Requires the AsyncSocket library
//  See: http://code.google.com/p/cocoaasyncsocket/
//
//  See: LICENSE
//	Stefan Saasen <stefan@coravy.com>
//  Based on StompService.{h,m} by Scott Raymond <sco@scottraymond.net>.
#import "CRVStompClient.h"

#define kStompDefaultPort			61613
#define kDefaultTimeout				5	//


// ============= http://stomp.codehaus.org/Protocol =============
#define kCommandConnect				@"CONNECT"
#define kCommandSend				@"SEND"
#define kCommandSubscribe			@"SUBSCRIBE"
#define kCommandUnsubscribe			@"UNSUBSCRIBE"
#define kCommandBegin				@"BEGIN"
#define kCommandCommit				@"COMMIT"
#define kCommandAbort				@"ABORT"
#define kCommandAck					@"ACK"
#define kCommandDisconnect			@"DISCONNECT"
#define	kControlChar				[NSString stringWithFormat:@"\n%C", 0] // TODO -> static

#define kAckClient					@"client"
#define kAckAuto					@"auto"

#define kResponseHeaderSession		@"session"
#define kResponseHeaderReceiptId	@"receipt-id"
#define kResponseHeaderErrorMessage @"message"

#define kResponseFrameConnected		@"CONNECTED"
#define kResponseFrameMessage		@"MESSAGE"
#define kResponseFrameReceipt		@"RECEIPT"
#define kResponseFrameError			@"ERROR"
// ============= http://stomp.codehaus.org/Protocol =============

#define CRV_RELEASE_SAFELY(__POINTER) { [__POINTER release]; __POINTER = nil; }

@interface CRVStompClient()
@property (nonatomic, retain) SRWebSocket *webSocket;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSString *passcode;
@property (nonatomic, copy) NSString *sessionId;
@end

@interface CRVStompClient(PrivateMethods)
- (void) sendFrame:(NSString *) command withHeader:(NSDictionary *) header andBody:(NSString *) body;
- (void) sendFrame:(NSString *) command;
- (void) readFrame;
@end

@implementation CRVStompClient

@synthesize delegate;
@synthesize webSocket, url, login, passcode, sessionId;

- (id)init {
	return [self initWithUrl:@"localhost" login:nil passcode:nil delegate:nil];
}

- (id)initWithUrl:(NSString *)theUrl
		  delegate:(id<CRVStompClientDelegate>)theDelegate
	   autoconnect:(BOOL) autoconnect {
	if(self = [self initWithUrl:theUrl login:nil passcode:nil delegate:theDelegate autoconnect: NO]) {
		anonymous = YES;
	}
	return self;
}

- (id)initWithUrl:(NSString *)theUrl 
			 login:(NSString *)theLogin 
		  passcode:(NSString *)thePasscode 
		  delegate:(id<CRVStompClientDelegate>)theDelegate {
	return [self initWithUrl:theUrl login:theLogin passcode:thePasscode delegate:theDelegate autoconnect: NO];
}

- (id)initWithUrl:(NSString *)theUrl
			 login:(NSString *)theLogin 
		  passcode:(NSString *)thePasscode 
		  delegate:(id<CRVStompClientDelegate>)theDelegate
	   autoconnect:(BOOL) autoconnect {
	if(self = [super init]) {
		
		anonymous = NO;
		doAutoconnect = autoconnect;
		
        [self setUrl:theUrl];
   /*
        NSMutableURLRequest *pushServerRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        [pushServerRequest setValue:@"websocket" forHTTPHeaderField:@"upgrade"];
        [pushServerRequest setValue:@"Upgrade" forHTTPHeaderField:@"connection"];
        webSocket = [[SRWebSocket alloc] initWithURLRequest:pushServerRequest protocols:@[@"hangies"]];
 */
        webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
        webSocket.delegate = self;
        //webSocket = theWebSocket;
		//[theWebSocket release];

		
		[self setDelegate:theDelegate];
		[self setLogin: theLogin];
		[self setPasscode: thePasscode];
		
		[webSocket open];
	}
	return self;
}

#pragma mark -
#pragma mark Public methods
- (void)connect {
	if(anonymous) {
		[self sendFrame:kCommandConnect];
	} else {
		NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: [self login], @"login", [self passcode], @"passcode", nil];
		[self sendFrame:kCommandConnect withHeader:headers andBody: nil];
	}
	[self readFrame];
}

- (void)sendMessage:(NSString *)theMessage toDestination:(NSString *)destination {
    [self sendMessage:theMessage toDestination:destination withHeaders:[NSDictionary dictionary]];
}

- (void)sendMessage:(NSString *)theMessage toDestination:(NSString *)destination withHeaders:(NSDictionary*)headers {
	NSMutableDictionary *allHeaders = [NSMutableDictionary dictionaryWithDictionary:headers];
    [allHeaders setValue:destination forKey:@"destination"];
    [self sendFrame:kCommandSend withHeader:allHeaders andBody:theMessage];
}

- (void)subscribeToDestination:(NSString *)destination {
	[self subscribeToDestination:destination withAck: CRVStompAckModeAuto];
}

- (void)subscribeToDestination:(NSString *)destination withAck:(CRVStompAckMode) ackMode {
	NSString *ack;
	switch (ackMode) {
		case CRVStompAckModeClient:
			ack = kAckClient;
			break;
		default:
			ack = kAckAuto;
			break;
	}
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: destination, @"destination", ack, @"ack", nil];
    [self sendFrame:kCommandSubscribe withHeader:headers andBody:nil];
}

- (void)subscribeToDestination:(NSString *)destination withHeader:(NSDictionary *) header {
	NSMutableDictionary *headers = [[NSMutableDictionary alloc] initWithDictionary:header];
	[headers setObject:destination forKey:@"destination"];
    [self sendFrame:kCommandSubscribe withHeader:headers andBody:nil];
	[headers release];
}

- (void)unsubscribeFromDestination:(NSString *)destination {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: destination, @"destination", nil];
    [self sendFrame:kCommandUnsubscribe withHeader:headers andBody:nil];
}

-(void)begin:(NSString *)transactionId {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: transactionId, @"transaction", nil];
    [self sendFrame:kCommandBegin withHeader:headers andBody:nil];
}

- (void)commit:(NSString *)transactionId {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: transactionId, @"transaction", nil];
    [self sendFrame:kCommandCommit withHeader:headers andBody:nil];
}

- (void)abort:(NSString *)transactionId {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: transactionId, @"transaction", nil];
    [self sendFrame:kCommandAbort withHeader:headers andBody:nil];
}

- (void)ack:(NSString *)messageId {
	NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: messageId, @"message-id", nil];
    [self sendFrame:kCommandAck withHeader:headers andBody:nil];
}

- (void)disconnect {
	[self sendFrame:kCommandDisconnect];
	[[self webSocket] close];
    //[[self socket] disconnectAfterReadingAndWriting];
}


#pragma mark -
#pragma mark PrivateMethods
- (void) sendFrame:(NSString *) command withHeader:(NSDictionary *) header andBody:(NSString *) body {
    NSMutableString *frameString = [NSMutableString stringWithString: [command stringByAppendingString:@"\n"]];	
	for (id key in header) {
		[frameString appendString:key];
		[frameString appendString:@":"];
		[frameString appendString:[header objectForKey:key]];
		[frameString appendString:@"\n"];
	}
	if (body) {
		[frameString appendString:@"\n"];
		[frameString appendString:body];
	}
    [frameString appendString:kControlChar];
	[[self webSocket] send:[frameString dataUsingEncoding:NSUTF8StringEncoding]];
    //[[self socket] writeData:[frameString dataUsingEncoding:NSUTF8StringEncoding] withTimeout:kDefaultTimeout tag:123];
}

- (void) sendFrame:(NSString *) command {
	[self sendFrame:command withHeader:nil andBody:nil];
}

- (void)receiveFrame:(NSString *)command headers:(NSDictionary *)headers body:(NSString *)body {
	//NSLog(@"receiveCommand '%@' [%@], @%", command, headers, body);
	
	// Connected
	if([kResponseFrameConnected isEqual:command]) {
		if([[self delegate] respondsToSelector:@selector(stompClientDidConnect:)]) {
			[[self delegate] stompClientDidConnect:self];
		}
		
		// store session-id
		NSString *sessId = [headers valueForKey:kResponseHeaderSession];
		[self setSessionId: sessId];
	
	// Response 
	} else if([kResponseFrameMessage isEqual:command]) {
		[[self delegate] stompClient:self messageReceived:body withHeader:headers];
		
	// Receipt
	} else if([kResponseFrameReceipt isEqual:command]) {		
		if([[self delegate] respondsToSelector:@selector(serverDidSendReceipt:withReceiptId:)]) {
			NSString *receiptId = [headers valueForKey:kResponseHeaderReceiptId];
			[[self delegate] serverDidSendReceipt:self withReceiptId: receiptId];
		}	
	
	// Error
	} else if([kResponseFrameError isEqual:command]) {
		if([[self delegate] respondsToSelector:@selector(serverDidSendError:withErrorMessage:detailedErrorMessage:)]) {
			NSString *msg = [headers valueForKey:kResponseHeaderErrorMessage];
			[[self delegate] serverDidSendError:self withErrorMessage: msg detailedErrorMessage: body];
		}		
	}
}

- (void)readFrame {
//	[[self socket] readDataToData:[AsyncSocket ZeroData] withTimeout:-1 tag:0];
}

#pragma mark -
#pragma mark SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message{
    NSLog(@"didReceiveMessage \n Message: %@", message);
	/*NSString *msg = message;
    NSMutableArray *contents = (NSMutableArray *)[[msg componentsSeparatedByString:@"\n"] mutableCopy];
	if([[contents objectAtIndex:0] isEqual:@""]) {
		[contents removeObjectAtIndex:0];
	}
	NSString *command = [[[contents objectAtIndex:0] copy] autorelease];
	NSMutableDictionary *headers = [[[NSMutableDictionary alloc] init] autorelease];
	NSMutableString *body = [[[NSMutableString alloc] init] autorelease];
	BOOL hasHeaders = NO;
    [contents removeObjectAtIndex:0];
	for(NSString *line in contents) {
		if(hasHeaders) {
			[body appendString:line];
		} else {
			if ([line isEqual:@""]) {
				hasHeaders = YES;
			} else {
				// message-id can look like this: message-id:ID:macbook-pro.local-50389-1237007652070-5:6:-1:1:1
				NSMutableArray *parts = [NSMutableArray arrayWithArray:[line componentsSeparatedByString:@":"]];
				// key ist the first part
				NSString *key = [parts objectAtIndex:0];
				[parts removeObjectAtIndex:0];
				[headers setObject:[parts componentsJoinedByString:@":"] forKey:key];
			}
		}
	}
	[msg release];
	[self receiveFrame:command headers:headers body:body];
	[self readFrame];
	[contents release];*/
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket{
    NSLog(@"webSocketDidOpen");
	if(doAutoconnect) {
		[self connect];
	}
}
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error{
    NSLog(@"didFailWithError");
    NSLog([error description]);
}
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean{
    NSLog(@"didCloseWithCode");
    NSLog(@"reaseon: %@, code: %d",reason, code);
}

/*
- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
	if(doAutoconnect) {
		[self connect];
	}
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag {
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock {
	if([[self delegate] respondsToSelector:@selector(stompClientDidDisconnect:)]) {
		[[self delegate] stompClientDidDisconnect: self];
	}
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err {
	if([[self delegate] respondsToSelector:@selector(stompClientWillDisconnect:withError:)]) {
		[[self delegate] stompClientWillDisconnect:self withError:err];
	}
}
*/

#pragma mark -
#pragma mark Memory management
-(void) dealloc {
	delegate = nil;
    webSocket.delegate = nil;
	[webSocket release];
    
	CRV_RELEASE_SAFELY(passcode);
	CRV_RELEASE_SAFELY(login);
//	CRV_RELEASE_SAFELY(host);
	CRV_RELEASE_SAFELY(url);

	[super dealloc];
}

@end
