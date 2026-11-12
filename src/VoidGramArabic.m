// VoidGramArabic — root settings UI localization + root-only links/credits visibility; no account state changes.
// iOS 15+ / arm64; built with Apple iOS SDK on macOS.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/dispatch.h>
#import <stdatomic.h>
#import "generated_voidgram_ar.h"

static NSDictionary<NSString *, NSString *> *AGMap(void) {
    static NSDictionary *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSData *data = [NSData dataWithBytes:VG_AR_BYTES length:sizeof(VG_AR_BYTES)];
        NSError *error = nil;
        id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        map = [parsed isKindOfClass:[NSDictionary class]] ? parsed : @{};
        if (error) NSLog(@"[VoidGramArabic] Failed to read embedded translations: %@", error);
    });
    return map;
}

static BOOL AGArabicEnabled(void) {
    id preference = [[NSUserDefaults standardUserDefaults] objectForKey:@"VoidGramArabicEnabled"];
    // The requested target is VoidGram's screens only, even if Telegram is set to English.
    return preference == nil || [preference boolValue];
}

// Scope is strictly the VoidGram page within Telegram Settings.
// Neither a generic ItemListController nor an Ayu-named class proves ownership.
// The distinctive intro text creates a short-lived root-opening hint. Once the
// page appears we mark THAT instance and follow only its current navigation stack.
static atomic_bool AGPendingAyuRoot = ATOMIC_VAR_INIT(false);
// Telegram uses its own NavigationController rather than UINavigationController.
// ItemListController pages therefore do not expose the marked root through
// UIKit's navigationController property. Keep the VoidGram session across
// pushes; clear it as soon as stock Telegram controllers become active.
static atomic_bool AGInVoidStack = ATOMIC_VAR_INIT(false);
static char AGRootMarker;
static char AGChildMarker; // each visited VoidGram sub-page remains identifiable after returning
static BOOL AGControllerIsWithinMarkedRoot(UIViewController *vc);

static UIViewController *AGVisibleController(UIViewController *controller, NSUInteger depth) {
    if (!controller || depth > 20) return controller;
    if (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) {
        return AGVisibleController(controller.presentedViewController, depth + 1);
    }
    if ([controller isKindOfClass:UINavigationController.class]) {
        UIViewController *active = ((UINavigationController *)controller).visibleViewController;
        return AGVisibleController(active ?: controller, depth + 1);
    }
    if ([controller isKindOfClass:UITabBarController.class]) {
        UIViewController *active = ((UITabBarController *)controller).selectedViewController;
        return AGVisibleController(active ?: controller, depth + 1);
    }
    // Telegram sometimes embeds its navigation controller as a child rather
    // than subclassing UINavigationController. Consider only visible children.
    for (UIViewController *child in [controller.childViewControllers reverseObjectEnumerator]) {
        if (child.isViewLoaded && child.view.window &&
            !child.view.hidden && child.view.alpha > 0.01) {
            UIViewController *visible = AGVisibleController(child, depth + 1);
            if (visible && AGControllerIsWithinMarkedRoot(visible)) return visible;
        }
    }
    return controller;
}

static BOOL AGIsOnAyuPage(void) {
    // Telegram TextNode creates some long footers on a background queue.
    // Once the UNIQUE VoidGram root is known, the scoped atomic session may
    // safely translate exact dictionary keys off-main too; never inspect UIKit
    // from a background queue.
    if (atomic_load(&AGInVoidStack)) return YES;
    if (![NSThread isMainThread]) return NO;
    // Used only during first appearance of the unique VoidGram root.
    if (atomic_load(&AGPendingAyuRoot)) return YES;
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.hidden || window.alpha < 0.01 || !window.rootViewController) continue;
        UIViewController *active = AGVisibleController(window.rootViewController, 0);
        NSString *activeClass = active ? NSStringFromClass(active.class) : @"";
        // Chat and account pages must never inherit VoidGram's dictionary.
        if ([activeClass rangeOfString:@"ChatController"].location != NSNotFound ||
            [activeClass rangeOfString:@"ChatListController"].location != NSNotFound ||
            [activeClass rangeOfString:@"AccountController"].location != NSNotFound ||
            [activeClass rangeOfString:@"PeerInfoController"].location != NSNotFound) continue;
        if (AGControllerIsWithinMarkedRoot(active)) return YES;
    }
    return NO;
}

