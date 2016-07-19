//
//  ViewController.m
//  VideoRecoder
//
//  Created by liangjiajian_mac on 16/6/3.
//  Copyright © 2016年 cn.ljj. All rights reserved.
//

#import "ViewController.h"
#import "VideoRecorder.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface ViewController () <VideoRecorderDelegate>
@property(strong, nonatomic) VideoRecorder *recorder;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.recorder = [VideoRecorder new];
    self.recorder.delegate = self;
    [self.recorder startPreviewFull:self.view];
//    [self.recorder startPreview];
//    AVCaptureVideoPreviewLayer *previewLayer = self.recorder.previewLayer;
//    previewLayer.frame = CGRectMake(0, 0, 100, 100);
//    [self.view.layer insertSublayer:previewLayer atIndex:0];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(onTap)];
    [self.view addGestureRecognizer:tap];
}



- (void)didReceiveMemoryWarning {

}

- (void)onTap{
    if(self.recorder.state == STATE_RECORDING){
        [self stopRecorder];
    }else{
        [self startRecorder];
    }
}

- (void)startRecorder{
    NSString *path = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger i = 0;
    while(path == nil || [fm fileExistsAtPath:path]){
        path = [NSString stringWithFormat:@"%@output%ld.mov", NSTemporaryDirectory(), (long)i];
        i++;
    }
    [self.recorder startRecording:[NSURL fileURLWithPath:path]];
}

- (void)stopRecorder{
    [self.recorder stopRecording];
}

#pragma mark VideoRecorderDelegate

- (void)didBeginRecording:(VideoRecorder *)recorder {
    NSLog(@"ViewController didBeginRecording");
}

- (void)didEndRecording:(VideoRecorder *)recorder savedPath:(NSURL *)url error:(NSError *)error {
    NSLog(@"ViewController didEndRecording url=%@, error=%@", url, [error localizedDescription]);
    [self copyFileToCameraRoll:url];
}

- (void)copyFileToCameraRoll:(NSURL *)fileURL {
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
            //remove temp file
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:&error];
            if(error){
                NSLog(@"error: %@", [error localizedDescription]);
            }
            
        }
    }];
    
}

@end
