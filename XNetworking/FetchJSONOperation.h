//
//  FetchJSONOperation.h
//  XNetworking
//
//  Created by Tim Monroe on 1/8/14.
//  Copyright (c) 2014 Tim Monroe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NetworkInvocationOperation.h"


@interface FetchJSONOperation : NetworkInvocationOperation

- (FetchJSONOperation *)initWithSrcDirectoryURL:(NSString *)srcDirectoryURL jsonFile:(NSString *)jsonFile userName:(NSString *)userName password:(NSString *)password;

// error parameter is optional
- (id)jsonWithError:(NSError **)error;

@end
