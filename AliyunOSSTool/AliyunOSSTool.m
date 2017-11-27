//
//  AliyunOSSTool.m
//  StarCar
//
//  Created by LYPC on 2017/7/25.
//  Copyright © 2017年 com.cattsoft. All rights reserved.
//

#import "AliyunOSSTool.h"
#import <AliyunOSSiOS/OSSService.h>

//视频存储路径
#define VideoUrlPath   \
[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"VideoURL"]

@interface AliyunOSSTool() {
    OSSClient *client;
    NSString *endPoint;
    NSString *accessKeyId;
    NSString *accessKeySecret;
    NSString *bucket;
    // 拼接地址的时候使用
    NSString *subEndPointPre;
    NSString *subEndPointEnd;
}

@end

@implementation AliyunOSSTool

+ (instancetype)sharedInstance {
    static AliyunOSSTool *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [AliyunOSSTool new];
        [instance initOSSClient];
    });
    return instance;
}

#pragma mark 初始化sdk
- (void)initOSSClient {
    id<OSSCredentialProvider> credential = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:accessKeyId                                                                                                     secretKey:accessKeySecret];
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 2;
    conf.timeoutIntervalForRequest = 30;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    client = [[OSSClient alloc] initWithEndpoint:endPoint credentialProvider:credential];
}

// 配置所需参数（去阿里云控制中心获取）
- (void)configAccessKeyId:(NSString *)accessKeyIdStr accessKeySecret:(NSString *)accessKeySecretStr endPoint:(NSString *)endPointStr bucket:(NSString *)bucketStr {
    accessKeyId = accessKeyIdStr;
    accessKeySecret = accessKeySecretStr;
    endPoint = endPointStr;
    bucket = bucketStr;
    subEndPointPre = @"https://";
    subEndPointEnd = [endPointStr substringFromIndex:subEndPointPre.length];
   
    id<OSSCredentialProvider> credential = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:accessKeyId                                                                                                     secretKey:accessKeySecret];
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 2;
    conf.timeoutIntervalForRequest = 30;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    client.endpoint = endPointStr;
    client.credentialProvider = credential;
}

#pragma mark 上传视频文件
- (void)uploadVideoFilePath:(NSString *)filePath
              objectPrePath:(NSString *)objectPre
               videoSuccess:(UploadSucceedListener)successFunc
                     failed:(UploadFailedListener)failedFunc
                   progress:(UploadProgressListener)progressFunc {
    if ([accessKeySecret isEqualToString:@""] || accessKeySecret == nil) {
        NSLog(@"请先调用configAccessKeyId方法配置参数");
        NSError * error;
        failedFunc(error);
        return;
    }
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    // required fields
    put.bucketName = bucket;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    // 设置时间格式
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *name = [formatter stringFromDate:[NSDate date]];
    
    NSString *uploadPath = [NSString stringWithFormat:@"%@/%@.mp4",objectPre, name];
    put.objectKey = uploadPath;
    put.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    // optional fields
    put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"视频上传进度：%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        progressFunc(bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    put.contentType = @"application/mp4"; // 文件类型
    put.contentMd5 = @"";
    put.contentEncoding = @"";
    put.contentDisposition = @"";
    
    OSSTask * putTask = [client putObject:put];
    __weak AliyunOSSTool *weakSelf = self;
    [putTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"objectKey: %@", put.objectKey);
        if (!task.error) {
            NSLog(@"upload object success!");
            // 清除沙盒缓存
            [weakSelf cleanUpCache];
            successFunc([NSString stringWithFormat:@"%@%@.%@/%@", subEndPointPre, bucket, subEndPointEnd, uploadPath]);
        } else {
            // 清除沙盒缓存
            [weakSelf cleanUpCache];
            NSLog(@"upload object failed, error: %@" , task.error);
            failedFunc(task.error);
        }
        return nil;
    }];
}

