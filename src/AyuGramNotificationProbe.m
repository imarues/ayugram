// AyuGram NSE diagnostic: app extension only. No key reading, network, or message logging.
// A transient visible marker confirms whether the extension's completion handler ran.
#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import <string.h>

static IMP AGOriginalReceive = NULL;
static const NSString *AGProbeMarker = @"[NSE ✓] ";

static void AGProbeReceive(id self, SEL cmd, UNNotificationRequest *request, void (^handler)(UNNotificationContent *)) {
    IMP original = AGOriginalReceive;
    if (!original || !handler) return;
    void (^wrapped)(UNNotificationContent *) = ^(UNNotificationContent *content) {
        if (!content) { handler(content); return; }
        UNMutableNotificationContent *copy = [content mutableCopy];
        // A non-persistent debug marker only; retains the original sender/body.
        NSString *title = copy.title ?: @"";
        if (![title hasPrefix:(NSString *)AGProbeMarker]) {
            copy.title = [(NSString *)AGProbeMarker stringByAppendingString:title];
        }
        handler(copy);
    };
    ((void (*)(id, SEL, UNNotificationRequest *, id))original)(self,cmd,request,[wrapped copy]);
}

__attribute__((constructor)) static void AGProbeInstall(void) {
    Class base = [UNNotificationServiceExtension class];
    int n=objc_getClassList(NULL,0);
    if (n <= 0 || n>100000) return;
    Class __unsafe_unretained *classes=(Class __unsafe_unretained *)calloc((size_t)n,sizeof(Class));
    if (!classes) return;
    int actual=objc_getClassList(classes,n);
    SEL selector=@selector(didReceiveNotificationRequest:withContentHandler:);
    for (int i=0; i<actual && i<n; i++) {
        Class cls=classes[i];
        if (cls == base) continue;
        const char *name=class_getName(cls);
        if (!name || !strstr(name,"NotificationService")) continue;
        Class s=class_getSuperclass(cls);
        BOOL isExtension=NO;
        for (int depth=0;s && depth<12;depth++,s=class_getSuperclass(s)) {
            if (s==base) {isExtension=YES; break;}
        }
        if (!isExtension) continue;
        Method method=class_getInstanceMethod(cls,selector);
        if (!method) continue;
        IMP impl=method_getImplementation(method);
        if (impl==(IMP)AGProbeReceive) break;
        // Do not globally change UNNotificationServiceExtension's inherited method.
        if (class_getInstanceMethod(base, selector) == method) continue;
        AGOriginalReceive=impl;
        method_setImplementation(method,(IMP)AGProbeReceive);
        break;
    }
    free(classes);
}
