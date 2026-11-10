// AyuGramArabic — localizes existing UI strings only; it does not modify Telegram account state.
// iOS 15+ / arm64; built with Apple iOS SDK on macOS.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import "generated_ar.h"

static NSDictionary<NSString *, NSString *> *AGMap(void) {
    static NSDictionary *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSData *data = [NSData dataWithBytes:AG_AR_BYTES length:sizeof(AG_AR_BYTES)];
        NSError *error = nil;
        id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        map = [parsed isKindOfClass:[NSDictionary class]] ? parsed : @{};
        if (error) NSLog(@"[AyuGramArabic] Failed to read embedded translations: %@", error);
    });
    return map;
}

static BOOL AGArabicEnabled(void) {
    id preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"AyuGramArabicEnabled"];
    // The requested target is AyuGram's screens only, even if Telegram is set to English.
    return preference == nil || [preference boolValue];
}

static BOOL AGViewControllerHasAyu(UIViewController *controller, NSUInteger depth) {
    if (!controller || depth > 12) return NO;
    NSString *name = NSStringFromClass([controller class]);
    if ([name localizedCaseInsensitiveContainsString:@"Ayu"]) return YES;
    if ([controller isKindOfClass:[UINavigationController class]]) {
        if (AGViewControllerHasAyu(((UINavigationController *)controller).visibleViewController, depth + 1)) return YES;
    }
    if ([controller isKindOfClass:[UITabBarController class]]) {
        if (AGViewControllerHasAyu(((UITabBarController *)controller).selectedViewController, depth + 1)) return YES;
    }
    if (controller.presentedViewController &&
        AGViewControllerHasAyu(controller.presentedViewController, depth + 1)) return YES;
    for (UIViewController *child in controller.childViewControllers) {
        if (child.viewIfLoaded.window && AGViewControllerHasAyu(child, depth + 1)) return YES;
    }
    return NO;
}

static BOOL AGIsOnAyuPage(void) {
    if (![NSThread isMainThread]) return NO;
    UIApplication *app = UIApplication.sharedApplication;
    for (UIWindow *window in app.windows) {
        if (window.isHidden || !window.rootViewController) continue;
        if (AGViewControllerHasAyu(window.rootViewController, 0)) return YES;
    }
    return NO;
}

static BOOL AGNeedsContext(NSString *text) {
    static NSSet<NSString *> *ambiguous;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ambiguous = [NSSet setWithArray:@[
            @"Privacy", @"Messages", @"Appearance", @"Security", @"More", @"Channel",
            @"Source Code", @"Chat list", @"Panels", @"Settings", @"History",
            @"Camera", @"Video", @"Audio", @"Chats", @"Calls", @"Photos",
            @"Notifications", @"Quality", @"Storage", @"Version", @"Type", @"Title",
            @"Description", @"Author", @"Filter", @"Edit", @"Delete", @"Save",
            @"Reset", @"Apply", @"Done", @"Cancel", @"Close", @"Add", @"Remove",
            @"Import", @"Export", @"Search", @"Enable", @"Disable",
            @"Enabled", @"Disabled", @"Refresh", @"Update", @"Download",
            @"Install", @"Uninstall", @"Copy", @"Share", @"All", @"None",
            @"Back", @"Next", @"Previous", @"Error", @"Warning", @"Success",
            @"Translation", @"Translate", @"Language", @"Automatic", @"System",
            @"Light", @"Dark", @"Account", @"Accounts", @"Open", @"Send",
            @"Confirm", @"Check", @"Tools", @"Permissions", @"Preview",
            @"Repeat", @"Themes", @"Colours", @"Badges", @"Message", @"Chat"
        ]];
    });
    return [ambiguous containsObject:text];
}

static NSString *AGTranslate(NSString *text) {
    if (!AGArabicEnabled() || ![text isKindOfClass:NSString.class] || text.length == 0) return text;
    NSString *found = AGMap()[text];
    if (found.length) {
        return AGNeedsContext(text) && !AGIsOnAyuPage() ? text : found;
    }
    // Match labels with harmless surrounding whitespace without affecting other content.
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length || [trimmed isEqualToString:text]) return text;
    found = AGMap()[trimmed];
    if (!found.length || (AGNeedsContext(trimmed) && !AGIsOnAyuPage())) return text;
    NSRange range = [text rangeOfString:trimmed];
    if (range.location == NSNotFound) return text;
    NSString *prefix = [text substringToIndex:range.location];
    NSString *suffix = [text substringFromIndex:NSMaxRange(range)];
    return [NSString stringWithFormat:@"%@%@%@", prefix, found, suffix];
}

