/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The cat detail data source, of course. Initialised with a cat instance, this data source will fetch the detail information about that cat.
 */

#import "AAPLCatDetailDataSource.h"
#import "AAPLKeyValueDataSource.h"
#import "AAPLTextValueDataSource.h"
#import "AAPLDataSource+Headers.h"

#import "AAPLCat.h"
#import "AAPLDataAccessManager.h"

@interface AAPLCatDetailDataSource ()
@property (nonatomic, strong) AAPLCat *cat;
@property (nonatomic, strong) AAPLKeyValueDataSource<AAPLCat *> *classificationDataSource;
@property (nonatomic, strong) AAPLTextValueDataSource<AAPLCat *> *descriptionDataSource;
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
    _classificationDataSource.defaultMetrics.estimatedRowHeight = 22;
    _classificationDataSource.title = NSLocalizedString(@"Classification", @"Title of the classification data section");
    (void)_classificationDataSource.dataSourceTitleHeader;

    [self addDataSource:_classificationDataSource];

    _descriptionDataSource = [[AAPLTextValueDataSource alloc] initWithObject:cat];
    _descriptionDataSource.defaultMetrics.estimatedRowHeight = 100;

    [self addDataSource:_descriptionDataSource];

    return self;
}

- (void)updateChildDataSources
{
    self.classificationDataSource.items = @[
                                            [AAPLKeyValueItem itemWithLocalizedTitle:NSLocalizedString(@"Kingdom", @"label for kingdom cell") keyPath:@"classificationKingdom"],

                                            [AAPLKeyValueItem itemWithLocalizedTitle:NSLocalizedString(@"Phylum", @"label for the phylum cell") keyPath:@"classificationPhylum"],
                                            [AAPLKeyValueItem itemWithLocalizedTitle:NSLocalizedString(@"Class", @"label for the class cell") keyPath:@"classificationClass"],
                                            [AAPLKeyValueItem itemWithLocalizedTitle:NSLocalizedString(@"Order", @"label for the order cell") keyPath:@"classificationOrder"],
                                            [AAPLKeyValueItem itemWithLocalizedTitle:NSLocalizedString(@"Family", @"label for the family cell") keyPath:@"classificationFamily"],
                                            [AAPLKeyValueItem itemWithLocalizedTitle:NSLocalizedString(@"Genus", @"label for the genus cell") keyPath:@"classificationGenus"],
                                            [AAPLKeyValueItem itemWithLocalizedTitle:NSLocalizedString(@"Species", @"label for the species cell") keyPath:@"classificationSpecies"]
                                            ];

    self.descriptionDataSource.items = @[
                                         [AAPLKeyValueItem itemWithLocalizedTitle:NSLocalizedString(@"Description", @"Title of the description data section") keyPath:@"longDescription"],
                                         [AAPLKeyValueItem itemWithLocalizedTitle:NSLocalizedString(@"Habitat", @"Title of the habitat data section") keyPath:@"habitat"]
                                         ];
}

- (void)loadContentWithProgress:(AAPLLoadingProgress *)progress
{
    [[AAPLDataAccessManager manager] fetchDetailForCat:self.cat completionHandler:^(AAPLCat *cat, NSError *error) {
        // Check to make certain a more recent call to load content hasn't superceded this one…
        if (progress.cancelled)
            return;

        if (error) {
            [progress doneWithError:error];
            return;
        }

        // There's always content, because this is a composed data source
        [progress updateWithContent:^(AAPLCatDetailDataSource *me) {
            [me updateChildDataSources];
        }];
    }];
}

@end
