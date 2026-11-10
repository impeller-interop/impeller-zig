#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

static CAMetalLayer* configureLayer(CAMetalLayer* layer) {
    if (layer == nil) {
        return nil;
    }
    if (layer.device == nil) {
        layer.device = MTLCreateSystemDefaultDevice();
    }
    if (layer.device == nil) {
        return nil;
    }
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = NO;
    return layer;
}

void* metalLayerFromWindow(void* window_ptr) {
    if (window_ptr == NULL) {
        return NULL;
    }

    @autoreleasepool {
        NSWindow* window = (__bridge NSWindow*)window_ptr;
        NSView* view = [window contentView];
        if (view == nil) {
            return NULL;
        }

        CAMetalLayer* layer = configureLayer([CAMetalLayer layer]);
        if (layer == nil) {
            return NULL;
        }
        layer.contentsScale = [window backingScaleFactor];
        [view setWantsLayer:YES];
        [view setLayer:layer];
        return (__bridge_retained void*)layer;
    }
}

void* metalLayerFromView(void* view_ptr, double scale) {
    if (view_ptr == NULL) {
        return NULL;
    }

    @autoreleasepool {
        NSView* view = (__bridge NSView*)view_ptr;
        CAMetalLayer* layer = configureLayer([CAMetalLayer layer]);
        if (layer == nil) {
            return NULL;
        }
        layer.contentsScale = scale > 0.0 ? scale : 1.0;
        [view setWantsLayer:YES];
        [view setLayer:layer];
        return (__bridge_retained void*)layer;
    }
}

void* metalConfigureLayer(void* layer_ptr) {
    if (layer_ptr == NULL) {
        return NULL;
    }
    @autoreleasepool {
        return (__bridge void*)configureLayer((__bridge CAMetalLayer*)layer_ptr);
    }
}

void metalLayerDestroy(void* layer_ptr) {
    if (layer_ptr == NULL) {
        return;
    }
    CFBridgingRelease(layer_ptr);
}

void* metalAcquireDrawable(void* layer_ptr, double width, double height) {
    if (layer_ptr == NULL) {
        return NULL;
    }

    @autoreleasepool {
        CAMetalLayer* layer = configureLayer((__bridge CAMetalLayer*)layer_ptr);
        if (layer == nil) {
            return NULL;
        }
        if (width > 0.0 && height > 0.0) {
            layer.drawableSize = CGSizeMake(width, height);
        }

        id<CAMetalDrawable> drawable = [layer nextDrawable];
        if (drawable == nil) {
            return NULL;
        }
        return (__bridge_retained void*)drawable;
    }
}

void metalReleaseDrawable(void* drawable_ptr) {
    if (drawable_ptr == NULL) {
        return;
    }
    CFBridgingRelease(drawable_ptr);
}
