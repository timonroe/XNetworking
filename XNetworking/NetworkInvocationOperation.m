//
//  NetworkInvocationOperation.m
//  XNetworking
//
//  Created by Tim Monroe on 1/8/14.
//  Copyright (c) 2014 Tim Monroe. All rights reserved.
//

#import "NetworkInvocationOperation.h"


// Semaphore wait time
const dispatch_time_t kXNetworking_SemaWaitTime = (30 * NSEC_PER_SEC);   // 30 seconds in nano-seconds

NSString* kXNetworking_CustomErrorDomain = @"XNetworkingCustomErrorDomain";


////////////////////////////////////////////////////////////////////////////////
//
//  NetworkInvocationOperation class implementation
//
/////////////////////////////////////////////////////////////////////////////////
#pragma mark - NetworkInvocationOperation class implementation

@interface NetworkInvocationOperation ()
{
}

- (void)setExecuting:(BOOL)executing;
- (void)setFinished:(BOOL)finished;

@end


@implementation NetworkInvocationOperation
{
@private
    NSOperationQueue* _operationQueue;
    
    dispatch_semaphore_t _dsemaExecuting;
    dispatch_semaphore_t _dsemaFinished;
    dispatch_semaphore_t _dsemaError;
    dispatch_semaphore_t _dsemaSrcDirectoryURL;
    dispatch_semaphore_t _dsemaSrcFileName;
    dispatch_semaphore_t _dsemaUserName;
    dispatch_semaphore_t _dsemaPassword;
    
    BOOL _executing;
    BOOL _finished;
    
    NSString* _srcDirectoryURL;
    NSString* _srcFileName;
    NSString* _userName;
    NSString* _password;
    
    NSError* _error;
}

- (void)dealloc
{
    _error = Nil;
    
    _srcDirectoryURL = Nil;
    _srcFileName = Nil;
    _userName = Nil;
    _password = Nil;
    
    _dsemaPassword = Nil;
    _dsemaUserName = Nil;
    _dsemaSrcFileName = Nil;
    _dsemaSrcDirectoryURL = Nil;
    _dsemaError = Nil;
    _dsemaFinished = Nil;
    _dsemaExecuting = Nil;
    
    _operationQueue = Nil;
}


/*********************** Private NetworkInvocationOperation Properties/Methods ***********************/

// Note: need to handle KVO
- (void)setExecuting:(BOOL)executing
{
    [self willChangeValueForKey:@"isExecuting"];
    if (dispatch_semaphore_wait(_dsemaExecuting, self.semaWaitTime) == 0)
    {
        _executing = executing;
        dispatch_semaphore_signal(_dsemaExecuting);
    }
    else
    {
        NSLog(@"\n*** ERROR: unable to set isExecuting value\n");
    }
    [self didChangeValueForKey:@"isExecuting"];
}

// Note: need to handle KVO
- (void)setFinished:(BOOL)finished
{
    [self willChangeValueForKey:@"isFinished"];
    if (dispatch_semaphore_wait(_dsemaFinished, self.semaWaitTime) == 0)
    {
        _finished = finished;
        dispatch_semaphore_signal(_dsemaFinished);
    }
    else
    {
        NSLog(@"\n*** ERROR: unable to set isFinished value\n");
    }
    [self didChangeValueForKey:@"isFinished"];
}


/*********************** Overriding Public NSOperation Properties/Methods ***********************/

- (BOOL)isExecuting
{
    BOOL executing = NO;
    if (dispatch_semaphore_wait(_dsemaExecuting, self.semaWaitTime) == 0)
    {
        executing = _executing;
        dispatch_semaphore_signal(_dsemaExecuting);
    }
    else
    {
        NSLog(@"\n*** ERROR: unable to access isExecuting value\n");
    }
    return executing;
}

- (BOOL)isFinished
{
    BOOL finished = NO;
    if (dispatch_semaphore_wait(_dsemaFinished, self.semaWaitTime) == 0)
    {
        finished = _finished;
        dispatch_semaphore_signal(_dsemaFinished);
    }
    else
    {
        NSLog(@"\n*** ERROR: unable to access isFinished value\n");
    }
    return finished;
}


/*********************** Public NetworkInvocationOperation Properties/Methods ***********************/

