//
//  XCURLRequestSerialization.m
//  demo_02
//
//  Created by wu xikun on 2016/11/17.
//  Copyright © 2016年 BDWX. All rights reserved.
//

#import "XCURLRequestSerialization.h"

#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <CoreService/CoreServices.h>
#endif

NSString * const XCURLRequestSerializationErrorDomain = @"com.alamofire.error.serialization.request";
NSString * const XCNetworingOperationFailingURLRequestErrorKey = @"com.alamofire.serialization.request.error.response";
typedef NSString * (^XCQUeryStringSerializationgBlock)(NSURLRequest *request, id parameters, NSError *__autoreleasing *error);

NSString * XCPercentEscapedStringFromString(NSString *string) {
    static NSString * const kAFCharactersGeneralDelimitersToEncode = @":$[]@";
    static NSString * const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";
    
    NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];
    
    static NSUInteger const batchSize = 50;
    NSUInteger index = 0;
    NSMutableString* escaped = @"".mutableCopy;
    
    while (index < string.length) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wgnu"
        NSUInteger length = MIN(string.length - index, batchSize);
#pragma GCC diagnostic pop
        NSRange range = NSMakeRange(index, length);
        range = [string rangeOfComposedCharacterSequencesForRange:range];
        
        NSString *subString = [string substringWithRange:range];
        NSString *encoded = [subString stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
        [escaped appendString: encoded];
        index += range.length;
    }
    return escaped;
}

#pragma mark -
@interface XCQueryStringPair : NSObject

@property (readwrite, nonatomic, strong) id field;
@property (readwrite, nonatomic, strong) id value;

- (instancetype)initWithField:(id)field value:(id)value;
- (NSString *)URLEncodedStringValue;

@end
@implementation XCQueryStringPair

- (instancetype)initWithField:(id)field value:(id)value{
    self = [super init];
    if (!self) {
        return nil;
    }
    self.field = field;
    self.value = value;
    return self;
}

- (NSString *)URLEncodedStringValue{
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return XCPercentEscapedStringFromString([self.field description]);
    }else{
        return [NSString stringWithFormat:@"%@=%@", XCPercentEscapedStringFromString([self.field description]), XCPercentEscapedStringFromString([self.value description])];
    }
}
@end

#pragma mark -
FOUNDATION_EXPORT NSArray * XCQueryStringPairsFromDictionary(NSDictionary *dictionary);
FOUNDATION_EXPORT NSArray * XCQueryStirngPairsFromKeyAndValue(NSString *key, id value);

NSString * XCQueryStringFromParameters(NSDictionary *parameters) {
    NSMutableArray *mutablePairs = [NSMutableArray array];
    
    for (XCQueryStringPair *pair in XCQueryStringPairsFromDictionary(parameters)) {
        [mutablePairs addObject:[pair URLEncodedStringValue]];
    }
    
    return [mutablePairs componentsJoinedByString:@"&"];
}

NSArray * XCQueryStringPairsFromDictionary(NSDictionary *dictionary) {
    return XCQueryStirngPairsFromKeyAndValue(nil, dictionary);
}

NSArray * XCQueryStringPairFromKeyAndValue(NSString *key, id value){
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];
    NSSortDescriptor * sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(compare:)];
    
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        for (id nestedKey in [dictionary.allKeys sortedArrayUsingDescriptors:@[sortDescriptor]]) {
            id nestedValue = dictionary[nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:XCQueryStringPairFromKeyAndValue((key ? [NSString stringWithFormat:@"%@[%@]",key,nestedValue] : nestedKey), nestedValue)];
            }
        }
    }else if ([value isKindOfClass:[NSArray class]]){
        NSArray *array = value;
        for (id nestedValue in array) {
            [mutableQueryStringComponents addObjectsFromArray:XCQueryStringPairFromKeyAndValue([NSString stringWithFormat:@"%@[]",key], nestedValue)];
        }
    }else if ([value isKindOfClass:[NSSet class]]){
        NSSet* set = value;
        for (id obj in [set sortedArrayUsingDescriptors:@[sortDescriptor]]) {
            [mutableQueryStringComponents addObjectsFromArray:XCQueryStringPairFromKeyAndValue(key, obj)];
        }
    }else{
        [mutableQueryStringComponents addObject:[[XCQueryStringPair alloc] initWithField:key value:value]];
    }
    
    return mutableQueryStringComponents;
}

