/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Support for common stylistic elements in an application.
 */

@import UIKit;

NS_ASSUME_NONNULL_BEGIN




/**
 A class defining common stylistic elements for an application. This based class is intended to be subclassed and customised for individual applications.
 */
@interface AAPLTheme : NSObject

/// A theme singleton.
+ (AAPLTheme *)theme;

/// Because many bits of code simply grab an instance of the AAPLTheme singleton, it's useful to be able to specify what class that singleton should be.
+ (void)setThemeClass:(Class)themeClass;

/// The standard font for section headers. Somewhat large. May be used in cells or elsewhere if you want a font that is the same as the section header font.
@property (readonly, nonatomic) UIFont *sectionHeaderFont;
/// The small font for section headers. This is used for the small text in the right label on the standard AAPLSectionHeaderView.
@property (readonly, nonatomic) UIFont *sectionHeaderSmallFont;

/// The large font used in the global header.
@property (readonly, nonatomic) UIFont *headerTitleFont;
/// The smaller font used in the global header.
@property (readonly, nonatomic) UIFont *headerBodyFont;

/// The font used in action cells as used in the AAPLActionDataSource.
@property (readonly, nonatomic) UIFont *actionButtonFont;
/// The font used in the swipe to edit buttons within AAPLCollectionViewCells.
@property (readonly, nonatomic) UIFont *cellActionButtonFont;
/// The font used for body text in AAPLKeyValueCell and AAPLTextValueCell instances.
@property (readonly, nonatomic) UIFont *bodyFont;
/// A smaller body font.
@property (readonly, nonatomic) UIFont *smallBodyFont;
/// A larger body font.
@property (readonly, nonatomic) UIFont *largeBodyFont;

/// A medium sized font for use in list items.
@property (readonly, nonatomic) UIFont *listBodyFont;
/// A smaller body font for use in list items.
@property (readonly, nonatomic) UIFont *listDetailFont;
/// A smaller font for use in list items.
@property (readonly, nonatomic) UIFont *listSmallFont;

/// Standard list item layout margins (default is 15pt on leading and trailing, 0 on top & bottom)
@property (readonly, nonatomic) UIEdgeInsets listLayoutMargins;
/// The layout margins for section headers. This may be overridden for individual headers. (default is 15pt on leading and trailing, 5pt on top & bottom)
@property (readonly, nonatomic) UIEdgeInsets sectionHeaderLayoutMargins;

/// The colour used when displaying a destructive action, whether in AAPLActionCell or AAPLCollectionViewCell swipe to edit actions.
@property (readonly, nonatomic) UIColor *destructiveActionColor;
/// The colours used when displaying non-destructive and non-primary actions in the AAPLCollectionViewCell swipe to edit actions.
@property (readonly, nonatomic) NSArray<UIColor *> *alternateActionColors;
/// The background colour for the area containing a cells action buttons
@property (readonly, nonatomic) UIColor *cellActionBackgroundColor;

/// The background colour for a cell when it is highlighted for selection (default is 235/255).
@property (readonly, nonatomic) UIColor *selectedBackgroundColor;
/// A light grey background colour (default is 248/255).
@property (readonly, nonatomic) UIColor *lightGreyBackgroundColor;
/// A medium grey background colour (default is 235/255).
@property (readonly, nonatomic) UIColor *greyBackgroundColor;
/// A dark grey background colour (default is 199/255).
@property (readonly, nonatomic) UIColor *darkGreyBackgroundColor;
/// The default background colour (white).
@property (readonly, nonatomic) UIColor *backgroundColor;

/// The colour for separator lines (204/255).
@property (readonly, nonatomic) UIColor *separatorColor;

/// A medium grey colour for text (116/255).
@property (readonly, nonatomic) UIColor *mediumGreyTextColor;
/// A lighter grey colour for text (172/255).
@property (readonly, nonatomic) UIColor *lightGreyTextColor;
/// A darker grey colour for text (77/255).
@property (readonly, nonatomic) UIColor *darkGreyTextColor;

@end




NS_ASSUME_NONNULL_END
