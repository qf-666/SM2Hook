/**
 * SM2 加密参数拦截器 - Tweak.x
 * 
 * Hook GMSm2Utils 的 +encryptText:publicKey: 方法，
 * 在加密前后截获明文、公钥、密文，并显示在悬浮窗中。
 */

#import <UIKit/UIKit.h>

// ============================================================
// MARK: - 悬浮窗视图 (SM2FloatingWindow)
// ============================================================

@interface SM2FloatingWindow : UIWindow
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *clipboardButton;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, assign) BOOL isCollapsed;
@property (nonatomic, assign) CGRect expandedFrame;
+ (instancetype)sharedInstance;
- (void)appendLog:(NSString *)text;
@end

static SM2FloatingWindow *SM2SharedWindow = nil;
static void SM2EnsureFloatingWindowVisible(void);

@implementation SM2FloatingWindow

+ (UIWindowScene *)activeWindowScene API_AVAILABLE(ios(13.0)) {
    NSSet *connectedScenes = [UIApplication sharedApplication].connectedScenes;

    for (UIScene *scene in connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        if (scene.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)scene;
        }
    }

    for (UIScene *scene in connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        if (scene.activationState == UISceneActivationStateForegroundInactive) {
            return (UIWindowScene *)scene;
        }
    }

    return nil;
}

+ (instancetype)sharedInstance {
    @synchronized(self) {
        if (SM2SharedWindow) {
            return SM2SharedWindow;
        }

        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        CGFloat windowWidth = screenWidth - 40;
        CGFloat windowHeight = screenHeight * 0.45;
        CGRect frame = CGRectMake(20, 80, windowWidth, windowHeight);

        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = [self activeWindowScene];
            if (!scene) {
                NSLog(@"[SM2Hook] 暂无可用 UIWindowScene，延后初始化悬浮窗。");
                return nil;
            }

            SM2SharedWindow = [[SM2FloatingWindow alloc] initWithWindowScene:scene];
            SM2SharedWindow.frame = frame;
        } else {
            SM2SharedWindow = [[SM2FloatingWindow alloc] initWithFrame:frame];
        }

        SM2SharedWindow.expandedFrame = frame;
        SM2SharedWindow.windowLevel = UIWindowLevelAlert + 1;
        SM2SharedWindow.backgroundColor = [UIColor clearColor];
        SM2SharedWindow.clipsToBounds = YES;
        SM2SharedWindow.layer.cornerRadius = 16;
        SM2SharedWindow.isCollapsed = NO;
        
        [SM2SharedWindow setupUI];
        [SM2SharedWindow makeKeyAndVisible];
    }
    return SM2SharedWindow;
}

- (void)setupUI {
    // 毛玻璃背景
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:blurView];
    
    // 头部栏
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 44)];
    self.headerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview:self.headerView];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 200, 44)];
    titleLabel.text = @"🔐 SM2 Monitor";
    titleLabel.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.7 alpha:1.0];
    titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.headerView addSubview:titleLabel];
    
    // 折叠/展开按钮
    self.toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.toggleButton.frame = CGRectMake(self.bounds.size.width - 44, 0, 44, 44);
    self.toggleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.toggleButton setTitle:@"▼" forState:UIControlStateNormal];
    [self.toggleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.toggleButton addTarget:self action:@selector(toggleCollapse) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.toggleButton];
    
    // 复制按钮
    self.clipboardButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clipboardButton.frame = CGRectMake(self.bounds.size.width - 88, 0, 44, 44);
    self.clipboardButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.clipboardButton setTitle:@"📋" forState:UIControlStateNormal];
    [self.clipboardButton addTarget:self action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.clipboardButton];
    
    // 清除按钮
    self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearButton.frame = CGRectMake(self.bounds.size.width - 132, 0, 44, 44);
    self.clearButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.clearButton setTitle:@"🗑" forState:UIControlStateNormal];
    [self.clearButton addTarget:self action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.clearButton];
    
    // 日志文本视图
    self.logTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, 44, self.bounds.size.width, self.bounds.size.height - 44)];
    self.logTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.logTextView.backgroundColor = [UIColor clearColor];
    self.logTextView.textColor = [UIColor colorWithRed:0.85 green:0.95 blue:0.85 alpha:1.0];
    self.logTextView.font = [UIFont fontWithName:@"Menlo" size:11];
    self.logTextView.editable = NO;
    self.logTextView.selectable = YES;
    self.logTextView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.logTextView.text = @"[SM2 Monitor] 等待 SM2 加密调用...\n";
    [self addSubview:self.logTextView];
    
    // 拖拽手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.headerView addGestureRecognizer:pan];
}

