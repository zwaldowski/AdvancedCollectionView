//
//  AAPLMacros.h
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 6/14/15.
//  Copyright © 2015 Apple. All rights reserved.
//

#pragma once

@import Foundation.NSObjCRuntime;

#define AAPL_FORCE_DOWNCAST(obj__, class__) ({ \
    NSAssert([obj__ isKindOfClass:[class__ self]], @"" #obj__ " not an instance of " #class__ "."); \
    (class__ *)obj__; \
})
