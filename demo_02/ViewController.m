//
//  ViewController.m
//  demo_02
//
//  Created by wu xikun on 2016/11/10.
//  Copyright © 2016年 BDWX. All rights reserved.
//

#import "ViewController.h"
#import "XCOperation.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    UIImageView* imageView = [[UIImageView alloc] init];
//    [self.view addSubview:imageView];
//    [imageView setFrame:CGRectMake(100, 100, 100, 100)];
//    
//    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
//    config.timeoutIntervalForRequest = 10;
//    config.allowsCellularAccess = YES;
//    NSURLSession* session = [NSURLSession sessionWithConfiguration:config];
//    NSURL* imgUrl = [NSURL URLWithString:@"http://images.jfdaily.com/jiefang/guonei/new/201611/W020161113285113227507.jpg"];
//
//    NSURLSessionTask* task = [session dataTaskWithURL:imgUrl completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//        [imageView setImage:[UIImage imageWithData:data]];
//    }];
//    [task resume];
    
//    NSOperationQueue* queue = [[NSOperationQueue alloc] init];
    
    XCOperation* operation = [[XCOperation alloc] init];
    
    [operation start];
//    [queue addOperation:operation];

    
}

- (void)sayhi{
    NSLog(@"---");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
