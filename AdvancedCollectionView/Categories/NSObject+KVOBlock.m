/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Category to add block based Key Value Observation methods to NSObject. Added support for removing the observer from the observation block, to allow for one-shot observers (it's safe to invoke appl_removeObserver from the block).
  
 */

#import "NSObject+KVOBlock.h"
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

static void * const AAPLObserverMapKey = @"com.example.apple-samplecode.blockObserverMap";
static dispatch_queue_t AAPLObserverMutationQueue = NULL;

static dispatch_queue_t AAPLObserverMutationQueueCreatingIfNecessary()
{
    static dispatch_once_t queueCreationPredicate = 0;
    dispatch_once(&queueCreationPredicate, ^{
        AAPLObserverMutationQueue = dispatch_queue_create("com.example.apple-samplecode.observerMutationQueue", 0);
    });
    return AAPLObserverMutationQueue;
}



@interface AAPLObserverTrampoline : NSObject
{
    __weak id _observee; // the trampoline is stored via associated object on
    NSString *_keyPath;
    AAPLBlockObserver _block;
    volatile int32_t _cancellationPredicate;
    NSKeyValueObservingOptions _options;
}

@property (readonly) id token;

- (AAPLObserverTrampoline *)initObservingObject:(id)obj keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(AAPLBlockObserver)block;

- (void)startObserving;

- (void)cancelObservation;
@end

@implementation AAPLObserverTrampoline

static void * const AAPLObserverTrampolineContext = @"AAPLObserverTrampolineContext";

- (void)dealloc
{
    [self cancelObservation];
}

- (AAPLObserverTrampoline *)initObservingObject:(id)obj keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(AAPLBlockObserver)block
{
    self = [super init];
    if (!self)
        return nil;

    _block = [block copy];
    _keyPath = [keyPath copy];
    _options = options;
    _observee = obj;
    return self;
}

- (void)startObserving
{
    [_observee addObserver:self forKeyPath:_keyPath options:_options context:AAPLObserverTrampolineContext];
}

- (id)token
{
    return [NSValue valueWithPointer:&_block];
}

- (void)observeValueForKeyPath:(NSString *)aKeyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == AAPLObserverTrampolineContext && !_cancellationPredicate) {
        _block(object, change, self.token);
    }
}

- (void)cancelObservation
{
    if (OSAtomicCompareAndSwap32(0, 1, &_cancellationPredicate)) {

        // Make sure we don't remove ourself before addObserver: completes
        if (_options & NSKeyValueObservingOptionInitial) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_observee removeObserver:self forKeyPath:_keyPath];
                _observee = nil;
            });
        }
        else {
            [_observee removeObserver:self forKeyPath:_keyPath];
            _observee = nil;
        }
    }
}

@end



@implementation NSObject (KVOBlock)

- (id)aapl_addObserverForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options withBlock:(AAPLBlockObserver)block
{
    __block id token = nil;

    __block AAPLObserverTrampoline *trampoline = nil;

    dispatch_sync(AAPLObserverMutationQueueCreatingIfNecessary(), ^{
        NSMutableDictionary *dict = objc_getAssociatedObject(self, AAPLObserverMapKey);
        if (!dict) {
            dict = [[NSMutableDictionary alloc] init];
            objc_setAssociatedObject(self, AAPLObserverMapKey, dict, OBJC_ASSOCIATION_RETAIN);
        }
        trampoline = [[AAPLObserverTrampoline alloc] initObservingObject:self keyPath:keyPath options:(NSKeyValueObservingOptions)options block:block];
        token = trampoline.token;
        dict[token] = trampoline;
    });

    // To avoid deadlocks when using appl_removeObserverWithBlockToken from within the dispatch_sync (for a one-shot with NSKeyValueObservingOptionInitial), start observing outside of the sync.
    [trampoline startObserving];
    return token;
}

- (void)aapl_removeObserver:(id)token
{
    dispatch_sync(AAPLObserverMutationQueueCreatingIfNecessary(), ^{
        NSMutableDictionary *observationDictionary = objc_getAssociatedObject(self, AAPLObserverMapKey);
        AAPLObserverTrampoline *trampoline = observationDictionary[token];
        if (!trampoline) {
            NSLog(@"Ignoring attempt to remove non-existent observer on %@ for token %@.", self, token);
            return;
        }
        [trampoline cancelObservation];
        [observationDictionary removeObjectForKey:token];

        // Due to a bug in the obj-c runtime, this dictionary does not get cleaned up on release when running without GC. (FWIW, I believe this was fixed in Snow Leopard.)
        if ([observationDictionary count] == 0)
            objc_setAssociatedObject(self, AAPLObserverMapKey, nil, OBJC_ASSOCIATION_RETAIN);
    });
}

@end