#pragma mark -
@interface XCStreamingMutiPartFormData : NSObject <XCMultiPartFormData>
- (instancetype)initWithURLRequest: (NSMutableURLRequest *)urlRequest stringEncoding:(NSStringEncoding)encoding;
- (NSMutableURLRequest *)requesetByFinalizingMultipartFormData;
@end
#pragma mark -

static NSArray * XCHTTPRequestSerializerOberserverKeyPaths() {
    static NSArray *_XCHTTPRequestSerializerObservedKeyPaths = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
       _XCHTTPRequestSerializerObservedKeyPaths = @[NSStringFromSelector(@selector(allowsCellularAccess)), NSStringFromSelector(@selector(cachePolicy)),
                                                    NSStringFromSelector(@selector(HTTPShouldHandleCookies)), NSStringFromSelector(@selector(HTTPShouldUsePipelining)), NSStringFromSelector(@selector(networkServiceType)), NSStringFromSelector(@selector(timeoutInterval))];
    });
    
    return _XCHTTPRequestSerializerObservedKeyPaths;
}

static void *XCHTTPRequestSerializerObserverContext = &XCHTTPRequestSerializerObserverContext;

@interface XCHTTPRequestSerializer()

@property (readwrite, nonatomic, strong) NSMutableSet *mutableObservedChangedKeyPaths;
@property (readwrite, nonatomic, strong) NSMutableDictionary *mutableHTTPRequestHeaders;
@property (readwrite, nonatomic, assign) XCHTTPRequestQueryStringSerializationStyle queryStringSerializationStyle;
@property (readwrite, nonatomic, copy) XCQUeryStringSerializationgBlock queryStringSerialization;

@end

@implementation XCHTTPRequestSerializer

+ (instancetype)serializer{
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.stringEncoding = NSUTF8StringEncoding;
    self.mutableHTTPRequestHeaders = [NSMutableDictionary dictionary];
    NSMutableArray *acceptLangusgesComponents = [NSMutableArray array];
    [[NSLocale preferredLanguages] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        float q = 1.0f - (idx * 0.1f);
        [acceptLangusgesComponents addObject:[NSString stringWithFormat:@"%@;q=%0.1g", obj, q]];
    }];
    
    [self setValue:[acceptLangusgesComponents componentsJoinedByString:@", "] forHTTPHeaderField:@"Accept-Language"];
    NSString *userAgent = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
#if TAEGET_OS_IOS
   userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], [[UIScreen mainScreen] scale]];