static NSAttributedString *AGTranslateAttributed(NSAttributedString *original) {
    if (![original isKindOfClass:NSAttributedString.class] || !original.length) return original;
    NSString *replacement = AGTranslate(original.string);
    if (!replacement || [replacement isEqualToString:original.string]) return original;
    NSMutableAttributedString *modified = [original mutableCopy];
    [modified replaceCharactersInRange:NSMakeRange(0, modified.length) withString:replacement];
    // Keep original font, color and other visual attributes.
    // Direction is attached only to strings actually translated by this tweak.
    if (modified.length) {
        NSMutableParagraphStyle *style = [[modified attribute:NSParagraphStyleAttributeName
            atIndex:0 effectiveRange:NULL] mutableCopy];
        if (!style) style = [[NSMutableParagraphStyle alloc] init];
        style.baseWritingDirection = NSWritingDirectionRightToLeft;
        style.alignment = NSTextAlignmentNatural;
        [modified addAttribute:NSParagraphStyleAttributeName value:style
                        range:NSMakeRange(0, modified.length)];
    }
    return modified;
}

#define AG_CALL_VOID3(ORIG, OBJ, CMD, ARG) \
    if (ORIG) ((void (*)(id, SEL, id))ORIG)(OBJ, CMD, ARG)

static IMP origUILabelText = NULL;
static void AGUILabelText(UILabel *obj, SEL cmd, NSString *value) {
    AG_CALL_VOID3(origUILabelText, obj, cmd, AGTranslate(value));
}
static IMP origUILabelAttr = NULL;
static void AGUILabelAttr(UILabel *obj, SEL cmd, NSAttributedString *value) {
    AG_CALL_VOID3(origUILabelAttr, obj, cmd, AGTranslateAttributed(value));
}
static IMP origUITextViewText = NULL;
static void AGUITextViewText(UITextView *obj, SEL cmd, NSString *value) {
    AG_CALL_VOID3(origUITextViewText, obj, cmd, AGTranslate(value));
}
static IMP origUITextViewAttr = NULL;
static void AGUITextViewAttr(UITextView *obj, SEL cmd, NSAttributedString *value) {
    AG_CALL_VOID3(origUITextViewAttr, obj, cmd, AGTranslateAttributed(value));
}
static IMP origUITextFieldPlaceholder = NULL;
static void AGUITextFieldPlaceholder(UITextField *obj, SEL cmd, NSString *value) {
    AG_CALL_VOID3(origUITextFieldPlaceholder, obj, cmd, AGTranslate(value));
}
static IMP origUITextFieldText = NULL;
static void AGUITextFieldText(UITextField *obj, SEL cmd, NSString *value) {
    AG_CALL_VOID3(origUITextFieldText, obj, cmd, AGTranslate(value));
}
static IMP origNavigationTitle = NULL;
static void AGNavigationTitle(UINavigationItem *obj, SEL cmd, NSString *value) {
    AG_CALL_VOID3(origNavigationTitle, obj, cmd, AGTranslate(value));
}
static IMP origControllerTitle = NULL;
static void AGControllerTitle(UIViewController *obj, SEL cmd, NSString *value) {
    AG_CALL_VOID3(origControllerTitle, obj, cmd, AGTranslate(value));
}
static IMP origBarTitle = NULL;
static void AGBarTitle(UIBarButtonItem *obj, SEL cmd, NSString *value) {
    AG_CALL_VOID3(origBarTitle, obj, cmd, AGTranslate(value));
}
static IMP origButtonTitle = NULL;
static void AGButtonTitle(UIButton *obj, SEL cmd, NSString *value, UIControlState state) {
    if (origButtonTitle)
        ((void (*)(id, SEL, NSString *, UIControlState))origButtonTitle)(obj, cmd, AGTranslate(value), state);
}
static IMP origButtonAttr = NULL;
static void AGButtonAttr(UIButton *obj, SEL cmd, NSAttributedString *value, UIControlState state) {
    if (origButtonAttr)
        ((void (*)(id, SEL, NSAttributedString *, UIControlState))origButtonAttr)
            (obj, cmd, AGTranslateAttributed(value), state);
}
static IMP origAttributedInit = NULL;
static id AGAttributedInit(id obj, SEL cmd, NSString *value) {
    return origAttributedInit
        ? ((id (*)(id, SEL, NSString *))origAttributedInit)(obj, cmd, AGTranslate(value))
        : obj;
}
static IMP origAttributedInitAttrs = NULL;
static id AGAttributedInitAttrs(id obj, SEL cmd, NSString *value, NSDictionary *attrs) {
    return origAttributedInitAttrs
        ? ((id (*)(id, SEL, NSString *, NSDictionary *))origAttributedInitAttrs)
            (obj, cmd, AGTranslate(value), attrs)
        : obj;
}
static IMP origASAttributed = NULL;
static void AGASAttributed(id obj, SEL cmd, NSAttributedString *value) {
    AG_CALL_VOID3(origASAttributed, obj, cmd, AGTranslateAttributed(value));
}
static IMP origAlertFactory = NULL;
static id AGAlertFactory(id cls, SEL cmd, NSString *title, NSString *msg, UIAlertControllerStyle style) {
    return origAlertFactory
        ? ((id (*)(id, SEL, NSString *, NSString *, UIAlertControllerStyle))origAlertFactory)
            (cls, cmd, AGTranslate(title), AGTranslate(msg), style)
        : nil;
}
static IMP origActionFactory = NULL;
static id AGActionFactory(id cls, SEL cmd, NSString *title, UIAlertActionStyle style, id handler) {
    return origActionFactory
        ? ((id (*)(id, SEL, NSString *, UIAlertActionStyle, id))origActionFactory)
            (cls, cmd, AGTranslate(title), style, handler)
        : nil;
}
static IMP origSegmentTitle = NULL;
static void AGSegmentTitle(UISegmentedControl *obj, SEL cmd, NSString *title, NSUInteger idx) {
    if (origSegmentTitle)
        ((void (*)(id, SEL, NSString *, NSUInteger))origSegmentTitle)(obj, cmd, AGTranslate(title), idx);
}

