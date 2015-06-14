/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A data source showing textual items.
 */

#import "AAPLKeyValueDataSource.h"

NS_ASSUME_NONNULL_BEGIN




/**
 A subclass of AAPLKeyValueDataSource displaying large blocks of text where the title of the key value item is displayed in the style of a section header above the text.

 @note The text value data source only permits AAPLKeyValueItems with itemType values of AAPLKeyValueItemTypeDefault.
 */
@interface AAPLTextValueDataSource<SourceType : id> : AAPLKeyValueDataSource<SourceType>
@end




NS_ASSUME_NONNULL_END