#elif TARGET_OS_WATCH
    // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; watchOS %@; Scale/%0.2f)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[WKInterfaceDevice currentDevice] model], [[WKInterfaceDevice currentDevice] systemVersion], [[WKInterfaceDevice currentDevice] screenScale]];
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
    userAgent = [NSString stringWithFormat:@"%@/%@ (Mac OS X %@)", [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleExecutableKey] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleIdentifierKey], [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] ?: [[NSBundle mainBundle] infoDictionary][(__bridge NSString *)kCFBundleVersionKey], [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif
#pragma clang diagnostic pop
    if (userAgent) {
        if (![userAgent canBeConvertedToEncoding:NSASCIIStringEncoding]) {
            NSMutableString *mutableUserAgent = [userAgent mutableCopy];
            if (CFStringTransform((__bridge CFMutableStringRef)(mutableUserAgent), NULL, (__bridge CFStringRef)@"Any-Latin; Latin-ASCLL; [:^ASCII:] Remove", false)) {
                userAgent = mutableUserAgent;
            }
        }
        [self setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    }
    
    self.HTTPMethodsEncodingParametersInURI = [NSSet setWithObjects:@"GET", @"HEAD", @"DELETE", nil];
    self.mutableObservedChangedKeyPaths = [NSMutableSet set];
    
    for (NSString *keyPath in XCHTTPRequestSerializerOberserverKeyPaths()) {
        if ([self respondsToSelector:NSSelectorFromString(keyPath)]) {
            [self addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:XCHTTPRequestSerializerObserverContext];
        }
    }
    
    return self;
}

- (void)dealloc{
    for (NSString *keyPath in XCHTTPRequestSerializerOberserverKeyPaths()) {
        if ([self respondsToSelector:NSSelectorFromString(keyPath)]) {
            [self removeObserver:self forKeyPath:keyPath context:XCHTTPRequestSerializerObserverContext];
        }
    }
}

#pragma mark -

- (void)setAllowsCellularAccess:(BOOL)allowsCellularAccess{
    [self willChangeValueForKey:NSStringFromSelector(@selector(allowsCellularAccess))];
    _allowsCellularAccess = allowsCellularAccess;
    [self didChangeValueForKey:NSStringFromSelector(@selector(allowsCellularAccess))];
}

- (void)setCachePolicy:(NSURLRequestCachePolicy)cachePolicy{
    [self willChangeValueForKey:NSStringFromSelector(@selector(cachePolicy))];
    _cachePolicy = cachePolicy;
    [self didChangeValueForKey:NSStringFromSelector(@selector(cachePolicy))];
}
- (void)setHTTPShouldHandleCookies:(BOOL)HTTPShouldHandleCookies {
    [self willChangeValueForKey:NSStringFromSelector(@selector(HTTPShouldHandleCookies))];
    _HTTPShouldHandleCookies = HTTPShouldHandleCookies;
    [self didChangeValueForKey:NSStringFromSelector(@selector(HTTPShouldHandleCookies))];
}

- (void)setHTTPShouldUsePipelining:(BOOL)HTTPShouldUsePipelining {
    [self willChangeValueForKey:NSStringFromSelector(@selector(HTTPShouldUsePipelining))];
    _HTTPShouldUsePipelining = HTTPShouldUsePipelining;
    [self didChangeValueForKey:NSStringFromSelector(@selector(HTTPShouldUsePipelining))];
}

- (void)setNetworkServiceType:(NSURLRequestNetworkServiceType)networkServiceType {
    [self willChangeValueForKey:NSStringFromSelector(@selector(networkServiceType))];
    _networkServiceType = networkServiceType;
    [self didChangeValueForKey:NSStringFromSelector(@selector(networkServiceType))];
}

- (void)setTimeoutInterval:(NSTimeInterval)timeoutInterval {
    [self willChangeValueForKey:NSStringFromSelector(@selector(timeoutInterval))];
    _timeoutInterval = timeoutInterval;
    [self didChangeValueForKey:NSStringFromSelector(@selector(timeoutInterval))];
}

#pragma mark -

- (NSDictionary *)HTTPRequstHeaders {
    return [NSDictionary dictionaryWithDictionary:self.mutableHTTPRequestHeaders];
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field{
    [self.mutableHTTPRequestHeaders setValue:value forKey:field];
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field{
    return [self.mutableHTTPRequestHeaders valueForKey:field];
}

- (void)setAuthorizationHeaderFieldWithUserName:(NSString *)username password:(NSString *)password{
    NSData *basicAuthCredentials = [[NSString stringWithFormat:@"%@:%@", username, password] dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64AuthCredentials = [basicAuthCredentials base64EncodedStringWithOptions:(NSDataBase64EncodingOptions)0];
    [self setValue:[NSString stringWithFormat:@"Basic %@", base64AuthCredentials] forHTTPHeaderField:@"Authorization"];
}

- (void)clearAuthorizationHeader{
    [self.mutableHTTPRequestHeaders removeObjectForKey:@"Authorization"];
}

@end












