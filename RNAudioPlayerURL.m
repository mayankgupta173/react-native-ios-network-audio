//React Native Audio Player logic(no UI)

#import "RNAudioPlayerURL.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
@import MediaPlayer;

@implementation RNAudioPlayerURL

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(initWithURL:(NSString *)url title:(NSString *) title artist:(NSString *) artist){
  if(!([url length]>0)) return;
  NSURL *soundUrl = [[NSURL alloc] initWithString:url];
  self.audioItem = [AVPlayerItem playerItemWithURL:soundUrl];
  if (self.audioPlayer) {
    [self.audioPlayer replaceCurrentItemWithPlayerItem:self.audioItem];
  } else {
    self.audioPlayer = [AVPlayer playerWithPlayerItem:self.audioItem];
    [self.audioPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
      [self.bridge.eventDispatcher
       sendAppEventWithName:@"AudioProgress"
       body: @{@"currentPosition": [NSNumber numberWithFloat:CMTimeGetSeconds(time)]}
      ];
    }];
  }
  
  [[AVAudioSession sharedInstance]
   setCategory: AVAudioSessionCategoryPlayback
   error: nil];
  
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.audioItem];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(playerPause:) name:AVPlayerItemPlaybackStalledNotification object:self.audioItem];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(playerPause:) name:AVAudioSessionRouteChangeNotification object:self.audioItem];
  
  [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = @{
    MPMediaItemPropertyTitle : title,
    MPMediaItemPropertyArtist : artist,
    MPNowPlayingInfoPropertyPlaybackRate : @1.0f
  };
  
  MPRemoteCommandCenter *remoteCommandCenter = [MPRemoteCommandCenter sharedCommandCenter];
  [[remoteCommandCenter playCommand] addTarget:self action:@selector(playerToggle:)];
  [remoteCommandCenter playCommand].enabled = true;

  [[remoteCommandCenter pauseCommand] addTarget:self action:@selector(playerToggle:)];
  [remoteCommandCenter pauseCommand].enabled = true;
  [[remoteCommandCenter togglePlayPauseCommand] addTarget:self action:@selector(playerToggle:)];
  [[remoteCommandCenter nextTrackCommand] addTarget:self action:@selector(playerSkip:)];
  [[remoteCommandCenter bookmarkCommand] addTarget:self action:@selector(playerLike:)];
  [remoteCommandCenter bookmarkCommand].enabled = true;
  [remoteCommandCenter bookmarkCommand].localizedTitle = @"like";
  [remoteCommandCenter bookmarkCommand].localizedShortTitle = @"like";
}

- (void)playerItemDidReachEnd:(NSNotification *)notification{
  [self.audioItem seekToTime:kCMTimeZero];
  self.audioItem = nil;
  [self.bridge.eventDispatcher sendAppEventWithName:@"AudioEnded" body:@{@"event": @"finished"}];
}

- (void)playerSkip:(NSNotification *)notification{
  [self.bridge.eventDispatcher sendAppEventWithName:@"AudioSkipped" body:@{@"event": @"finished"}];
}

- (void)playerToggle:(NSNotification *)notification{
  [self.bridge.eventDispatcher sendAppEventWithName:@"AudioToggled" body:@{@"event": @"finished"}];
}

- (void)playerLike:(NSNotification *)notification{
  [self.bridge.eventDispatcher sendAppEventWithName:@"AudioLiked" body:@{@"event": @"finished"}];
}

- (void)playerPause:(NSNotification *)notification{
  [self.bridge.eventDispatcher sendAppEventWithName:@"AudioPaused" body:@{@"event": @"finished"}];
}


RCT_EXPORT_METHOD(getDuration:(RCTResponseSenderBlock)callback){
  while(self.audioItem.status != AVPlayerItemStatusReadyToPlay){
  }  //this is kind of crude but it will prevent the app from crashing due to a "NAN" return(this allows the getDuration method to be executed in the componentDidMount function of the React class without the app crashing
  float duration = CMTimeGetSeconds(self.audioItem.duration);
  callback(@[[[NSNumber alloc] initWithFloat:duration]]);
}

RCT_EXPORT_METHOD(getCurrentTime:(RCTResponseSenderBlock)callback){
  if(self.audioItem.status != AVPlayerItemStatusReadyToPlay){
    callback(nil);
  }
  float currentTime = CMTimeGetSeconds(self.audioItem.currentTime);
  callback(@[[[NSNumber alloc] initWithFloat:currentTime]]);
}

RCT_EXPORT_METHOD(play){
  __block RNAudioPlayerURL *weakSelf = self;
  [self.audioPlayer play];
}

RCT_EXPORT_METHOD(pause){
  [self.audioPlayer pause];
}

RCT_EXPORT_METHOD(seekToTime:(nonnull NSNumber *)toTime){
  [self.audioPlayer seekToTime: CMTimeMakeWithSeconds([toTime floatValue], NSEC_PER_SEC)];
}

@end


