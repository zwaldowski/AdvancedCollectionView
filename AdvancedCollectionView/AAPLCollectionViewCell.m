/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  The base collection view cell used by the AAPLCollectionViewGridLayout code. This cell provides swipe to edit and drag to reorder support.
  
 */

#import "AAPLCollectionViewCell_Private.h"
#import "AAPLHairlineView.h"
#import "AAPLCollectionViewGridLayout_Private.h"
#import "AAPLCollectionViewController.h"
#import "UIView+Helpers.h"
#import "AAPLAction.h"

#define DESTRUCTIVE_COLOR [UIColor colorWithRed:220/255.0 green:55/255.0 blue:50/255.0 alpha:1.0]
#define ANIMATION_DURATION 0.25

@interface AAPLActionsView : UIView <UIActionSheetDelegate>
@property (nonatomic) CGFloat visibleWidth;
@property (nonatomic, strong) CALayer *maskLayer;
@property (nonatomic, weak) AAPLCollectionViewCell *cell;
@property (nonatomic, strong) NSArray *editActionConstraints;
@property (nonatomic, strong) NSArray *actionButtons;

- (void)prepareActionButtons;
@end

@interface AAPLCollectionViewCell ()

@property (nonatomic, strong) UIView *privateContentView;

@property (nonatomic, strong) CALayer *leftGradientMask;
@property (nonatomic, assign) NSInteger columnIndex;
@property (nonatomic, strong) AAPLHairlineView *topHairline;
@property (nonatomic, strong) AAPLHairlineView *bottomHairline;
@property (nonatomic, strong) NSArray *editActionsConstraints;
@property (nonatomic, strong) NSArray *hairlineConstraints;
@property (nonatomic, strong) NSLayoutConstraint *contentLeftConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentWidthConstraint;
@property (nonatomic, strong) NSArray *editingConstraints;
@property (nonatomic, strong) UIImageView *reorderImageView;
@property (nonatomic, strong) UIImageView *removeImageView;
@property (nonatomic, strong) AAPLActionsView *editActionsView;
@property (nonatomic) BOOL removeControlRotated;
@property (nonatomic, readwrite) BOOL shouldDisplaySwipeToEditAccessories;

/// Flag from attributes
@property (nonatomic) BOOL movable;

@end

@implementation AAPLActionsView

- (instancetype)initWithFrame:(CGRect)frame cell:(AAPLCollectionViewCell *)cell
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    [self setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _cell = cell;

    _maskLayer = [[CALayer alloc] init];
    _maskLayer.backgroundColor = [[UIColor blackColor] CGColor];
    _maskLayer.delegate = self; // so this layer can participate in UIView animations
    self.layer.mask = _maskLayer;
    self.visibleWidth = 0.0;

    self.userInteractionEnabled = NO;
    return self;
}

- (void)setVisibleWidth:(CGFloat)visibleWidth
{
    if (_visibleWidth == visibleWidth)
        return;

    _visibleWidth = visibleWidth;
    CGRect bounds = self.bounds;
    visibleWidth = MIN(visibleWidth, CGRectGetWidth(bounds));
    _maskLayer.frame = CGRectMake(CGRectGetWidth(bounds) - visibleWidth, 0.0, visibleWidth, CGRectGetHeight(bounds));
}