- (id)initWithTarget:(id)target selector:(SEL)sel object:(id)arg
{
    self = [super initWithTarget:target selector:sel object:arg];
    if (self)
    {
        // Create the Operation Queue
        _operationQueue = [[NSOperationQueue alloc] init];
        if (!_operationQueue) return Nil;
        
        _dsemaExecuting = dispatch_semaphore_create(1);
        if (!_dsemaExecuting) return Nil;
        
        _dsemaFinished = dispatch_semaphore_create(1);
        if (!_dsemaFinished) return Nil;
        
        _dsemaError = dispatch_semaphore_create(1);
        if (!_dsemaError) return Nil;
        
        _dsemaSrcDirectoryURL = dispatch_semaphore_create(1);
        if (!_dsemaSrcDirectoryURL) return Nil;
        
        _dsemaSrcFileName = dispatch_semaphore_create(1);
        if (!_dsemaSrcFileName) return Nil;
        
        _dsemaUserName = dispatch_semaphore_create(1);
        if (!_dsemaUserName) return Nil;
        
        _dsemaPassword = dispatch_semaphore_create(1);
        if (!_dsemaPassword) return Nil;
        
        _executing = NO;
        _finished = NO;
        
        _srcDirectoryURL = Nil;
        _srcFileName = Nil;
        _userName = Nil;
        _password = Nil;
        
        _error = Nil;
    }
    return self;
}

- (NSOperationQueue *)operationQueue {return _operationQueue;}

// Flag the Operation as executing and not finished.
- (void)operationMethod:(id)data
{
    [self setExecuting:YES];
    [self setFinished:NO];
}

// Flag the Operation as not executing and is finished.
// This tells the OperationQueue to remove the Operation from its queue
- (void)completed
{
    [self setExecuting:NO];
    [self setFinished:YES];
}

- (dispatch_time_t)semaWaitTime {return kXNetworking_SemaWaitTime;}

- (NSError *)errorFromStatusCode:(NSInteger)statusCode
{
    NSString* statusCodeMsg = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
    NSDictionary* errorDictionary = @{ NSLocalizedDescriptionKey : statusCodeMsg };
    NSError* error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:statusCode userInfo:errorDictionary];
    return error;
}

- (NSError *)customErrorFromStatusCode:(NSInteger)statusCode message:(NSString *)message
{
    NSDictionary* errorDictionary = @{ NSLocalizedDescriptionKey : message };
    NSError* error = [[NSError alloc] initWithDomain:kXNetworking_CustomErrorDomain code:statusCode userInfo:errorDictionary];
    return error;
}

- (NSError *)error
{
    NSError* error = Nil;
    if (dispatch_semaphore_wait(_dsemaError, self.semaWaitTime) == 0)
    {
        error = _error;
        dispatch_semaphore_signal(_dsemaError);
    }
    else
    {
        NSLog(@"\n*** ERROR: unable to access error value\n");
    }
    return error;
}

- (void)setError:(NSError *)error
{
    if (self.isExecuting && error)
    {
        if (dispatch_semaphore_wait(_dsemaError, self.semaWaitTime) == 0)
        {
            // If an error is already set don't replace it
            // Want to track the first error (root cause) that occurred during the operation
            if (!_error) _error = [[NSError alloc] initWithDomain:error.domain code:error.code userInfo:error.userInfo];
            dispatch_semaphore_signal(_dsemaError);
        }
        else
        {
            NSLog(@"\n*** ERROR: unable to set error value\n");
        }
    }
}

- (void)setSrcDirectoryURL:(NSString *)srcDirectoryURL srcFileName:(NSString *)srcFileName userName:(NSString *)userName password:(NSString *)password
{
    self.srcDirectoryURL = srcDirectoryURL;
    self.srcFileName = srcFileName;
    self.userName = userName;
    self.password = password;
}

- (NSString *)srcDirectoryURL
{
    NSString* srcDirectoryURL = Nil;
    if (dispatch_semaphore_wait(_dsemaSrcDirectoryURL, self.semaWaitTime) == 0)
    {
        srcDirectoryURL = _srcDirectoryURL;
        dispatch_semaphore_signal(_dsemaSrcDirectoryURL);
    }
    else
    {
        NSLog(@"\n*** ERROR: unable to access srcDirectoryURL value\n");
    }
    return srcDirectoryURL;
}

- (void)setSrcDirectoryURL:(NSString *)srcDirectoryURL
{
    if (!self.isExecuting && srcDirectoryURL)
    {
        if (dispatch_semaphore_wait(_dsemaSrcDirectoryURL, self.semaWaitTime) == 0)
        {
            _srcDirectoryURL = [NSString stringWithString:srcDirectoryURL];
            dispatch_semaphore_signal(_dsemaSrcDirectoryURL);
        }
        else
        {
            NSLog(@"\n*** ERROR: unable to set srcDirectoryURL value\n");
        }
    }
}

- (NSString *)srcFileName
{
    NSString* srcFileName = Nil;
    if (dispatch_semaphore_wait(_dsemaSrcFileName, self.semaWaitTime) == 0)
    {
        srcFileName = _srcFileName;
        dispatch_semaphore_signal(_dsemaSrcFileName);
    }
    else
    {
        NSLog(@"\n*** ERROR: unable to access srcFileName value\n");
    }
    return srcFileName;
}

