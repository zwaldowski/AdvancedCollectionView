/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A data source for presenting items represented by key paths on a single object. The items in the data source are instances of AAPLKeyValueItem and may represent a text string, button, or URL. All items are rendered using AAPLKeyValueCell.
 */

#import "AAPLBasicDataSource.h"

NS_ASSUME_NONNULL_BEGIN




typedef __nullable NSString * (^AAPLKeyValueTransformer)(__nullable id value);
typedef __nullable UIImage * (^AAPLKeyValueImageTransformer)(__nullable id value);

typedef NS_ENUM(NSInteger, AAPLKeyValueItemType) {
    AAPLKeyValueItemTypeDefault = 0,
    AAPLKeyValueItemTypeButton,
    AAPLKeyValueItemTypeURL
};

/**
 Content items for the `AAPLKeyValueDataSource` and `AAPLTextValueDataSource` data sources.

 AAPLKeyValueItem instances have a title and a value. The value may be a string, a button, or a URL and is obtained via a key path on the source object of the AAPLKeyValueDataSource. A transformer may be set to modify the string or button value. In addition, for buttons, a transformer is available to provide an image for the button.
 */
@interface AAPLKeyValueItem : NSObject

/// Create a key value item with a localized title and a value represented by the given key path on the source object.
+ (instancetype)itemWithLocalizedTitle:(NSString *)title keyPath:(NSString *)keyPath;

/// Create a key value item with a localized title and a value represented by the given key path on the source object. Before rendering, the value will be transformed using the given transformer.
+ (instancetype)itemWithLocalizedTitle:(NSString *)title keyPath:(nullable NSString *)keyPath transformer:(nullable AAPLKeyValueTransformer)transformer;

/// Create a key value item with a localized title that uses a transformer on the object value rather than a property of the object.
+ (instancetype)itemWithLocalizedTitle:(NSString *)title transformer:(AAPLKeyValueTransformer)transformer;

/// Create a key/value item that renders as a button, because sometimes you just want one. The keyPath is to the object from which the button title and image is derived. If keyPath yields a string, then the button will not have an image. If keyPath yields something other than a string, transformer will be used to get a string and imageTransformer will be used to get a UIImage.
+ (instancetype)buttonItemWithLocalizedTitle:(NSString *)title keyPath:(NSString *)keyPath transformer:(AAPLKeyValueTransformer)transformer imageTransformer:(AAPLKeyValueImageTransformer)imageTransformer action:(SEL)action;

/// Create a key/value item that renders as an URL. Tapping the value of the URL will open the URL in Safari.
+ (instancetype)URLWithLocalizedTitle:(NSString *)title keyPath:(NSString *)keyPath;

/// Create a key/value item that renders as an URL, allow a transformer to generate the URL string. Tapping the value of the URL will open the URL in Safari.
+ (instancetype)URLWithLocalizedTitle:(NSString *)title keyPath:(NSString *)keyPath transformer:(nullable AAPLKeyValueTransformer)transformer;

/// What kind of item is this?
@property (nonatomic, readonly) AAPLKeyValueItemType itemType;

/// The title to display for this AAPLKeyValueItem.
@property (nonatomic, copy) NSString *localizedTitle;

/// The key path associated with this AAPLKeyValueItem. This key path should represent a string value on the source object associated with the AAPLKeyValueDataSource. When the keyPath is nil, -valueForObject: and -imageForObject: will pass the object parameter itself to any transformers.
@property (nullable, nonatomic, copy) NSString *keyPath;

/// The transformer for the value of an AAPLKeyValueItem representing a string or a button.
@property (nullable, nonatomic, copy) AAPLKeyValueTransformer transformer;

/// The transformer for the image of an AAPLKeyValueItem representing a button.
@property (nullable, nonatomic, copy) AAPLKeyValueImageTransformer imageTransformer;

/// For button items, this is the action that will be sent up the responder chain when the button is tapped.
@property (nullable, nonatomic) SEL action;

/// Return a string value based on the provided object. This uses the transformer property if one is assigned.
- (nullable NSString *)valueForObject:(id)object;

/// Return an image value based on the provided object. This method requires imageTransformer be non-nil. @note This is a synchronous operation. The image must already be available.
- (nullable UIImage *)imageForObject:(id)object;
@end




/** A subclass of `AAPLBasicDataSource` using key paths with a source object to generate simple key value cells. The items in this data source must be instances of `AAPLKeyValueItem`.

 This data source filters its items based on whether the `AAPLKeyValueItem` returns a value from `-valueForObject:`. Items that return nil from `-valueForObject:` will not be presented in the final list of items, however, if the object is changed, the original list of items will be reevaluated. **Note**, the data source does not observe changes to the key paths represented by the items. Therefore, a manual refresh is necessary.
 */
@interface AAPLKeyValueDataSource<SourceType : id> : AAPLBasicDataSource<AAPLKeyValueItem *>

/// Initialise an AAPLKeyValueDataSource with an object which will be used as the source for values for AAPLKeyValueItem instances.
- (instancetype)initWithObject:(nullable SourceType)object NS_DESIGNATED_INITIALIZER;

/// The object used to resolve the key paths of AAPLKeyValueItem instances in this data source. Modifying this value will refresh the data source.
@property (nullable, nonatomic, strong) SourceType object;

/// The width of the title column. This will be passed to the `AAPLKeyValueCell` instances to allow the title column for all cells to have the same width. THIS IS A SHAMEFUL HACK!
@property (nonatomic) CGFloat titleColumnWidth;

@end




NS_ASSUME_NONNULL_END
