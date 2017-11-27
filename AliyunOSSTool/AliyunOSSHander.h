//
//  AliyunOSSHander.h
//  StarCar
//
//  Created by LYPC on 2017/7/25.
//  Copyright © 2017年 com.cattsoft. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UploadImageState) {
    UploadImageFailed   = 0,
    UploadImageSuccess  = 1
};

// 上传成功 vodeoUrl:成功后的视频地址
typedef void (^UploadSucceedListener) (NSString *vodeoUrl);
// 上传失败 error：失败原因
typedef void (^UploadFailedListener) (NSError * error);
// 进度条 uploadedSize：当前进度    totalSize:总进度
typedef void (^UploadProgressListener) (long long bytesSent, long long totalByteSent, long long totalBytesExpectedToSend);
// 下载成功||保存到本地相册成功
typedef void(^DownloadSucceedListener)(NSString *succeedDisc);
// 下载失败||保存到本地相册失败
typedef void(^DownloadFaildListener)(NSString *faildDisc);

@interface AliyunOSSHander : NSObject


@property (nonatomic,assign) DownloadSucceedListener downloadSucceedListener;
@property (nonatomic,assign) DownloadFaildListener downloadFaildListener;

+ (instancetype)sharedInstance;

/**
 打开调试log
 */
- (void)enableLog;

/**
 配置所需参数（去阿里云控制中心获取,如有改动可以重新调用该方法设置一遍即可）

 @param accessKeyIdStr 用于标示用户用于标示用户
 @param accessKeySecretStr 是用户用于加密签名字符串和 OSS 用来验证签名字符串的密钥 必须保密
 @param endPointStr SDK配置项中需要填写的EndPoint
 @param bucketStr 用户用来管理所存储对象（object）的单元,所有的对象都必须隶属于某个存储空间
 */
- (void)configAccessKeyId:(NSString *)accessKeyIdStr accessKeySecret:(NSString *)accessKeySecretStr endPoint:(NSString *)endPointStr bucket:(NSString *)bucketStr;

/**************分****割*****线*******视频上传*************/

/**
 上传视频文件
 @param filePath 要上传的本地缓存的文件地址
 @param objectPre object文件层次路径
 @param successFunc 成功回调
 @param failedFunc 成功回调
 @param progressFunc 进度回调
 */
- (void)uploadVideoFilePath:(NSString *)filePath objectPrePath:(NSString *)objectPre videoSuccess:(UploadSucceedListener)successFunc
                      failed:(UploadFailedListener)failedFunc
                   progress:(UploadProgressListener)progressFunc;

/**
 下载视频到本地相册

 @param fileName 视频名字（endPoint后面文件路径如视频链接为http://test20170317.oss-cn-shenzhen.aliyuncs.com/video/ios/20170728134634.mp4，它的视频名字就是：video/ios/20170728134634.mp4）
 @param objectPre object文件层次路径
 @param downloadedSuccessFunc 保存相册成功回掉
 @param failedFunc 保存相册失败回掉
 @param progressFunc 下载进度
 */
- (void)downloadVideoFileName:(NSString *)fileName
                 videoSuccess:(DownloadSucceedListener)downloadedSuccessFunc
                       failed:(DownloadFaildListener)failedFunc
                     progress:(UploadProgressListener)progressFunc;


/**
 将原始视频的URL转化为NSData数据,写入沙盒 获取存取的本地沙盒路径
 
 @param url 图片的url属性
 @param fileName 图片名字
 @return 沙盒路径
 */
- (NSString *)writeToFileAVURLAssetURL:(NSURL *)url withFileName:(NSString *)fileName;


/**************分****割*****线*******图片上传*************/

/**
 上传图片

 @param images 图片数组
 @param objectPre object文件层次路径
 @param complete 上传成功失败的状态
 */
- (void)uploadImages:(NSArray<UIImage *> *)images objectPrePath:(NSString *)objectPre complete:(void(^)(NSArray<NSString *> *names, UploadImageState state))complete;

/**
 DeleteObject用于删除某个Object

 @param bucketName bucket名字
 @param objectKey objectKey名字(@"home/car/20171127100532.mp4")
 @param deletedResultBlock 删除操作结果回掉
 */
- (void)deleteObjecBucketName:(NSString *)bucketName objectKey:(NSString *)objectKey deletedResult:(void (^)(BOOL isCucssed, NSString *result))deletedResultBlock;

/**
 危险操作：删除无用的Bucket

 @param bucketName Bucket名字
 @param deletedResultBlock 删除操作结果回掉
 */
- (void)deleteBucket:(NSString *)bucketName deletedResult:(void (^)(BOOL isCucssed, NSString *result))deletedResultBlock;



@end
