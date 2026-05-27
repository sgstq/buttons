#import "MultitouchBridge.h"
#import <dlfcn.h>

#pragma mark - Private MultitouchSupport types

typedef struct { float x, y; } MTVector;
typedef struct { MTVector position, velocity; } MTReadout;

typedef struct {
    int frame;
    double timestamp;
    int identifier;
    int state;
    int foo3;
    int foo4;
    MTReadout normalized;
    float size;
    int zero1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTReadout mm;
    int zero2[2];
    float density;
} MTFinger;

typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef device,
                                 MTFinger *fingers,
                                 int nFingers,
                                 double timestamp,
                                 int frame);

typedef CFArrayRef (*MTDeviceCreateList_t)(void);
typedef void (*MTRegisterContactFrameCallback_t)(MTDeviceRef, MTContactCallback);
typedef void (*MTUnregisterContactFrameCallback_t)(MTDeviceRef, MTContactCallback);
typedef void (*MTDeviceStart_t)(MTDeviceRef, int);
typedef void (*MTDeviceStop_t)(MTDeviceRef);

#pragma mark - BTNTouch

@implementation BTNTouch
@end

#pragma mark - BTNTrackpadMonitor

@implementation BTNTrackpadMonitor {
    void *_handle;
    NSMutableArray *_devices;
    MTRegisterContactFrameCallback_t _registerCB;
    MTUnregisterContactFrameCallback_t _unregisterCB;
    MTDeviceStart_t _startDevice;
    MTDeviceStop_t _stopDevice;
}

// We use a weak global pointer because the C callback has no userdata.
static __weak BTNTrackpadMonitor *g_currentMonitor = nil;

static int contactCallback(MTDeviceRef device, MTFinger *fingers, int nFingers, double timestamp, int frame) {
    BTNTrackpadMonitor *monitor = g_currentMonitor;
    if (!monitor || !monitor.delegate) return 0;

    NSMutableArray *active = [NSMutableArray arrayWithCapacity:nFingers];
    NSInteger activeCount = 0;

    for (int i = 0; i < nFingers; i++) {
        MTFinger f = fingers[i];
        // Treat state 3 (making touch), 4 (touching), and 6 (linger) as active contact.
        // State 0 = not tracking, 1 = starting (hover-ish), 2 = hovering, 5 = breaking, 7 = out of range.
        if (f.state == 3 || f.state == 4 || f.state == 6) {
            activeCount++;
        }
        BTNTouch *t = [[BTNTouch alloc] init];
        t.identifier = f.identifier;
        t.state = f.state;
        t.x = f.normalized.position.x;
        t.y = f.normalized.position.y;
        t.vx = f.normalized.velocity.x;
        t.vy = f.normalized.velocity.y;
        t.size = f.size;
        [active addObject:t];
    }

    NSArray *snapshot = [active copy];
    NSInteger count = activeCount;
    double ts = timestamp;
    dispatch_async(dispatch_get_main_queue(), ^{
        [monitor.delegate trackpadDidUpdateWithTouches:snapshot activeCount:count timestamp:ts];
    });
    return 0;
}

- (BOOL)start {
    if (_handle) return YES;

    const char *path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport";
    _handle = dlopen(path, RTLD_NOW);
    if (!_handle) {
        // Fallback path used on some macOS versions.
        const char *alt = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/Versions/Current/MultitouchSupport";
        _handle = dlopen(alt, RTLD_NOW);
    }
    if (!_handle) {
        NSLog(@"Buttons: failed to dlopen MultitouchSupport.framework");
        return NO;
    }

    MTDeviceCreateList_t createList = (MTDeviceCreateList_t)dlsym(_handle, "MTDeviceCreateList");
    _registerCB = (MTRegisterContactFrameCallback_t)dlsym(_handle, "MTRegisterContactFrameCallback");
    _unregisterCB = (MTUnregisterContactFrameCallback_t)dlsym(_handle, "MTUnregisterContactFrameCallback");
    _startDevice = (MTDeviceStart_t)dlsym(_handle, "MTDeviceStart");
    _stopDevice = (MTDeviceStop_t)dlsym(_handle, "MTDeviceStop");

    if (!createList || !_registerCB || !_startDevice) {
        NSLog(@"Buttons: required MultitouchSupport symbols missing");
        dlclose(_handle); _handle = NULL;
        return NO;
    }

    g_currentMonitor = self;

    CFArrayRef list = createList();
    if (!list) {
        NSLog(@"Buttons: MTDeviceCreateList returned NULL");
        return NO;
    }

    _devices = [NSMutableArray array];
    CFIndex count = CFArrayGetCount(list);
    for (CFIndex i = 0; i < count; i++) {
        MTDeviceRef d = (MTDeviceRef)CFArrayGetValueAtIndex(list, i);
        _registerCB(d, contactCallback);
        _startDevice(d, 0);
        [_devices addObject:[NSValue valueWithPointer:d]];
    }
    CFRelease(list);
    return _devices.count > 0;
}

- (void)stop {
    for (NSValue *v in _devices) {
        MTDeviceRef d = [v pointerValue];
        if (_unregisterCB) _unregisterCB(d, contactCallback);
        if (_stopDevice) _stopDevice(d);
    }
    [_devices removeAllObjects];
    if (_handle) {
        dlclose(_handle);
        _handle = NULL;
    }
    g_currentMonitor = nil;
}

- (void)dealloc {
    [self stop];
}

@end
