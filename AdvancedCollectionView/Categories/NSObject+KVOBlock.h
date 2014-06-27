/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  Category to add block based Key Value Observation methods to NSObject. Added support for removing the observer from the observation block, to allow for one-shot observers (it's safe to invoke appl_removeObserver from the block).
  
 */

#import <Foundation/Foundation.h>

typedef void (^AAPLBlockObserver)(id obj, NSDictionary *change, id observer);

@interface NSObject (KVOBlock)

/// Add a block-based observer. Returns a token for use with removeObserverWithBlockToken:.
- (id)aapl_addObserverForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options withBlock:(AAPLBlockObserver)block;

/// Remove block-based observer
- (void)aapl_removeObserver:(id)observer;

@end
