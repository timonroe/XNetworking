//
//  ViewController.m
//  XNetworking
//
//  Created by Tim Monroe on 12/23/13.
//  Copyright (c) 2013 Tim Monroe. All rights reserved.
//

#import "ViewController.h"
#import "FetchJSONOperation.h"
#import "DownloadFileOperation.h"


// Server values
NSString* kServerName = @"192.168.1.3";
NSString* kImagesDirName = @"images";      // images folder name on the server
NSString* kUserName = @"rbowen";           // username on the server
NSString* kPassword = @"password";         // username's password on the server
NSString* kBaseballImagesJSONFile = @"BaseballImageFiles.json";
NSString* kBasketballImagesJSONFile = @"BasketballImageFiles.json";
NSString* kFootballImagesJSONFile = @"FootballImageFiles.json";
NSString* kGolfImagesJSONFile = @"GolfImageFiles.json";
NSString* kHockeyImagesJSONFile = @"HockeyImageFiles.json";

// JSON values
NSString* kImageObjectsArrayKey = @"imageObjects";
NSString* kFileNameKey = @"fileName";
NSString* kDateKey = @"date";

// KVO
NSString* kIsFinished = @"isFinished";

const NSTimeInterval kTimerInterval = 1;   // seconds

dispatch_time_t kSemaWaitTime = (30 * NSEC_PER_SEC);   // 30 seconds in nano-seconds


@interface ViewController ()
{
}

@property (strong, nonatomic) IBOutlet UIImageView *imageView1;

@property (strong, nonatomic) IBOutlet UIImageView *imageView2;

- (IBAction)baseballBtnSelected:(id)sender;

- (IBAction)basketballBtnSelected:(id)sender;

- (IBAction)footballBtnSelected:(id)sender;

- (IBAction)golfBtnSelected:(id)sender;

- (IBAction)hockeyBtnSelected:(id)sender;

@end


@implementation ViewController
{
@private
    NSOperationQueue* _operationQueue;
    
    NSString* _srcDirectoryURL;
    
    FetchJSONOperation* _fetchJSONOperation;
    NSMutableArray* _downloadFileOperations;
    
    dispatch_semaphore_t _dsemaDownloadFiles;
    NSMutableArray* _downloadFiles;
    NSUInteger _numDownloadFiles;
    
    NSTimer* _repeatingTimer;
}

- (void)dealloc
{
    // Note: cannot call 'invalidate' from this thread.  Must be called from the thread the Timer was created on.
    _repeatingTimer = Nil;
    
    _downloadFiles = Nil;
    _dsemaDownloadFiles = Nil;
    
    _fetchJSONOperation = Nil;
    _downloadFileOperations = Nil;
    
    _srcDirectoryURL = Nil;
    
    _operationQueue = Nil;
}


/*********************** Overriding NSKeyValueObserving protocol ***********************/

// This method is called when the downloadFileOperaton is finished (KVO)
// Build the list of downloaded files
// Note: cannot make changes in the UI in this routine.
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSNumber* number = [change objectForKey:NSKeyValueChangeNewKey];
    if (number.boolValue == NO) return;
    
    if (dispatch_semaphore_wait(_dsemaDownloadFiles, kSemaWaitTime) == 0)
    {
        DownloadFileOperation* downloadFileOperation = (DownloadFileOperation*)CFBridgingRelease(context);
        NSError* error = downloadFileOperation.error;
        if (!error)
        {
            NSString* downloadFile = downloadFileOperation.downloadFile;
            
            // Add the downloaded file to the list
            [_downloadFiles addObject:downloadFile];
        }
        else
        {
            // Decrement the number of files being downloaded
            _numDownloadFiles -= 1;
        }
        dispatch_semaphore_signal(_dsemaDownloadFiles);
    }
}


/*********************** Private ViewController Properties/Methods ***********************/

/*
// Clear out the images on the device
- (void)clearCacheImageFiles
{
    if (!_cacheDir || !_cacheDirURL) return;
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError* error = Nil;
    NSArray* contentsOfDirectory = [fileManager contentsOfDirectoryAtPath:_cacheDir error:&error];
    if (!contentsOfDirectory || contentsOfDirectory.count == 0) return;
    
    NSString* fileName = Nil;
    NSURL* filepathURL = Nil;
    NSString* extension = Nil;
    for (NSUInteger x = 0; x < contentsOfDirectory.count; x++)
    {
        fileName = contentsOfDirectory[x];
        filepathURL = [_cacheDirURL URLByAppendingPathComponent:fileName];
        extension = [filepathURL pathExtension];
        if ([extension compare:_PNGExtension options:NSCaseInsensitiveSearch] == NSOrderedSame ||
            [extension compare:_JPGExtension options:NSCaseInsensitiveSearch] == NSOrderedSame ||
            [extension compare:_GIFExtension options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            [fileManager removeItemAtURL:filepathURL error:&error];
        }
    }
}
*/