- (void)setSrcFileName:(NSString *)srcFileName
{
    if (!self.isExecuting && srcFileName)
    {
        if (dispatch_semaphore_wait(_dsemaSrcFileName, self.semaWaitTime) == 0)
        {
            _srcFileName = [NSString stringWithString:srcFileName];
            dispatch_semaphore_signal(_dsemaSrcFileName);
        }
        else
        {
            NSLog(@"\n*** ERROR: unable to set srcFileName value\n");
        }
    }
}

- (NSString *)userName
{
    NSString* userName = Nil;
    if (dispatch_semaphore_wait(_dsemaUserName, self.semaWaitTime) == 0)
    {
        userName = _userName;
        dispatch_semaphore_signal(_dsemaUserName);
    }
    else
    {
        NSLog(@"\n*** ERROR: unable to access userName value\n");
    }
    return userName;
}

- (void)setUserName:(NSString *)userName
{
    if (!self.isExecuting && userName)
    {
        if (dispatch_semaphore_wait(_dsemaUserName, self.semaWaitTime) == 0)
        {
            _userName = [NSString stringWithString:userName];
            dispatch_semaphore_signal(_dsemaUserName);
        }
        else
        {
            NSLog(@"\n*** ERROR: unable to set userName value\n");
        }
    }
}

- (NSString *)password
{
    NSString* password = Nil;
    if (dispatch_semaphore_wait(_dsemaPassword, self.semaWaitTime) == 0)
    {
        password = _password;
        dispatch_semaphore_signal(_dsemaPassword);
    }
    else
    {
        NSLog(@"\n*** ERROR: unable to access password value\n");
    }
    return password;
}

- (void)setPassword:(NSString *)password
{
    if (!self.isExecuting && password)
    {
        if (dispatch_semaphore_wait(_dsemaPassword, self.semaWaitTime) == 0)
        {
            _password = [NSString stringWithString:password];
            dispatch_semaphore_signal(_dsemaPassword);
        }
        else
        {
            NSLog(@"\n*** ERROR: unable to set password value\n");
        }
    }
}


/*********************** Implement NSURLSessionDelegate Methods ***********************/

/*
// Session level Authentication challenge
 - (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
 {
 }
*/

/*********************** Implement NSURLSessionTaskDelegate Methods ***********************/

// Task level Authentication challenges
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    // Returns the receiver’s count of failed authentication attempts.
    NSInteger previousFailureCount = challenge.previousFailureCount;
    
    // Note: This method will return nil if the protocol doesn’t use responses to indicate an authentication failure.
    // Returns the NSURLResponse object representing the last authentication failure.
    NSHTTPURLResponse* httpURLFailureResponse = (NSHTTPURLResponse*)challenge.failureResponse;
    
    // The 4xx codes are intended for cases in which the client seems to have errored
    // The 5xx codes for the cases in which the server is aware that the server has errored
    if (previousFailureCount != 0 && httpURLFailureResponse && httpURLFailureResponse.statusCode >= 400 && httpURLFailureResponse.statusCode <= 500)
    {
        // Create an error for the caller
        self.error = [self errorFromStatusCode:httpURLFailureResponse.statusCode];
        
        // Cancel the request
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, Nil);
        
        return;
    }
    
    // Note: This method returns nil if the protocol doesn’t use errors to indicate an authentication failure.
    // Returns the NSError object representing the last authentication failure.
    NSError* error = challenge.error;
    if (previousFailureCount != 0 && error)
    {
        // Make a copy of the error for the caller
        self.error = error;
        
        // Cancel the request
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, Nil);
        
        return;
    }
    
    // If HTTP protocal and Basic or Default authentication
    NSString* protocol = challenge.protectionSpace.protocol;
    NSString* authenticationMethod = challenge.protectionSpace.authenticationMethod;
    if ([protocol compare:NSURLProtectionSpaceHTTP options:NSCaseInsensitiveSearch] == NSOrderedSame &&
        ([authenticationMethod compare:NSURLAuthenticationMethodHTTPBasic options:NSCaseInsensitiveSearch] == NSOrderedSame ||
         [authenticationMethod compare:NSURLAuthenticationMethodDefault options:NSCaseInsensitiveSearch] == NSOrderedSame))
    {
        // Create the username / password credential and authenticate with the server
        NSURLCredential* credential = [[NSURLCredential alloc] initWithUser:self.userName password:self.password persistence:NSURLCredentialPersistenceNone];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    }
    else
    {
        // Try performing the default handling
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, Nil);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    // Make a copy of the error for the caller
    if (error) self.error = error;
    
    // Important: need to flag the Operation as completed.  This tells the OperationQueue to remove the Operation from its queue
    [self completed];
}


@end