static void AGHook(Class cls, SEL selector, IMP replacement, IMP *original) {
    if (!cls || !selector) return;
    Method m = class_getInstanceMethod(cls, selector);
    if (!m) return;
    *original = method_getImplementation(m);
    if (*original != replacement) method_setImplementation(m, replacement);
}


#pragma mark - Concrete attributed text classes and Telegram text nodes

// NSAttributedString is a class cluster: Swift's NSAttributedString(string:)
// creates concrete objects. Swizzling only the public base class was ineffective
// for several custom Telegram ItemList/TextNode UI components.
static IMP originalConcreteImmutablePlain = NULL;
static IMP originalConcreteImmutableAttrs = NULL;
static IMP originalConcreteMutablePlain = NULL;
static IMP originalConcreteMutableAttrs = NULL;

static id AGConcreteImmutablePlain(id obj, SEL cmd, NSString *value) {
    return originalConcreteImmutablePlain
        ? ((id (*)(id, SEL, NSString *))originalConcreteImmutablePlain)(obj, cmd, AGTranslate(value))
        : obj;
}
static id AGConcreteImmutableAttrs(id obj, SEL cmd, NSString *value, NSDictionary *attrs) {
    return originalConcreteImmutableAttrs
        ? ((id (*)(id, SEL, NSString *, NSDictionary *))originalConcreteImmutableAttrs)
          (obj, cmd, AGTranslate(value), attrs)
        : obj;
}
static id AGConcreteMutablePlain(id obj, SEL cmd, NSString *value) {
    return originalConcreteMutablePlain
        ? ((id (*)(id, SEL, NSString *))originalConcreteMutablePlain)(obj, cmd, AGTranslate(value))
        : obj;
}
static id AGConcreteMutableAttrs(id obj, SEL cmd, NSString *value, NSDictionary *attrs) {
    return originalConcreteMutableAttrs
        ? ((id (*)(id, SEL, NSString *, NSDictionary *))originalConcreteMutableAttrs)
          (obj, cmd, AGTranslate(value), attrs)
        : obj;
}

