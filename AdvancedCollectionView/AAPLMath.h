//
//  Header.h
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/13/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

#ifndef AdvancedCollectionView_Math_h
#define AdvancedCollectionView_Math_h

@import Darwin.C.math;

#if __has_extension(c_generic_selections)
#define __tg_typeof(x)    _Generic(x, default: 0, float: 0)
#define __tg_fn(x, y, fn) _Generic(__tg_typeof(x) + __tg_typeof(y), default: fn, float: fn##f)
#else
#error "Type generic math not implemented for this compiler"
#endif

#define fabs(x)    __tg_fn(x, x, fabs)(x)
#define fmin(x, y) __tg_fn(x, y, fmin)(x, y)
#define fmax(x, y) __tg_fn(x, y, fmax)(x, y)
#define floor(x)   __tg_fn(x, x, floor)(x)
#define rint(x)    __tg_fn(x, x, rint)(x)
#define round(x)   __tg_fn(x, x, round)(x)
#define ceil(x)    __tg_fn(x, x, ceil)(x)

NS_INLINE BOOL _approxeqf(float a, float b) { return fabs(a - b) < FLT_EPSILON; }
NS_INLINE BOOL _approxeq(double a, double b) { return fabs(a - b) < DBL_EPSILON; }
#define _approxeq(x, y) __tg_fn(x, y, _approxeq)(x, y)

NS_INLINE UIEdgeInsets AAPLInsetsWithout(UIEdgeInsets insets, UIRectEdge edge) {
    UIEdgeInsets ret = insets;
    if (edge & UIRectEdgeTop) { ret.top = 0; }
    if (edge & UIRectEdgeLeft) { ret.left = 0; }
    if (edge & UIRectEdgeBottom) { ret.bottom = 0; }
    if (edge & UIRectEdgeRight) { ret.right = 0; }
    return ret;
}

NS_INLINE CGRect AAPLSeparatorRect(CGRect frame, CGRectEdge edge, CGFloat width) {
    switch (edge) {
        case CGRectMinXEdge: return CGRectMake(CGRectGetMinX(frame), CGRectGetMinY(frame), width, CGRectGetHeight(frame));
        case CGRectMinYEdge: return CGRectMake(CGRectGetMinX(frame), CGRectGetMinY(frame), CGRectGetWidth(frame), width);
        case CGRectMaxXEdge: return CGRectMake(CGRectGetMaxX(frame) - width, CGRectGetMinY(frame), width, CGRectGetHeight(frame));
        case CGRectMaxYEdge: return CGRectMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - width, CGRectGetWidth(frame), width);
    }
    return frame;
}

#endif /* !AdvancedCollectionView_Math_h */