// Timer callback function
- (void)timerTarget:(NSTimer *)timer
{
    if (dispatch_semaphore_wait(_dsemaDownloadFiles, kSemaWaitTime) == 0)
    {
        // When all of the files have been downloaded
        if (_downloadFiles.count == _numDownloadFiles)
        {
            // Update the UI
            UIImage* image = Nil;
            for (NSUInteger x = 0; x < _downloadFiles.count; x++)
            {
                image = [[UIImage alloc] initWithContentsOfFile:_downloadFiles[x]];
                if (image)
                {
                    // Only handles displaying two images for now
                    if (x == 0) self.imageView1.image = image;
                    else self.imageView2.image = image;
                }
            }
            
            // Turn off the network activity indicator when the download operations have finished
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            
            // Kill the timer
            if (_repeatingTimer)
            {
                [_repeatingTimer invalidate];
                _repeatingTimer = Nil;
            }
        }
        dispatch_semaphore_signal(_dsemaDownloadFiles);
    }
}

/*
- (void)parseJSONInfo
{
    NSError* error = Nil;
    id json = [_fetchJSONOperation jsonWithError:&error];
    if (!json || error)
    {
        NSLog(@"Data Task failed with error: %@\n", error);
        return;
    }
    
    NSDictionary* imageFilesDictionary = json;
    NSArray* imageObjectsArray = [imageFilesDictionary objectForKey:kImageObjectsArrayKey];
    NSDictionary* jsonImageObject = Nil;
    NSString* fileName = Nil;
    NSString* date = Nil;
    for (NSUInteger x = 0; x < imageObjectsArray.count; x++)
    {
        // Parse the fields out of the json object
        jsonImageObject = imageObjectsArray[x];
        fileName = [jsonImageObject objectForKey:kFileNameKey];
        NSLog(@"fileName: %@\n", fileName);
        date = [jsonImageObject objectForKey:kDateKey];
        NSLog(@"date: %@\n", date);
    }
}
*/

// Parse through the JSON and download the specified files
- (void)downloadFilesInJSON:(id)json
{
    NSArray* imageObjectsArray = [json objectForKey:kImageObjectsArrayKey];
    
    // Need to retain a reference to the downloadFileOperation objects to make sure they don't go away
    _downloadFileOperations = [[NSMutableArray alloc] initWithCapacity:imageObjectsArray.count];
    
    // Turn on the network activity indicator during the download operations
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    // Start downloading the files
    NSDictionary* jsonImageObject = Nil;
    NSString* downloadFileName = Nil;
    DownloadFileOperation* downloadFileOperation = Nil;
    NSString* downloadFile = Nil;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    for (NSUInteger x = 0; x < imageObjectsArray.count; x++)
    {
        // Parse the fields out of the json object
        jsonImageObject = imageObjectsArray[x];
        downloadFileName = [jsonImageObject objectForKey:kFileNameKey];
        
        downloadFileOperation = [[DownloadFileOperation alloc] initWithSrcDirectoryURL:_srcDirectoryURL downloadFileName:downloadFileName userName:kUserName password:kPassword];
        if (downloadFileOperation)
        {
            // If the downloadFile already exists, delete it
            downloadFile = downloadFileOperation.downloadFile;
            [fileManager removeItemAtPath:downloadFile error:Nil];
            
            // Add to the list of active Operations - keeps the Operations from going away
            [_downloadFileOperations addObject:downloadFileOperation];
            
            // Add observer so we can track when the Operation is finished
            [downloadFileOperation addObserver:self forKeyPath:kIsFinished options:NSKeyValueObservingOptionNew context:(void*)downloadFileOperation];
            
            // Add to the Operation Queue - starts the Operation
            [_operationQueue addOperation:downloadFileOperation];
        }
        else
        {
            if (dispatch_semaphore_wait(_dsemaDownloadFiles, kSemaWaitTime) == 0)
            {
                // Decrement the number of files being downloaded
                _numDownloadFiles -= 1;
                dispatch_semaphore_signal(_dsemaDownloadFiles);
            }
        }
    }
}

