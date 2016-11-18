//
//  XCURLRequestSerialization.h
//  demo_02
//
//  Created by wu xikun on 2016/11/17.
//  Copyright © 2016年 BDWX. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>


#if TARGET_OS_IOS || TAEGET_OS_TV
#import <UIKit/UIKit.h>
#elif TARGET_OS_WATCH
#import <WatchKit/WatchKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * XCPercentEscapedStringFromeString(NSString *string);

FOUNDATION_EXPORT NSString * XCQueryStringFromParameters(NSDictionary *parameters);

@protocol XCURLRequestSerialization <NSObject, NSSecureCoding, NSCopying>

- (nullable NSURLRequest *)requestBySerializingRequest:(NSURLRequest *)request withParameters:(nullable id)parameters error:(NSError* _Nullable __autoreleasing *) error NS_SWIFT_NOTHROW;

@end

#pragma mark -
typedef NS_ENUM(NSInteger, XCHTTPRequestQueryStringSerializationStyle) {
    XCHTTPRequestQueryStringDefaultStyle = 0,
};

@protocol XCMultiPartFormData;

@interface XCHTTPRequestSerializer : NSObject<XCURLRequestSerialization>

@property (nonatomic, assign) NSStringEncoding stringEncoding;
@property (nonatomic, assign) BOOL allowsCellularAccess;
@property (nonatomic, assign) NSURLRequestCachePolicy cachePolicy;
@property (nonatomic, assign) BOOL HTTPShouldHandleCookies;
@property (nonatomic, assign) BOOL HTTPShouldUsePipelining;
@property (nonatomic, assign) NSURLRequestNetworkServiceType networkServiceType;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (readonly, nonatomic, strong) NSDictionary <NSString *, NSString *> *HTTPRequestHeaders;

+ (instancetype)serializer;

- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nonnull NSString *)field;
- (nullable NSString *)valueForHTTPHeaderField:(NSString *)field;

- (void)setAuthorizationHeaderFieldWithUserName:(NSString *)username password:(NSString *)password;
- (void)clearAuthorizationHeader;

@property (nonatomic, strong) NSSet <NSString *> *HTTPMethodsEncodingParametersInURI;

- (void)setQueryStringSerializationWithStyle:(XCHTTPRequestQueryStringSerializationStyle)style;
- (void)setQueryStringSerializationWithBlock:(nullable NSString* (^)(NSURLRequest *request, id parameters, NSError * __autoreleasing* error))block;

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method URLString:(NSString *)URLString parameters:(nullable id)parameters error:(NSError * _Nullable __autoreleasing *)error;

- (NSMutableURLRequest *)multipartFormRequestWithMethod:(NSString *)method URLString:(NSString *)URLString parameters:(nullable NSDictionary<NSString *, id> *)parameters constructingBodyWithBlock:(nullable void(^)(id <XCMultiPartFormData> formData))block error:(NSError * _Nullable __autoreleasing *)error;
- (NSMutableURLRequest *)requestWithMutipartFormRequest:(NSURLRequest *)request
                            writingStreamContentsToFile:(NSURL *)fileURL
                                      completionHandler:(nullable void(^)(NSError * _Nullable error))handler;


@end

@protocol XCMultiPartFormData

- (BOOL)appendPartWithFileURL:(NSURL* )fileURL name:(NSString *)name error:(NSError * _Nullable __autoreleasing *)error;

- (void)appendPartWithInputStream:(nullable NSInputStream *)inputStream
                             name:(NSString *)name
                         fileName:(NSString *)fileName
                           length:(int64_t)length
                         mimeType:(NSString *)mimeType;

- (void)appendPartWithFileData:(NSData *)data name:(NSString *)name fileName:(NSString *)fileName mimeType:(NSString *)mimeType;

- (void)appendPartWithFormData:(NSData *)data name:(NSString *)name;

- (void)appendPartWithHeaders:(nullable NSDictionary <NSString *, NSString *> *)headers body:(NSData *)body;

- (void)throttleBandWidthWithPacketSize:(NSUInteger)numberOfBytes delay:(NSTimeInterval)delay;

@end

@interface XCJsonRequestSerializer : XCHTTPRequestSerializer

@property (nonatomic, assign) NSJSONWritingOptions writingOptions;
+ (instancetype)serializerWithWritingOptions:(NSJSONWritingOptions)writingOptions;

@end

@interface XCPropertyListRequestSerializer : XCHTTPRequestSerializer

@property (nonatomic, assign) NSPropertyListFormat format;
@property (nonatomic, assign) NSPropertyListWriteOptions writeOptions;

+ (instancetype)serializerWithFormat:(NSPropertyListFormat)format witeOptions:(NSPropertyListWriteOptions)writeOptions;

@end

#pragma mark -

FOUNDATION_EXPORT NSString * const XCURLRequestSerializationErrorDomain;

FOUNDATION_EXPORT NSString * const XCNetworingOperationFailingURLRequestErrorKey;

FOUNDATION_EXPORT NSUInteger const kAFUploadStream3GSuggestedPacketSize;
FOUNDATION_EXPORT NSTimeInterval const kAFUploadStream3GSuggestedDelay;




NS_ASSUME_NONNULL_END