#pragma mark 下载文件
- (void)downloadVideoFileName:(NSString *)fileName
                 videoSuccess:(DownloadSucceedListener)downloadedSuccessFunc
                       failed:(DownloadFaildListener)failedFunc
                     progress:(UploadProgressListener)progressFunc {
    OSSGetObjectRequest * request = [OSSGetObjectRequest new];
    // required
    request.bucketName = bucket;
    request.objectKey = fileName;
    
    //optional
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        progressFunc(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    };
    
    OSSTask * getTask = [client getObject:request];
    [getTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            NSLog(@"download object success!");
            OSSGetObjectResult * getResult = task.result;
            NSLog(@"download dota length: %lu", [getResult.downloadedData length]);
            self.downloadSucceedListener = downloadedSuccessFunc;
            [self savaDownloadedFile:getResult.downloadedData];
        } else {
            NSLog(@"download object failed, error: %@" ,task.error);
            self.downloadFaildListener = failedFunc;
            self.downloadFaildListener(@"下载失败||保存到本地相册失败");
        }
        return nil;
    }];
}

// get local file dir which is readwrite able
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

#pragma mark 将原始视频的URL转化为NSData数据,写入沙盒 获取存取的本地沙盒路径
- (NSString *)writeToFileAVURLAssetURL:(NSURL *)url withFileName:(NSString *)fileName
{
    NSFileManager * fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:VideoUrlPath]) {
        [fileManager createDirectoryAtPath:VideoUrlPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    // 找出存在沙盒里面的本地视频路径（先存）
    NSString *videoPath = [VideoUrlPath stringByAppendingPathComponent:fileName];
    // 把视频存到本地沙盒路径里面
    NSData *data = [NSData dataWithContentsOfURL:url];
    [data writeToFile:videoPath atomically:YES];
    
    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:videoPath isDirectory:&isDir];
    if(isDir) {
        //是文件夹
        NSLog(@"444");
        return @"";
    }else{
        // 路径
        NSLog(@"写入沙盒之成功 视频大小：%llu", [[fileManager attributesOfItemAtPath :videoPath error: nil] fileSize]);
        return videoPath;
    }
}

#pragma mark 存储下载好的视频到相册
- (void)savaDownloadedFile:(NSData *)fileData {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    // 设置时间格式
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *name = [formatter stringFromDate:[NSDate date]];
    
    NSString *filenName = [NSString stringWithFormat:@"%@.mp4",name];
    NSString *videoPath = [VideoUrlPath stringByAppendingPathComponent:filenName];
    [fileData writeToFile:videoPath atomically:YES];
    
    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:videoPath isDirectory:&isDir];
    if(isDir) {
        //是文件夹
        self.downloadFaildListener(@"下载失败||保存到本地相册失败");
    }else{
        // 路径
        NSLog(@"下载的文件写入沙盒之成功 视频大小：%llu", [[[NSFileManager defaultManager] attributesOfItemAtPath :videoPath error: nil] fileSize]);
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(videoPath)) {
            UISaveVideoAtPathToSavedPhotosAlbum(videoPath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        }
    }
}

- (void)video:(NSString *)video didFinishSavingWithError:(NSError *)
error contextInfo:(void *)contextInfo {
    [self cleanUpCache];
    if (!error) {
        NSLog(@"Save album success!");
        self.downloadSucceedListener(@"下载成功||保存到本地相册成功");
    } else {
        NSLog(@"Save album fail!");
        self.downloadFaildListener(@"下载失败||保存到本地相册失败");
    }
}

/**************分****割*****线*******图片上传*************/

#pragma mark 上传图片
- (void)uploadImages:(NSArray<UIImage *> *)images objectPrePath:(NSString *)objectPre complete:(void(^)(NSArray<NSString *> *names, UploadImageState state))complete {
    if ([accessKeySecret isEqualToString:@""] || accessKeySecret == nil) {
        NSLog(@"请先调用configAccessKeyId方法配置参数");
        complete([NSArray arrayWithArray:images] ,UploadImageFailed);
        return;
    }
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = images.count;
    NSMutableArray *callBackNames = [NSMutableArray array];
    int i = 0;
    for (UIImage *image in images) {
        if (image) {
            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                //任务执行
                OSSPutObjectRequest * put = [OSSPutObjectRequest new];
                put.bucketName = bucket;
                NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                // 设置时间格式
                formatter.dateFormat = @"yyyyMMddHHmmss";
                NSString *name = [formatter stringFromDate:[NSDate date]];
                NSString *imageName = [NSString stringWithFormat:@"%@/%@.jpg", objectPre, name];
                put.objectKey = imageName;
                [callBackNames addObject:imageName];
                NSData *data = UIImageJPEGRepresentation(image, 0.3);
                put.uploadingData = data;
                OSSTask * putTask = [client putObject:put];
                [putTask waitUntilFinished]; // 阻塞直到上传完成
                if (!putTask.error) {
                    NSLog(@"upload object success!");
                } else {
                    NSLog(@"upload object failed, error: %@" , putTask.error);
                }
                if (image == images.lastObject) {
                    NSLog(@"upload object finished!");
                    if (complete) {
                        complete([NSArray arrayWithArray:callBackNames] ,UploadImageSuccess);
                    }else {
                        complete([NSArray arrayWithArray:callBackNames] ,UploadImageFailed);
                    }
                }
            }];
            if (queue.operations.count != 0) {
                [operation addDependency:queue.operations.lastObject];
            }
            [queue addOperation:operation];
        }
        i++;
    }
}

