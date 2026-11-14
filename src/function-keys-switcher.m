#import <Cocoa/Cocoa.h>

#define VERSION @"1.0.1"

static NSArray<NSString *> *fnBundleIDs;
static BOOL lastFnState;
static BOOL stateInitialized = NO;
static BOOL switching = NO;
static BOOL requestedFnState;

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

static BOOL runTask(NSString *path, NSArray<NSString *> *arguments)
{
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:path];
    task.arguments = arguments;
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        NSLog(@"Could not launch %@: %@", path, error.localizedDescription);
        return NO;
    }
    [task waitUntilExit];
    if (task.terminationStatus != 0) {
        NSLog(@"%@ failed with exit status %d", path, task.terminationStatus);
        return NO;
    }
    return YES;
}

static void setFunctionKeys(BOOL enabled)
{
    // waitUntilExit can run the main run loop and deliver another activation.
    // Keep its latest request, but never nest two settings updates.
    requestedFnState = enabled;
    if (switching)
        return;

    switching = YES;
    while (!stateInitialized || requestedFnState != lastFnState) {
        BOOL target = requestedFnState;
        BOOL succeeded = runTask(@"/usr/bin/defaults", @[
            @"write", @"-g", @"com.apple.keyboard.fnState", @"-bool",
            target ? @"true" : @"false"
        ]) && runTask(activateSettings, @[@"-u"]);

        if (!succeeded) {
            stateInitialized = NO;
            break;
        }
        lastFnState = target;
        stateInitialized = YES;
        NSLog(@"Function keys: %@", target ? @"F1-F12" : @"Media keys");
    }
    switching = NO;
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