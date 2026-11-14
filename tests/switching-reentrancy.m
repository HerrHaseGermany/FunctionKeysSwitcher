// Run without changing keyboard settings:
// clang -fobjc-arc -fblocks -framework Cocoa tests/switching-reentrancy.m -o /tmp/fks-test && /tmp/fks-test
#define main switcherMain
#import "../src/function-keys-switcher.m"
#undef main
#import <objc/runtime.h>
#include <assert.h>

static NSMutableArray<NSString *> *writes;
static BOOL interruptUpdate;
static BOOL failTask;

@interface NSTask (TestTasks)
- (BOOL)testLaunch:(NSError **)error;
- (void)testWait;
- (int)testStatus;
@end
@implementation NSTask (TestTasks)
- (BOOL)testLaunch:(NSError **)error {
    if ([self.executableURL.path isEqualToString:@"/usr/bin/defaults"])
        [writes addObject:self.arguments.lastObject];
    return YES;
}
- (void)testWait {
    if (interruptUpdate) {
        interruptUpdate = NO;
        setFunctionKeys(YES);
    }
}
- (int)testStatus { return failTask ? 1 : 0; }
@end

int main(void) {
    @autoreleasepool {
        Class taskClass = [[[NSTask alloc] init] class];
        SEL originals[] = {@selector(launchAndReturnError:), @selector(waitUntilExit), @selector(terminationStatus)};
        SEL replacements[] = {@selector(testLaunch:), @selector(testWait), @selector(testStatus)};
        for (int i = 0; i < 3; i++) {
            Method replacement = class_getInstanceMethod(NSTask.class, replacements[i]);
            class_replaceMethod(taskClass, originals[i], method_getImplementation(replacement), method_getTypeEncoding(replacement));
        }
        writes = [NSMutableArray array];
        setFunctionKeys(YES);
        [writes removeAllObjects];
        interruptUpdate = YES;
        setFunctionKeys(NO);
        assert(([writes isEqualToArray:@[@"false", @"true"]]));
        assert(stateInitialized && lastFnState && !switching);
        setFunctionKeys(YES);
        assert(writes.count == 2);
        failTask = YES;
        setFunctionKeys(NO);
        assert(!stateInitialized && !switching);
        failTask = NO;
        setFunctionKeys(NO);
        assert(stateInitialized && !lastFnState && !switching);
        puts("PASS: overlapping activations, unchanged state, and failed-task retry");
    }
}
