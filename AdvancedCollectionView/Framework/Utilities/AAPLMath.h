//
//  AAPLMath.h
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 6/14/15.
//  Copyright © 2015 Apple. All rights reserved.
//

#pragma once

@import Foundation.NSObjCRuntime;
@import Darwin.C.math;

#if __has_extension(c_generic_selections)
#define aapl_tg_typeof__(x)    _Generic(x, default: 0, float: 0)
#define aapl_tg_fn__(x, y, fn) _Generic(aapl_tg_typeof__(x) + aapl_tg_typeof__(y), default: fn, float: fn##f)
#else
#error "Type generic math not implemented for this compiler"
#endif

#define fabs(x)    aapl_tg_fn__(x, x, fabs)(x)
#define fmin(x, y) aapl_tg_fn__(x, y, fmin)(x, y)
#define fmax(x, y) aapl_tg_fn__(x, y, fmax)(x, y)
#define floor(x)   aapl_tg_fn__(x, x, floor)(x)
#define rint(x)    aapl_tg_fn__(x, x, rint)(x)
#define round(x)   aapl_tg_fn__(x, x, round)(x)
#define ceil(x)    aapl_tg_fn__(x, x, ceil)(x)
#define log10f(x)  aapl_tg_fn__(x, x, log10)(x)

NS_INLINE BOOL _approxeqf(float a, float b) { return fabs(a - b) < FLT_EPSILON; }
NS_INLINE BOOL _approxeq(double a, double b) { return fabs(a - b) < DBL_EPSILON; }
#define _approxeq(x, y) __tg_fn(x, y, _approxeq)(x, y)
