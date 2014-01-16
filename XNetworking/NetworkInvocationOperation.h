//
//  NetworkInvocationOperation.h
//  XNetworking
//
//  Created by Tim Monroe on 1/8/14.
//  Copyright (c) 2014 Tim Monroe. All rights reserved.
//

#import <Foundation/Foundation.h>


// Note: NetworkInvocationOperation is an abstract base class

@interface NetworkInvocationOperation : NSInvocationOperation <NSURLSessionTaskDelegate>

@property(nonatomic, readonly) NSOperationQueue* operationQueue;
- (void)operationMethod:(id)data;
- (void)completed;

@property(nonatomic, readonly) dispatch_time_t semaWaitTime;

- (NSError *)errorFromStatusCode:(NSInteger)statusCode;
- (NSError *)customErrorFromStatusCode:(NSInteger)statusCode message:(NSString *)message;
@property(nonatomic, readwrite) NSError* error;

- (void)setSrcDirectoryURL:(NSString *)srcDirectoryURL srcFileName:(NSString *)srcFileName userName:(NSString *)userName password:(NSString *)password;
@property(nonatomic, readwrite) NSString* srcDirectoryURL;
@property(nonatomic, readwrite) NSString* srcFileName;
@property(nonatomic, readwrite) NSString* userName;
@property(nonatomic, readwrite) NSString* password;

@end
