//
//  OssService.m
//  OssIOSDemo
//
//  Created by jingdan on 17/11/23.
//  Copyright © 2015年 Ali. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AliyunOSSiOS/OSSService.h>
#import "OssService.h"
#import "Base64Safe.h"

@implementation OssService
{
    OSSClient * client;
    NSString * endPoint;
    NSString * callbackAddress;
    NSMutableDictionary * uploadStatusRecorder;
    NSString * currentUploadRecordKey;
    OSSPutObjectRequest * putRequest;
    OSSGetObjectRequest * getRequest;
    
    // 简单起见，全局只维护一个断点上传任务
    OSSResumableUploadRequest * resumableUpload;
    ViewController * viewController;
    BOOL isCancelled;
    BOOL isResumeUpload;
}

- (id)initWithViewController:(ViewController *)view
                withEndPoint:(NSString *)enpoint {
    if (self = [super init]) {
        viewController = view;
        endPoint = enpoint;
        isResumeUpload = NO;
        isCancelled = NO;
        currentUploadRecordKey = @"";
        uploadStatusRecorder = [NSMutableDictionary new];
        [self ossInit];
    }
    return self;
}

/**
 *    @brief    初始化获取OSSClient
 */
- (void)ossInit {
//    id<OSSCredentialProvider> credential = [[OSSAuthCredentialProvider alloc] initWithAuthServerUrl:STS_AUTH_URL];
//    client = [[OSSClient alloc] initWithEndpoint:endPoint credentialProvider:credential];
    
//    // 明文模式
//    id<OSSCredentialProvider> credential = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:@"5Ml1pqrg9s9Z8lbI" secretKey:@"EeAjwQfyOiejZp8NKtTdcuepC3RWTR"];
//    client = [[OSSClient alloc] initWithEndpoint:endPoint credentialProvider:credential];
    
    // 自签名模式
    id<OSSCredentialProvider> credential = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
        // 您需要在这里依照OSS规定的签名算法，实现加签一串字符内容，并把得到的签名传拼接上AccessKeyId后返回
        // 一般实现是，将字符内容post到您的业务服务器，然后返回签名
        // 如果因为某种原因加签失败，描述error信息后，返回nil
        NSString *signature = [OSSUtil calBase64Sha1WithData:contentToSign withSecret:@"<Secret>"]; // 这里是用SDK内的工具函数进行本地加签，建议您通过业务server实现远程加签
        if (signature != nil) {
            *error = nil;
        } else {
            *error = [NSError errorWithDomain:@"<your domain>" code:-1001 userInfo:@{}];
            return nil;
        }
        return [NSString stringWithFormat:@"OSS %@:%@", @"<ID>", signature];
    }];
    client = [[OSSClient alloc] initWithEndpoint:endPoint credentialProvider:credential];
    
}


/**
 *    @brief    设置server callback地址
 */
- (void)setCallbackAddress:(NSString *)address {
    callbackAddress = address;
}


/**
 *    @brief    上传图片
 *
 *    @param     objectKey     objectKey
 *    @param     filePath     路径
 */
- (void)asyncPutImage:(NSString *)objectKey
        localFilePath:(NSString *)filePath {
    
    if (objectKey == nil || [objectKey length] == 0) {
        return;
    }
    
    putRequest = [OSSPutObjectRequest new];
    putRequest.bucketName = BUCKET_NAME;
    putRequest.objectKey = objectKey;
    putRequest.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    putRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    if (callbackAddress != nil) {
        putRequest.callbackParam = @{
                                     @"callbackUrl": callbackAddress,
                                     // callbackBody可自定义传入的信息
                                     @"callbackBody": @"filename=${object}"
                                     };
    }
    OSSTask * task = [client putObject:putRequest];
    [task continueWithBlock:^id(OSSTask *task) {
        OSSPutObjectResult * result = task.result;
        // 查看server callback是否成功
        if (!task.error) {
            NSLog(@"Put image success!");
            NSLog(@"server callback : %@", result.serverReturnJsonString);
            dispatch_async(dispatch_get_main_queue(), ^{
                [viewController showMessage:@"普通上传" inputMessage:@"Success!"];
            });
        } else {
            NSLog(@"Put image failed, %@", task.error);
            if (task.error.code == OSSClientErrorCodeTaskCancelled) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"普通上传" inputMessage:@"任务取消!"];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"普通上传" inputMessage:@"Failed!"];
                });
            }
        }
        putRequest = nil;
        return nil;
    }];
}

/**
 *    @brief    下载图片
 */
- (void)asyncGetImage:(NSString *)objectKey {
    if (objectKey == nil || [objectKey length] == 0) {
        return;
    }
    getRequest = [OSSGetObjectRequest new];
    getRequest.bucketName = BUCKET_NAME;
    if (![objectKey containsString:@"@"]) {
        getRequest.objectKey = objectKey;
    } else {
        getRequest.objectKey = [[objectKey componentsSeparatedByString:@"@"] firstObject];
        NSString *str = [[objectKey componentsSeparatedByString:@"@"] lastObject];
        NSArray *arr = [str componentsSeparatedByString:@"&"];
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        for (NSString *s in arr) {
            NSArray *a = [s componentsSeparatedByString:@"="];
            [dic setValue:a[1] forKey:a[0]];
        }
        NSString *safeBase64 = [Base64Safe base64EncodedStringWithString:[NSString stringWithFormat:@"ts.jpg?x-oss-process=image/resize,P_30"]];
        getRequest.xOssProcess = [NSString stringWithFormat:@"image/resize,w_300,h_300/watermark,type_%@,size_%@,text_%@,color_FFFFFF,image_%@,interval_10", [dic objectForKey:@"type"], [dic objectForKey:@"size"], [dic objectForKey:@"text"], safeBase64];
    }
    
    OSSTask * task = [client getObject:getRequest];
    [task continueWithBlock:^id(OSSTask *task) {
        OSSGetObjectResult * result = task.result;
        if (!task.error) {
            NSLog(@"Get image success!");
            dispatch_async(dispatch_get_main_queue(), ^{
                [viewController saveAndDisplayImage:result.downloadedData downloadObjectKey:![objectKey containsString:@"@"] ? objectKey : [[objectKey componentsSeparatedByString:@"@"] firstObject]];
                [viewController showMessage:@"普通下载" inputMessage:@"Success!"];
            });
        } else {
            NSLog(@"Get image failed, %@", task.error);
            if (task.error.code == OSSClientErrorCodeTaskCancelled) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"普通下载" inputMessage:@"任务取消!"];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"普通下载" inputMessage:@"Failed!"];
                });
            }
        }
        getRequest = nil;
        return nil;
    }];
}

