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
        
        NSError *error = nil;
        
        NSURL *videoUrl = [[NSURL alloc] initFileURLWithPath:tempPath];
        
        [self mergeAudio:inputURL withVideo:videoUrl andSaveToPathUrl:output withCompletion:^(BOOL success) {
            if (success) {
                UISaveVideoAtPathToSavedPhotosAlbum(output, self, nil, nil);
                resolve(output);
            } else {
                reject(@"Export Failed", nil, nil);
            }
        }];
    }];
}

- (void)mergeAudio:(NSURL *) audioURL withVideo:(NSURL *) videoURL andSaveToPathUrl:(NSString *) savePath withCompletion:(void (^)(BOOL success))completion {

    AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:audioURL options:nil];
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:videoURL options:nil];

    AVMutableComposition* mixComposition = [AVMutableComposition composition];

    AVMutableCompositionTrack *compositionCommentaryTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
    preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionCommentaryTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration)
    ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
    atTime:kCMTimeZero error:nil];

    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
    preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration)
    ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
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
