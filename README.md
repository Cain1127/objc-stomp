STOMP client for Objective-C over WebSocket
============================================

objc-stomp/WebSocket is a simple [STOMP](http://stomp.github.io) client that works over [WebSocket](http://www.websocket.org). It is an adaptation of the TCP-socket-based [objc-stomp](https://github.com/juretta/objc-stomp) library (which in-turn uses the [AsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) library.)

objc-stomp/WebSocket uses the [SocketRocket](https://github.com/square/SocketRocket) library.

Usage
-----

Add CRVStompClient.{h,m} to your project, and add the library SocketRocket.

MyExample.h

	#import <Foundation/Foundation.h>
	
	@class CRVStompClient;
	@protocol CRVStompClientDelegate;


	@interface MyExample : NSObject<CRVStompClientDelegate> {
    	@private
		CRVStompClient *service;
	}
	@property(nonatomic, retain) CRVStompClient *service;

	@end


In MyExample.m

	#define kUsername	@"USERNAME"
	#define kPassword	@"PASS"
	#define kQueueName	@"/topic/systemMessagesTopic"

	[...]

	-(void) aMethod {
		CRVStompClient *s = [[CRVStompClient alloc] 
				initWithHost:@"localhost" 
						port:61613 
						login:kUsername
					passcode:kQueueName
					delegate:self];
		[s connect];
	

		NSDictionary *headers = [NSDictionary dictionaryWithObjectsAndKeys: 	
				@"client", @"ack", 
				@"true", @"activemq.dispatchAsync",
				@"1", @"activemq.prefetchSize", nil];
		[s subscribeToDestination:kQueueName withHeader: headers];
	
		[self setService: s];
		[s release];
	}
	
	#pragma mark CRVStompClientDelegate
	- (void)stompClientDidConnect:(CRVStompClient *)stompService {
			NSLog(@"stompServiceDidConnect");
	}

	- (void)stompClient:(CRVStompClient *)stompService messageReceived:(NSString *)body withHeader:(NSDictionary *)messageHeader {
		NSLog(@"gotMessage body: %@, header: %@", body, messageHeader);
		NSLog(@"Message ID: %@", [messageHeader valueForKey:@"message-id"]);
		// If we have successfully received the message ackknowledge it.
		[stompService ack: [messageHeader valueForKey:@"message-id"]];
	}
	
	- (void)dealloc {
		[service unsubscribeFromDestination: kQueueName];
		[service release];
		[super dealloc];
	}
	
Contributors
------------

* Scott Raymond
* Stefan Saasen
* Graham Haworth
* jbg
* [Néstor Malet](https://github.com/nmaletm)

