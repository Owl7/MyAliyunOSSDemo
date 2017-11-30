//
//  Base64Safe.h
//  MyAliyunOSSDemo
//
//  Created by Crack on 2017/11/29.
//  Copyright © 2017年 Crack. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Base64Safe : NSObject

+ (NSString *)base64EncodedStringWithString:(NSString *)str;
+ (NSString *)stringWithBase64EncodedString:(NSString *)base64EncodedString;

@end
