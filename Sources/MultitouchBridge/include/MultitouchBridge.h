#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One touch sample passed to the delegate. Coordinates are normalized 0..1.
@interface BTNTouch : NSObject
@property (nonatomic, assign) NSInteger identifier;
@property (nonatomic, assign) NSInteger state;   ///< raw MT state (4=touching is typical)
@property (nonatomic, assign) double x;
@property (nonatomic, assign) double y;
@property (nonatomic, assign) double vx;
@property (nonatomic, assign) double vy;
@property (nonatomic, assign) double size;
@end

@protocol BTNTrackpadDelegate <NSObject>
/// Called on the main thread (we dispatch in the bridge).
/// `touches` are only those considered active (state filtering done in the bridge).
- (void)trackpadDidUpdateWithTouches:(NSArray<BTNTouch *> *)touches
                          activeCount:(NSInteger)activeCount
                            timestamp:(double)timestamp;
@end

@interface BTNTrackpadMonitor : NSObject
@property (nonatomic, weak, nullable) id<BTNTrackpadDelegate> delegate;

/// Loads MultitouchSupport.framework and starts all attached devices.
/// Returns NO if the framework is missing or symbols can't be resolved.
- (BOOL)start;

/// Stops all devices and unloads the framework.
- (void)stop;
@end

NS_ASSUME_NONNULL_END
