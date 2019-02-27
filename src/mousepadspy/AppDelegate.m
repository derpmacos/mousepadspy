//
//  AppDelegate.m
//  mousepadspy
//
//

#import "AppDelegate.h"

#pragma mark private

#import "MultiTouch.h"

#import <IOKit/kext/KextManager.h>

// private class
@interface NSStatusBarButtonCell : NSCell
@end

#pragma mark util

static void CGContextPathRoundedRect(CGContextRef cg, CGRect rect, CGFloat r) {
    CGFloat minx = CGRectGetMinX(rect), midx = CGRectGetMidX(rect), maxx = CGRectGetMaxX(rect);
    CGFloat miny = CGRectGetMinY(rect), midy = CGRectGetMidY(rect), maxy = CGRectGetMaxY(rect);
    CGContextMoveToPoint(cg, minx, midy);
    CGContextAddArcToPoint(cg, minx, miny, midx, miny, r);
    CGContextAddArcToPoint(cg, maxx, miny, maxx, midy, r);
    CGContextAddArcToPoint(cg, maxx, maxy, midx, maxy, r);
    CGContextAddArcToPoint(cg, minx, maxy, minx, midy, r);
    CGContextClosePath(cg);
}

static BOOL isDarkInterfaceStyle() {
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    return [style isEqualToString:@"Dark"];
}

#pragma mark app

#define kStatusIconMargin 2

@interface AppDelegate ()
- (void)cell:(NSCell*)cell drawTouches:(NSRect)rect;
@end

@interface StatusBarDrawableCell : NSStatusBarButtonCell
@end
@implementation StatusBarDrawableCell
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    AppDelegate *delegate = (AppDelegate*)[NSApp delegate];
    [delegate cell:self drawTouches:cellFrame];
}
@end

@implementation AppDelegate {
    struct {
        mtTouch *data;
        NSUInteger count;
    } _touches;
    
    MTDeviceRef _dev; // weak - being retained within menu
    
    NSStatusItem *_statusItem;
    BOOL _statusItemNoButton; // osx 10.9
}

- (void)cell:(NSCell*)cell drawTouches:(NSRect)rect {
    NSGraphicsContext *ctx = [NSGraphicsContext currentContext];
    CGContextRef cg = _statusItemNoButton ? [ctx graphicsPort] : [ctx CGContext];
 
    const BOOL highlighted = cell.isHighlighted;
    if(highlighted) {
        CGContextSetFillColorWithColor(cg, [[NSColor selectedMenuItemColor] CGColor]);
        CGContextFillRect(cg, rect);
    }
    
    const BOOL dark = isDarkInterfaceStyle() || highlighted;
    CGContextSetGrayStrokeColor(cg, dark?1:0, 1);
    CGContextSetGrayFillColor(cg, dark?1:0, 1);
    
    rect = CGRectInset(rect, kStatusIconMargin/2, kStatusIconMargin/2);
    
    CGContextPathRoundedRect(cg, rect, MIN(rect.size.width, rect.size.height)/4);
    CGPathRef path = CGContextCopyPath(cg);
    CGContextClip(cg);
    CGContextAddPath(cg, path);
    CGContextStrokePath(cg);
    CFRelease(path);
    
    if(_dev && _touches.count) {
        const BOOL flipped = _statusItemNoButton ? NO : _statusItem.button.isFlipped;
        CGAffineTransform trans = CGAffineTransformMakeTranslation(rect.origin.x, rect.origin.y + (flipped?rect.size.height:0));
        if(flipped) trans = CGAffineTransformScale(trans, 1, -1);
        CGContextSaveGState(cg);
        CGContextConcatCTM(cg, trans);
        
        for(NSUInteger i = 0; i < _touches.count; i++) {
            mtTouch *touch = _touches.data+i;
            CGFloat s = touch->size*12;
            s = (s > 1) ? logf(s)*0.15 : 0.0;
            CGFloat w = touch->majorAxis * s + 0.5;
            CGFloat h = touch->minorAxis * s + 0.5;
            
            CGAffineTransform trans = CGAffineTransformMakeTranslation(touch->normalized.position.x * rect.size.width,
                                                                       touch->normalized.position.y * rect.size.height);
            trans = CGAffineTransformRotate(trans, touch->angle);
            CGContextSaveGState(cg);
            CGContextConcatCTM(cg, trans);
            
            CGRect rect = CGRectMake(-w/2, -h/2, w, h);
            CGContextFillEllipseInRect(cg, rect);
            
            CGContextRestoreGState(cg);
        }
        CGContextRestoreGState(cg);
    }
    
    if(!_dev) {
        // draw an 'x'
        rect = CGRectInset(rect, rect.size.width/4, rect.size.height/4);
        CGContextMoveToPoint(cg, rect.origin.x, rect.origin.y);
        CGContextAddLineToPoint(cg, rect.origin.x+rect.size.width, rect.origin.y+rect.size.height);
        CGContextMoveToPoint(cg, rect.origin.x+rect.size.width, rect.origin.y);
        CGContextAddLineToPoint(cg, rect.origin.x, rect.origin.y+rect.size.height);
        CGContextStrokePath(cg);
    }
}