// Init some downloading information used to keep the status of the downloads
- (void)initDownloadFileInfoWithJSON:(id)json
{
    NSArray* imageObjectsArray = [json objectForKey:kImageObjectsArrayKey];
    
    // Init the downloaded files information
    if (dispatch_semaphore_wait(_dsemaDownloadFiles, kSemaWaitTime) == 0)
    {
        _downloadFiles = [[NSMutableArray alloc] initWithCapacity:0];
        _numDownloadFiles = imageObjectsArray.count;
        
        if (_repeatingTimer)
        {
            [_repeatingTimer invalidate];
            _repeatingTimer = Nil;
        }
        
        // Start the timer - needed for updating the UI with the downloaded files
        _repeatingTimer = [NSTimer scheduledTimerWithTimeInterval:kTimerInterval target:self selector:@selector(timerTarget:) userInfo:Nil repeats:YES];
        
        dispatch_semaphore_signal(_dsemaDownloadFiles);
    }
}

// Fetch the JSON file and build the JSON object
- (id)fetchJSONFromFile:(NSString *)jsonFile
{
    if (!jsonFile) return Nil;
    
    // Create the Operation
    _fetchJSONOperation = [[FetchJSONOperation alloc] initWithSrcDirectoryURL:_srcDirectoryURL jsonFile:jsonFile userName:kUserName password:kPassword];
    if (!_fetchJSONOperation) return Nil;
    
    // Execute the Operation
    [_operationQueue addOperation:_fetchJSONOperation];
    
    // Wait until it's finished
    [_operationQueue waitUntilAllOperationsAreFinished];
    
    // Get the JSON object
    NSError* error = Nil;
    id json = [_fetchJSONOperation jsonWithError:&error];
    if (error || !json)
    {
        NSLog(@"Error fetching JSON: %@\n", error);
        return Nil;
    }
    
    return json;
}

// Download the files from the server
- (BOOL)downloadFilesInJSONFile:(NSString *)jsonFile
{
    // Build the JSON that contains the files we need to download
    id json = [self fetchJSONFromFile:jsonFile];
    if (!json) return NO;
    
    // Do some setup work
    [self initDownloadFileInfoWithJSON:json];
    
    //  Download the files
    [self downloadFilesInJSON:json];
    
    return YES;
}


/*********************** Public ViewController Properties/Methods ***********************/

// Setup the view controller
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Create the Operation Queue
    _operationQueue = [[NSOperationQueue alloc] init];
    if (!_operationQueue) return;
    
    // Build the URL for the directory on the server
    NSString* serverName = kServerName;
    NSString* imagesDirName = kImagesDirName;
    _srcDirectoryURL = [NSString stringWithString:NSURLProtectionSpaceHTTP];
    _srcDirectoryURL = [_srcDirectoryURL stringByAppendingString:@"://"];
    _srcDirectoryURL = [_srcDirectoryURL stringByAppendingString:serverName];
    _srcDirectoryURL = [_srcDirectoryURL stringByAppendingString:@"/"];
    _srcDirectoryURL = [_srcDirectoryURL stringByAppendingString:imagesDirName];
    _srcDirectoryURL = [_srcDirectoryURL stringByAppendingString:@"/"];
    
    _fetchJSONOperation = Nil;
    _downloadFileOperations = Nil;
    
    _dsemaDownloadFiles = dispatch_semaphore_create(1);
    if (!_dsemaDownloadFiles) return;
    
    _downloadFiles = Nil;
    
    _numDownloadFiles = 0;
    
    _repeatingTimer = Nil;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/*********************** Methods invoked from UI actions ***********************/

- (IBAction)baseballBtnSelected:(id)sender
{
    [self downloadFilesInJSONFile:kBaseballImagesJSONFile];
}

- (IBAction)basketballBtnSelected:(id)sender
{
    [self downloadFilesInJSONFile:kBasketballImagesJSONFile];
}

- (IBAction)footballBtnSelected:(id)sender
{
    [self downloadFilesInJSONFile:kFootballImagesJSONFile];
}

- (IBAction)golfBtnSelected:(id)sender
{
    [self downloadFilesInJSONFile:kGolfImagesJSONFile];
}

- (IBAction)hockeyBtnSelected:(id)sender
{
    [self downloadFilesInJSONFile:kHockeyImagesJSONFile];
}

@end
