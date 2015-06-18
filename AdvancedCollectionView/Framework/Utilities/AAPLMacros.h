//
//  AAPLMacros.h
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 6/14/15.
//  Copyright © 2015 Apple. All rights reserved.
//

#pragma once

@import Foundation.NSObjCRuntime;

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#define AAPL_FORCE_DOWNCAST(obj__, class__) ({ \
    NSAssert([obj__ isKindOfClass:[class__ self]], @"" #obj__ " not an instance of " #class__ "."); \
    (class__ *)obj__; \
})

#if __has_feature(objc_generics)

#define AAPLGeneric(CLASS_NAME, ...) CLASS_NAME<__VA_ARGS__>
#define AAPLKindOf(...) __kindof __VA_ARGS__
#define AAPLGenericType(...) __VA_ARGS__

#else

#define AAPLGeneric(CLASS_NAME, ...) CLASS_NAME
#define AAPLKindOf(...) id
#define AAPLGenericType(TYPE_NAME) id

#endif