// 断点续传
- (void)resumableUpload:(NSString *)objectKey localFilePath:(NSString *)filePath {
    __block NSString * recordKey;
    
//    NSString * docDir = [self getDocumentDirectory];
//    NSString * filePath = [docDir stringByAppendingPathComponent:@"file10m"];
    
    [[[[[[OSSTask taskWithResult:nil] continueWithBlock:^id(OSSTask *task) {
        // 为该文件构造一个唯一的记录键
        NSURL * fileURL = [NSURL fileURLWithPath:filePath];
        NSDate * lastModified;
        NSError * error;
        [fileURL getResourceValue:&lastModified forKey:NSURLContentModificationDateKey error:&error];
        if (error) {
            return [OSSTask taskWithError:error];
        }
        recordKey = [NSString stringWithFormat:@"%@-%@-%@-%@", BUCKET_NAME, objectKey, [OSSUtil getRelativePath:filePath], lastModified];
        // 通过记录键查看本地是否保存有未完成的UploadId
        NSUserDefaults * userDefault = [NSUserDefaults standardUserDefaults];
        return [OSSTask taskWithResult:[userDefault objectForKey:recordKey]];
    }] continueWithSuccessBlock:^id(OSSTask *task) {
        if (!task.result) {
            // 如果本地尚无记录，调用初始化UploadId接口获取
            OSSInitMultipartUploadRequest * initMultipart = [OSSInitMultipartUploadRequest new];
            initMultipart.bucketName = BUCKET_NAME;
            initMultipart.objectKey = objectKey;
            initMultipart.contentType = @"application/octet-stream";
            return [client multipartUploadInit:initMultipart];
        }
        OSSLogVerbose(@"An resumable task for uploadid: %@", task.result);
        return task;
    }] continueWithSuccessBlock:^id(OSSTask *task) {
        NSString * uploadId = nil;
        
        if (task.error) {
            return task;
        }
        
        if ([task.result isKindOfClass:[OSSInitMultipartUploadResult class]]) {
            uploadId = ((OSSInitMultipartUploadResult *)task.result).uploadId;
        } else {
            uploadId = task.result;
        }
        
        if (!uploadId) {
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain
                                                              code:OSSClientErrorCodeNilUploadid
                                                          userInfo:@{OSSErrorMessageTOKEN: @"Can't get an upload id"}]];
        }
        // 将“记录键：UploadId”持久化到本地存储
        NSUserDefaults * userDefault = [NSUserDefaults standardUserDefaults];
        [userDefault setObject:uploadId forKey:recordKey];
        [userDefault synchronize];
        return [OSSTask taskWithResult:uploadId];
    }] continueWithSuccessBlock:^id(OSSTask *task) {
        // 持有UploadId上传文件
        resumableUpload = [OSSResumableUploadRequest new];
        resumableUpload.bucketName = BUCKET_NAME;
        resumableUpload.objectKey = objectKey;
        resumableUpload.uploadId = task.result;
        resumableUpload.uploadingFileURL = [NSURL fileURLWithPath:filePath];
        resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
            NSLog(@"%lld %lld %lld", bytesSent, totalBytesSent, totalBytesExpectedToSend);
        };
        return [client resumableUpload:resumableUpload];
    }] continueWithBlock:^id(OSSTask *task) {
        if (task.error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [viewController showMessage:@"上传失败，可以续传！" inputMessage:@"Failed!"];
            });
            if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                // 如果续传失败且无法恢复，需要删除本地记录的UploadId，然后重启任务
                dispatch_async(dispatch_get_main_queue(), ^{
                    [viewController showMessage:@"该任务无法续传，需要重新上传" inputMessage:@"Failed!"];
                });
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:recordKey];
            }
        } else {
            NSLog(@"upload completed!");
            // 上传成功，删除本地保存的UploadId
            dispatch_async(dispatch_get_main_queue(), ^{
                [viewController showMessage:@"断点续传成功" inputMessage:@"Success！"];
            });
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:recordKey];
        }
        return nil;
    }];
}

- (NSString *)getDocumentDirectory {
    NSString * path = NSHomeDirectory();
    NSLog(@"NSHomeDirectory:%@",path);
    NSString * userName = NSUserName();
    NSString * rootPath = NSHomeDirectoryForUser(userName);
    NSLog(@"NSHomeDirectoryForUser:%@",rootPath);
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * documentsDirectory = [paths objectAtIndex:0];
    return documentsDirectory;
}

/**
 *    @brief    普通上传/下载取消
 */
- (void)normalRequestCancel {
    if (putRequest) {
        [putRequest cancel];
    }
    if (getRequest) {
        [getRequest cancel];
    }
}


@end