- (void)prepareActionButtons
{
    if (_actionButtons == nil) {
        NSMutableArray *actionButtons = [NSMutableArray array];

        [_cell.editActions enumerateObjectsUsingBlock:^(AAPLAction *editAction, NSUInteger actionIndex, BOOL *stop) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];

            [button setTitle:editAction.title forState:UIControlStateNormal];
            button.titleLabel.numberOfLines = 0;
            button.titleLabel.font = [UIFont systemFontOfSize:16];

            if (editAction.destructive)
                button.backgroundColor = DESTRUCTIVE_COLOR;
            else
                button.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];

            button.translatesAutoresizingMaskIntoConstraints = NO;
            button.contentEdgeInsets = UIEdgeInsetsMake(0, 9, 0, 9);

            [button addTarget:self action:@selector(didTouchEditAction:) forControlEvents:UIControlEventTouchUpInside];
            [actionButtons addObject:button];

            *stop = [_cell.editActions count] > 2 && actionIndex == 0;
        }];

        if ([_cell.editActions count] > 2) {
            UIButton *moreButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [moreButton setTitle:NSLocalizedString(@"More", @"Text for More actions button") forState:UIControlStateNormal];
            moreButton.titleLabel.numberOfLines = 0;
            moreButton.titleLabel.font = [UIFont systemFontOfSize:18];
            moreButton.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];;
            moreButton.translatesAutoresizingMaskIntoConstraints = NO;
            moreButton.contentEdgeInsets = UIEdgeInsetsMake(0, 9, 0, 9);

            [moreButton addTarget:self action:@selector(didTouchMoreEditAction:) forControlEvents:UIControlEventTouchUpInside];
            [actionButtons addObject:moreButton];
        }

        self.actionButtons = actionButtons;
    }
}