static void AGHookConcrete(Class cls, SEL selector, IMP impl, IMP *original) {
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, selector);
    if (!m) return;
    *original = method_getImplementation(m);
    if (*original == impl) return;
    // class_replaceMethod overrides an inherited method on this concrete class,
    // unlike method_setImplementation which may patch the superclass globally.
    class_replaceMethod(cls, selector, impl, method_getTypeEncoding(m));
}

static void AGHookAttributedClusters(void) {
    NSAttributedString *immutable = [[NSAttributedString alloc] initWithString:@"Arabic diagnostic"];
    NSMutableAttributedString *mutable = [[NSMutableAttributedString alloc] initWithString:@"Arabic diagnostic"];
    Class immutableClass = object_getClass(immutable);
    Class mutableClass = object_getClass(mutable);
    NSLog(@"[AyuGramArabic] Cluster classes: %@ / %@",
          NSStringFromClass(immutableClass), NSStringFromClass(mutableClass));
    AGHookConcrete(immutableClass, @selector(initWithString:),
                   (IMP)AGConcreteImmutablePlain, &originalConcreteImmutablePlain);
    AGHookConcrete(immutableClass, @selector(initWithString:attributes:),
                   (IMP)AGConcreteImmutableAttrs, &originalConcreteImmutableAttrs);
    if (mutableClass != immutableClass) {
        AGHookConcrete(mutableClass, @selector(initWithString:),
                       (IMP)AGConcreteMutablePlain, &originalConcreteMutablePlain);
        AGHookConcrete(mutableClass, @selector(initWithString:attributes:),
                       (IMP)AGConcreteMutableAttrs, &originalConcreteMutableAttrs);
    }
}

// ASTextNode is not the only Telegram text renderer. ImmediateTextNode and
// TextNode are common in the ItemList controllers used by AyuGram settings.
static IMP origImmediateTextAttributed = NULL;
static IMP origTelegramTextAttributed = NULL;
static void AGImmediateTextAttributed(id obj, SEL cmd, NSAttributedString *value) {
    AG_CALL_VOID3(origImmediateTextAttributed, obj, cmd, AGTranslateAttributed(value));
}
static void AGTelegramTextAttributed(id obj, SEL cmd, NSAttributedString *value) {
    AG_CALL_VOID3(origTelegramTextAttributed, obj, cmd, AGTranslateAttributed(value));
}

static void AGHookTelegramTextNodes(void) {
    // Hook only methods implemented on a specific class (not inherited).
    Class immediate = NSClassFromString(@"ImmediateTextNode");
    if (immediate) {
        Method m = class_getInstanceMethod(immediate, @selector(setAttributedText:));
        if (m) AGHookConcrete(immediate, @selector(setAttributedText:),
                              (IMP)AGImmediateTextAttributed, &origImmediateTextAttributed);
    }
    Class textNode = NSClassFromString(@"TextNode");
    if (textNode && textNode != immediate) {
        Method m = class_getInstanceMethod(textNode, @selector(setAttributedText:));
        if (m) AGHookConcrete(textNode, @selector(setAttributedText:),
                              (IMP)AGTelegramTextAttributed, &origTelegramTextAttributed);
    }
}

#pragma mark - Short diagnostic toast for this unverified injection build

