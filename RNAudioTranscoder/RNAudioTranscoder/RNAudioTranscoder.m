#import "RNAudioTranscoder.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTUtils.h>
#import <React/RCTLog.h>
#import <AVFoundation/AVFoundation.h>
#import "HJImagesToVideo.h"
#import <AssetsLibrary/AssetsLibrary.h>

@implementation RNAudioTranscoder

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(
    transcode: (NSDictionary *) obj
    resolver:(RCTPromiseResolveBlock) resolve
    rejecter: (RCTPromiseRejectBlock) reject
) {
    NSString *inputPath = obj[@"input"];
    if ([inputPath hasPrefix:@"file"]) {
        inputPath = [inputPath stringByReplacingOccurrencesOfString:@"file:/" withString:@""];
    }
    NSURL *inputURL = [[NSURL alloc] initFileURLWithPath:inputPath];
    
    AVURLAsset *audiotrack = [AVURLAsset assetWithURL:inputURL];
    NSMutableArray *imagesArray = [NSMutableArray array];
    for (int i = 0; i < CMTimeGetSeconds(audiotrack.duration) - 1; ++i) {
        [imagesArray addObject:[UIImage imageNamed:@"soundOnly"]];
    }
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"temp.mp4"]];
    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
    
    NSString *output = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"output.mp4"]];
    [[NSFileManager defaultManager] removeItemAtPath:output error:NULL];
    
    [HJImagesToVideo videoFromImages:imagesArray
                              toPath:tempPath
                            withSize:CGSizeMake(670, 380)
                             withFPS:1
                  animateTransitions:nil
                   withCallbackBlock:^(BOOL success1) {
        
        if (success1) {
            NSURL *videoUrl = [[NSURL alloc] initFileURLWithPath:tempPath];
            [self mergeAudio:inputURL withVideo:videoUrl andSaveToPathUrl:output withCompletion:^(BOOL success) {
                if (success) {
                    // UISaveVideoAtPathToSavedPhotosAlbum(output, self, nil, nil);
                    resolve(output);
                } else {
                    reject(@"Export Failed", nil, nil);
                }
            }];
        } else {
            reject(@"Export Failed", nil, nil);
        }
       
    }];
}

- (void)mergeAudio:(NSURL *) audioURL withVideo:(NSURL *) videoURL andSaveToPathUrl:(NSString *) savePath withCompletion:(void (^)(BOOL success))completion {
    dispatch_semaphore_t sem1 = dispatch_semaphore_create(0);
    AVURLAsset *audioAsset = [[AVURLAsset alloc] initWithURL:audioURL options:nil];
    [audioAsset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        NSLog(@"LOAD AUDIO COMPLETED");
        dispatch_semaphore_signal(sem1);
    }];
    dispatch_semaphore_wait(sem1, DISPATCH_TIME_FOREVER);
    
    dispatch_semaphore_t sem2 = dispatch_semaphore_create(0);
    AVURLAsset* videoAsset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    [videoAsset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        NSLog(@"LOAD VIDEO COMPLETED");
        dispatch_semaphore_signal(sem2);
    }];
    dispatch_semaphore_wait(sem2, DISPATCH_TIME_FOREVER);
    
    NSArray *audioTracks = [audioAsset tracksWithMediaType:AVMediaTypeAudio];
    NSArray *videoTracks = [videoAsset tracksWithMediaType:AVMediaTypeVideo];
    
    if (audioTracks.count == 0 || videoTracks.count == 0) {
        completion(NO);
        return;
    }

    AVMutableComposition* mixComposition = [AVMutableComposition composition];

    AVMutableCompositionTrack *compositionCommentaryTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
    preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionCommentaryTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration)
    ofTrack:[audioTracks objectAtIndex:0]
    atTime:kCMTimeZero error:nil];

    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
    preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration)
    ofTrack:[videoTracks objectAtIndex:0]
    atTime:kCMTimeZero error:nil];

    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition
    presetName:AVAssetExportPresetPassthrough];

    NSURL *savetUrl = [NSURL fileURLWithPath:savePath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
    }

    _assetExport.outputFileType = @"com.apple.quicktime-movie";


    _assetExport.outputURL = savetUrl;
    _assetExport.shouldOptimizeForNetworkUse = YES;

    [_assetExport exportAsynchronouslyWithCompletionHandler:^(void) {
        NSLog(@"fileSaved !");
        if (_assetExport.status == AVAssetExportSessionStatusCompleted) {
            completion(YES);
        } else {
            completion(NO);
        }
    }];
}

@end