- (void)setActionButtons:(NSArray *)actionButtons
{
    if (_actionButtons == actionButtons)
        return;

    for (UIButton *button in _actionButtons)
        [button removeFromSuperview];

    _actionButtons = actionButtons;

    if (_editActionConstraints)
        [self removeConstraints:_editActionConstraints];

    for (UIButton *button in _actionButtons)
        [self addSubview:button];

    NSMutableArray *editActionConstraints = [NSMutableArray array];

    [_actionButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger buttonIndex, BOOL *stop) {
        [editActionConstraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
        [editActionConstraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

        if (buttonIndex == 0) {
            [editActionConstraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
        }

        if (buttonIndex > 0) {
            [editActionConstraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_actionButtons[buttonIndex-1] attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
        }

        if (buttonIndex == [_actionButtons count] - 1) {
            [editActionConstraints addObject:[NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:button attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
        }

        [editActionConstraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:72]];

        [button setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    }];

    self.editActionConstraints = editActionConstraints;
    [self addConstraints:_editActionConstraints];
}

- (void)didTouchEditAction:(UIButton *)sender
{
    NSUInteger buttonIndex = [_actionButtons indexOfObject:sender];
    SEL action = [_cell.editActions[buttonIndex] selector];
    if (!action)
        return;

    self.userInteractionEnabled = NO; // is reenabled when shown again
    [self aapl_sendAction:action from:_cell];
}

- (void)didTouchMoreEditAction:(UIButton *)moreButton
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];

    NSMutableArray *actions = [NSMutableArray arrayWithCapacity:[_cell.editActions count] - 1];
    [_cell.editActions enumerateObjectsUsingBlock:^(AAPLAction *editAction, NSUInteger actionIndex, BOOL *stop) {
        if (actionIndex > 0) {
            [actionSheet addButtonWithTitle:editAction.title];
            [actions addObject:[NSValue valueWithPointer:editAction.selector]];
        }
    }];

    // This action never seems to be used, because we get the -actionSheet:willDismissWithButtonIndex: delegate method called instead.
    [actions addObject:[NSValue valueWithPointer:@selector(willDismissActionSheetFromCell:)]];
    actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button")];

    [actionSheet showInView:self];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSUInteger idx = buttonIndex + 1;
    if (idx < [_cell.editActions count]) {
        SEL action = [_cell.editActions[idx] selector];
        if (!action)
            return;
        [self aapl_sendAction:action from:_cell];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex)
        [self aapl_sendAction:@selector(willDismissActionSheetFromCell:) from:_cell];
}

@end

@implementation AAPLCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    // We default to showing the reorder control unless we're told not to.
    _showsReorderControl = YES;

    // We don't get background or selectedBackground views unless we create them!
    self.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    self.selectedBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];

    UIView *contentView = [super contentView];

    _privateContentView = [[UIView alloc] initWithFrame:contentView.bounds];
    _privateContentView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:_privateContentView];

    _editActionsView = [[AAPLActionsView alloc] initWithFrame:CGRectZero cell:self];
    _editActionsView.translatesAutoresizingMaskIntoConstraints = NO;

    [self addConstraint:[NSLayoutConstraint constraintWithItem:_privateContentView attribute:NSLayoutAttributeTop
                                                     relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

    [self addConstraint:[NSLayoutConstraint constraintWithItem:_privateContentView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];

    _contentWidthConstraint = [NSLayoutConstraint constraintWithItem:_privateContentView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
    [self addConstraint:_contentWidthConstraint];

    _contentLeftConstraint = [NSLayoutConstraint constraintWithItem:_privateContentView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeft multiplier:1 constant:0];

    [self addConstraint:_contentLeftConstraint];

    _topHairline = [AAPLHairlineView hairlineViewForAlignment:AAPLHairlineAlignmentHorizontal];
    _topHairline.translatesAutoresizingMaskIntoConstraints = NO;
    _topHairline.alpha = 0;

    _bottomHairline = [AAPLHairlineView hairlineViewForAlignment:AAPLHairlineAlignmentHorizontal];
    _bottomHairline.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomHairline.alpha = 0;

    _removeImageView = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"AAPLRemoveControl"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _removeImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _removeImageView.tintColor = DESTRUCTIVE_COLOR;

    [_removeImageView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _reorderImageView = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"AAPLDragGrabber"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _reorderImageView.translatesAutoresizingMaskIntoConstraints = NO;
    _reorderImageView.tintColor = [UIColor lightGrayColor];
    [_reorderImageView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    contentView.clipsToBounds = YES;
    return self;
}

//- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
//{
//    UICollectionViewLayoutAttributes *attributes = [layoutAttributes copy];
//    CGRect frame = attributes.frame;
////    [self layoutSubviews];
//    frame.size = [self.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
//    attributes.frame = frame;
//    return attributes;
//}

- (UIColor *)separatorColor
{
    return _topHairline.backgroundColor;
}

- (void)setSeparatorColor:(UIColor *)separatorColor
{
    _topHairline.backgroundColor = separatorColor;
    _bottomHairline.backgroundColor = separatorColor;
}

- (UIView *)actionsView
{
    return _editActionsView;
}

- (UIView *)removeControl
{
    return _removeImageView;
}

- (UIView *)reorderControl
{
    if (![self shouldShowReorderControl])
        return nil;
    return _reorderImageView;
}

- (void)invalidateCollectionViewLayout
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_invalidateCollectionViewLayout) object:self];
    [self performSelector:@selector(_invalidateCollectionViewLayout) withObject:nil afterDelay:0.0];
}

- (void)_invalidateCollectionViewLayout
{
    UICollectionView *collectionView = (UICollectionView *)self.superview;

    while (collectionView && ![collectionView isKindOfClass:[UICollectionView class]])
        collectionView = (UICollectionView *)collectionView.superview;

    if (!collectionView)
        return;

    AAPLCollectionViewGridLayout *layout = (AAPLCollectionViewGridLayout *)collectionView.collectionViewLayout;
    if (![layout isKindOfClass:[AAPLCollectionViewGridLayout class]])
        return;

    NSIndexPath *indexPath = [collectionView indexPathForCell:self];
    if (!indexPath)
        return;
    
    [layout invalidateLayoutForItemAtIndexPath:indexPath];
}

- (UIView *)contentView
{
    return _privateContentView;
}

- (CGFloat)minimumSwipeTrackingPosition
{
    return CGRectGetMinX(_editActionsView.frame) - CGRectGetWidth([super contentView].frame);
}

- (CGFloat)swipeTrackingPosition
{
    return _privateContentView.frame.origin.x;
}

- (void)setSwipeTrackingPosition:(CGFloat)swipeTrackingPosition
{
    if (_editing)
        _contentLeftConstraint.constant = swipeTrackingPosition + CGRectGetWidth(_removeImageView.frame) + 15;
    else {
        CGRect frame = _privateContentView.frame;
        frame.origin.x = swipeTrackingPosition;
        _privateContentView.frame = frame;
    }
    _editActionsView.visibleWidth = MAX(0, -swipeTrackingPosition);
}

- (CGFloat)editActionsVisibleWidth
{
    return _editActionsView.visibleWidth;
}

- (void)setEditActionsVisibleWidth:(CGFloat)editActionsVisibleWidth
{
    _editActionsView.visibleWidth = editActionsVisibleWidth;
}

- (void)prepareHairlineConstraintsIfNeeded
{
    if (_hairlineConstraints)
        return;

    NSMutableArray *hairlineConstraints = [[NSMutableArray alloc] init];

    UIView *contentView = [super contentView];
    [hairlineConstraints addObject:[NSLayoutConstraint constraintWithItem:_topHairline attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    [hairlineConstraints addObject:[NSLayoutConstraint constraintWithItem:_topHairline attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [hairlineConstraints addObject:[NSLayoutConstraint constraintWithItem:_topHairline attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];

    [hairlineConstraints addObject:[NSLayoutConstraint constraintWithItem:_bottomHairline attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    [hairlineConstraints addObject:[NSLayoutConstraint constraintWithItem:_bottomHairline attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];
    [hairlineConstraints addObject:[NSLayoutConstraint constraintWithItem:_bottomHairline attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];

    _hairlineConstraints = hairlineConstraints;
}

- (void)prepareEditActionsConstraintsIfNeeded
{
    if (_editActionsConstraints)
        return;

    NSMutableArray *editActionsConstraints = [[NSMutableArray alloc] init];

    UIView *contentView = [super contentView];
    [editActionsConstraints addObject:[NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [editActionsConstraints addObject:[NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    [editActionsConstraints addObject:[NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [editActionsConstraints addObject:[NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeBottom multiplier:1 constant:0]];

    _editActionsConstraints = editActionsConstraints;
}

- (void)showEditActions
{
    UIView *contentView = [super contentView];
    [contentView addSubview:_editActionsView];
    [self prepareEditActionsConstraintsIfNeeded];
    [self addConstraints:_editActionsConstraints];
    [_editActionsView prepareActionButtons];

    if (!_editing)
        [self removeConstraint:_contentLeftConstraint];

    self.shouldDisplaySwipeToEditAccessories = YES;
    [_editActionsView layoutIfNeeded];
    // Prevent the weird animated mask layer
    _editActionsView.visibleWidth = 1;
    _editActionsView.visibleWidth = 0;
}

- (void)hideEditActions
{
    if (_editActionsConstraints)
        [self removeConstraints:_editActionsConstraints];
    [_editActionsView removeFromSuperview];

    self.shouldDisplaySwipeToEditAccessories = NO;
}

- (void)animateOutSwipeToEditAccessories
{
    self.shouldDisplaySwipeToEditAccessories = NO;
}

- (void)setUserInteractionEnabledForEditing:(BOOL)userInteractionEnabledForEditing
{
    _editActionsView.userInteractionEnabled = userInteractionEnabledForEditing;
}

- (BOOL)userInteractionEnabledForEditing
{
    return _editActionsView.userInteractionEnabled;
}

- (BOOL)touchWithinEditActions:(UITouch *)touch
{
    CGPoint touchPoint = [touch locationInView:_editActionsView];
    CGRect disabledRect = _editActionsView.bounds;
    return CGRectContainsPoint(disabledRect, touchPoint);
}

- (CALayer *)leftGradientMask
{
    UIView *contentView = [super contentView];
    CGRect newBounds = contentView.bounds;
    if (_leftGradientMask == nil || !CGRectEqualToRect(_leftGradientMask.frame, newBounds)) {
        CAGradientLayer *leftGradient = [CAGradientLayer layer];
        leftGradient.frame = newBounds;
        leftGradient.colors = @[(id)[[UIColor clearColor] CGColor],
                                (id)[[UIColor clearColor] CGColor],
                                (id)[[UIColor blackColor] CGColor]];
        leftGradient.locations = @[@0, @0.25, @1];
        leftGradient.startPoint = CGPointMake(0, 0.5);
        leftGradient.endPoint = CGPointMake(0.025, 0.5);
        self.leftGradientMask = leftGradient;
    }

    return _leftGradientMask;
}

- (void)applyGradientMaskIfNeeded
{
    BOOL shouldMask = _shouldDisplaySwipeToEditAccessories && (_columnIndex != 0);

    UIView *contentView = [super contentView];
    CALayer *contentLayer = contentView.layer;

    if (shouldMask) {
        contentLayer.mask = self.leftGradientMask;
    }
    else {
        contentLayer.mask = nil;

        // No point keeping the mask around
        self.leftGradientMask = nil;
    }
}

- (void)setShouldDisplaySwipeToEditAccessories:(BOOL)shouldDisplaySwipeToEditAccessories
{
    if (_shouldDisplaySwipeToEditAccessories == shouldDisplaySwipeToEditAccessories)
        return;

    _shouldDisplaySwipeToEditAccessories = shouldDisplaySwipeToEditAccessories;

    BOOL showsSeparators = self.showsSeparatorsWhileEditing;

    if (_shouldDisplaySwipeToEditAccessories && showsSeparators) {
        UIView *contentView = [super contentView];
        [contentView addSubview:_topHairline];
        [contentView addSubview:_bottomHairline];
        [self prepareHairlineConstraintsIfNeeded];
        [self addConstraints:_hairlineConstraints];
    }

    [self applyGradientMaskIfNeeded];

    [UIView animateWithDuration:0.5 animations:^{
        self.topHairline.alpha = _shouldDisplaySwipeToEditAccessories ? 1 : 0;
        self.bottomHairline.alpha = _shouldDisplaySwipeToEditAccessories ? 1 : 0;
    } completion:^(BOOL finished) {
        if (!_shouldDisplaySwipeToEditAccessories && showsSeparators) {
            [self removeConstraints:_hairlineConstraints];
            [_topHairline removeFromSuperview];
            [_bottomHairline removeFromSuperview];
        }
    }];
}

- (void)setColumnIndex:(NSInteger)columnIndex
{
    if (columnIndex == _columnIndex)
        return;

    _columnIndex = columnIndex;
    [self applyGradientMaskIfNeeded];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self applyGradientMaskIfNeeded];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    self.hidden = layoutAttributes.hidden;
    if ([layoutAttributes isKindOfClass:[AAPLCollectionViewGridLayoutAttributes class]]) {
        AAPLCollectionViewGridLayoutAttributes *attributes = (AAPLCollectionViewGridLayoutAttributes *)layoutAttributes;
        self.columnIndex = attributes.columnIndex;
        self.backgroundView.backgroundColor = attributes.backgroundColor;
        self.selectedBackgroundView.backgroundColor = attributes.selectedBackgroundColor;
        BOOL oldEditing = _editing;
        self.movable = attributes.movable;
        self.editing = attributes.editing;
        if (oldEditing != self.editing) {
            if (self.editing)
                [self showEditingControls];
            else
                [self hideEditingControls];
        }
    }
}

- (void)closeForDelete
{
    CGRect contentFrame = _privateContentView.frame;
    contentFrame.origin.x -= contentFrame.size.width;
    _privateContentView.frame = contentFrame;

    CGRect maskFrame = _editActionsView.maskLayer.frame;
    maskFrame.size.height = 0;
    _editActionsView.maskLayer.frame = maskFrame;

    CGRect bottomHairlineFrame = _bottomHairline.frame;
    bottomHairlineFrame.origin.y = 0;
    _bottomHairline.frame = bottomHairlineFrame;
}

- (BOOL)shouldShowReorderControl
{
    return self.showsReorderControl && self.movable;
}

- (void)rotateRemoveControl
{
    CGAffineTransform tform = CGAffineTransformMakeRotation(_removeControlRotated ? 0.0 : -M_PI_2);
    _removeControlRotated = !_removeControlRotated;
    [_removeImageView setTransform:tform];
}

- (void)closeActionPaneAnimated:(BOOL)animate completionHandler:(void(^)(BOOL finished))handler
{
    dispatch_block_t shut = ^{
        self.swipeTrackingPosition = 0;
        if (_editing)
            [self rotateRemoveControl];
        [self layoutIfNeeded];
    };

    if (animate) {
        [UIView animateWithDuration:ANIMATION_DURATION animations:shut completion:^(BOOL finished) {
            if (!_editing)
                [self addConstraint:_contentLeftConstraint];
            if (handler) {
                handler(finished);
            }
        }];
    }
    else {
        shut();
        if (!_editing)
            [self addConstraint:_contentLeftConstraint];
        if (handler) {
            handler(YES);
        }
    }
}

- (void)openActionPaneAnimated:(BOOL)animated completionHandler:(void (^)(BOOL finished))handler
{
    [self showEditActions];

    if (animated)
        [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            self.swipeTrackingPosition = self.minimumSwipeTrackingPosition;
            [self rotateRemoveControl];
            [self layoutIfNeeded];
        } completion:handler];
    else {
        [self rotateRemoveControl];
        self.swipeTrackingPosition = self.minimumSwipeTrackingPosition;
        if (handler)
            handler(YES);
    }
}

- (void)showEditingControls
{
    NSMutableArray *constraints = [NSMutableArray array];

    UIView *superContentView = [super contentView];

    CGFloat contentHeight = CGRectGetHeight(_privateContentView.frame);
    CGFloat contentWidth = CGRectGetWidth(_privateContentView.frame);

    CGFloat editingWidth = 0;
    [superContentView addSubview:_removeImageView];

    [constraints addObject:[NSLayoutConstraint constraintWithItem:_removeImageView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:superContentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_removeImageView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_privateContentView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];

    CGFloat removeWidth = CGRectGetWidth(_removeImageView.frame);
    CGFloat removeHeight = CGRectGetHeight(_removeImageView.frame);

    // setup initial position
    CGRect removeFrame = CGRectMake(-removeWidth, ceilf((contentHeight-removeHeight)/2), removeWidth, removeHeight);
    _removeImageView.frame = removeFrame;

    editingWidth += removeWidth + 15;

    if ([self shouldShowReorderControl]) {
        [superContentView addSubview:_reorderImageView];

        [constraints addObject:[NSLayoutConstraint constraintWithItem:_reorderImageView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:superContentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:_reorderImageView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_privateContentView attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];

        CGRect reorderFrame = _reorderImageView.frame;
        reorderFrame.origin = CGPointMake(contentWidth, ceilf((contentHeight - CGRectGetHeight(reorderFrame))/2));
        _reorderImageView.frame = reorderFrame;

        editingWidth += CGRectGetWidth(_reorderImageView.frame) + 15;
    }

    _editingConstraints = constraints;
    [superContentView addConstraints:constraints];
    _contentLeftConstraint.constant = removeWidth + 15;
    _contentWidthConstraint.constant = -editingWidth;

    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        [self layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self showEditActions];
    }];
}

- (void)hideEditingControls
{
    UIView *superContentView = [super contentView];
    if (!_editingConstraints)
        return;

    [UIView animateWithDuration:ANIMATION_DURATION animations:^{
        _contentWidthConstraint.constant = 0;
        _contentLeftConstraint.constant = 0;
        [self layoutIfNeeded];
    } completion:^(BOOL finished) {
        [superContentView removeConstraints:_editingConstraints];
        _editingConstraints = nil;
        [_removeImageView removeFromSuperview];
        [_reorderImageView removeFromSuperview];
        [self hideEditActions];
    }];
}

- (void)setEditing:(BOOL)editing
{
    if (_editing == editing)
        return;

    _privateContentView.userInteractionEnabled = !editing;
    _editing = editing;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];

    if (highlighted) {
        [self insertSubview:self.selectedBackgroundView aboveSubview:self.backgroundView];
        self.selectedBackgroundView.alpha = 1;
        self.selectedBackgroundView.hidden = NO;
    }
    else {
        self.selectedBackgroundView.hidden = YES;
    }

    if (_editing)
        self.selectedBackgroundView.hidden = YES;
}
@end
