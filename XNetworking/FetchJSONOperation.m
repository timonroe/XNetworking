//
//  FetchJSONOperation.m
//  XNetworking
//
//  Created by Tim Monroe on 1/8/14.
//  Copyright (c) 2014 Tim Monroe. All rights reserved.
//

#import "FetchJSONOperation.h"


/*
// Note: these default values are somewhat random - copied from Apple sample app
const NSUInteger kXNetworking_CacheMemoryCapacity = 16384;
const NSUInteger kXNetworking_CacheDiskCapacity = 268435456;
*/


////////////////////////////////////////////////////////////////////////////////
//
//  FetchJSONOperation class implementation
//
/////////////////////////////////////////////////////////////////////////////////
#pragma mark - FetchJSONOperation class implementation

@interface FetchJSONOperation () <NSURLSessionDataDelegate>
{
}

@property(nonatomic, readwrite) id json;

@end


@implementation FetchJSONOperation
{
@private
    dispatch_semaphore_t _dsemaJson;
    
    id _json;
    
    NSMutableData* _data;
    
    NSURLSessionConfiguration* _dataTaskConfigObject;
    NSURLSession* _dataTaskSession;
}

- (void)dealloc
{
    // Allow outstanding tasks to finish before invalidating the object.
    // After invalidating the session, when all outstanding tasks have been canceled or have finished,
    // the session sends the delegate a URLSession:didBecomeInvalidWithError: message. When that delegate method returns,
    // the session disposes of its strong reference to the delegate.
    // The session object keeps a strong reference to the delegate until your app explicitly invalidates the session.
    // If you do not invalidate the session, your app leaks memory.
    [_dataTaskSession finishTasksAndInvalidate];
    _dataTaskSession = Nil;  // ??
    
    _dataTaskConfigObject = Nil;
    
    _data = Nil;
    
    _json = Nil;
    
    _dsemaJson = Nil;
}


/*********************** Private FetchJSONOperation Properties/Methods ***********************/

- (id)json
{
    id json = Nil;
    if (dispatch_semaphore_wait(_dsemaJson, self.semaWaitTime) == 0)
    {
        json = _json;
        dispatch_semaphore_signal(_dsemaJson);
    }
    else
    {
        NSLog(@"\n*** ERROR: unable to access json value\n");
    }
    return json;
}

- (void)setJson:(id)json
{
    if (self.isExecuting && json)
    {
        if (dispatch_semaphore_wait(_dsemaJson, self.semaWaitTime) == 0)
        {
            // Note: we adopt the json object (for performance reasons)
            _json = json;
            dispatch_semaphore_signal(_dsemaJson);
        }
        else
        {
            NSLog(@"\n*** ERROR: unable to set json value\n");
        }
    }
}


/*********************** Overriding Public NetworkInvocationOperation Properties/Methods ***********************/

// Execute the HTTP request
- (void)operationMethod:(id)data
{
    // Important: call super first to flag the Operation as executing
    [super operationMethod:data];
    
    _data = [[NSMutableData alloc] initWithCapacity:0];
    
    NSString* srcFile = [self.srcDirectoryURL stringByAppendingString:self.srcFileName];
    NSURL* url = [NSURL URLWithString:srcFile];
    NSURLSessionDataTask* dataTask = [_dataTaskSession dataTaskWithURL:url];
    if (dataTask) [dataTask resume];
    else [self completed];  // flag the Operation as completed
}


/*********************** Public FetchJSONOperation Properties/Methods ***********************/

- (FetchJSONOperation *)initWithSrcDirectoryURL:(NSString *)srcDirectoryURL jsonFile:(NSString *)jsonFile userName:(NSString *)userName password:(NSString *)password;
{
    self = [super initWithTarget:self selector:@selector(operationMethod:) object:Nil];
    if (self)
    {
        _dsemaJson = dispatch_semaphore_create(1);
        if (!_dsemaJson) return Nil;
        
        if (!srcDirectoryURL || !jsonFile) return Nil;
        [self setSrcDirectoryURL:srcDirectoryURL srcFileName:jsonFile userName:userName password:password];
        
        _json = Nil;
        
        _data = Nil;
        
        // Create the Data Task Configuration object
        _dataTaskConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
        if (!_dataTaskConfigObject) return Nil;
        
        /*
        // Note: this call with create the default cache directory for the app (if it doesn't already exist)
        NSURLCache* myCache = [[NSURLCache alloc] initWithMemoryCapacity:kXNetworking_CacheMemoryCapacity diskCapacity:kXNetworking_CacheDiskCapacity diskPath:Nil];  // Nil uses default directory
        if (!myCache) return Nil;
        _dataTaskConfigObject.URLCache = myCache;
        _dataTaskConfigObject.requestCachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
        */
        
        // Don't use caching
        _dataTaskConfigObject.URLCache = Nil;
        
        // Create the Session for the Data Task Configuration
        _dataTaskSession = [NSURLSession sessionWithConfiguration:_dataTaskConfigObject delegate:self delegateQueue:self.operationQueue];
        if (!_dataTaskSession) return Nil;
    }
    return self;
}

// error parameter is optional
- (id)jsonWithError:(NSError **)error
{
    id json = self.json;
    
    if (error) *error = self.error;
    
    return json;
}


/*********************** Implement NSURLSessionTaskDelegate Methods ***********************/

// Need to override this method so we can convert the data to JSON and send it back to the caller
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (!error && !self.error && _data)
    {
        // Convert the NSData object to a JSON object
        NSJSONReadingOptions options = NSJSONReadingMutableContainers | NSJSONReadingMutableLeaves | NSJSONReadingAllowFragments;
        NSError* err = Nil;
        self.json = [NSJSONSerialization JSONObjectWithData:_data options:options error:&err];
        
        // Make a copy of the error for the caller
        if (err) self.error = err;
    }
    
    // Important: call super last to flag the Operation as finished
    [super URLSession:session task:task didCompleteWithError:error];
}


/*********************** Implement NSURLSessionDataDelegate Methods ***********************/

// Tells the delegate that the data task received the initial reply (headers) from the server.
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    // A URL response object populated with headers.
    NSHTTPURLResponse* httpURLResponse = (NSHTTPURLResponse*)response;

    // The 4xx codes are intended for cases in which the client seems to have errored
    // The 5xx codes for the cases in which the server is aware that the server has errored
    if (httpURLResponse && httpURLResponse.statusCode >= 400 && httpURLResponse.statusCode <= 500)
    {
        // Create an error for the caller
        self.error = [self errorFromStatusCode:httpURLResponse.statusCode];
        
        // Cancel the request
        completionHandler(NSURLSessionResponseCancel);
    }
    // Continue with the request
    else
    {
        completionHandler(NSURLSessionResponseAllow);
    }
}

// Tells the delegate that the data task has received some of the expected data.
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // Display the raw data coming back from the server (if error, will contain HTML error code, eg. 404)
    //NSLog(@"\nBEGIN DATA:\n%@\nEND DATA\n", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    
    // Process the data
    if (!self.error && data && data.length != 0 && _data) [_data appendData:data];
}


@end

