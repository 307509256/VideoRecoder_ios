#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#define DEVICE_MIC          0x01
#define DEVICE_FRONT_CAMERA 0x02
#define DEVICE_BACK_CAMERA  0x04

@protocol VideoRecorderDelegate;

typedef enum {
    STATE_IDEL = 0,
    STATE_RECORDING = 1,
    STATE_STOP = 2,
}RecorderState;

@interface VideoRecorder : NSObject <AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, weak) id<VideoRecorderDelegate> delegate;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (atomic, assign, readonly) RecorderState state;
@property (nonatomic, assign) AVCaptureVideoOrientation orientation;
@property (nonatomic, assign) BOOL autoOrientation;

- (instancetype)initWithDevices:(int8_t)devices;
- (void)startPreview;
- (void)startPreviewFull:(UIView*)view;
- (void)stopPreview;
- (void)startRecording:(NSURL*)path;
- (void)stopRecording;
- (void)adaptOrientation;
@end

@protocol VideoRecorderDelegate <NSObject>
@required
- (void)didBeginRecording:(VideoRecorder *)recorder;
- (void)didEndRecording:(VideoRecorder *)recorder savedPath:(NSURL *)url error:(NSError *)error;
@end