static NSString *AGCanonicalText(NSString *text) {
    if (!text || text.length == 0) return text;
    NSString *value = [text stringByReplacingOccurrencesOfString:@"\u00a0" withString:@" "];
    value = [value stringByReplacingOccurrencesOfString:@"\u200b" withString:@""];
    value = [value stringByReplacingOccurrencesOfString:@"\u2026" withString:@"..."];
    value = [value stringByReplacingOccurrencesOfString:@"\u2019" withString:@"'"];
    value = [value stringByReplacingOccurrencesOfString:@"\u201c" withString:@"\""];
    value = [value stringByReplacingOccurrencesOfString:@"\u201d" withString:@"\""];
    return value;
}
// Swift settings can join multi-line footers or introduce NBSP/line breaks
// after the localization key was written. Build a second exact map with
// normalized whitespace, instead of replacing arbitrary substrings.
static NSString *AGNormalizedUILabel(NSString *source) {
    if (!source.length) return source;
    NSString *canonical = AGCanonicalText(source);
    NSArray<NSString *> *components =
        [canonical componentsSeparatedByCharactersInSet:
         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray<NSString *> *words = [NSMutableArray arrayWithCapacity:components.count];
    for (NSString *part in components) if (part.length) [words addObject:part];
    return [words componentsJoinedByString:@" "];
}
static NSDictionary<NSString *, NSString *> *AGNormalizedMap(void) {
    static NSDictionary *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableDictionary *entries = [NSMutableDictionary dictionary];
        NSMutableSet *conflicts = [NSMutableSet set];
        [AGMap() enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *translation, BOOL *stop) {
            NSString *normalized = AGNormalizedUILabel(key);
            if (!normalized.length) return;
            NSString *previous = entries[normalized];
            if (previous && ![previous isEqualToString:translation]) {
                [conflicts addObject:normalized];
            } else if (!previous) entries[normalized] = translation;
        }];
        for (NSString *key in conflicts) [entries removeObjectForKey:key];
        map = [entries copy];
    });
    return map;
}

