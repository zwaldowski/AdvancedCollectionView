/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  The cat detail data source, of course. Initialised with a cat instance, this data source will fetch the detail information about that cat.
  
 */

#import "AAPLCatDetailDataSource.h"
#import "AAPLKeyValueDataSource.h"
#import "AAPLTextValueDataSource.h"
#import "AAPLCat.h"
#import "AAPLDataAccessManager.h"

@interface AAPLCatDetailDataSource ()
@property (nonatomic, strong) AAPLCat *cat;
@property (nonatomic, strong) AAPLKeyValueDataSource *classificationDataSource;
@property (nonatomic, strong) AAPLTextValueDataSource *descriptionDataSource;
@end

@implementation AAPLCatDetailDataSource

- (instancetype)init
{
    return [self initWithCat:nil];
}

- (instancetype)initWithCat:(AAPLCat *)cat
{
    self = [super init];
    if (!self)
        return nil;

    _cat = cat;
    _classificationDataSource = [[AAPLKeyValueDataSource alloc] initWithObject:cat];
    _classificationDataSource.defaultMetrics.rowHeight = 22;
    _classificationDataSource.title = NSLocalizedString(@"Classification", @"Title of the classification data section");
    [_classificationDataSource dataSourceTitleHeader];

    [self addDataSource:_classificationDataSource];

    _descriptionDataSource = [[AAPLTextValueDataSource alloc] initWithObject:cat];
    _descriptionDataSource.defaultMetrics.rowHeight = AAPLRowHeightVariable;

    [self addDataSource:_descriptionDataSource];

    return self;
}

- (void)updateChildDataSources
{
    self.classificationDataSource.items = @[
                                            @{ @"label" : NSLocalizedString(@"Kingdom", @"label for kingdom cell"), @"keyPath" : @"classificationKingdom" },
                                            @{ @"label" : NSLocalizedString(@"Phylum", @"label for the phylum cell"), @"keyPath" : @"classificationPhylum" },
                                            @{ @"label" : NSLocalizedString(@"Class", @"label for the class cell"), @"keyPath" : @"classificationClass" },
                                            @{ @"label" : NSLocalizedString(@"Order", @"label for the order cell"), @"keyPath" : @"classificationOrder" },
                                            @{ @"label" : NSLocalizedString(@"Family", @"label for the family cell"), @"keyPath" : @"classificationFamily" },
                                            @{ @"label" : NSLocalizedString(@"Genus", @"label for the genus cell"), @"keyPath" : @"classificationGenus" },
                                            @{ @"label" : NSLocalizedString(@"Species", @"label for the species cell"), @"keyPath" : @"classificationSpecies" }
                                            ];

    self.descriptionDataSource.items = @[
                                         @{ @"label" : NSLocalizedString(@"Description", @"Title of the description data section"), @"keyPath" : @"longDescription" },
                                         @{ @"label" : NSLocalizedString(@"Habitat", @"Title of the habitat data section"), @"keyPath" : @"habitat" }
                                         ];
}

- (void)loadContent
{
    [self loadContentWithBlock:^(AAPLLoading *loading) {
        [[AAPLDataAccessManager manager] fetchDetailForCat:self.cat completionHandler:^(AAPLCat *cat, NSError *error) {
            // Check to make certain a more recent call to load content hasn't superceded this one…
            if (!loading.current) {
                [loading ignore];
                return;
            }

            if (error) {
                [loading doneWithError:error];
                return;
            }

            // There's always content, because this is a composed data source
            [loading updateWithContent:^(AAPLCatDetailDataSource *me) {
                [me updateChildDataSources];
            }];
        }];
    }];
}

@end