// must consume data
- (void)touchedMultitouchDevice:(MTDeviceRef)dev touches:(mtTouch *)data count:(NSUInteger)count {
    if(dev == _dev) {
        free(_touches.data);
        _touches.data = data;
        _touches.count = count;
        
        if(_statusItemNoButton) {
            // osx 10.9 - inefficient!
            // bug - length is animated so isn't calculated correctly!
            NSStatusBar *bar = [NSStatusBar systemStatusBar];
            NSSize size = NSMakeSize([_statusItem length], [bar thickness]);
            if(size.width*size.height > 0) {
                NSImage *image = [[[NSImage alloc] initWithSize:size] autorelease];
                [image lockFocus];
                [self cell:nil drawTouches:NSMakeRect(0,0,size.width,size.height)];
                [image unlockFocus];
                [_statusItem setImage:image];
            }
        } else {
            [_statusItem.button setNeedsDisplay]; // DONT draw immediately, this method may be called at up to 120fps
        }
    } else {
        free(data);
    }
}


// clues from http://swtch.com/usr/local/plan9/src/cmd/devdraw/osx-screen-carbon.m

static void RegisterMultitouch(void *ctx, io_iterator_t iter) {
    AppDelegate *delegate = (AppDelegate *)ctx;
    io_object_t io;
    while((io = IOIteratorNext(iter)) != 0){
        [delegate foundMultitouchIO:io];
        IOObjectRelease(io);
    }
}

static void UnregisterMultitouch(void *ctx, io_iterator_t iter) {
    AppDelegate *delegate = (AppDelegate *)ctx;
    io_object_t io;
    while((io = IOIteratorNext(iter)) != 0){
        [delegate lostMultitouchIO:io];
        IOObjectRelease(io);
    }
}

// everything in the menu which can do a 'select:'
- (NSArray*)deviceMenuItems {
    NSMutableArray *items = [NSMutableArray array];
    SEL sel = @selector(select:);
    NSMenu *menu = [_statusItem menu];
    for(NSMenuItem *item in [menu itemArray]) {
        if([item action]==sel) [items addObject:item];
    }
    return items;
}

- (void)foundMultitouchIO:(io_object_t)io {
    MTDeviceRef dev = MTDeviceCreateFromService(io);
    if(dev) {
        NSString *name = MTDeviceIsBuiltIn(dev)?@"BuiltIn":@"External";
        
        // append to device menu
        NSMenu *menu = [_statusItem menu];
        NSUInteger index = [menu indexOfItem:[[self deviceMenuItems] lastObject]];
        NSMenuItem *item = [menu insertItemWithTitle:name action:@selector(select:) keyEquivalent:@"" atIndex:index+1];
        [item setRepresentedObject:dev];
 
        // auto-activate if the first one found
        if(!_dev) {
            [self selectMultitouchDevice:dev];
        }
        
        CFRelease(dev);
    }
}

