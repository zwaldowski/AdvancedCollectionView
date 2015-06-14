/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A class for managing registration of reusable views.
 */

#import "AAPLShadowRegistrar.h"

@interface AAPLShadowRegistration : NSObject
@property (nullable, nonatomic, strong) UICollectionReusableView *reusableView;
@property (nullable, nonatomic, strong) UINib *nib;
@property (nullable, nonatomic, weak) Class viewClass;
@end

@interface AAPLShadowRegistrar ()
@property (nonatomic, strong) NSMutableDictionary *cellRegistry;
@property (nonatomic, strong) NSMutableDictionary *supplementaryViewRegistry;
@end



@implementation AAPLShadowRegistration
@end


@implementation AAPLShadowRegistrar

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _cellRegistry = [NSMutableDictionary dictionary];
    _supplementaryViewRegistry = [NSMutableDictionary dictionary];

    return self;
}

- (AAPLShadowRegistration *)shadowRegistrationForCellWithReuseIdentifier:(NSString *)identifier
{
    AAPLShadowRegistration *shadowRegistration = _cellRegistry[identifier];
    if (!shadowRegistration)
        _cellRegistry[identifier] = shadowRegistration = [[AAPLShadowRegistration alloc] init];
    return shadowRegistration;
}

- (AAPLShadowRegistration *)shadowRegistrationForSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier
{
    NSMutableDictionary *elementKindRegistry = _supplementaryViewRegistry[elementKind];
    if (!elementKindRegistry)
        _supplementaryViewRegistry[elementKind] = elementKindRegistry = [NSMutableDictionary dictionary];

    AAPLShadowRegistration *shadowRegistration = elementKindRegistry[identifier];
    if (!shadowRegistration)
        elementKindRegistry[identifier] = shadowRegistration = [[AAPLShadowRegistration alloc] init];
    return shadowRegistration;
}

- (void)registerClass:(Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier
{
    AAPLShadowRegistration *shadowRegistration = [self shadowRegistrationForCellWithReuseIdentifier:identifier];
    shadowRegistration.viewClass = cellClass;
    shadowRegistration.nib = nil;
    shadowRegistration.reusableView = nil;
}

- (void)registerNib:(UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier
{
    AAPLShadowRegistration *shadowRegistration = [self shadowRegistrationForCellWithReuseIdentifier:identifier];
    shadowRegistration.viewClass = nil;
    shadowRegistration.nib = nib;
    shadowRegistration.reusableView = nil;
}

- (void)registerClass:(Class)viewClass forSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier
{
    AAPLShadowRegistration *shadowRegistration = [self shadowRegistrationForSupplementaryViewOfKind:elementKind withReuseIdentifier:identifier];
    shadowRegistration.viewClass = viewClass;
    shadowRegistration.nib = nil;
    shadowRegistration.reusableView = nil;
}

- (void)registerNib:(UINib *)nib forSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier
{
    AAPLShadowRegistration *shadowRegistration = [self shadowRegistrationForSupplementaryViewOfKind:elementKind withReuseIdentifier:identifier];
    shadowRegistration.viewClass = nil;
    shadowRegistration.nib = nib;
    shadowRegistration.reusableView = nil;
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes toView:(UICollectionReusableView *)view
{
    view.center = layoutAttributes.center;
    CGRect bounds = view.bounds;
    bounds.size = layoutAttributes.size;
    view.bounds = bounds;
    view.alpha = layoutAttributes.alpha;
    view.layer.transform = layoutAttributes.transform3D;
    [view applyLayoutAttributes:layoutAttributes];
}

- (id)dequeueReusableViewForShadowRegistration:(AAPLShadowRegistration *)shadowRegistration reuseIdentifier:(NSString *)identifier layoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes collectionView:(UICollectionView *)collectionView
{
    UICollectionReusableView *view = shadowRegistration.reusableView;
    Class viewClass = shadowRegistration.viewClass;
    UINib *nib = shadowRegistration.nib;

    if (view) {
        [view prepareForReuse];
    }
    else if (viewClass) {
        // Get the frame without any transformations
        CGRect frame = layoutAttributes.frame;
        frame.size = layoutAttributes.size;

        view = [[viewClass alloc] initWithFrame:frame];
    }
    else if (nib) {
        NSArray* topLevelObjects = [nib instantiateWithOwner:nil options:nil];
        view = topLevelObjects.firstObject;

        NSAssert(view && [view isKindOfClass:[UICollectionReusableView class]], @"invalid nib registered for identifier (%@) - nib must contain exactly one top level object which must be a UICollectionReusableView instance", identifier);
        NSString* viewReuseIdentifier = view.reuseIdentifier;
        NSAssert(viewReuseIdentifier.length == 0 || [viewReuseIdentifier isEqualToString:identifier], @"view reuse identifier in nib (%@) does not match the identifier used to register the nib (%@)", viewReuseIdentifier, identifier);
    }

    shadowRegistration.reusableView = view;
    view.autoresizingMask = UIViewAutoresizingNone;
    view.translatesAutoresizingMaskIntoConstraints = YES;

    [UIView performWithoutAnimation:^{
        [collectionView addSubview:view];
        [self applyLayoutAttributes:layoutAttributes toView:view];
    }];

    return view;
}

- (id)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath*)indexPath collectionView:(UICollectionView *)collectionView
{
    UICollectionViewLayout *collectionViewLayout = collectionView.collectionViewLayout;
    UICollectionViewLayoutAttributes *layoutAttributes = [collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];

    AAPLShadowRegistration *shadowRegistration = [self shadowRegistrationForCellWithReuseIdentifier:identifier];
    return [self dequeueReusableViewForShadowRegistration:shadowRegistration reuseIdentifier:identifier layoutAttributes:layoutAttributes collectionView:collectionView];
}

- (id)dequeueReusableSupplementaryViewOfKind:(NSString*)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath*)indexPath collectionView:(UICollectionView *)collectionView
{
    UICollectionViewLayout *collectionViewLayout = collectionView.collectionViewLayout;
    UICollectionViewLayoutAttributes *layoutAttributes = [collectionViewLayout layoutAttributesForSupplementaryViewOfKind:elementKind atIndexPath:indexPath];

    AAPLShadowRegistration *shadowRegistration = [self shadowRegistrationForSupplementaryViewOfKind:elementKind withReuseIdentifier:identifier];
    return [self dequeueReusableViewForShadowRegistration:shadowRegistration reuseIdentifier:identifier layoutAttributes:layoutAttributes collectionView:collectionView];
}

@end