#pragma mark 清除VideoUrlPath路径下缓存的文件
- (void)cleanUpCache {
    NSString *fileDir = [NSString stringWithFormat:@"%@", VideoUrlPath];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager removeItemAtPath:fileDir error:NULL]) {
        NSLog(@"Removed all files successfully");
    }
}


/**
 检测某个指定Object是否在OSS上

 @param bucket bucket
 @param objectKey objectKey(@"home/car/20171127100532.mp4")
 @return return YES／NO
 */
- (BOOL)doesObjectExistInBucket:(NSString *)bucket objectKey:(NSString *)objectKey {
    NSError * error = nil;
    BOOL isExist = [client doesObjectExistInBucket:bucket objectKey:objectKey error:&error];
    if (!error) {
        if(isExist) {
            NSLog(@"File exists.");
            return YES;
        } else {
            NSLog(@"File not exists.");
            return NO;
        }
    } else {
        NSLog(@"Error!");
        return NO;
    }
}

// 删除已上传过的OSS对象objectKey(objectKey的参考格式：@"home/car/20171127100532.mp4")
- (void)deleteObjecBucketName:(NSString *)bucketName objectKey:(NSString *)objectKey deletedResult:(void (^)(BOOL isCucssed, NSString *result))deletedResultBlock {
    if ([accessKeySecret isEqualToString:@""] || accessKeySecret == nil) {
        NSLog(@"请先调用configAccessKeyId方法配置参数");
        deletedResultBlock(NO, @"请先调用configAccessKeyId方法配置参数");
        return;
    }
    // 删除之前 先做检测某个指定Object是否在OSS上
    if ([self doesObjectExistInBucket:bucketName objectKey:objectKey]) {
        OSSDeleteObjectRequest * delete = [OSSDeleteObjectRequest new];
        delete.bucketName = bucketName;
        delete.objectKey = objectKey;
        OSSTask * deleteTask = [client deleteObject:delete];
        [deleteTask continueWithBlock:^id(OSSTask *task) {
            if (!task.error) {
                deletedResultBlock(YES, @"删除成功");
            } else {
                deletedResultBlock(NO, task.error.description);
            }
            return nil;
        }];
    }else {
        deletedResultBlock(NO, @"数据不存在");
    }
}

#pragma mark 删除bucket 该方法建议不要轻易使用 可以在阿里云控制台操作
- (void)deleteBucket:(NSString *)bucketName deletedResult:(void (^)(BOOL isCucssed, NSString *result))deletedResultBlock {
    if ([accessKeySecret isEqualToString:@""] || accessKeySecret == nil) {
        NSLog(@"请先调用configAccessKeyId方法配置参数");
        deletedResultBlock(NO, @"请先调用configAccessKeyId方法配置参数");
        return;
    }
    OSSDeleteBucketRequest * delete = [OSSDeleteBucketRequest new];
    delete.bucketName = bucketName;
    OSSTask * deleteTask = [client deleteBucket:delete];
    [deleteTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            deletedResultBlock(YES, @"删除成功");
            NSLog(@"delete bucket success!");
        } else {
            deletedResultBlock(NO, task.error.description);
        }
        return nil;
    }];
}

// 打开调试log
- (void)enableLog {
    [OSSLog enableLog];
}

@end
