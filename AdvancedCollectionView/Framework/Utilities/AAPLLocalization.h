/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Basic localized strings defined as macros. These are strings the collection view code will try to use and should be available in the application.
 */

static inline NSString *AAPLLocalizedStringWithDefaultValue(NSString *key, NSString *tableName, NSBundle *bundle, NSString *value, NSString *comment)
{
    if (!bundle)
        bundle = [NSBundle mainBundle];
    return [bundle localizedStringForKey:key value:value table:tableName];
}


#define AAPL_LOC_MORE_EDIT_BUTTON AAPLLocalizedStringWithDefaultValue(@"MORE_EDIT_BUTTON", nil, nil, @"More", @"Text for the more button in cell's edit actions")
#define AAPL_LOC_CANCEL_BUTTON AAPLLocalizedStringWithDefaultValue(@"CANCEL_BUTTON", nil, nil, @"Cancel", @"Text used on cancel buttons")
