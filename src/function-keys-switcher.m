#import <Cocoa/Cocoa.h>

#define VERSION @"1.0.0"

static NSArray<NSString *> *fnBundleIDs;
static BOOL lastFnState;
static BOOL stateInitialized = NO;

static NSString * const activateSettings =
    @"/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings";

static NSString *configPath(void)
{
    return [NSHomeDirectory()
        stringByAppendingPathComponent:
        @"Library/Application Support/FunctionKeysSwitcher/apps.conf"];
}

static void loadConfiguration(void)
{
    NSError *error = nil;

    NSString *content =
        [NSString stringWithContentsOfFile:configPath()
                                 encoding:NSUTF8StringEncoding
                                    error:&error];

    if (!content) {
        NSLog(@"Could not read configuration: %@", error.localizedDescription);
        fnBundleIDs = @[];
        return;
    }

    NSMutableArray<NSString *> *bundleIDs =
        [NSMutableArray array];

    [content enumerateLinesUsingBlock:
        ^(NSString *line, BOOL *stop) {

        NSString *trimmed =
            [line stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (trimmed.length == 0)
            return;

        if ([trimmed hasPrefix:@"#"])
            return;

        [bundleIDs addObject:trimmed];
    }];

    fnBundleIDs = [bundleIDs copy];

    NSLog(@"Loaded %lu configured application(s)",
          (unsigned long)fnBundleIDs.count);
}

static void setFunctionKeys(BOOL enabled)
{
    if (stateInitialized && enabled == lastFnState)
        return;

    NSTask *defaultsTask = [[NSTask alloc] init];

    defaultsTask.launchPath = @"/usr/bin/defaults";

    defaultsTask.arguments = @[
        @"write",
        @"-g",
        @"com.apple.keyboard.fnState",
        @"-bool",
        enabled ? @"true" : @"false"
    ];

    [defaultsTask launch];
    [defaultsTask waitUntilExit];

    NSTask *activateTask = [[NSTask alloc] init];

    activateTask.launchPath = activateSettings;
    activateTask.arguments = @[@"-u"];

    [activateTask launch];
    [activateTask waitUntilExit];

    lastFnState = enabled;
    stateInitialized = YES;

    NSLog(@"Function keys: %@",
          enabled ? @"F1-F12" : @"Media keys");
}

static void handleApplication(NSRunningApplication *app)
{
    if (!app)
        return;

    NSString *name =
        app.localizedName ?: @"(unknown)";

    NSString *bundleID =
        app.bundleIdentifier;

    NSLog(@"Active application: %@ | Bundle ID: %@",
          name,
          bundleID ?: @"(none)");

    BOOL useFunctionKeys =
        bundleID &&
        [fnBundleIDs containsObject:bundleID];

    setFunctionKeys(useFunctionKeys);
}

static void printUsage(void)
{
    printf(
        "FunctionKeysSwitcher %s\n\n"
        "Usage:\n"
        "  function-keys-switcher\n"
        "  function-keys-switcher --version\n"
        "  function-keys-switcher --list\n\n",
        [VERSION UTF8String]
    );
}

int main(int argc, const char * argv[])
{
    @autoreleasepool {

        if (argc > 1) {

            NSString *argument =
                [NSString stringWithUTF8String:argv[1]];

            if ([argument isEqualToString:@"--version"]) {
                printf("FunctionKeysSwitcher %s\n",
                       [VERSION UTF8String]);
                return 0;
            }

            if ([argument isEqualToString:@"--list"]) {

                loadConfiguration();

                for (NSString *bundleID in fnBundleIDs)
                    printf("%s\n", bundleID.UTF8String);

                return 0;
            }

            printUsage();
            return 1;
        }

        loadConfiguration();

        NSWorkspace *workspace =
            [NSWorkspace sharedWorkspace];

        handleApplication(
            workspace.frontmostApplication
        );

        [[workspace notificationCenter]
            addObserverForName:
                NSWorkspaceDidActivateApplicationNotification
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *note) {

                NSRunningApplication *app =
                    note.userInfo[
                        NSWorkspaceApplicationKey
                    ];

                handleApplication(app);
            }];

        [[NSRunLoop mainRunLoop] run];
    }

    return 0;
}