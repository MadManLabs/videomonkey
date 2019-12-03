//
//  Transcoder.m
//  VideoMonkey
//
//  Created by Chris Marrin on 11/26/08.

/*
Copyright (c) 2009-2011 Chris Marrin (chris@marrin.com)
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

    - Redistributions of source code must retain the above copyright notice, this 
      list of conditions and the following disclaimer.

    - Redistributions in binary form must reproduce the above copyright notice, 
      this list of conditions and the following disclaimer in the documentation 
      and/or other materials provided with the distribution.

    - Neither the name of Video Monkey nor the names of its contributors may be 
      used to endorse or promote products derived from this software without 
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH 
DAMAGE.
*/

#import <ScriptingBridge/ScriptingBridge.h>
#import "iTunes.h"

#import "Transcoder.h"
#import "AppController.h"
#import "Command.h"
#import "DeviceController.h"
#import "FileInfoPanelController.h"
#import "MoviePanelController.h"
#import "Metadata.h"

static NSString* makeFrameSize(int width, int height)
{
    return [[NSString stringWithFormat:@"%dx%d", width, height] retain];
}

@implementation OverrideableValue

@synthesize overriddenValue;

- (id)initWithListener:(id)l
{
    if (self = [super init]) {
        listener = [l retain];
    }
    return self;
}