static NSString *AGTranslateNumericSummary(NSString *text) {
    if (!AGIsOnAyuPage()) return nil;
    static NSRegularExpression *countPattern, *secondsPattern, *shortSecondsPattern;
    static NSRegularExpression *archivePattern, *fileCountPattern, *capacityPattern, *rulesPattern;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        rulesPattern = [NSRegularExpression regularExpressionWithPattern:
            @"^RULES\\s*[·•]\\s*([0-9]+)\\s+OF\\s+([0-9]+)$"
            options:NSRegularExpressionCaseInsensitive error:NULL];
        countPattern = [NSRegularExpression regularExpressionWithPattern:@"^([0-9]+) of ([0-9]+)$"
            options:0 error:NULL];
        secondsPattern = [NSRegularExpression regularExpressionWithPattern:@"^([0-9]+) (seconds?|minutes?)$"
            options:NSRegularExpressionCaseInsensitive error:NULL];
        shortSecondsPattern = [NSRegularExpression regularExpressionWithPattern:@"^([0-9]+)\\s+s$"
            options:NSRegularExpressionCaseInsensitive error:NULL];
        // The media archive mixes an English count and English "of" with
        // the device-localized size, e.g. "0 files · 0 KB · of 250 MB".
        // Preserve the original values/units while translating only the labels.
        archivePattern = [NSRegularExpression regularExpressionWithPattern:
            @"^([0-9]+)\\s+files?\\s*[·•]\\s*(.+?)\\s*[·•]\\s*of\\s+([0-9]+)\\s+(MB|GB)$"
            options:NSRegularExpressionCaseInsensitive error:NULL];
        fileCountPattern = [NSRegularExpression regularExpressionWithPattern:
            @"^([0-9]+)\\s+files?$"
            options:NSRegularExpressionCaseInsensitive error:NULL];
        capacityPattern = [NSRegularExpression regularExpressionWithPattern:
            @"^of\\s+([0-9]+)\\s+(MB|GB)$"
            options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    NSTextCheckingResult *ruleMatch = [rulesPattern firstMatchInString:text options:0
        range:NSMakeRange(0, text.length)];
    if (ruleMatch && ruleMatch.range.length == text.length) {
        NSString *a = [text substringWithRange:[ruleMatch rangeAtIndex:1]];
        NSString *b = [text substringWithRange:[ruleMatch rangeAtIndex:2]];
        return [NSString stringWithFormat:@"القواعد · %@ من %@", a, b];
    }
    NSTextCheckingResult *m = [archivePattern firstMatchInString:text options:0
        range:NSMakeRange(0, text.length)];
    if (m && m.range.length == text.length) {
        NSString *count = [text substringWithRange:[m rangeAtIndex:1]];
        NSString *size = [text substringWithRange:[m rangeAtIndex:2]];
        NSString *limit = [text substringWithRange:[m rangeAtIndex:3]];
        NSString *unit = [text substringWithRange:[m rangeAtIndex:4]];
        return [NSString stringWithFormat:@"%@ %@ · %@ · من %@ %@",
                count, count.integerValue == 1 ? @"ملف" : @"ملفات",
                size, limit, unit];
    }
    m = [fileCountPattern firstMatchInString:text options:0
        range:NSMakeRange(0, text.length)];
    if (m && m.range.length == text.length) {
        NSString *count = [text substringWithRange:[m rangeAtIndex:1]];
        return [NSString stringWithFormat:@"%@ %@",
                count, count.integerValue == 1 ? @"ملف" : @"ملفات"];
    }
    m = [capacityPattern firstMatchInString:text options:0
        range:NSMakeRange(0, text.length)];
    if (m && m.range.length == text.length) {
        NSString *limit = [text substringWithRange:[m rangeAtIndex:1]];
        NSString *unit = [text substringWithRange:[m rangeAtIndex:2]];
        return [NSString stringWithFormat:@"من %@ %@", limit, unit];
    }
    m = [countPattern firstMatchInString:text options:0
        range:NSMakeRange(0, text.length)];
    if (m && m.range.length == text.length) {
        NSString *a = [text substringWithRange:[m rangeAtIndex:1]];
        NSString *b = [text substringWithRange:[m rangeAtIndex:2]];
        return [NSString stringWithFormat:@"%@ من %@", a, b];
    }
    m = [secondsPattern firstMatchInString:text options:0 range:NSMakeRange(0,text.length)];
    if (m && m.range.length == text.length) {
        NSString *a = [text substringWithRange:[m rangeAtIndex:1]];
        NSString *unit = [text substringWithRange:[m rangeAtIndex:2]];
        return [NSString stringWithFormat:@"%@ %@", a,
            [[unit lowercaseString] hasPrefix:@"second"] ? @"ثانية" : @"دقيقة"];
    }
    m = [shortSecondsPattern firstMatchInString:text options:0 range:NSMakeRange(0,text.length)];
    if (m && m.range.length == text.length) {
        NSString *value = [text substringWithRange:[m rangeAtIndex:1]];
        return [NSString stringWithFormat:@"%@ ثانية", value];
    }
    return nil;
}

static NSString *AGTranslate(NSString *text) {
    if (!AGArabicEnabled() || ![text isKindOfClass:NSString.class] || text.length == 0) return text;
    // IMPORTANT: never use CATEGORIES, Privacy, Messages, or Ghost Mode by chat
    // as a root marker. Those may be rendered in other Telegram surfaces.
    if ([text isEqualToString:@"Just an exteraGram based client with ToS breaking features in mind."] &&
        [NSThread isMainThread]) {
        atomic_store(&AGPendingAyuRoot, true);
    }
    if (!AGIsOnAyuPage()) return text; // exact mapping is never global
    NSString *found = AGMap()[text];
    if (!found) found = AGMap()[AGCanonicalText(text)];
    if (!found) found = AGNormalizedMap()[AGNormalizedUILabel(text)];
    if (found.length) return found;
    NSString *numeric = AGTranslateNumericSummary(text);
    if (numeric) return numeric;
    // Common layout: an icon/emoji/bullet followed by a known label.
    // Preserve the exact prefix (including ZWJ emoji sequences).
    if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[text characterAtIndex:0]]) {
        NSUInteger prefixEnd = 0;
        while (prefixEnd < text.length && prefixEnd <= 16) {
            unichar ch = [text characterAtIndex:prefixEnd];
            if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) break;
            NSRange cluster = [text rangeOfComposedCharacterSequenceAtIndex:prefixEnd];
            prefixEnd = NSMaxRange(cluster);
        }
        if (prefixEnd && prefixEnd <= 16 && prefixEnd < text.length) {
            NSString *suffix = [text substringFromIndex:prefixEnd];
            NSString *candidate = AGMap()[suffix];
            if (!candidate) candidate = AGMap()[AGCanonicalText(suffix)];
            if (candidate.length) {
                return [[text substringToIndex:prefixEnd] stringByAppendingString:candidate];
            }
        }
    }

    // Translate a known label with a trailing emoji or decorative bullet.
    // Preserve the suffix's exact composed characters (including ZWJ emoji).
    if (text.length > 2) {
        NSUInteger suffixStart = text.length;
        while (suffixStart > 0 && text.length - suffixStart <= 16) {
            NSRange cluster = [text rangeOfComposedCharacterSequenceAtIndex:suffixStart - 1];
            NSString *glyph = [text substringWithRange:cluster];
            unichar ch = [glyph characterAtIndex:0];
            if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
                (ch >= '0' && ch <= '9')) break;
            suffixStart = cluster.location;
        }
        if (suffixStart < text.length && suffixStart > 0) {
            NSString *prefix = [text substringToIndex:suffixStart];
            NSString *mapped = AGMap()[prefix];
            if (mapped.length) {
                return [mapped stringByAppendingString:[text substringFromIndex:suffixStart]];
            }
        }
    }

    // Telegram's VoidGram settings renderer sometimes combines several UI-only lines
    // into one attributed string; translate complete lines independently.
    // No heuristic substring translation is performed on arbitrary chat text.
    if (AGIsOnAyuPage() && [text rangeOfString:@"\n"].location != NSNotFound) {
        NSArray<NSString *> *parts = [text componentsSeparatedByString:@"\n"];
        NSMutableArray<NSString *> *translatedParts = [NSMutableArray arrayWithCapacity:parts.count];
        BOOL changed = NO;
        for (NSString *line in parts) {
            NSString *lineValue = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            NSString *lookup = AGMap()[lineValue];
            if (!lookup) lookup = AGMap()[AGCanonicalText(lineValue)];
            if (!lookup.length) {
                [translatedParts addObject:line];
            } else {
                NSRange location = [line rangeOfString:lineValue];
                NSString *head = [line substringToIndex:location.location];
                NSString *tail = [line substringFromIndex:NSMaxRange(location)];
                [translatedParts addObject:[NSString stringWithFormat:@"%@%@%@", head, lookup, tail]];
                changed = YES;
            }
        }
        if (changed) return [translatedParts componentsJoinedByString:@"\n"];
    }
    // Preview chat bubbles may contain timestamps in the same TextNode.
    if (AGIsOnAyuPage()) {
        for (NSString *example in @[@"Meet at 7", @"Meet at 7?",
                                    @"OK, see you there 👍", @"Okay, see you there 👍"]) {
            if ([text hasPrefix:example] && text.length > example.length) {
                unichar following = [text characterAtIndex:example.length];
                if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:following]) {
                    NSString *translated = AGMap()[example];
                    if (translated.length) return [translated stringByAppendingString:
                        [text substringFromIndex:example.length]];
                }
            }
        }
    }
    // Match labels with harmless surrounding whitespace without affecting other content.
    NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length || [trimmed isEqualToString:text]) return text;
    found = AGMap()[trimmed];
    if (!found) found = AGMap()[AGCanonicalText(trimmed)];
    if (!found) found = AGNormalizedMap()[AGNormalizedUILabel(trimmed)];
    if (!found.length) return text;
    NSRange range = [text rangeOfString:trimmed];
    if (range.location == NSNotFound) return text;
    NSString *prefix = [text substringToIndex:range.location];
    NSString *suffix = [text substringFromIndex:NSMaxRange(range)];
    return [NSString stringWithFormat:@"%@%@%@", prefix, found, suffix];
}

