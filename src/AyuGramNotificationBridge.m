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

// The patcher sets the same group in both app and notification extension Info.plists.
// This must be an App Group explicitly granted to BOTH signed targets.
static NSString *AGAllowedSharedGroup(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        id configured = [NSBundle.mainBundle objectForInfoDictionaryKey:@"AyuGramBridgeGroup"];
        if ([configured isKindOfClass:NSString.class] &&
            [configured hasPrefix:@"group."] && [configured length] < 256) {
            agSharedGroup = [configured copy];
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
