//
//  IDFileManager.m
//  VideoCaptureDemo
//
//  Created by Adriaan Stellingwerff on 9/04/2015.
//  Copyright (c) 2015 Infoding. All rights reserved.
//

#import "IDFileManager.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <UIKit/UIKit.h>

@implementation IDFileManager

+ (NSString *)inDocumentsDirectory:(NSString *)path
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:path];
}

- (NSURL *)tempFileURL
{
    NSString *path = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger i = 0;
    while(path == nil || [fm fileExistsAtPath:path]){
        path = [NSString stringWithFormat:@"%@output%ld.mov", NSTemporaryDirectory(), (long)i];
        i++;
    }
    return [NSURL fileURLWithPath:path];
}

+ (void) removeFile:(NSURL *)fileURL
{
    NSString *filePath = [fileURL path];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        NSError *error;
        [fileManager removeItemAtPath:filePath error:&error];
        if(error){
            NSLog(@"error removing file: %@", [error localizedDescription]);
        }
    }
    else
    {
        NSLog(@"Kdd: file:%@ not found", filePath);
    }
}

- (void) copyFileToDocuments:(NSURL *)fileURL
{
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *destinationPath = [documentsDirectory stringByAppendingFormat:@"/output_%@.mov", [dateFormatter stringFromDate:[NSDate date]]];
    NSError	*error;
    [[NSFileManager defaultManager] copyItemAtURL:fileURL toURL:[NSURL fileURLWithPath:destinationPath] error:&error];
    if(error){
        NSLog(@"error copying file: %@", [error localizedDescription]);
    }
}

+ (void)copyFileToCameraRoll:(NSURL *)fileURL  didFinishcompledBlock:(void (^)(void))aftersaved
{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    if(![library videoAtPathIsCompatibleWithSavedPhotosAlbum:fileURL]){
        NSLog(@"video incompatible with camera roll");
    }
    
    [library writeVideoAtPathToSavedPhotosAlbum:fileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        
        if(error){
            NSLog(@"Error: Domain = %@, Code = %@", [error domain], [error localizedDescription]);
        } else if(assetURL == nil){
            
            //It's possible for writing to camera roll to fail, without receiving an error message, but assetURL will be nil
            //Happens when disk is (almost) full
            NSLog(@"Error saving to camera roll: no error message, but no url returned");
            
        } else {
  
            if(aftersaved)
            {
                aftersaved();
            }
        }
    }];

}

- (void) saveImageFileToCameraRoll:(NSData*)imageData didFinishcompledBlock:(void (^)(void))aftersaved
{
    ALAssetsLibraryWriteImageCompletionBlock completionBlock = ^(NSURL *assetURL, NSError *error)
    {
        if (error)
        {
            // error handling
            NSLog(@"ALAssetsLibraryWriteImageCompletionBlock error");
        }
        else
        {
            if(aftersaved)
            {
                aftersaved();
            }
        }
    };
    
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    UIImage *image = [[UIImage alloc] initWithData:imageData];
    
    // 将图像保存到“照片” 中
    [library writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation]
                          completionBlock:completionBlock];
    
}

//返回
+ (uint64_t)sizeOfFile:(NSURL *)fileURL
{
    NSString *filePath = [fileURL path];
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    NSInteger fileSize = [[fileAttributes objectForKey:NSFileSize] integerValue];
    NSString *fileSizeString = [NSByteCountFormatter stringFromByteCount:fileSize countStyle:NSByteCountFormatterCountStyleFile];
    
    NSLog(@"current video size: %@", fileSizeString);
    
    //return fileSizeString;
    return fileSize;
}

+ (unsigned)getFreeDiskspacePrivate
{
    NSDictionary *atDict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/" error:NULL];
    unsigned freeSpace = [[atDict objectForKey:NSFileSystemFreeSize] unsignedIntValue];
    NSLog(@"%s - Free Diskspace: %u bytes - %u MiB", __PRETTY_FUNCTION__, freeSpace, (freeSpace/1024)/1024);
    return freeSpace;
}

/*
 + (uint64_t)getFreeDiskspace
 {
 uint64_t totalSpace = 0;
 uint64_t totalFreeSpace = 0;
 NSError *error = nil;
 NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
 NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
 
 if (dictionary) {
 NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
 NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
 totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
 totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
 NSLog(@"Memory Capacity of %llu MiB with %llu MiB Free memory available.", ((totalSpace/1024ll)/1024ll), ((totalFreeSpace/1024ll)/1024ll));
 } else {
 NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %@", [error domain], [error code]);
 }
 
 return totalFreeSpace;
 }
 */

+ (uint64_t)getFreeDiskspace
{
    uint64_t totalSpace = 0;
    uint64_t totalFreeSpace = 0;
    
    __autoreleasing NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    
    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
        //        NSLog(@"Memory Capacity of %llu MiB with %llu MiB Free memory available.", ((totalSpace/1024ll)/1024ll), ((totalFreeSpace/1024ll)/1024ll));
//        NSLog(@"total free space:%llu bytes", totalFreeSpace);
    } else {
        NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %ld", [error domain], (long)[error code]);
    }
    
    return totalFreeSpace;
}

+ (NSString *)humanReadableStringFromBytes:(unsigned long long)byteCount
{
    
    float numberOfBytes = byteCount;
    int multiplyFactor = 0;
    
    NSArray *tokens = [NSArray arrayWithObjects:@"bytes",@"KB",@"MB",@"GB",@"TB",@"PB",@"EB",@"ZB",@"YB",nil];
    
    while (numberOfBytes > 1024) {
        numberOfBytes /= 1024;
        multiplyFactor++;
    }
    
    return [NSString stringWithFormat:@"%4.2f %@",numberOfBytes, [tokens objectAtIndex:multiplyFactor]];
}

+ (double)getBatteryLevel
{
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    UIDevice *device = [UIDevice currentDevice];
    double deviceLevel = device.batteryLevel;

    if (device.batteryState == UIDeviceBatteryStateUnknown) {
//        NSLog(@"UnKnow");
    }else if (device.batteryState == UIDeviceBatteryStateUnplugged){
//        NSLog(@"Unplugged");
    }else if (device.batteryState == UIDeviceBatteryStateCharging){
//        NSLog(@"Charging");
        deviceLevel = 1.0;
    }else if (device.batteryState == UIDeviceBatteryStateFull){
//        NSLog(@"Full");
        deviceLevel = 1.0;
    }
    
    return deviceLevel;
}

@end