// Every Swift/Telegram text node may create multiple intermediate attributed
// strings. Translating inside an attributed-string copy constructor and then
// cloning again used to recursively revisit this hot path. Guard the whole
// conversion, not only initWithAttributedString:.
static _Thread_local BOOL agInsideTextConversion = NO;
static NSAttributedString *AGTranslateAttributed(NSAttributedString *original) {
    if (![original isKindOfClass:NSAttributedString.class] ||
        !original.length || original.length > 5000 || agInsideTextConversion ||
        !AGArabicEnabled() || !AGIsOnAyuPage()) return original;
    agInsideTextConversion = YES;
    NSAttributedString *result = original;
    @try {
        NSString *plain = original.string;
        NSString *replacement = AGTranslate(plain);
        if (replacement.length && ![replacement isEqualToString:plain]) {
            // Only create the mutable copy if an exact UI translation exists.
            // Avoid touching user-editable text or continuously rebuilding nodes.
            NSMutableAttributedString *modified = [original mutableCopy];
            [modified replaceCharactersInRange:NSMakeRange(0, modified.length)
                                    withString:replacement];
            NSMutableParagraphStyle *style = [[modified attribute:NSParagraphStyleAttributeName
                atIndex:0 effectiveRange:NULL] mutableCopy];
            if (!style) style = [[NSMutableParagraphStyle alloc] init];
            style.baseWritingDirection = NSWritingDirectionRightToLeft;
            style.alignment = NSTextAlignmentNatural;
            [modified addAttribute:NSParagraphStyleAttributeName value:style
                            range:NSMakeRange(0, modified.length)];
            result = modified;
        }
    } @finally {
        agInsideTextConversion = NO;
    }
    return result;
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
    AG_CALL_VOID3(origUITextViewText, obj, cmd, obj.editable ? value : AGTranslate(value));
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
    // Never replace user-typed search terms, filter rules, or account data.
    AG_CALL_VOID3(origUITextFieldText, obj, cmd, value);
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

// Some Telegram/Swift TextNodes clone attributed strings after adding spans.
// Translate that path too, with reentrancy protection for mutableCopy().
static IMP originalConcreteImmutableCopy = NULL;
static IMP originalConcreteMutableCopy = NULL;
static _Thread_local BOOL agInsideAttributedCopy = NO;

static id AGAttributedCopyInit(id obj, SEL cmd, NSAttributedString *value, IMP original) {
    if (!original) return obj;
    if (!value || agInsideAttributedCopy || !AGArabicEnabled() || !AGIsOnAyuPage()) {
        return ((id (*)(id, SEL, NSAttributedString *))original)(obj, cmd, value);
    }
    agInsideAttributedCopy = YES;
    NSAttributedString *translated = AGTranslateAttributed(value);
    id result = ((id (*)(id, SEL, NSAttributedString *))original)(obj, cmd, translated);
    agInsideAttributedCopy = NO;
    return result;
}
static id AGConcreteImmutableCopy(id obj, SEL cmd, NSAttributedString *value) {
    return AGAttributedCopyInit(obj, cmd, value, originalConcreteImmutableCopy);
}
static id AGConcreteMutableCopy(id obj, SEL cmd, NSAttributedString *value) {
    return AGAttributedCopyInit(obj, cmd, value, originalConcreteMutableCopy);
}


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
    NSLog(@"[VoidGramArabic] Cluster classes: %@ / %@",
          NSStringFromClass(immutableClass), NSStringFromClass(mutableClass));
    AGHookConcrete(immutableClass, @selector(initWithString:),
                   (IMP)AGConcreteImmutablePlain, &originalConcreteImmutablePlain);
    AGHookConcrete(immutableClass, @selector(initWithString:attributes:),
                   (IMP)AGConcreteImmutableAttrs, &originalConcreteImmutableAttrs);
    // Deliberately do not swizzle initWithAttributedString: here. The copy
    // constructor is used heavily by interactive gesture previews, and
    // translating it triggers recursive layout/copy storms.
    if (mutableClass != immutableClass) {
        AGHookConcrete(mutableClass, @selector(initWithString:),
                       (IMP)AGConcreteMutablePlain, &originalConcreteMutablePlain);
        AGHookConcrete(mutableClass, @selector(initWithString:attributes:),
                       (IMP)AGConcreteMutableAttrs, &originalConcreteMutableAttrs);
        // Keep the native mutable-copy initializer untouched as well.
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
    notice.text = @"VoidGramArabic v2 — تم تحميل الديلب";
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


// Navigate by the anchored root's presence in the CURRENT stack, never by
// a sticky global boolean or by generic Telegram class names.
static IMP origAyuViewDidAppear = NULL;
static BOOL AGControllerIsWithinMarkedRoot(UIViewController *vc) {
    for (NSUInteger depth = 0; vc && depth < 20; depth++) {
        // A modal opened from a real chat is still a chat, even if the
        // VoidGram root happens to remain lower in the navigation stack.
        NSString *name = NSStringFromClass(vc.class);
        if ([name rangeOfString:@"ChatController"].location != NSNotFound ||
            [name rangeOfString:@"ChatListController"].location != NSNotFound ||
            [name rangeOfString:@"AccountController"].location != NSNotFound ||
            [name rangeOfString:@"PeerInfoController"].location != NSNotFound) return NO;
        if (objc_getAssociatedObject(vc, &AGRootMarker) ||
            objc_getAssociatedObject(vc, &AGChildMarker)) return YES;
        UINavigationController *nav = vc.navigationController;
        if (nav) {
            for (UIViewController *item in nav.viewControllers) {
                if (objc_getAssociatedObject(item, &AGRootMarker)) return YES;
            }
        }
        vc = vc.parentViewController ?: vc.presentingViewController;
    }
    return NO;
}
static void AGRefreshSettingsView(UIView *view, NSUInteger depth, NSUInteger *remaining) {
    if (!view || depth > 20 || view.hidden || !remaining || *remaining == 0) return;
    --(*remaining);
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        if (label.attributedText.length) {
            NSAttributedString *old = label.attributedText;
            NSAttributedString *translated = AGTranslateAttributed(old);
            if (translated != old) label.attributedText = translated;
        } else if (label.text.length) {
            NSString *translated = AGTranslate(label.text);
            if (![translated isEqualToString:label.text]) label.text = translated;
        }
    } else if ([view isKindOfClass:UIButton.class]) {
        UIButton *button = (UIButton *)view;
        for (NSNumber *n in @[@(UIControlStateNormal), @(UIControlStateSelected)]) {
            UIControlState state = (UIControlState)n.unsignedIntegerValue;
            NSString *old = [button titleForState:state];
            NSString *translated = AGTranslate(old);
            if (old.length && ![translated isEqualToString:old]) [button setTitle:translated forState:state];
        }
    } else if ([view isKindOfClass:UITextField.class]) {
        UITextField *field = (UITextField *)view;
        NSString *translated = AGTranslate(field.placeholder);
        if (field.placeholder.length && ![translated isEqualToString:field.placeholder]) field.placeholder = translated;
    } else if ([view isKindOfClass:UITextView.class]) {
        UITextView *field = (UITextView *)view;
        if (!field.editable && !field.isFirstResponder && field.text.length) {
            NSString *translated = AGTranslate(field.text);
            if (![translated isEqualToString:field.text]) field.text = translated;
        }
    }
    for (UIView *child in view.subviews) {
        if (*remaining == 0) break;
        AGRefreshSettingsView(child, depth + 1, remaining);
    }
}
static void AGRefreshAyuPage(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded || !AGIsOnAyuPage()) return;
    NSString *name = NSStringFromClass(vc.class);
    if ([name rangeOfString:@"ItemList" options:NSCaseInsensitiveSearch].location == NSNotFound &&
        [name rangeOfString:@"Void" options:NSCaseInsensitiveSearch].location == NSNotFound &&
        [name rangeOfString:@"Ayu" options:NSCaseInsensitiveSearch].location == NSNotFound) return;
    NSString *translated = AGTranslate(vc.title);
    if (vc.title.length && ![translated isEqualToString:vc.title]) vc.title = translated;
    // Nested pages are built while the translation session is active; hooks
    // already translate their labels on creation. Traversing all subviews
    // again on each appearance can lock up gesture-heavy ItemList screens.
    // Only the root needs a one-time catch-up pass because it was constructed
    // before we detected the unique VoidGram intro text.
    if (objc_getAssociatedObject(vc, &AGRootMarker) ||
        objc_getAssociatedObject(vc, &AGChildMarker)) {
        // Revisit cached text exactly once per appearance, not during every
        // layout pass. This restores labels retained in English while the
        // scope had temporarily been inactive.
        NSUInteger remaining = 650; // cap cache-recovery work on gesture-heavy settings pages
        AGRefreshSettingsView(vc.view, 0, &remaining);
    }
}
// A stock Telegram screen always closes translation scope. The root can be
// reopened later by its unique intro text. Generic ItemListController pages
// are deliberately NOT treated as stock controllers here.
static BOOL AGIsStockTelegramPage(UIViewController *vc) {
    NSString *name = NSStringFromClass(vc.class);
    for (NSString *known in @[
        @"ChatController", @"ChatListController", @"SettingsController",
        @"AccountController", @"PeerInfoController", @"ContactsController",
        @"CallsController", @"GalleryController", @"PhotoViewerController"
    ]) {
        if ([name rangeOfString:known options:NSCaseInsensitiveSearch].location != NSNotFound)
            return YES;
    }
    return NO;
}

