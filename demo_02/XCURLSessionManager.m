//
//  XCURLSessionManager.m
//  demo_02
//
//  Created by wu xikun on 2016/11/17.
//  Copyright © 2016年 BDWX. All rights reserved.
//

#import "XCURLSessionManager.h"

static dispatch_queue_t url_session_manager_creation_queue(){
    static dispatch_queue_t af_url_session_manager_creation_queue;
    static dispatch_once_t onceToke;
    dispatch_once(&onceToke, ^{
        af_url_session_manager_creation_queue = dispatch_queue_create("com.xc.networking.session.manager.creation", DISPATCH_QUEUE_SERIAL);
    });
    return af_url_session_manager_creation_queue;
}

static void url_session_manager_create_task_safely(dispatch_block_t block) {
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_8_0) {
        dispatch_async(url_session_manager_creation_queue(), ^{
            block();
        });
    }else{
        block();
    }
}

static dispatch_queue_t url_session_manager_processing_queue(){
    static dispatch_queue_t af_url_session_manager_processing_queue;
    dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_url_session_manager_processing_queue = dispatch_queue_create("com.xc.networking.session.manager.processing", DISPATCH_QUEUE_CONCURRENT);
    });
    return af_url_session_manager_processing_queue;
}

static dispatch_group_t url_session_manager_completion_group(){
    static dispatch_group_t af_url_session_manager_completion_group;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_url_session_manager_completion_group = dispatch_group_create();
    });
    return af_url_session_manager_completion_group;
}

NSString * const XCNetworkingTaskDidResumeNotification = @"com.alamofire.networking.task.resume";
NSString * const XCNetworkingTaskDidCompleteNotification = @"com.alamofire.networking.task.complete";
NSString * const XCNetworkingTaskDidSuspendNotification = @"com.alamofire.networking.task.suspend";
NSString * const XCURLSessionDidInvalidateNotification = @"com.alamofire.networking.session.invalidate";
NSString * const XCURLSessionDownloadTaskDidFailToMoveFileNotification = @"com.alamofire.networking.session.download.file-manager-error";

NSString * const XCNetworkingTaskDidCompleteSerializedResponseKey = @"com.alamofire.networking.task.complete.serializedresponse";
NSString * const XCNetworkingTaskDidCompleteResponseSerializerKey = @"com.alamofire.networking.task.complete.responseserializer";
NSString * const XCNetworkingTaskDidCompleteResponseDataKey = @"com.alamofire.networking.complete.finish.responsedata";
NSString * const XCNetworkingTaskDidCompleteErrorKey = @"com.alamofire.networking.task.complete.error";
NSString * const XCNetworkingTaskDidCompleteAssetPathKey = @"com.alamofire.networking.task.complete.assetpath";

static NSString * const XCURLSessionManagerLockName = @"com.alamofire.networking.session.manager.lock";

static NSUInteger const XCMaximumNumberOfAttemptsToRecreateBackgroundSessionUploadTask = 3;

static void * XCTaskStateChangedContext = &XCTaskStateChangedContext;

typedef void (^XCURLSessionDidBecomeInvalidBlock)(NSURLSession* session, NSURLSessionTask* task, NSURLResponse* response, NSURLRequest* request);
typedef NSURLSessionAuthChallengeDisposition (^XCURLSessionDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential);
typedef void (^XCURLSessionDidFinishEventsForBackgroundURLSessionBlock)(NSURLSession* session);
typedef NSInputStream * (^AFURLSessionTaskNeedNewBodyStreamBlock)(NSURLSession *session, NSURLSessionTask *task);
typedef void (^XCURLSessionTaskDidSendBodyDataBlock)(NSURLSession *session, NSURLSessionTask *task, int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend);
typedef void (^XCURLSessionTaskDidCompleteBlock)(NSURLSession *session, NSURLSessionTask *task, NSError *error);

typedef NSURLSessionResponseDisposition (^XCURLSessionDataTaskDidReceiveResponseBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLResponse *response);
typedef void (^XCURLSessionDataTaskDidBecomeDownloadTaskBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLSessionDownloadTask *downloadTask);
typedef void (^XCURLSessionDataTaskDidReceiveDataBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data);
typedef NSCachedURLResponse * (^XCURLSessionDataTaskWillCacheResponseBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSCachedURLResponse *proposedResponse);

typedef NSURL * (^XCURLSessionDownloadTaskDidFinishDownloadingBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location);
typedef void (^XCURLSessionDownloadTaskDidWriteDataBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite);
typedef void (^XCURLSessionDownloadTaskDidResumeBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t fileOffset, int64_t expectedTotalBytes);
typedef void (^XCURLSessionTaskProgressBlock)(NSProgress *);

typedef void (^XCURLSessionTaskCompletionHandler)(NSURLResponse *response, id responseObject, NSError *error);

#pragma mark -
@interface XCURLSessionManagerTaskDelegate : NSObject <NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
@property (nonatomic, weak) XCURLSessionManager *manager;
@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic, strong) NSProgress *uploadProgress;
@property (nonatomic, strong) NSProgress *downloadProgress;
@property (nonatomic, copy) NSURL *downloadFileURL;
@property (nonatomic, copy) XCURLSessionDownloadTaskDidFinishDownloadingBlock downloadTaskDidFinishDownloading;
@property (nonatomic, copy) XCURLSessionTaskProgressBlock uploadProgressBlock;
@property (nonatomic, copy) XCURLSessionTaskProgressBlock downloadProgressBlock;
@property (nonatomic, copy) XCURLSessionTaskCompletionHandler completionHandler;
@end
@implementation XCURLSessionManagerTaskDelegate

