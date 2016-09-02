//
//  IDFileManager.h
//  VideoCaptureDemo
//
//  Created by Adriaan Stellingwerff on 9/04/2015.
//  Copyright (c) 2015 Infoding. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IDFileManager : NSObject

- (NSURL *) tempFileURL;
+ (void) removeFile:(NSURL *)outputFileURL;
- (void) copyFileToDocuments:(NSURL *)fileURL;
+ (void) copyFileToCameraRoll:(NSURL *)fileURL didFinishcompledBlock:(void (^)(void))aftersaved;
- (void) saveImageFileToCameraRoll:(NSData*)imageData didFinishcompledBlock:(void (^)(void))aftersaved;
+ (uint64_t)sizeOfFile:(NSURL *)fileURL;
+ (uint64_t)getFreeDiskspace;
+ (double)getBatteryLevel;
+ (NSString *)inDocumentsDirectory:(NSString *)path;
+ (NSString *)humanReadableStringFromBytes:(unsigned long long)byteCount;

@end