- (void)lostMultitouchIO:(io_object_t)io {
    // deactivate if current _dev
    if(_dev && IOObjectIsEqualTo(MTDeviceGetService(_dev), io)) {
        [self selectMultitouchDevice:NULL];
    }
    
    // remove from menu
    NSMenu *menu = [_statusItem menu];
    for(NSMenuItem *item in [menu itemArray]) {
        if(MTDeviceGetService([item representedObject])==io) {
            [menu removeItem:item];
            break;
        }
    }
}

static int touchCallback(MTDeviceRef dev, mtTouch *data, int numfingers, double timestamp, int frame) {
    // copy the data and hand off to main thread
    mtTouch *copy = NULL;
    if(numfingers > 0) {
        const size_t size = sizeof(mtTouch)*numfingers;
        copy = malloc(size);
        memcpy(copy, data, size);
    }
    AppDelegate *delegate = (AppDelegate *)[NSApp delegate];
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate touchedMultitouchDevice:dev touches:copy count:numfingers];
    });
    return 0;
}

- (void)selectMultitouchDevice:(MTDeviceRef)dev {
    if(dev && (dev == _dev)) return;
    if(_dev) {
        MTDeviceStop(_dev);
        MTUnregisterContactFrameCallback(_dev, touchCallback);
        _dev = NULL;
    }
    
    // clear icon
    [self touchedMultitouchDevice:NULL touches:NULL count:0];
    
    if(dev) {
        _dev = dev;
        // make the menu widget the right size for the device
        int sw = 0, sh = 0;
        MTDeviceGetSensorSurfaceDimensions(_dev, &sw, &sh);
        if(sw*sh == 0) { sw = sh = 100; }
        NSStatusBar *bar = [NSStatusBar systemStatusBar];
        const int height = [bar thickness] - kStatusIconMargin;
        const int width = (height * sw) / sh + kStatusIconMargin;
        [_statusItem setLength:width];

        MTRegisterContactFrameCallback(_dev, touchCallback);
        MTDeviceStart(_dev, 0);
    } else {
        NSStatusBar *bar = [NSStatusBar systemStatusBar];
        const int height = [bar thickness] - kStatusIconMargin;
        [_statusItem setLength:height+ kStatusIconMargin];
    }
    
    // update menu to show selected _dev
    for(NSMenuItem *item in [self deviceMenuItems]) {
        [item setState:([item representedObject] == _dev)];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    [menu addItemWithTitle:@"None" action:@selector(select:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(quit:) keyEquivalent:@""];

    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    _statusItem = [[bar statusItemWithLength:NSVariableStatusItemLength] retain];
    
    if([_statusItem respondsToSelector:@selector(button)]) {
        [_statusItem.button setCell:[[StatusBarDrawableCell alloc] init]];
    } else {
        // osx 10.9
        _statusItemNoButton = YES;
    }
    [_statusItem setMenu:menu];
    
    [self selectMultitouchDevice:NULL];
    
    // observe multitouch devices
    IONotificationPortRef port = IONotificationPortCreate(kIOMasterPortDefault);
    CFRunLoopAddSource(CFRunLoopGetCurrent(),IONotificationPortGetRunLoopSource(port), kCFRunLoopDefaultMode);
    
    CFDictionaryRef matching = IOServiceMatching("AppleMultitouchDevice");
    CFRetain(matching); // Need to use it twice and IOServiceAddMatchingNotification() consumes a reference
    
    io_iterator_t iter;
    if(IOServiceAddMatchingNotification(port, kIOTerminatedNotification, matching, &UnregisterMultitouch, self, &iter) == KERN_SUCCESS) {
        // arm
        UnregisterMultitouch(self, iter);
    }
    if(IOServiceAddMatchingNotification(port, kIOMatchedNotification,  matching, &RegisterMultitouch, self, &iter) == KERN_SUCCESS) {
        // arm and load the initial devices
        RegisterMultitouch(self, iter);
    }
}

#pragma mark menu actions

- (void)select:(id)sender {
    [self selectMultitouchDevice:[(NSMenuItem*)sender representedObject]];
}

- (void)quit:(id)sender {
   [[NSApplication sharedApplication] terminate:self];
}

@end
