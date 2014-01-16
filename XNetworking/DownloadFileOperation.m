//
//  DownloadFileOperation.m
//  XNetworking
//
//  Created by Tim Monroe on 1/8/14.
//  Copyright (c) 2014 Tim Monroe. All rights reserved.
//

#import "DownloadFileOperation.h"


NSString* kXNetworking_DownloadTaskSessionIdentifierPrefix = @"XNetworkingDownloadTaskSessionIdentifier_";


////////////////////////////////////////////////////////////////////////////////
//
//  DownloadFileOperation class implementation
//
/////////////////////////////////////////////////////////////////////////////////
#pragma mark - DownloadFileOperation class implementation

@interface DownloadFileOperation () <NSURLSessionDownloadDelegate>
{
}

@end


@implementation DownloadFileOperation
{
@private
    NSURLSessionConfiguration* _downloadTaskConfigObject;
    NSURLSession* _downloadTaskSession;
    
    NSString* _downloadDirectory;
    NSURL* _downloadDirectoryURL;
}

- (void)dealloc
{
    _downloadTaskConfigObject = Nil;
    // Allow outstanding tasks to finish before invalidating the object.
    // After invalidating the session, when all outstanding tasks have been canceled or have finished,
    // the session sends the delegate a URLSession:didBecomeInvalidWithError: message. When that delegate method returns,
    // the session disposes of its strong reference to the delegate.
    // The session object keeps a strong reference to the delegate until your app explicitly invalidates the session.
    // If you do not invalidate the session, your app leaks memory.
    //[_downloadTaskSession finishTasksAndInvalidate];
    
    // Cancels all outstanding tasks and then invalidates the session object.
    // Once invalidated, references to the delegate and callback objects are broken. Session objects cannot be reused.
    [_downloadTaskSession invalidateAndCancel];
    _downloadTaskSession = Nil;  // ??
    
    _downloadDirectory = Nil;
    _downloadDirectoryURL = Nil;
}


/*********************** Private DownloadFileOperation Properties/Methods ***********************/



/*********************** Overriding Public NetworkInvocationOperation Properties/Methods ***********************/

// Execute the HTTP request
- (void)operationMethod:(id)data
{
    // Important: call super first to flag the Operation as executing
    [super operationMethod:data];
    
    NSString* srcFile = [self.srcDirectoryURL stringByAppendingString:self.srcFileName];
    NSURL* url = [NSURL URLWithString:srcFile];
    NSURLSessionDownloadTask* downloadTask = [_downloadTaskSession downloadTaskWithURL:url];
    if (downloadTask) [downloadTask resume];
    else [self completed];  // flag the Operation as completed
}


/*********************** Public DownloadFileOperation Properties/Methods ***********************/

- (DownloadFileOperation *)initWithSrcDirectoryURL:(NSString *)srcDirectoryURL downloadFileName:(NSString *)downloadFileName userName:(NSString *)userName password:(NSString *)password;
{
    self = [super initWithTarget:self selector:@selector(operationMethod:) object:Nil];
    if (self)
    {
        if (!srcDirectoryURL || !downloadFileName) return Nil;
        [self setSrcDirectoryURL:srcDirectoryURL srcFileName:downloadFileName userName:userName password:password];
        
        // Get the download directory
        NSArray* myPathList = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString* myCachePath = [myPathList objectAtIndex:0];
        NSString* bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        _downloadDirectory = [myCachePath stringByAppendingPathComponent:bundleIdentifier];
        if (!_downloadDirectory) return Nil;
        _downloadDirectoryURL = [NSURL fileURLWithPath:_downloadDirectory];
        if (!_downloadDirectoryURL) return Nil;
        
        // Build the identifier
        // Note: this string needs to be unique
        NSString* identifier = kXNetworking_DownloadTaskSessionIdentifierPrefix;
        identifier = [identifier stringByAppendingString:downloadFileName];
        identifier = [identifier stringByAppendingString:@"_"];
        identifier = [identifier stringByAppendingString:[NSDate date].description];
        NSUInteger number = random();
        NSString* randomNumber = [NSString stringWithFormat:@"%lu", number];
        identifier = [identifier stringByAppendingString:@"_"];
        identifier = [identifier stringByAppendingString:randomNumber];
        
        // Create the Download Task Configuration object
        _downloadTaskConfigObject = [NSURLSessionConfiguration backgroundSessionConfiguration:identifier];
        if (!_downloadTaskConfigObject) return Nil;
        
        // Create the Session for the Download Task Configuration
        _downloadTaskSession = [NSURLSession sessionWithConfiguration:_downloadTaskConfigObject delegate:self delegateQueue:self.operationQueue];
        if (!_downloadTaskSession) return Nil;
        
    }
    return self;
}

- (NSString *)downloadDirectory { return _downloadDirectory; }

- (NSURL *)downloadDirectoryURL { return _downloadDirectoryURL; }

- (NSString *)downloadFile
{
    NSString* downloadDirectory = self.downloadDirectory;
    NSString* srcFileName = self.srcFileName;
    NSString* downloadFile = [downloadDirectory stringByAppendingString:@"/"];
    downloadFile = [downloadFile stringByAppendingString:srcFileName];
    return downloadFile;
}


/*********************** Implement NSURLSessionDownloadDelegate Methods ***********************/

// Tells the delegate that the download task has resumed downloading. (required)
// Usage Notes:
// If a resumable download task is canceled or fails, the app can request a resumeData object that provides enough information to restart the download in the future.
// Later, the app can call downloadTaskWithResumeData: or downloadTaskWithResumeData:completionHandler: with that data. Those calls return a new download task,
// and the delegate’s URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes: method is called with the new task to indicate that the download is resumed.
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes
{
    //NSLog(@"Session %@ download task %@ resumed at offset %lld bytes out of an expected %lld bytes.\n", session, downloadTask, fileOffset, expectedTotalBytes);
}

// Periodically informs the delegate about the download’s progress. (required)
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    //NSLog(@"Session %@ download task %@ wrote an additional %lld bytes (total %lld bytes) out of an expected %lld bytes.\n", session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
}

// Tells the delegate that a download task has finished downloading. (required)
// Usage Notes:
// A file URL where the temporary file can be found. Because the file is temporary, your delegate method must either open the file for reading
// or move it to a permanent location in your app’s sandbox container directory before returning.  If you choose to open the file for reading,
// you should do the actual reading in another thread to avoid blocking the delegate queue.
// When this method returns, the temporary file is deleted if it still exists at its original location.
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    // Append the filename to the download directory
    NSURL* destFileURL = [_downloadDirectoryURL URLByAppendingPathComponent:self.srcFileName];
    if (!destFileURL) return;
    
    // Move the downloaded file to the download directory
    NSError* error = nil;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    BOOL success = [fileManager moveItemAtURL:location toURL:destFileURL error:&error];
    
    // Make a copy of the error for the caller
    if (!success) self.error = error;
}

@end
