/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Helper functions for debugging.
 */

@import Foundation;

#import "AAPLDebug.h"

NSString *AAPLStringFromBOOL(BOOL value)
{
    return value ? @"YES" : @"NO";
}

NSString *AAPLStringFromNSIndexPath(NSIndexPath *indexPath)
{
    NSMutableArray *indexes = [NSMutableArray array];
    NSUInteger numberOfIndexes = indexPath.length;

    for (NSUInteger currentIndex = 0; currentIndex < numberOfIndexes; ++ currentIndex)
        [indexes addObject:@([indexPath indexAtPosition:currentIndex])];

    return [NSString stringWithFormat:@"(%@)", [indexes componentsJoinedByString:@", "]];
}

NSString *AAPLStringFromNSIndexSet(NSIndexSet *indexSet)
{
    NSMutableArray *result = [NSMutableArray array];

    [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
        switch (range.length) {
            case 0:
                [result addObject:@"empty"];
                break;
            case 1:
                [result addObject:[NSString stringWithFormat:@"%ld", (unsigned long)range.location]];
                break;
            default:
                [result addObject:[NSString stringWithFormat:@"%ld..%lu", (unsigned long)range.location, (unsigned long)(range.location + range.length - 1)]];
                break;
        }
    }];

    return [NSString stringWithFormat:@"(%@)", [result componentsJoinedByString:@", "]];
}