- (instancetype)init{
    self = [super init];
    if (!self) {
        return nil;
    }
    self.mutableData = [NSMutableData data];
    self.uploadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    self.uploadProgress.totalUnitCount = NSURLSessionTransferSizeUnknown;
    self.downloadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    self.downloadProgress.totalUnitCount = NSURLSessionTransferSizeUnknown;
    return self;
}

#pragma mark - NSProgress Tracking
- (void)setupProgressForTask:(NSURLSessionTask *)task {
    __weak __typeof__(task) weakTask = task;
    self.uploadProgress.totalUnitCount = task.countOfBytesExpectedToSend;
    [self.uploadProgress setCancellable:YES];
    [self.uploadProgress setCancellationHandler:^{
        __typeof__(weakTask) strongTask = weakTask;
        [strongTask cancel];
    }];
    
    [self.uploadProgress setPausable:YES];
    [self.uploadProgress setPausingHandler:^{
        __typeof__(weakTask) strongTask = weakTask;
        [strongTask suspend];
    }];
    
    if ([self.uploadProgress respondsToSelector:@selector(setResumingHandler:)]) {
        [self.uploadProgress setResumingHandler:^{
            __typeof__(weakTask) strongTask = weakTask;
            [strongTask resume];
        }];
    }
    
    [self.downloadProgress setCancellable:YES];
    [self.downloadProgress setCancellationHandler:^{
        __typeof__(weakTask) strongTask = weakTask;
        [strongTask cancel];
    }];
    
    [self.downloadProgress setPausable:YES];
    [self.downloadProgress setPausingHandler:^{
        __typeof__(weakTask) strongTask = weakTask;
        [strongTask suspend];
    }];
    
    if ([self.downloadProgress respondsToSelector:@selector(setResumingHandler:)]) {
        [self.downloadProgress setResumingHandler:^{
            __typeof__(weakTask) strongTask = weakTask;
            [strongTask resume];
        }];
    }
    
    [task addObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesReceived)) options:NSKeyValueObservingOptionNew context:NULL];
    [task addObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesExpectedToReceive)) options:NSKeyValueObservingOptionNew context:NULL];
    [task addObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesSent)) options:NSKeyValueObservingOptionNew context:NULL];
    [task addObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesExpectedToSend) ) options:NSKeyValueObservingOptionNew context:NULL];
    
    [self.downloadProgress addObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted)) options:NSKeyValueObservingOptionNew context:NULL];
    [self.uploadProgress addObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted)) options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)cleanUpProgressForTask:(NSURLSessionTask *)task{
    [task removeObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))];
    [task removeObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesReceived))];
    [task removeObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesSent))];
    [task removeObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesExpectedToSend))];
    [self.downloadProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
    [self.uploadProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if ([object isKindOfClass:[NSURLSessionTask class]] || [object isKindOfClass:[NSURLSessionTask class]]) {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesReceived))]) {
            self.downloadProgress.completedUnitCount = [change[NSKeyValueChangeNewKey] longLongValue];
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesSent))]) {
            self.uploadProgress.completedUnitCount = [change[NSKeyValueChangeNewKey] longLongValue];
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesExpectedToSend))]) {
            self.uploadProgress.totalUnitCount = [change[NSUnderlyingErrorKey] longLongValue];
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))]) {
            self.downloadProgress.totalUnitCount = [change[NSKeyValueChangeNewKey] longLongValue];
        }
    }else if ([object isEqual:self.downloadProgress]){
        if (self.downloadProgressBlock) {
            self.downloadProgressBlock(object);
        }
    }else if ([object isEqual:self.uploadProgress]){
        if (self.uploadProgressBlock) {
            self.uploadProgressBlock(object);
        }
    }
}

#pragma mark -NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    __strong XCURLSessionManager *manager = self.manager;
    __block id responsObject = nil;
    
    __block NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[XCNetworkingTaskDidCompleteResponseSerializerKey] = manager.responseSerializer;
    
    NSData *data = nil;
    if (self.mutableData) {
        data = [self.mutableData copy];
        self.mutableData = nil;
    }
    
    if (self.downloadFileURL) {
        userInfo[XCNetworkingTaskDidCompleteAssetPathKey] = self.downloadFileURL;
    }else if (data){
        userInfo[XCNetworkingTaskDidCompleteResponseDataKey] = data;
    }
    
    if (error) {
        userInfo[XCNetworkingTaskDidCompleteErrorKey] = error;
        dispatch_group_async(manager.completionGroup ?: url_session_manager_completion_group(), manager.completionQueue ?:dispatch_get_main_queue(), ^{
            if (self.completionHandler) {
                self.completionHandler(task.response, responsObject, error);
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:XCNetworkingTaskDidCompleteNotification object:task userInfo:userInfo];
            });
        });
    } else {
        dispatch_async(url_session_manager_processing_queue(), ^{
            NSError *serializationError = nil;
            responsObject = [manager.responseSerializer responsObjectForResponse:task.response data:data error:&serializationError];
        });
    }
}

#pragma mark -NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
}
@end
@implementation XCURLSessionManager



@end