- (void)dealloc
{
    [listener release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    OverrideableValue* v = [[OverrideableValue allocWithZone:zone] init];
    v.overridden = overridden;
    v.overriddenValue = [overriddenValue retain];
    v.value = [value retain];
    return v;
}

- (void)setOverridden:(BOOL)v
{
    BOOL changed = v ^ overridden;
    overridden = v;
    if (changed) {
        if (overridden && !overriddenValue)
            self.overriddenValue = value;
        self.value = value; // Update value in GUI
        [[AppController instance] uiChanged];    
    }
}

- (BOOL)overridden
{
    return overridden;
}

- (void)setValue:(id)v
{
    [value release];
    value = [v retain];
    if (listener)
        [listener overrideableValueUdated:self];
}

- (id)value
{
    if (overridden)
        return overriddenValue;
    return value;
}

- (void)setOverriddenValue:(id)v
{
    [overriddenValue release];
    overriddenValue = [v retain];
    if (overridden)
        self.value = value;
    [[AppController instance] uiChanged];    
}

- (id)overriddenValue
{
    return overriddenValue;
}

@end

@implementation TranscoderFileInfo

// General
@synthesize filename;
@synthesize format;
@synthesize duration;
@synthesize bitrate;
@synthesize fileSize;

// Video
@synthesize videoIndex;
@synthesize videoCodec;
@synthesize videoProfile;
@synthesize videoInterlaced;
@synthesize videoFrameSize;
@synthesize videoWidth;
@synthesize videoHeight;
@synthesize videoAspectRatio;
@synthesize videoFrameRate;
@synthesize videoBitrate;
@synthesize videoPadLeft;
@synthesize videoPadRight;
@synthesize videoPadTop;
@synthesize videoPadBottom;

// Audio
@synthesize audioIndex;
@synthesize audioCodec;
@synthesize audioSampleRate;
@synthesize audioChannels;
@synthesize audioBitrate;

@synthesize extraOptions;

- (void)setVideoWidthHeightOverridden:(BOOL)v
{
    self.videoWidth.overridden = v;
    self.videoHeight.overridden = v;
}

- (BOOL)videoWidthHeightOverridden
{
    return self.videoWidth.overridden;
}

- (void)setVideoPaddingOverridden:(BOOL)v
{
    self.videoPadLeft.overridden = v;
    self.videoPadRight.overridden = v;
    self.videoPadTop.overridden = v;
    self.videoPadBottom.overridden = v;
}

- (BOOL)videoPaddingOverridden
{
    return self.videoPadLeft.overridden;
}

- (id)init
{
    if (self = [super init]) {
        audioCodec = [[OverrideableValue alloc] init];
        audioChannels = [[OverrideableValue alloc] init];
        audioSampleRate = [[OverrideableValue alloc] init];
        audioBitrate = [[OverrideableValue alloc] init];
        videoCodec = [[OverrideableValue alloc] init];
        videoProfile = [[OverrideableValue alloc] init];
        videoFrameRate = [[OverrideableValue alloc] init];
        videoWidth = [[OverrideableValue alloc] initWithListener:self];
        videoHeight = [[OverrideableValue alloc] initWithListener:self];
        videoAspectRatio = [[OverrideableValue alloc] init];
        videoPadLeft = [[OverrideableValue alloc] init];
        videoPadRight = [[OverrideableValue alloc] init];
        videoPadTop = [[OverrideableValue alloc] init];
        videoPadBottom = [[OverrideableValue alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [audioCodec release];
    [audioChannels release];
    [audioSampleRate release];
    [audioSampleRate release];
    [videoCodec release];
    [videoProfile release];
    [videoFrameRate release];
    [videoWidth release];
    [videoHeight release];
    [videoAspectRatio release];
    [videoPadLeft release];
    [videoPadRight release];
    [videoPadTop release];
    [videoPadBottom release];
    [super dealloc];
}

- (void)overrideableValueUdated:(OverrideableValue*)value
{
    self.videoFrameSize = makeFrameSize([videoWidth.value intValue], [videoHeight.value intValue]);
}

@end


@implementation Transcoder

+(TranscoderFileInfo*) dummyFileInfo
{
    static TranscoderFileInfo* dummy;
    if (!dummy)
        dummy = [[TranscoderFileInfo alloc] init];
    return dummy;
}

-(TranscoderFileInfo*) inputFileInfo
{
    return ([m_inputFiles count] > 0) ? ((TranscoderFileInfo*) [m_inputFiles objectAtIndex: 0]) : [Transcoder dummyFileInfo];
}

// Properties
@synthesize outputFileInfo = m_outputFileInfo;
@synthesize audioQuality = m_audioQuality;
@synthesize avOffset = m_avOffset;
@synthesize progress = m_progress;
@synthesize enabled = m_enabled;
@synthesize metadata = m_metadata;
@synthesize fileStatus = m_fileStatus;

- (BOOL)noFrameSizeSnap
{
    return m_noFrameSizeSnap;
}

- (void)setNoFrameSizeSnap:(BOOL)v
{
    m_noFrameSizeSnap = v;
    [[AppController instance] uiChanged];    
}

-(BOOL) enabled
{
    return m_enabled;    
}

-(void) setEnabled:(BOOL) enabled
{
    if (m_fileStatus == FS_ENCODING || m_fileStatus == FS_PAUSED) {
        NSBeginAlertSheet([NSString stringWithFormat:@"Unable to disable %@", [self.inputFileInfo.filename lastPathComponent]], 
                            nil, nil, nil, [[NSApplication sharedApplication] mainWindow], 
                            nil, nil, nil, nil, 
                            @"File is being encoded. Stop encoding then try again.");
        return;
    }
    
    m_enabled = enabled;
    [[AppController instance] updateEncodingInfo];    
}

-(FileInfoPanelController*) fileInfoPanelController
{
    return [[AppController instance] fileInfoPanelController];
}

static double ffmpegFramerateFromString(NSString* string)
{
    // split into lines
    NSArray* lines = [string componentsSeparatedByString:@"\n"];
    
    for (NSString* line in lines) {
        if ([line hasPrefix:@"    Stream #"]) {
            NSString* substring = [line substringFromIndex:12];
            NSArray* array = [substring componentsSeparatedByString:@" "];
            if ([[array objectAtIndex:1] isEqualToString:@"Video:"]) {
                // find a value that is "fps", "tbr" or "tb(r)", framerate is the value before that
                NSUInteger index = [array indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop)
                {
                    if ([obj caseInsensitiveCompare:@"fps,"] == NSOrderedSame || [obj caseInsensitiveCompare:@"tbr,"] == NSOrderedSame || 
                            [obj caseInsensitiveCompare:@"tb(r),"] == NSOrderedSame || [obj caseInsensitiveCompare:@"fps"] == NSOrderedSame || 
                            [obj caseInsensitiveCompare:@"tbr"] == NSOrderedSame || [obj caseInsensitiveCompare:@"tb(r)"] == NSOrderedSame) {
                        *stop = YES;
                        return YES;
                    }
                    return NO;
                }];
                return (index < [array count]) ? [[array objectAtIndex:index - 1] doubleValue] : 0;
            }
        }
    }
    
    return 0;
}

static int ffmpegIndexFromString(NSString* string, NSString* codec)
{
    // split into lines
    NSArray* lines = [string componentsSeparatedByString:@"\n"];
    
    for (NSString* line in lines) {
        if ([line hasPrefix:@"    Stream #"]) {
            NSString* streamIndex = [line substringFromIndex:12];
            NSArray* array = [streamIndex componentsSeparatedByString:@" "];
            if ([[array objectAtIndex:1] isEqualToString:codec]) {
                NSArray* streamIndexes = [[array objectAtIndex:0] componentsSeparatedByString:@"."];
                if ([streamIndexes count] < 2)
                    streamIndexes = [[array objectAtIndex:0] componentsSeparatedByString:@":"];
                if ([streamIndexes count] < 2)
                    return -1;
                return [[streamIndexes objectAtIndex:1] intValue];
            }
        }
    }
    
    return -1;
}

// Determine if the passed NSFileHandle has any data to read
static BOOL isReadable(NSFileHandle* fileHandle)
{
    int fd = [fileHandle fileDescriptor];
    fd_set fdset;
    struct timeval tmout = { 0, 0 }; // return immediately
    FD_ZERO(&fdset);
    FD_SET(fd, &fdset);
    return select(fd + 1, &fdset, NULL, NULL, &tmout) > 0;
}

static void logInputFileError(NSString* filename)
{
    [[AppController instance] log: [NSString stringWithFormat:@"The file '%@' is not a video format Video Monkey understands. \n", filename]];
}

-(BOOL) _validateInputFile: (TranscoderFileInfo*) info
{
    NSMutableString* mediainfoPath = [NSMutableString stringWithString: [[NSBundle mainBundle] resourcePath]];
    [mediainfoPath appendString:@"/bin/mediainfo"];
    
    NSMutableString* mediainfoInformPath = [NSMutableString stringWithString: @"--Inform=file://"];
    [mediainfoInformPath appendString: [[NSBundle mainBundle] resourcePath]];
    [mediainfoInformPath appendString:@"/mediainfo-inform.csv"];
    
    NSTask* task = [[NSTask alloc] init];
    NSMutableArray* args = [NSMutableArray arrayWithObjects: mediainfoInformPath, [info filename], nil];
    [task setArguments: args];
    [task setLaunchPath: mediainfoPath];
    
    NSPipe* pipe = [[NSPipe alloc] init];
    [task setStandardOutput:[pipe fileHandleForWriting]];
    
    [task launch];
    
    [task waitUntilExit];
    if (!isReadable([pipe fileHandleForReading])) {
        logInputFileError([info filename]);
        [task release];
        [pipe release];
        return NO;
    }
    
    NSString* data = [[NSString alloc] initWithData: [[pipe fileHandleForReading] availableData] encoding: NSASCIIStringEncoding];
    [task release];
    [pipe release];
    
    // The first line must start with "-General-" or the file is not valid
    if (![data hasPrefix: @"-General-"]) {
        logInputFileError([info filename]);
        [data release];
        return NO;
    }
    
    NSArray* components = [data componentsSeparatedByString:@"\n"];
    [data release];
    
    // We always have a General line.
    NSArray* general = [[components objectAtIndex:0] componentsSeparatedByString:@","];
    if ([general count] != 6) {
        logInputFileError([info filename]);
        return NO;
    }
        
    info.format = [general objectAtIndex:1];
    if ([[general objectAtIndex:2] isEqualToString:@"QuickTime"])
        info.format = @"Quicktime";
    info.duration = [[general objectAtIndex:3] doubleValue] / 1000;
    double overallBitrate = [[general objectAtIndex:4] doubleValue];
    info.fileSize = [[general objectAtIndex:5] doubleValue];

    if ([info.format length] == 0) {
        logInputFileError([info filename]);
        return NO;
    }
        
    // Do video if it's there
    int offset = 1;
    double originalFramerate = 0;
    double nominalFramerate = 0;
    double ffmpegFramerate = 0;
    double mediaInfoFramerate = 0;
    if ([components count] > offset && [[components objectAtIndex:offset] hasPrefix: @"-Video-"]) {
        NSArray* video = [[components objectAtIndex:offset] componentsSeparatedByString:@","];
        offset = 2;
        
        // -Video-,%StreamKindID%,%ID%,%Language%,%Format%,%Codec_Profile%,%ScanType%,%ScanOrder%,%Width%,%Height%,%PixelAspectRatio%,%DisplayAspectRatio%,%FrameRate%.%Bitrate%

        if ([video count] != 14) {
            logInputFileError([info filename]);
            return NO;
        }
            
        info.videoCodec.value = [video objectAtIndex:2];
        info.videoProfile.value = [video objectAtIndex:3];
        info.videoInterlaced = [[video objectAtIndex:4] isEqualToString:@"Interlace"];
        info.videoWidth.value = [video objectAtIndex:6];
        info.videoHeight.value = [video objectAtIndex:7];
        info.videoAspectRatio.value = [video objectAtIndex:9];
        info.videoBitrate = [[video objectAtIndex:11] doubleValue];
        mediaInfoFramerate = [[video objectAtIndex:10] doubleValue];
        originalFramerate = [[video objectAtIndex:12] doubleValue];
        nominalFramerate = [[video objectAtIndex:13] doubleValue];
        
        // standardize video codec name
        if ([info.videoCodec.value caseInsensitiveCompare:@"vc-1"] == NSOrderedSame || [info.videoCodec.value caseInsensitiveCompare:@"wmv3"] == NSOrderedSame)
            info.videoCodec.value = VC_WMV3;
        else if ([info.videoCodec.value caseInsensitiveCompare:@"avc"] == NSOrderedSame || [info.videoCodec.value caseInsensitiveCompare:@"avc1"] == NSOrderedSame)
            info.videoCodec.value = VC_H264;
    }
    
    // Do audio if it's there
    BOOL hasAudio = NO;
    
    if ([components count] > offset && [[components objectAtIndex:offset] hasPrefix: @"-Audio-"]) {
        NSArray* audio = [[components objectAtIndex:offset] componentsSeparatedByString:@","];

        // -Audio-,%StreamKindID%,%ID%,%Language%,%Format%,%SamplingRate%,%Channels%,%BitRate%
        if ([audio count] != 6) {
            logInputFileError([info filename]);
            return NO;
        }

        info.audioCodec.value = [audio objectAtIndex:2];
        info.audioSampleRate.value = [audio objectAtIndex:3];
        info.audioChannels.value = [audio objectAtIndex:4];
        info.audioBitrate.value = [audio objectAtIndex:5];
        
        hasAudio = YES;
    }
    
    info.videoIndex = -1;
    info.audioIndex = -1;
    m_avOffset = hasAudio ? 0 : nan(0);
    
    // We need some things mediainfo doesn't provide (at least not accurately). This includes:
    //
    //      - Stream indexes
    //      - framerate
            
    NSMutableString* ffmpegPath = [NSMutableString stringWithString: [[NSBundle mainBundle] resourcePath]];
    [ffmpegPath appendString:@"/bin/ffmpeg"];
    args = [NSMutableArray arrayWithObjects: @"-i", [info filename], nil];
    
    task = [[NSTask alloc] init];
    [task setArguments: args];
    [task setLaunchPath: ffmpegPath];
    
    pipe = [[NSPipe alloc] init];
    [task setStandardError:[pipe fileHandleForWriting]];
    [task launch];
    [task waitUntilExit];
        
    if (!isReadable([pipe fileHandleForReading]))
        [[AppController instance] log: [NSString stringWithFormat:@"Unable to obtain stream index data from the file '%@'. "
                                                                   "The A/V offset feature will not be available. \n", info.filename]];
    else {
        data = [[NSString alloc] initWithData:[[pipe fileHandleForReading] availableData] encoding: NSASCIIStringEncoding];
    
        if (hasAudio) {
            info.videoIndex = ffmpegIndexFromString(data, @"Video:");
            info.audioIndex = ffmpegIndexFromString(data, @"Audio:");
        }
        ffmpegFramerate = ffmpegFramerateFromString(data);
        [data release];
    }
    
    [task release];
    [pipe release];
    
    // compute some values
    double framerate = 0;
    if (!mediaInfoFramerate)
        if (!originalFramerate)
            if (!nominalFramerate)
                if (!ffmpegFramerate)
                    framerate = 30;
                else
                    framerate = ffmpegFramerate;
            else
                framerate = nominalFramerate;
        else
            framerate = originalFramerate;
    else
        framerate = mediaInfoFramerate;
            
    info.videoFrameRate.value = [NSString stringWithFormat:@"%f", framerate];

    if (!info.videoBitrate)
        info.videoBitrate = overallBitrate - [info.audioBitrate.value doubleValue];
        
    info.bitrate = info.videoBitrate + [info.audioBitrate.value doubleValue];
    return YES;
}

static NSImage* fileStatusImage(FileStatus status)
{
    NSString* name = nil;
    switch(status)
    {
        case FS_INVALID:    name = @"invalid";     break;
        case FS_VALID:      name = @"ready";       break;
        case FS_ENCODING:   name = @"converting";  break;
        case FS_FAILED:     name = @"error";       break;
        case FS_SUCCEEDED:  name = @"ok";          break;
        case FS_PAUSED:     name = @"paused";      break;
    }
    
    if (!name)
        return nil;
        
    NSString* path = [[NSBundle mainBundle] pathForResource:name ofType:@"png"];
    return [[[NSImage alloc] initWithContentsOfFile:path] autorelease]; 
}

- (void)updateOutputFileName
{
    NSString* inputFileName = self.inputFileInfo.filename;
    
    // extract filename
    NSString* lastComponent = [inputFileName lastPathComponent];
    NSString* inputPath = [inputFileName stringByDeletingLastPathComponent];
    NSString* baseName = [lastComponent stringByDeletingPathExtension];
    NSString* suffix = [[AppController instance].deviceController fileSuffix];
    NSString* savePath = [AppController instance].savePath;

    if (!savePath)
        savePath = inputPath;
        
    // If the output file name hasn't changed, don't do an existance check. 
    // Doing so would generate a new file name if this function is called
    // after this file is encoded.
        
    // now make sure the file doesn't exist
    NSString* filename;
    for (int i = 0; i < 10000; ++i) {
        if (i == 0)
            filename = [[savePath stringByAppendingPathComponent: baseName] stringByAppendingPathExtension: suffix];
        else
            filename = [[savePath stringByAppendingPathComponent: 
                        [NSString stringWithFormat: @"%@_%d", baseName, i]] stringByAppendingPathExtension: suffix];
            
        if (![[NSFileManager defaultManager] fileExistsAtPath: filename])
            break;
    }
    
    self.outputFileInfo.filename = filename;
}

- (Transcoder*)initWithFilename:(NSString*) filename;
{
    if (self = [super init]) {
        m_inputFiles = [[NSMutableArray alloc] init];
        m_outputFileInfo = [[TranscoderFileInfo alloc] init];
        m_fileStatus = FS_INVALID;
        m_enabled = YES;
        m_tempAudioFileName = [[NSString stringWithFormat:@"/tmp/%p-tmpaudio.wav", self] retain];
        
        // init the progress indicator
        m_progressIndicator = [[NSProgressIndicator alloc] init];
        [m_progressIndicator setMinValue:0];
        [m_progressIndicator setMaxValue:1];
        [m_progressIndicator setIndeterminate: NO];
        [m_progressIndicator setBezeled: NO];
        
        // init the status image view
        m_statusImageView = [[NSImageView alloc] init];
        [m_statusImageView setImage: fileStatusImage(m_fileStatus)];
        
        [self addInputFile:filename];
        [self updateOutputFileName];

        self.outputFileInfo.duration = self.inputFileInfo.duration;
    }
    return self;
}

-(void) dealloc
{
    [m_tempAudioFileName release];
    [m_progressIndicator removeFromSuperview];
    [m_statusImageView removeFromSuperview];
    [m_progressIndicator release];
    [m_statusImageView release];
    [m_inputFiles release];
    [m_outputFileInfo release];
    
    [super dealloc];
}
    
-(void) createMetadata
{
    self.metadata = [Metadata metadataWithTranscoder:self];
}

- (int) addInputFile: (NSString*) filename
{
    TranscoderFileInfo* file = [[TranscoderFileInfo alloc] init];
    file.filename = filename;
    
    m_fileStatus = [self _validateInputFile: file] ? FS_VALID : FS_INVALID;
    m_enabled = m_fileStatus == FS_VALID;
    [m_statusImageView setImage: fileStatusImage(m_fileStatus)];
    [m_inputFiles addObject: file];
    [file release];
    
    if (m_fileStatus == FS_VALID) {
        // read the metadata
        [self createMetadata];
        if ([[[AppController instance] fileInfoPanelController] autoSearch])
            [self.metadata searchAgain];
    }
    
    return (m_fileStatus == FS_VALID) ? (int)([m_inputFiles count] - 1) : -1;
}

-(NSValue*) progressCell
{
    return [NSValue valueWithPointer:self];
}

-(void) resetStatus
{
    // If we're enabled, set the status to FS_VALID, even if we were M_FAILED or M_INVALID.
    // This gives the encoder a chance to run, just in case we were wrong about it.
    if (m_enabled) {
        m_fileStatus = FS_VALID;
        [m_statusImageView setImage: fileStatusImage(m_fileStatus)];
    }
}

-(NSProgressIndicator*) progressIndicator
{
    return m_progressIndicator;
}

-(NSImageView*) statusImageView
{
    return m_statusImageView;
}

-(FileStatus) fileStatus
{
    return m_fileStatus;
}

-(BOOL) hasInputAudio
{
    return [self.inputFileInfo.audioSampleRate.value doubleValue] != 0;
}

-(NSString*) tempAudioFileName
{
    return m_tempAudioFileName;
}

static NSString* escapePath(NSString* path)
{
    NSArray* array = [path componentsSeparatedByString:@"$"];
    return [array componentsJoinedByString:@"$$"];
}

-(void) setParams
{
    // build the environment
    NSMutableDictionary* env = [[NSMutableDictionary alloc] init];

    // fill in the environment
    NSString* cmdPath = [NSString stringWithString: [[NSBundle mainBundle] resourcePath]];
    [env setValue: escapePath(cmdPath) forKey: @"app_resource_path"];

    // fill in the filenames
    [env setValue: escapePath(self.inputFileInfo.filename) forKey: @"input_file"];
    [env setValue: escapePath(self.outputFileInfo.filename) forKey: @"output_file"];
    [env setValue: [self tempAudioFileName] forKey: @"tmp_audio_file"];
    
    // fill in params
    [env setValue: self.inputFileInfo.videoWidth.value forKey: @"input_video_width"];
    [env setValue: self.inputFileInfo.videoHeight.value forKey: @"input_video_height"];
    [env setValue: self.inputFileInfo.videoFrameRate.value forKey: @"input_frame_rate"];
    [env setValue: self.inputFileInfo.videoAspectRatio.value forKey: @"input_video_aspect"];
    [env setValue: [[NSNumber numberWithDouble: self.inputFileInfo.videoBitrate] stringValue] forKey: @"input_video_bitrate"];
    [env setValue: [[NSNumber numberWithDouble: self.inputFileInfo.duration] stringValue] forKey: @"duration"];
    
    // Set the AV offsets. Positive offsets delay video
    BOOL enableAVOffset = self.inputFileInfo.videoIndex >= 0 && self.inputFileInfo.audioIndex >= 0;
    
    [env setValue: [[NSNumber numberWithInt: enableAVOffset ? self.inputFileInfo.videoIndex : 0] stringValue] forKey: @"input_video_index"];
    [env setValue: [[NSNumber numberWithInt: enableAVOffset ? self.inputFileInfo.audioIndex : 0] stringValue] forKey: @"input_audio_index"];
    float audioOffset = (enableAVOffset && m_avOffset < 0) ? -m_avOffset : 0;
    float videoOffset = (enableAVOffset && m_avOffset > 0) ? m_avOffset : 0;
    [env setValue: [[NSNumber numberWithDouble: audioOffset] stringValue] forKey: @"audio_offset"];
    [env setValue: [[NSNumber numberWithDouble: videoOffset] stringValue] forKey: @"video_offset"];
    
    [env setValue: self.inputFileInfo.format forKey: @"input_format"];
    [env setValue: ([self hasInputAudio] ? @"true" : @"false") forKey: @"has_audio"];
    [env setValue: ([[AppController instance] limitParams] ? @"true" : @"false") forKey: @"limit_output_params"];
    [env setValue: m_noFrameSizeSnap ? @"true" : @"false" forKey: @"no_framesize_snap"];
    
    // set the number of CPUs
    [env setValue: [[NSNumber numberWithInt: [[AppController instance] numCPUs]] stringValue] forKey: @"num_cpus"];

    // If we have overrides, set them here.
    [env setValue:self.outputFileInfo.audioCodec.overridden ? self.outputFileInfo.audioCodec.value : @"" forKey: @"output_audio_codec_name_override"];
    [env setValue:self.outputFileInfo.audioChannels.overridden ? self.outputFileInfo.audioChannels.value : @"" forKey: @"output_audio_channels_override"];
    [env setValue:self.outputFileInfo.audioSampleRate.overridden ? self.outputFileInfo.audioSampleRate.value : @"" forKey: @"output_audio_sample_rate_override"];
    [env setValue:self.outputFileInfo.audioBitrate.overridden ? self.outputFileInfo.audioBitrate.value : @"" forKey: @"output_audio_bitrate_override"];
    [env setValue:self.outputFileInfo.videoCodec.overridden ? self.outputFileInfo.videoCodec.value : @"" forKey: @"output_video_codec_name_override"];
    [env setValue:self.outputFileInfo.videoProfile.overridden ? self.outputFileInfo.videoProfile.value : @"" forKey: @"output_video_profile_name_override"];
    [env setValue:self.outputFileInfo.videoFrameRate.overridden ? self.outputFileInfo.videoFrameRate.value : @"" forKey: @"output_video_frame_rate_override"];
    [env setValue:self.outputFileInfo.videoWidth.overridden ? self.outputFileInfo.videoWidth.value : @"" forKey: @"output_video_width_override"];
    [env setValue:self.outputFileInfo.videoHeight.overridden ? self.outputFileInfo.videoHeight.value : @"" forKey: @"output_video_height_override"];
    [env setValue:self.outputFileInfo.videoAspectRatio.overridden ? self.outputFileInfo.videoAspectRatio.value : @"" forKey: @"output_video_aspect_ratio_override"];
    [env setValue:self.outputFileInfo.videoPadLeft.overridden ? self.outputFileInfo.videoPadLeft.value : @"" forKey: @"output_video_padleft_override"];
    [env setValue:self.outputFileInfo.videoPadRight.overridden ? self.outputFileInfo.videoPadRight.value : @"" forKey: @"output_video_padright_override"];
    [env setValue:self.outputFileInfo.videoPadTop.overridden ? self.outputFileInfo.videoPadTop.value : @"" forKey: @"output_video_padtop_override"];
    [env setValue:self.outputFileInfo.videoPadBottom.overridden ? self.outputFileInfo.videoPadBottom.value : @"" forKey: @"output_video_padbottom_override"];

    [env setValue:self.outputFileInfo.extraOptions forKey: @"ffmpeg_extra_options"];

    // set the params
    [[[AppController instance] deviceController] setCurrentParamsWithEnvironment:env];
    [env release];
    
    // save some of the values
    self.outputFileInfo.videoWidth.value = [[[AppController instance] deviceController] paramForKey:@"output_video_width"];
    self.outputFileInfo.videoHeight.value = [[[AppController instance] deviceController] paramForKey:@"output_video_height"];
    
    self.outputFileInfo.format = [[[AppController instance] deviceController] paramForKey:@"output_format_name"];

    self.outputFileInfo.videoCodec.value = [[[AppController instance] deviceController] paramForKey:@"output_video_codec_name"];
    self.outputFileInfo.videoBitrate = [[[[AppController instance] deviceController] paramForKey:@"output_video_bitrate"] doubleValue];
    
    self.outputFileInfo.videoFrameRate.value = [[[AppController instance] deviceController] paramForKey:@"output_video_frame_rate"];
    self.outputFileInfo.videoAspectRatio.value = [[[AppController instance] deviceController] paramForKey:@"output_video_aspect_ratio"];
    self.outputFileInfo.videoPadLeft.value = [[[AppController instance] deviceController] paramForKey:@"ffmpeg_option_padleft"];
    self.outputFileInfo.videoPadRight.value = [[[AppController instance] deviceController] paramForKey:@"ffmpeg_option_padright"];
    self.outputFileInfo.videoPadTop.value = [[[AppController instance] deviceController] paramForKey:@"ffmpeg_option_padtop"];
    self.outputFileInfo.videoPadBottom.value = [[[AppController instance] deviceController] paramForKey:@"ffmpeg_option_padbottom"];
    
    // Compose a profile and level
    NSString* profile = [[[AppController instance] deviceController] paramForKey:@"output_video_profile_name"];
    int level = [[[[AppController instance] deviceController] paramForKey:@"output_video_level_name"] intValue];
    
    if ([profile length] > 0)
        self.outputFileInfo.videoProfile.value = (level > 0) ?
            [NSString stringWithFormat:@"%@@%d.%d", profile, level/10, level%10] : profile;

    m_audioQuality = [[[AppController instance] deviceController] paramForKey:@"output_audio_quality"];

    self.outputFileInfo.audioCodec.value = [[[AppController instance] deviceController] paramForKey:@"output_audio_codec_name"];
    self.outputFileInfo.audioBitrate.value = [[[AppController instance] deviceController] paramForKey:@"output_audio_bitrate"];
    self.outputFileInfo.audioSampleRate.value = [[[AppController instance] deviceController] paramForKey:@"output_audio_sample_rate"];
    self.outputFileInfo.audioChannels.value = [[[AppController instance] deviceController] paramForKey:@"output_audio_channels"];

    self.outputFileInfo.bitrate = self.outputFileInfo.videoBitrate + [self.outputFileInfo.audioBitrate.value doubleValue];
    self.outputFileInfo.fileSize = self.outputFileInfo.duration * self.outputFileInfo.bitrate / 8;
    
    [[AppController instance].moviePanelController setWidth:[self.outputFileInfo.videoHeight.value intValue] * [self.outputFileInfo.videoAspectRatio.value doubleValue]
                                                     height:[self.outputFileInfo.videoHeight.value intValue]
                                                     padLeft:[self.outputFileInfo.videoPadLeft.value intValue]
                                                     padRight:[self.outputFileInfo.videoPadRight.value intValue]
                                                     padTop:[self.outputFileInfo.videoPadTop.value intValue]
                                                     padBottom:[self.outputFileInfo.videoPadBottom.value intValue]];
}

-(void) finish: (int) status
{
    BOOL deleteOutputFile = NO;
    BOOL moveOutputFileToTrash = NO;
    
    m_fileStatus = (status == 0) ? FS_SUCCEEDED : (status == 255) ? FS_VALID : FS_FAILED;
    
    if (m_fileStatus == FS_SUCCEEDED) {
        [[AppController instance] log: @"Succeeded!\n"];
        
        if ([[AppController instance] addToMediaLibrary]) {
            NSString* filename = [[[AppController instance] deviceController] shouldWriteMetadataToInputFile] ?
                                self.inputFileInfo.filename : self.outputFileInfo.filename;
            if (![self addToMediaLibrary: filename]) {
                m_fileStatus = FS_FAILED;
            }
            else if ([[AppController instance] deleteFromDestination] && ![[[AppController instance] deviceController] shouldWriteMetadataToInputFile])
                moveOutputFileToTrash = YES;
        }
    }
    else if (m_fileStatus != FS_VALID) {
        deleteOutputFile = YES;
        [[AppController instance] log: @"FAILED with error code: %d\n", status];
    }
        
    [m_statusImageView setImage: fileStatusImage(m_fileStatus)];
    if (m_fileStatus != FS_VALID)
        m_enabled = false;
    m_progress = (status == 0) ? 1 : 0;
    [m_progressIndicator setDoubleValue: m_progress];
    [[AppController instance] encodeFinished:self withStatus:status];
    [m_logFile closeFile];
    [m_logFile release];
    m_logFile = nil;
    
    NSString* outputPath = [self.outputFileInfo.filename stringByDeletingLastPathComponent];
    
    // toss output file if not successful
    if (deleteOutputFile)
        [[NSFileManager defaultManager] removeItemAtPath:self.outputFileInfo.filename error:nil];
    else if (moveOutputFileToTrash)
        [[NSWorkspace sharedWorkspace] 
            performFileOperation:NSWorkspaceRecycleOperation 
            source:outputPath
            destination:@""
            files:[NSArray arrayWithObject:[self.outputFileInfo.filename lastPathComponent]]
            tag:nil];
            
    // In case metadata was written, cleanup after it
    [self.metadata cleanupAfterMetadataWrite];

    // After we're done with the encode we need to re-init the output filename. It may now exist
    // and if we were to try to encode again, we need a new filename for it
    [self updateOutputFileName];
    
    // Toss tmp files
    [[NSFileManager defaultManager] removeItemAtPath:m_tempAudioFileName error:nil];
    
    // Get rid of ffmpeg 2 pass temp files
    [[NSFileManager defaultManager] removeItemAtPath:[outputPath stringByAppendingPathComponent:@"x264_2pass.log"] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[outputPath stringByAppendingPathComponent:@"x264_2pass.log.mbtree"] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[outputPath stringByAppendingPathComponent:@"ffmpeg2pass-0.log"] error:nil];    
}

-(void) startNextCommands
{
    Command* command = [m_commands objectAtIndex:m_currentCommandIndex];
    
    while (1) {
        Command* nextCommand = ([m_commands count]-1 == m_currentCommandIndex) ? nil : [m_commands objectAtIndex:m_currentCommandIndex+1];
        [command execute: nextCommand];
        m_currentCommandIndex++;
        if (!nextCommand || [command needsToWait])
            return;
        command = nextCommand;
    }
}

static void addCommandElement(NSMutableArray* elements, NSString* command, NSString* recipe)
{
    NSDictionary* entry = [NSDictionary dictionaryWithObjectsAndKeys:
        command, @"command",
        recipe, @"recipe",
        nil];
    
    [elements addObject:entry];
}

- (BOOL) startEncode
{
    if (![self.outputFileInfo.filename length] || !m_enabled)
        return NO;
    
    [self updateOutputFileName];
    [self setParams];

    // Make sure the output file doesn't exist
    if ([[NSFileManager defaultManager] fileExistsAtPath: self.outputFileInfo.filename]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Internal Error"];
        [alert setInformativeText:[NSString stringWithFormat:@"The output file '%@' exists. Video Monkey should never write to an existing file.", self.outputFileInfo.filename]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        return NO;
    }

    // initialize progress values
    m_progress = 0;
    [m_progressIndicator setDoubleValue: m_progress];
    
    // open the log file
    if (m_logFile) {
        [m_logFile closeFile];
        [m_logFile release];
    }
    
    [[AppController instance] log: @"============================================================================\n"];
    [[AppController instance] log: @"Begin transcode: %@ --> %@\n", [self.inputFileInfo.filename lastPathComponent], [self.outputFileInfo.filename lastPathComponent]];
    
    // Make sure path exists
    NSString* logFilePath = [LOG_FILE_PATH stringByStandardizingPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath: logFilePath])
        [[NSFileManager defaultManager] createDirectoryAtPath:logFilePath withIntermediateDirectories:YES attributes:nil error: nil];
        
    NSString* logFileName = [NSString stringWithFormat:@"%@/%@-%@.log",
                                logFilePath, [self.outputFileInfo.filename lastPathComponent], [[NSDate date] description]];
    [[NSFileManager defaultManager] removeItemAtPath:logFileName error:nil];
    [[NSFileManager defaultManager] createFileAtPath:logFileName contents:nil attributes:nil];
                                
    m_logFile = [[NSFileHandle fileHandleForWritingAtPath:logFileName] retain];
    
    // make sure the tmp tmp files do not exist
    [[NSFileManager defaultManager] removeItemAtPath:m_tempAudioFileName error:nil];
    
    // get recipe
    NSString* recipe = [[[AppController instance] deviceController] recipe];

    if ([recipe length] == 0) {
        [[AppController instance] log:@"*** ERROR: No recipe returned, probably due to a previous JavaScript error\n"];
        [self finish: -1];
        return NO;
    }
    
    m_commands = [[NSMutableArray alloc] init];
    
    if ([[[AppController instance] deviceController] shouldEncode]) {
        // Split out each command. Commands go into the 'elements' array. Each entry is a dictionary with
        // two entries:
        //      'command' - Single character command (';', '&', '|')
        //      'recipe' - Command string to execute
        //
        // Go through each character, looking for a command character. Ignore command chars
        // if they are inside single or double quotes.
        NSMutableArray* elements = [[NSMutableArray alloc] init];
        int stringIndex = 0;
        BOOL done = NO;
        
        while (!done) {
            NSMutableString* s = [NSMutableString string];
            BOOL inSingleQuotes = NO;
            BOOL inDoubleQuotes = NO;
            
            while (1) {
                if (stringIndex >= [recipe length]) {
                    addCommandElement(elements, @";", s);
                    done = YES;
                    break;
                }
                    
                unichar c = [recipe characterAtIndex:stringIndex++];
                NSString* charString = [NSString stringWithCharacters:&c length:1];
                
                if (c == '\'')
                    inSingleQuotes = !inSingleQuotes;
                else if (c == '"')
                    inDoubleQuotes = !inDoubleQuotes;
                else if ((c == '|' || c == '&' || c == ';') && (!inSingleQuotes && !inDoubleQuotes)) {
                    // we're at a command boundary
                    addCommandElement(elements, charString, s);
                    s = [NSMutableString string];
                    continue;
                }
                
                [s appendString:charString];
            }
        }
    
        for (NSDictionary* entry in elements) {
            CommandOutputType type = OT_NONE;
            
            // determine type of command
            if ([[entry objectForKey:@"command"] isEqualToString:@";"])
                type = OT_WAIT;
            else if ([[entry objectForKey:@"command"] isEqualToString:@"|"])
                type = OT_PIPE;
            else if ([[entry objectForKey:@"command"] isEqualToString:@"&"])
                type = OT_CONTINUE;
            else
                type = OT_NONE;
            
            // make a Command object for this command
            [m_commands addObject:[Command commandWithTranscoder:self 
                                command:[entry objectForKey:@"recipe"]
                                outputType:type 
                                index:(int)[m_commands count]]];
        }
        
        [elements release];
    }
    
    if ([[[AppController instance] deviceController] shouldWriteMetadata]) {
        // Before writing metadata, make sure it can be done
        BOOL canWrite = true;
        
        if (![[[AppController instance] deviceController] shouldEncode]) {
            if ([[[AppController instance] deviceController] shouldWriteMetadataToOutputFile]) {
                if (![self.metadata canWriteMetadataToOutputFile])
                    canWrite = false;
            }
            else {
                if (![self.metadata canWriteMetadataToInputFile])
                    canWrite = false;
            }
        }
        
        NSString* filename = [[[AppController instance] deviceController] shouldWriteMetadataToOutputFile] ?
                                self.outputFileInfo.filename :
                                self.inputFileInfo.filename;
        NSString* metadataCommand = [self.metadata metadataCommand:filename];
                                
        if ([metadataCommand length] > 0) {
            if (canWrite) {
                // Add command for writing metadata
                [m_commands addObject:[Command commandWithTranscoder:self command:metadataCommand
                            outputType:OT_WAIT index:(int)[m_commands count]]];
            }
            else {
                // Can't write metadata to this type of file
                NSString* msg;
                if ([[[AppController instance] deviceController] shouldWriteMetadataToOutputFile])
                    msg = @"Unable to write metadata to output file. "
                            "Either the path to the output file is not writable "
                            "or this file format does not support metadata.\n";
                else
                    msg = @"Unable to write metadata to input file. "
                            "Either the path to the input file is not writable "
                            "or this file format does not support metadata.\n";
                
                [[AppController instance] log: msg];
                [[AppController instance] log: @"Nothing to do.\n"];
                NSBeginAlertSheet(@"Nothing to do", nil, nil, nil, [[NSApplication sharedApplication] mainWindow], 
                            nil, nil, nil, nil, @"%@", msg);

                [self finish:255];
                return YES;
            }
        }
    }
    
    // execute each command in turn
    if ([m_commands count] > 0) {
        m_currentCommandIndex = 0;
        [self startNextCommands];

        m_fileStatus = FS_ENCODING;
        [m_statusImageView setImage: fileStatusImage(m_fileStatus)];
        return YES;
    }
    else {
        [self finish: -1];
        return NO;
    }
}

- (BOOL) pauseEncode
{
    NSEnumerator* enumerator = [m_commands objectEnumerator];
    Command* command;
    
    while(command = [enumerator nextObject])
        [command suspend];
        
    m_fileStatus = FS_PAUSED;
    return YES;
}

-(BOOL) resumeEncode
{
    NSEnumerator* enumerator = [m_commands objectEnumerator];
    Command* command;
    
    while(command = [enumerator nextObject])
        [command resume];
        
    m_fileStatus = FS_ENCODING;
    return YES;
}

-(BOOL) stopEncode
{
    NSEnumerator* enumerator = [m_commands objectEnumerator];
    Command* command;
    
    while(command = [enumerator nextObject])
        [command terminate];
        
    [self finish: 255];
    return YES;
}

-(BOOL) addToMediaLibrary:(NSString*) filename
{
    iTunesApplication* iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    NSURL *file = [NSURL fileURLWithPath: filename];
    iTunesTrack* track;
    NSString* errorString = nil;
    
    @try {
        track = [iTunes add: [NSArray arrayWithObject:file] to: nil];
        if (!track)
            errorString = @"File could not be added to iTunes (probably an invalid type)";
    }
    @catch (NSException* e) {
        NSError* error = [NSError errorWithDomain:NSCocoaErrorDomain code:[[[e userInfo] valueForKey:@"ErrorNumber"] intValue] userInfo:[e userInfo]];
        errorString = [error localizedDescription];
    }
    
    if (!errorString) {
        [[AppController instance] log: @"Copy to iTunes succeeded!\n"];
        return YES;
    }
    
    // Error
    [[AppController instance] log: @"Copy to iTunes FAILED with error: %@\n", errorString];
    return NO;
}

-(void) setProgressForCommand: (Command*) command to: (double) value
{
    // TODO: need to give each command a percentage of the progress
    m_progress = value;
    [m_progressIndicator setDoubleValue: m_progress];
    [[AppController instance] setProgressFor: self to: m_progress];
}

-(void) commandFinished: (Command*) command status: (int) status
{
    // If this command is last in the list, finish up. 
    // If it's the last currently executing command, fire off the next
    if (command.index == [m_commands count] - 1)
        [self finish: status];
    else if (command.index == m_currentCommandIndex - 1)
        [self startNextCommands];
}

-(void) updateFileInfo
{
    [[AppController instance] updateFileInfo];
}

-(void) logToFile: (NSString*) string
{
    // Output to log file
    if (m_logFile)
        [m_logFile writeData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

-(void) logCommand: (int) index withFormat: (NSString*) format, ...
{
    va_list args;
    va_start(args, format);
    NSString* string = [[NSString alloc] initWithFormat:format arguments:args];
    [[AppController instance] log: @"    [Command %@] %@\n", [[NSNumber numberWithInt:index] stringValue], string];
    [string release];
}

-(void) log: (NSString*) format, ...
{
    va_list args;
    va_start(args, format);
    NSString* s = [[NSString alloc] initWithFormat:format arguments: args];
    [[AppController instance] log: s];
    [s release];
}

- (id)valueForUndefinedKey:(NSString *)key
{
    NSLog(@"*** Transcoder::valueForUndefinedKey:%@\n", key);
    return nil;
}

@end
