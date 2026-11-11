// AyuGram Notification Bridge — shared container recovery for re-signed iOS apps.
// No message reading, network traffic, or private key access.
// Inject into BOTH Telegram.app and NotificationServiceExtensionv1.appex.
// Works only when both signed targets are entitled to the same App Group.
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

typedef NSURL *(*AGOriginalContainerFn)(id, SEL, NSString *);
static AGOriginalContainerFn agOriginalContainerURL = NULL;
static NSString *agSharedGroup = nil;

static NSString *AGAllowedSharedGroup(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
        if (!task) return;
        CFErrorRef error = NULL;
        CFTypeRef entitled = SecTaskCopyValueForEntitlement(task,
            CFSTR("com.apple.security.application-groups"), &error);
        CFRelease(task);
        if (error) CFRelease(error);
        if (entitled) {
            if (CFGetTypeID(entitled) == CFArrayGetTypeID()) {
                NSArray *groups = CFBridgingRelease(entitled);
                NSMutableArray<NSString *> *valid = [NSMutableArray array];
                for (id item in groups) {
                    if ([item isKindOfClass:NSString.class] && [item hasPrefix:@"group."]) {
                        [valid addObject:item];
                    }
                }
                [valid sortUsingSelector:@selector(compare:)];
                agSharedGroup = [valid.firstObject copy];
            } else {
                CFRelease(entitled);
            }
        }
    });
    return agSharedGroup;
}

static NSURL *AGPatchedContainerURL(id instance, SEL selector, NSString *identifier) {
    if (!agOriginalContainerURL) return nil;
    NSURL *original = agOriginalContainerURL(instance, selector, identifier);
    if (original || ![identifier hasPrefix:@"group."]) return original;
    NSString *allowed = AGAllowedSharedGroup();
    if (!allowed || [identifier isEqualToString:allowed]) return original;
    NSURL *alternate = agOriginalContainerURL(instance, selector, allowed);
    // Never return an app-local fake group: the extension couldn't share it.
    if (alternate) NSLog(@"[AyuGramNotificationBridge] Shared container remap succeeded");
    return alternate ?: original;
}

__attribute__((constructor)) static void AGInstallBridge(void) {
    @autoreleasepool {
        Class cls = NSFileManager.class;
        SEL selector = @selector(containerURLForSecurityApplicationGroupIdentifier:);
        Method method = class_getInstanceMethod(cls, selector);
        if (!method) return;
        IMP current = method_getImplementation(method);
        if (current == (IMP)AGPatchedContainerURL) return;
        agOriginalContainerURL = (AGOriginalContainerFn)current;
        method_setImplementation(method, (IMP)AGPatchedContainerURL);
    }
}