static void AGShowLoadedToast(void) {
    UIApplication *app = UIApplication.sharedApplication;
    UIWindow *targetWindow = nil;
    for (UIWindow *w in app.windows) {
        if (!w.hidden && w.rootViewController && (!targetWindow || w.isKeyWindow)) {
            targetWindow = w;
        }
    }
    if (!targetWindow) return;
    UILabel *notice = [[UILabel alloc] initWithFrame:CGRectZero];
    notice.text = @"AyuGramArabic v2 — تم تحميل الديلب";
    notice.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    notice.textAlignment = NSTextAlignmentCenter;
    notice.textColor = UIColor.whiteColor;
    notice.backgroundColor = [UIColor colorWithRed:0.24 green:0.16 blue:0.52 alpha:0.96];
    notice.layer.cornerRadius = 13;
    notice.layer.masksToBounds = YES;
    notice.userInteractionEnabled = NO;
    CGFloat w = MIN(CGRectGetWidth(targetWindow.bounds) - 32, 310);
    notice.frame = CGRectMake((CGRectGetWidth(targetWindow.bounds) - w)/2.0,
                             targetWindow.safeAreaInsets.top + 12, w, 38);
    [targetWindow addSubview:notice];
    [UIView animateWithDuration:0.3 delay:9.0 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{ notice.alpha = 0.0; }
                     completion:^(__unused BOOL finished){ [notice removeFromSuperview]; }];
}
static void AGScheduleLoadedToast(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.7*NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ AGShowLoadedToast(); });
    });
}
static void AGInstallDiagnostics(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(__unused NSNotification *note){ AGScheduleLoadedToast(); }];
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
            AGScheduleLoadedToast();
        }
    });
}

__attribute__((constructor))
static void AGStart(void) {
    @autoreleasepool {
        // UIKit surfaces used by settings, sheets, dialogs and plugin lists.
        AGHook(UILabel.class, @selector(setText:), (IMP)AGUILabelText, &origUILabelText);
        AGHook(UILabel.class, @selector(setAttributedText:), (IMP)AGUILabelAttr, &origUILabelAttr);
        AGHook(UITextView.class, @selector(setText:), (IMP)AGUITextViewText, &origUITextViewText);
        AGHook(UITextView.class, @selector(setAttributedText:), (IMP)AGUITextViewAttr, &origUITextViewAttr);
        AGHook(UITextField.class, @selector(setText:), (IMP)AGUITextFieldText, &origUITextFieldText);
        AGHook(UITextField.class, @selector(setPlaceholder:), (IMP)AGUITextFieldPlaceholder, &origUITextFieldPlaceholder);
        AGHook(UINavigationItem.class, @selector(setTitle:), (IMP)AGNavigationTitle, &origNavigationTitle);
        AGHook(UIViewController.class, @selector(setTitle:), (IMP)AGControllerTitle, &origControllerTitle);
        AGHook(UIBarButtonItem.class, @selector(setTitle:), (IMP)AGBarTitle, &origBarTitle);
        AGHook(UIButton.class, @selector(setTitle:forState:), (IMP)AGButtonTitle, &origButtonTitle);
        AGHook(UIButton.class, @selector(setAttributedTitle:forState:), (IMP)AGButtonAttr, &origButtonAttr);
        AGHook(UISegmentedControl.class, @selector(setTitle:forSegmentAtIndex:),
               (IMP)AGSegmentTitle, &origSegmentTitle);
        // Swift TextNode and several Telegram settings components construct NSAttributedString.
        AGHook(NSAttributedString.class, @selector(initWithString:),
               (IMP)AGAttributedInit, &origAttributedInit);
        AGHook(NSAttributedString.class, @selector(initWithString:attributes:),
               (IMP)AGAttributedInitAttrs, &origAttributedInitAttrs);
        // Fix Swift/Foundation class-cluster dispatch paths.
        AGHookAttributedClusters();
        // Fix Telegram-specific custom TextNodes.
        AGHookTelegramTextNodes();
        // Temporary on-screen proof that the injector actually loaded this dylib.
        AGInstallDiagnostics();
        // AsyncDisplayKit text nodes can receive already-initialized attributed text.
        Class asTextNode = NSClassFromString(@"ASTextNode");
        if (asTextNode) AGHook(asTextNode, @selector(setAttributedText:),
                               (IMP)AGASAttributed, &origASAttributed);
        Class alertMeta = object_getClass(UIAlertController.class);
        AGHook(alertMeta, @selector(alertControllerWithTitle:message:preferredStyle:),
               (IMP)AGAlertFactory, &origAlertFactory);
        Class actionMeta = object_getClass(UIAlertAction.class);
        AGHook(actionMeta, @selector(actionWithTitle:style:handler:),
               (IMP)AGActionFactory, &origActionFactory);
    }
}
