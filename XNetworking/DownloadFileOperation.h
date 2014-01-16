//
//  DownloadFileOperation.h
//  XNetworking
//
//  Created by Tim Monroe on 1/8/14.
//  Copyright (c) 2014 Tim Monroe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NetworkInvocationOperation.h"


@interface DownloadFileOperation : NetworkInvocationOperation

- (DownloadFileOperation *)initWithSrcDirectoryURL:(NSString *)srcDirectoryURL downloadFileName:(NSString *)downloadFileName userName:(NSString *)userName password:(NSString *)password;

@property(nonatomic, readonly) NSString* downloadDirectory;
@property(nonatomic, readonly) NSURL* downloadDirectoryURL;
@property(nonatomic, readonly) NSString* downloadFile;

@end