- (void)toggleCollapse {
    self.isCollapsed = !self.isCollapsed;
    
    [UIView animateWithDuration:0.3 animations:^{
        if (self.isCollapsed) {
            self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.expandedFrame.size.width, 44);
            self.logTextView.alpha = 0;
            [self.toggleButton setTitle:@"▲" forState:UIControlStateNormal];
        } else {
            self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.expandedFrame.size.width, self.expandedFrame.size.height);
            self.logTextView.alpha = 1;
            [self.toggleButton setTitle:@"▼" forState:UIControlStateNormal];
        }
    }];
}

- (void)copyLogs {
    [UIPasteboard generalPasteboard].string = self.logTextView.text;
    
    // 简短的复制成功提示
    UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 30)];
    toast.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    toast.text = @"✅ 已复制";
    toast.textColor = [UIColor whiteColor];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont boldSystemFontOfSize:14];
    toast.layer.cornerRadius = 8;
    toast.clipsToBounds = YES;
    [self addSubview:toast];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            toast.alpha = 0;
        } completion:^(BOOL finished) {
            [toast removeFromSuperview];
        }];
    });
}

- (void)clearLogs {
    self.logTextView.text = @"[SM2 Monitor] 日志已清除，等待新的 SM2 加密调用...\n";
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.superview];
}

- (void)appendLog:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *timestamp = [self currentTimestamp];
        NSString *entry = [NSString stringWithFormat:@"[%@]\n%@\n", timestamp, text];
        self.logTextView.text = [self.logTextView.text stringByAppendingString:entry];
        
        // 自动滚动到底部
        NSRange range = NSMakeRange(self.logTextView.text.length - 1, 1);
        [self.logTextView scrollRangeToVisible:range];
        
        // 展开窗口（如果处于折叠状态）
        if (self.isCollapsed) {
            [self toggleCollapse];
        }
    });
}

- (NSString *)currentTimestamp {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss.SSS";
    return [fmt stringFromDate:[NSDate date]];
}

// 让触摸事件能穿透到下层（仅当触摸点不在悬浮窗上时）
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *subview in self.subviews) {
        if ([subview hitTest:[self convertPoint:point toView:subview] withEvent:event]) {
            return YES;
        }
    }
    return NO;
}

@end

static void SM2EnsureFloatingWindowVisible(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        SM2FloatingWindow *window = [SM2FloatingWindow sharedInstance];
        if (window) {
            NSLog(@"[SM2Hook] 悬浮窗已就绪，等待 SM2 加密调用。");
        }
    });
}

// ============================================================
// MARK: - Hook 逻辑
// ============================================================

%hook GMSm2Utils

+ (id)encryptText:(id)text publicKey:(id)pubKey {
    // ---- 加密前：截获入参 ----
    NSString *plainText = @"(nil)";
    NSString *publicKey = @"(nil)";
    
    if (text && [text isKindOfClass:[NSString class]]) {
        plainText = (NSString *)text;
    } else if (text) {
        plainText = [NSString stringWithFormat:@"%@", text];
    }
    
    if (pubKey && [pubKey isKindOfClass:[NSString class]]) {
        publicKey = (NSString *)pubKey;
    } else if (pubKey) {
        publicKey = [NSString stringWithFormat:@"%@", pubKey];
    }
    
    NSLog(@"[SM2Hook] ===== SM2 加密调用 =====");
    NSLog(@"[SM2Hook] 明文: %@", plainText);
    NSLog(@"[SM2Hook] 公钥: %@", publicKey);
    
    // ---- 调用原始方法 ----
    id result = %orig;
    
    // ---- 加密后：截获密文 ----
    NSString *cipherText = @"(nil)";
    if (result && [result isKindOfClass:[NSString class]]) {
        cipherText = (NSString *)result;
    } else if (result) {
        cipherText = [NSString stringWithFormat:@"%@", result];
    }
    
    NSLog(@"[SM2Hook] 密文: %@", cipherText);
    NSLog(@"[SM2Hook] ========================");
    
    // ---- 组装日志并推送到悬浮窗 ----
    NSString *logEntry = [NSString stringWithFormat:
        @"━━━ SM2 加密捕获 ━━━\n"
        @"📝 明文: %@\n"
        @"🔑 公钥: %@\n"
        @"🔒 密文: %@\n"
        @"━━━━━━━━━━━━━━━━━━━\n",
        plainText, publicKey, cipherText];
    
    [[SM2FloatingWindow sharedInstance] appendLog:logEntry];
    
    return result;
}

%end

// ============================================================
// MARK: - 构造器（App 启动时自动注入悬浮窗）
// ============================================================

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[SM2Hook] 悬浮窗初始化...");
        SM2EnsureFloatingWindowVisible();

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
            SM2EnsureFloatingWindowVisible();
        }];
    });
}