// ROOT-ONLY VISUAL FILTER
// The upstream VoidGram root renders LINKS and credits as independent Swift
// ItemList sections. No internal Telegram model, account preference, link or
// action is changed. Their item views are hidden and cannot receive touches.
// This must never run on category pages (Privacy, More, Tools, etc).
static __weak UIViewController *AGForegroundVoidController;
static NSTimer *AGRootFooterTimer;
static char AGHiddenFooterMarker;
static char AGPreviousFooterTouch;

static id AGCallObjectGetter(id obj, NSString *selector) {
    if (!obj) return nil;
    SEL sel = NSSelectorFromString(selector);
    if (![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static NSString *AGVisibleTextFromObject(id obj) {
    id value = AGCallObjectGetter(obj, @"attributedText");
    if ([value isKindOfClass:NSAttributedString.class]) return [value string];
    value = AGCallObjectGetter(obj, @"text");
    if ([value isKindOfClass:NSString.class]) return value;
    if ([obj isKindOfClass:UILabel.class]) return ((UILabel *)obj).text;
    return nil;
}

static BOOL AGIsRootFooterText(NSString *value) {
    if (!value.length || value.length > 120) return NO;
    NSString *label = [[AGNormalizedUILabel(value)
                        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                        lowercaseString];
    if (!label.length) return NO;
    static NSSet<NSString *> *removedLabels;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        removedLabels = [NSSet setWithArray:@[
            // Everything starting at LINKS, including the following credits.
            @"links", @"الروابط", @"acknowledgments", @"acknowledgements",
            @"credits", @"thanks", @"thanks & credits", @"شكر وتقدير",
            @"شكر وتقدير:", @"شكر وتقدير :", @"спасибо", @"ссылки",
            @"channel", @"القناة", @"source code", @"الرمز المصدري",
            @"official group", @"المجموعة الرسمية",
            @"repository owner", @"مالك المستودع",
            @"github", @"تليجرام", @"telegram",
            @"@neosay", @"@neosay1337", @"murk-sus",
            @"@asuka4scape_developer", @"neistv", @"@neistv",
            @"@murk-sus", @"@jailbreak_iphone", @"@jailbreak_iph"
        ]];
    });
    if ([removedLabels containsObject:label]) return YES;
    // Lower links/credits rows can show shortened handles or a full URI.
    if ([label hasPrefix:@"@neosay"] ||
        [label hasPrefix:@"@asuka4scape_"] ||
        [label hasPrefix:@"@jailbreak_iph"]) return YES;
    return NO;
}

static BOOL AGNodeContainsFooterText(id node, NSUInteger depth, NSUInteger *remaining) {
    if (!node || depth > 8 || !remaining || *remaining == 0) return NO;
    --(*remaining);
    if (AGIsRootFooterText(AGVisibleTextFromObject(node))) return YES;
    id children = AGCallObjectGetter(node, @"subnodes");
    if (![children isKindOfClass:NSArray.class]) return NO;
    for (id child in (NSArray *)children) {
        if (AGNodeContainsFooterText(child, depth + 1, remaining)) return YES;
    }
    return NO;
}

static id AGNodeForView(UIView *view) {
    return AGCallObjectGetter(view, @"asyncdisplaykit_node");
}

static UIView *AGFooterRowForTextView(UIView *textView, UIView *rootView) {
    UIView *candidate = nil;
    CGFloat width = CGRectGetWidth(rootView.bounds);
    for (UIView *v = textView; v && v != rootView; v = v.superview) {
        CGRect rect = [v convertRect:v.bounds toView:rootView];
        // ItemList cells are full-width rows. Never hide a whole group
        // containing upper feature entries or the navigation container.
        if (CGRectGetWidth(rect) >= width * 0.65 &&
            CGRectGetHeight(rect) >= 22 &&
            CGRectGetHeight(rect) <= 170) {
            candidate = v;
        }
    }
    return candidate;
}

static void AGCollectFooterRows(UIView *view, UIView *rootView,
                                NSMutableSet<UIView *> *hideRows,
                                NSMutableSet<UIView *> *oldHidden,
                                NSUInteger depth, NSUInteger *remaining) {
    if (!view || depth > 32 || !remaining || *remaining == 0) return;
    --(*remaining);
    if (objc_getAssociatedObject(view, &AGHiddenFooterMarker)) {
        [oldHidden addObject:view];
    }
    id node = AGNodeForView(view);
    if (node) {
        NSString *name = NSStringFromClass([node class]);
        // Prefer the actual ListView item node. This removes the icon, row
        // arrow, text, accessibility and tap surface together.
        if ([name containsString:@"ItemNode"] &&
            ([name containsString:@"ItemList"] || [name containsString:@"Ayu"])) {
            NSUInteger nodeLimit = 180;
            if (AGNodeContainsFooterText(node, 0, &nodeLimit)) {
                [hideRows addObject:view];
                return;
            }
        }
    }
    // Fallback for UILabel-backed variants of SettingsUI.
    if (AGIsRootFooterText(AGVisibleTextFromObject(view))) {
        UIView *item = AGFooterRowForTextView(view, rootView);
        if (item) [hideRows addObject:item];
    }
    for (UIView *child in view.subviews) {
        if (*remaining == 0) break;
        AGCollectFooterRows(child, rootView, hideRows, oldHidden,
                            depth + 1, remaining);
    }
}

static void AGHideLinksAndCreditsOnRoot(UIViewController *root) {
    if (!root || AGForegroundVoidController != root ||
        !objc_getAssociatedObject(root, &AGRootMarker) || !root.isViewLoaded ||
        !root.view.window) return;
    NSMutableSet<UIView *> *toHide = [NSMutableSet set];
    NSMutableSet<UIView *> *previous = [NSMutableSet set];
    NSUInteger remaining = 1500; // bounded and root-only: no app-wide polling
    AGCollectFooterRows(root.view, root.view, toHide, previous, 0, &remaining);
    for (UIView *item in previous) {
        if ([toHide containsObject:item]) continue;
        // ItemList may recycle a view for a feature row while scrolling.
        item.hidden = NO;
        NSNumber *touch = objc_getAssociatedObject(item, &AGPreviousFooterTouch);
        if (touch) item.userInteractionEnabled = touch.boolValue;
        objc_setAssociatedObject(item, &AGHiddenFooterMarker, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(item, &AGPreviousFooterTouch, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (UIView *item in toHide) {
        if (!objc_getAssociatedObject(item, &AGHiddenFooterMarker)) {
            objc_setAssociatedObject(item, &AGPreviousFooterTouch,
                                     @(item.userInteractionEnabled),
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        objc_setAssociatedObject(item, &AGHiddenFooterMarker, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        item.userInteractionEnabled = NO;
        item.hidden = YES;
        item.accessibilityElementsHidden = YES;
    }
}

static void AGMonitorRootFooter(UIViewController *root) {
    [AGRootFooterTimer invalidate];
    AGRootFooterTimer = nil;
    __weak UIViewController *weakRoot = root;
    AGRootFooterTimer = [NSTimer scheduledTimerWithTimeInterval:0.16 repeats:YES
        block:^(NSTimer *timer) {
            UIViewController *page = weakRoot;
            if (!page) {
                [timer invalidate];
                return;
            }
            if (AGForegroundVoidController != page) return;
            AGHideLinksAndCreditsOnRoot(page);
        }];
    // Hide immediately on root appearance, not only after a scroll tick.
    AGHideLinksAndCreditsOnRoot(root);
}

static IMP origAyuViewWillAppear = NULL;
static void AGAyuViewWillAppear(UIViewController *vc, SEL sel, BOOL animated) {
    // Telegram keeps its own ItemListControllers alive when the user returns
    // to a parent screen. Their text is often cached, so the intro string
    // is NOT constructed again. Recover from the controller marker instead.
    NSString *name = NSStringFromClass(vc.class);
    BOOL knownVoid = objc_getAssociatedObject(vc, &AGRootMarker) != nil ||
                     objc_getAssociatedObject(vc, &AGChildMarker) != nil;
    if (knownVoid) {
        atomic_store(&AGPendingAyuRoot, false);
        atomic_store(&AGInVoidStack, true);
    } else if (AGIsStockTelegramPage(vc)) {
        atomic_store(&AGInVoidStack, false);
        atomic_store(&AGPendingAyuRoot, false);
    } else if (atomic_load(&AGInVoidStack) &&
               [name rangeOfString:@"ItemListController"].location != NSNotFound) {
        // Tag every nested page individually. Reopening it restores scope
        // even after switching briefly to other Telegram screens.
        objc_setAssociatedObject(vc, &AGChildMarker, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (origAyuViewWillAppear)
        ((void (*)(id, SEL, BOOL))origAyuViewWillAppear)(vc, sel, animated);
}

static void AGAyuViewDidAppear(UIViewController *vc, SEL sel, BOOL animated) {
    if (origAyuViewDidAppear)
        ((void (*)(id, SEL, BOOL))origAyuViewDidAppear)(vc, sel, animated);
    NSString *name = NSStringFromClass(vc.class);
    if (AGIsStockTelegramPage(vc)) {
        AGForegroundVoidController = nil;
        atomic_store(&AGInVoidStack, false);
        atomic_store(&AGPendingAyuRoot, false);
        return;
    }
    if (atomic_load(&AGPendingAyuRoot) &&
        [name rangeOfString:@"ItemListController"].location != NSNotFound &&
        vc.isViewLoaded && vc.view.window) {
        objc_setAssociatedObject(vc, &AGRootMarker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        atomic_store(&AGPendingAyuRoot, false);
        atomic_store(&AGInVoidStack, true);
        NSLog(@"[VoidGramArabic] Located VoidGram settings root; nested stack localization enabled");
    }
    // Keep the scope from the marked root into EVERY nested ItemList page,
    // even when UIKit's navigationController is nil (Telegram custom stack).
    BOOL isScoped = AGControllerIsWithinMarkedRoot(vc) ||
                    objc_getAssociatedObject(vc, &AGChildMarker) != nil ||
                    atomic_load(&AGInVoidStack);
    if (isScoped) {
        atomic_store(&AGInVoidStack, true);
        AGForegroundVoidController = vc;
        if (objc_getAssociatedObject(vc, &AGRootMarker)) {
            AGMonitorRootFooter(vc);
        }
        // This ItemListController may be re-presented without rebuilding
        // the unique VoidGram intro or its previous strings.
        if ([name rangeOfString:@"ItemListController"].location != NSNotFound &&
            !objc_getAssociatedObject(vc, &AGRootMarker)) {
            objc_setAssociatedObject(vc, &AGChildMarker, @YES,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        __weak UIViewController *weakVC = vc;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *page = weakVC;
            if (page && (objc_getAssociatedObject(page, &AGRootMarker) ||
                         objc_getAssociatedObject(page, &AGChildMarker)))
                AGRefreshAyuPage(page);
        });
    }
}

__attribute__((constructor))
static void AGStart(void) {
    @autoreleasepool {
        // Context marker follows ONLY the anchored VoidGram ItemListController stack.
        AGHook(UIViewController.class, @selector(viewWillAppear:),
               (IMP)AGAyuViewWillAppear, &origAyuViewWillAppear);
        AGHook(UIViewController.class, @selector(viewDidAppear:),
               (IMP)AGAyuViewDidAppear, &origAyuViewDidAppear);
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
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"VoidGramArabicDiagnostics"]) {
            AGInstallDiagnostics();
        }
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
