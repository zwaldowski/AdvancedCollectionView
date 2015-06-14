/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Support for common stylistic elements in an application.
 */

#import "AAPLTheme.h"

@implementation AAPLTheme
static Class AAPLThemeClass = nil;
static AAPLTheme *theme = nil;

+ (instancetype)theme
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!AAPLThemeClass)
            AAPLThemeClass = [AAPLTheme class];
        theme = [[AAPLThemeClass alloc] init];
    });

    return theme;
}

+ (void)setThemeClass:(Class)themeClass
{
    NSParameterAssert(themeClass != nil);
    NSAssert(theme == nil, @"Theme has already been created. Setting a class will not work now.");
    AAPLThemeClass = themeClass;
}

- (UIColor *)lightGreyBackgroundColor
{
    return [UIColor colorWithWhite:248/255.0 alpha:1];
}

- (UIColor *)greyBackgroundColor
{
    return [UIColor colorWithWhite:235/255.0 alpha:1];
}

- (UIColor *)darkGreyBackgroundColor
{
    return [UIColor colorWithWhite:199/255.0 alpha:1];
}

- (UIColor *)backgroundColor
{
    return [UIColor whiteColor];
}

- (UIColor *)separatorColor
{
    return [UIColor colorWithWhite:204/255.0 alpha:1];
}

- (UIColor *)selectedBackgroundColor
{
    return [UIColor colorWithWhite:235/255.0 alpha:1];
}

- (UIFont *)sectionHeaderFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
}

- (UIFont *)sectionHeaderSmallFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
}

- (UIFont *)actionButtonFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
}

- (UIFont *)cellActionButtonFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
}

- (UIFont *)bodyFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
}

- (UIFont *)smallBodyFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
}

- (UIFont *)largeBodyFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
}

- (UIFont *)listBodyFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
}

- (UIFont *)listDetailFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
}

- (UIFont *)listSmallFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
}

- (UIFont *)headerBodyFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
}

- (UIFont *)headerTitleFont
{
    return [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
}

- (UIColor *)destructiveActionColor
{
    return [UIColor colorWithRed:1.000 green:0.231 blue:0.188 alpha:1.000];
}

- (NSArray *)alternateActionColors
{
    return @[[UIColor colorWithRed:1.000 green:0.584 blue:0.000 alpha:1.000], [UIColor colorWithWhite:199/255.0 alpha:1]];
}

- (UIColor *)cellActionBackgroundColor
{
    return [UIColor colorWithWhite:235/255.0 alpha:1];
}

- (UIColor *)mediumGreyTextColor
{
    return [UIColor colorWithWhite:116/255.0 alpha:1];
}

- (UIColor *)lightGreyTextColor
{
    return [UIColor colorWithWhite:172/255.0 alpha:1];
}

- (UIColor *)darkGreyTextColor
{
    return [UIColor colorWithWhite:77/255.0 alpha:1];
}

- (UIEdgeInsets)listLayoutMargins
{
    return UIEdgeInsetsMake(8, 15, 8, 15);
}

- (UIEdgeInsets)sectionHeaderLayoutMargins
{
    return UIEdgeInsetsMake(5, 15, 5, 15);
}

@end
