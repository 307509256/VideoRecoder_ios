#import "VideoRecorder.h"
#import <AVFoundation/AVFoundation.h>

@interface VideoRecorder() <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDevice *cameraDevice;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;
@end

@implementation VideoRecorder

- (instancetype)init {
    return [self initWithDevices:DEVICE_MIC | DEVICE_BACK_CAMERA];
}

#pragma mark - interface methods

- (instancetype)initWithDevices:(int8_t)devices {
    self = [super init];
    if(self){
        self.captureSession = [self setupCaptureSession:devices];
        [self setupOutput];
        _state = STATE_IDEL;
        _orientation = AVCaptureVideoOrientationPortrait;
        _autoOrientation = YES;
    }
    return self;
}

- (void)startRecording:(NSURL *)path {
    if(_autoOrientation){
        [self adaptOrientation];
    }else{
        self.orientation = _orientation;
    }
    [self.movieFileOutput startRecordingToOutputFileURL:path recordingDelegate:self];
    _state = STATE_RECORDING;
}

- (void)stopRecording {
    [self.movieFileOutput stopRecording];
    _state = STATE_STOP;
}

- (void)startPreview {
    [self.captureSession startRunning];
}

/// fully preview on the view
- (void)startPreviewFull:(UIView*)view{
    [self startPreview];
    AVCaptureVideoPreviewLayer *previewLayer = self.previewLayer;
    previewLayer.frame = view.bounds;
    [view.layer insertSublayer:previewLayer atIndex:0];
}

- (void)stopPreview {
    [self stopRecording];
    [self.captureSession stopRunning];
}

/// auto adapt captured video orientation
- (void)adaptOrientation{
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    switch (orientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            [self setOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
            break;
        case UIDeviceOrientationLandscapeRight:
            [self setOrientation:AVCaptureVideoOrientationLandscapeLeft];
            break;
        case UIDeviceOrientationLandscapeLeft:
            [self setOrientation:AVCaptureVideoOrientationLandscapeRight];
            break;
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationUnknown:
        case UIDeviceOrientationPortrait:
        default:
            [self setOrientation:AVCaptureVideoOrientationPortrait];
            break;
    }
}

#pragma mark - AVCaptureFileOutputRecordingDelegate methods

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections {
    [self.delegate didBeginRecording:self];
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    [self.delegate didEndRecording:self savedPath:outputFileURL error:error];
    
}

#pragma mark - setter & getter

- (void)setOrientation:(AVCaptureVideoOrientation)orientation{
    _orientation = orientation;
    if(!self.movieFileOutput){
        NSLog(@"setCaptureOrientation movieFileOutput=nil");
        return;
    }
    AVCaptureConnection *videoConnection = nil;
    for(AVCaptureConnection *connection in [self.movieFileOutput connections]) {
        for ( AVCaptureInputPort *port in [connection inputPorts]) {
            if ( [[port mediaType] isEqual:AVMediaTypeVideo])
            {
                videoConnection = connection;
            }
        }
    }
    if([videoConnection isVideoOrientationSupported]) {
        videoConnection.videoOrientation = orientation;
    }else{
        NSLog(@"setCaptureOrientation isVideoOrientationSupported=false");
    }
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    if(!_previewLayer && self.captureSession){
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    }
    return _previewLayer;
}

#pragma mark - Capture Session Setup

- (AVCaptureSession *)setupCaptureSession:(int8_t)devices {
    AVCaptureSession *captureSession = [AVCaptureSession new];
    if(devices & DEVICE_MIC){
        [self addDefaultMicInputToCaptureSession:captureSession];
    }
    if(devices & DEVICE_BACK_CAMERA){
        [self addCameraAtPosition:AVCaptureDevicePositionBack toCaptureSession:captureSession];
    }else if(devices & DEVICE_FRONT_CAMERA){
        [self addCameraAtPosition:AVCaptureDevicePositionFront toCaptureSession:captureSession];
    }
    return captureSession;
}

- (void)addCameraAtPosition:(AVCaptureDevicePosition)position toCaptureSession:(AVCaptureSession *)captureSession {
    NSError *error;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *cameraDeviceInput;
    for(AVCaptureDevice *device in devices){
        if(device.position == position){
            cameraDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
        }
    }
    if(!cameraDeviceInput){
        NSLog(@"No capture device found for requested position");
    }
    
    if(error){
        NSLog(@"error configuring camera input: %@", [error localizedDescription]);
    } else {
        [self addInput:cameraDeviceInput toCaptureSession:captureSession];
        self.cameraDevice = cameraDeviceInput.device;
    }
}

- (void)addDefaultMicInputToCaptureSession:(AVCaptureSession *)captureSession {
    NSError *error;
    AVCaptureDeviceInput *micDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:&error];
    if(error){
        NSLog(@"error configuring mic input: %@", [error localizedDescription]);
    } else {
        [self addInput:micDeviceInput toCaptureSession:captureSession];
    }
}

- (void)addInput:(AVCaptureDeviceInput *)input toCaptureSession:(AVCaptureSession *)captureSession {
    if([captureSession canAddInput:input]){
        [captureSession addInput:input];
    } else {
        NSLog(@"can't add input: %@", input);
    }
}

- (void)setupOutput{
    self.movieFileOutput = [AVCaptureMovieFileOutput new];
    if([self.captureSession canAddOutput:self.movieFileOutput]){
        [self.captureSession addOutput:self.movieFileOutput];
    } else {
        NSLog(@"setupOutput can't add output: %@", self.movieFileOutput);
    }
    
    NSURL *url = [NSURL fileURLWithPath:@""];
    AVAssetWriter *assetWriter = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:nil];
    AVAssetWriterInput *videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:nil];
    videoInput.expectsMediaDataInRealTime = YES;
    AVAssetWriterInput *audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:nil];
    audioInput.expectsMediaDataInRealTime = YES;
    if ([assetWriter canAddInput:videoInput]) {
        [assetWriter addInput:videoInput];
    }
    if ([assetWriter canAddInput:audioInput]) {
        [assetWriter addInput:audioInput];
    }
    
    
    dispatch_queue_t videoDataOutputQueue = dispatch_queue_create( "com.example.capturesession.videodata", DISPATCH_QUEUE_SERIAL );
    AVCaptureVideoDataOutput *_videoDataOutput = [AVCaptureVideoDataOutput new];
    _videoDataOutput.videoSettings = nil;
    _videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    [_videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    [self.captureSession addOutput:_videoDataOutput];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    NSLog(@"captureOutput formatDescription=%@", formatDescription);
    NSLog(@"captureOutput sampleBuffer=%@", sampleBuffer);
}

@end

