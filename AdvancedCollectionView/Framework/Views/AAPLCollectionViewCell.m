/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The base collection view cell used by the AAPLCollectionViewLayout code. This cell provides swipe to edit and drag to reorder support.
 */

#import "AAPLCollectionViewCell_Private.h"
#import "AAPLHairlineView.h"
#import "AAPLCollectionViewLayout_Private.h"
#import "AAPLCollectionViewController.h"
#import "AAPLLocalization.h"
#import "UIView+Helpers.h"
#import "AAPLAction.h"
#import "AAPLTheme.h"
#import "AAPLDebug.h"

#define ANIMATION_DURATION 0.25

@class AAPLActionsView;

@interface AAPLCollectionViewCell ()

@property (nonatomic, strong) UIView *privateContentView;

@property (nonatomic, strong) CALayer *leftGradientMask;
@property (nonatomic, assign) NSInteger columnIndex;
@property (nonatomic, strong) AAPLHairlineView *topHairline;
@property (nonatomic, strong) AAPLHairlineView *bottomHairline;
@property (nonatomic, strong) NSArray *hairlineConstraints;
@property (nonatomic, strong) NSLayoutConstraint *contentLeftConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *contentHeightConstraint;
@property (nonatomic, strong) NSArray *deletionConstraints;
@property (nonatomic, strong) NSArray *editingConstraints;
@property (nonatomic, strong) NSArray *actionsConstraints;
@property (nonatomic, strong) UIImageView *reorderImageView;
@property (nonatomic, strong) UIImageView *removeImageView;
@property (nonatomic, strong) AAPLActionsView *editActionsView;
@property (nonatomic) BOOL removeControlRotated;
@property (nonatomic, readwrite) BOOL shouldDisplaySwipeToEditAccessories;

@property (nonatomic, readonly) CGFloat minimumSwipeTrackingPosition;
@property (nonatomic) CGFloat swipeTranslation;
@property (nonatomic) CGFloat swipeVelocity;
@property (nonatomic) CGFloat swipeInitialFramePosition;
@property (nonatomic) CGPoint swipeStartPosition;
@property (nonatomic) CGPoint originalStartPosition;
@property (nonatomic) BOOL swipePastBounds;
/// YES when this cell is about to be deleted due to user interaction
@property (nonatomic) BOOL deletePending;

/// Flag from attributes
@property (nonatomic) BOOL movable;

- (void)performAction:(AAPLAction *)action;
- (void)performMoreAction;

@end


@interface AAPLActionsView : UIView <UIActionSheetDelegate>
@property (nonatomic, weak) AAPLCollectionViewCell *cell;
@property (nonatomic, copy) NSArray *actions;
@property (nonatomic) AAPLCollectionViewCellSwipeType swipeType;
@property (nonatomic) CGFloat maximumWidth;
@property (nonatomic, strong) NSArray *editConstraints;
@property (nonatomic) BOOL highlightDefaultAction;
/// A constraint that's enabled to highlight the default action
@property (nonatomic, strong) NSArray *highlightActivatedConstraints;
@property (nonatomic, strong) NSArray *highlightDeactivatedConstraints;
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
    _swipeType = AAPLCollectionViewCellSwipeTypePrimary;

    self.userInteractionEnabled = NO;
    return self;
}

- (void)createSubviewsForActions:(NSArray *)actions
{
    for (UIView *view in self.subviews)
        [view removeFromSuperview];

    // Just incase there were some that didn't get removed by removing all the views.
    if (_editConstraints)
        [self removeConstraints:_editConstraints];
    _editConstraints = nil;

    NSUInteger numberOfActions = actions.count;
    const NSUInteger maxNumberOfActions = 3;

    AAPLCollectionViewCell *cell = self.cell;
    AAPLTheme *theme = cell.theme;
    NSArray<UIColor *> *alternateColors = theme.alternateActionColors;

    __block CGFloat maxButtonWidth = 0;
    // alternateColorIndex needs to start at the last, because we go backwards with our views
    __block NSInteger alternateColorIndex = alternateColors.count;

    [actions enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(AAPLAction *buttonAction, NSUInteger actionIndex, BOOL *stop) {

        if (actionIndex >= maxNumberOfActions)
            return;

        BOOL isMoreAction = numberOfActions > maxNumberOfActions && actionIndex + 1 == maxNumberOfActions;
        NSString *title = isMoreAction ? AAPL_LOC_MORE_EDIT_BUTTON : buttonAction.title;
        BOOL destructive = isMoreAction ? NO : buttonAction.destructive;
        BOOL isDefaultAction = (actionIndex == 0);

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitle:title forState:UIControlStateNormal];
        button.titleLabel.numberOfLines = 0;
        button.titleLabel.font = cell.theme.cellActionButtonFont;
        button.tag = actionIndex;

        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.contentEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 8);
        [button setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [button setContentHuggingPriority:UILayoutPriorityRequired - 10 forAxis:UILayoutConstraintAxisHorizontal];

        if (isMoreAction)
            [button addTarget:self action:@selector(didTapMoreAction:) forControlEvents:UIControlEventTouchUpInside];
        else
            [button addTarget:self action:@selector(didTapEditAction:) forControlEvents:UIControlEventTouchUpInside];

        UIView *wrapper = [[UIView alloc] initWithFrame:CGRectZero];
        wrapper.translatesAutoresizingMaskIntoConstraints = NO;
        wrapper.clipsToBounds = YES;
        [wrapper addSubview:button];
        [self addSubview:wrapper];

        [wrapper addSubview:button];

        if (destructive)
            wrapper.backgroundColor = theme.destructiveActionColor;
        else if (isDefaultAction)
            wrapper.backgroundColor = self.tintColor;
        else
            wrapper.backgroundColor = alternateColors[--alternateColorIndex];

        maxButtonWidth = MAX(maxButtonWidth, [button intrinsicContentSize].width);
    }];

    _maximumWidth = maxButtonWidth * self.subviews.count;

    [self createConstraints];
}

- (void)removeAllCustomConstraints
{
    if (_editConstraints) {
        [NSLayoutConstraint deactivateConstraints:_editConstraints];
        _editConstraints = nil;
    }

    if (_highlightActivatedConstraints) {
        [NSLayoutConstraint deactivateConstraints:_highlightActivatedConstraints];
        _highlightActivatedConstraints = nil;
    }

    if (_highlightDeactivatedConstraints) {
        [NSLayoutConstraint deactivateConstraints:_highlightDeactivatedConstraints];
        _highlightDeactivatedConstraints = nil;
    }
}

- (void)createConstraintsForPrimaryActions
{
    [self removeAllCustomConstraints];

    NSMutableArray *constraints = [NSMutableArray array];
    NSMutableArray *highlightActivatedConstraints = [NSMutableArray array];
    NSMutableArray *highlightDeactivatedConstraints = [NSMutableArray array];

    __block UIView *previousView = nil;
    __block UIButton *previousButton = nil;

    NSUInteger numberOfButtons = self.subviews.count;
    AAPLAction *defaultAction = self.actions.firstObject;

    // Enumerate the subviews in reverse. This means the default action will be the LAST item.
    [self.subviews enumerateObjectsUsingBlock:^(UIView *wrapper, NSUInteger viewIndex, BOOL *stop) {
        UIButton *button = wrapper.subviews.firstObject;
        AAPLAction *action = [self actionFromButton:button];

        BOOL isDefaultAction = (action == defaultAction);
        BOOL isLastAction = (viewIndex == 0);

        // Set the height and vertical alignment of the wrapper
        [constraints addObject:[NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

        // Constrain the vertical size & position of the button within the wrapper
        [constraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:wrapper attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:wrapper attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:wrapper attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
        if (previousButton) {
            NSLayoutConstraint *buttonWidth = [NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:previousButton attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
            [constraints addObject:buttonWidth];
        }

        NSLayoutConstraint *wrapperWidth;
        wrapperWidth = [NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeWidth multiplier:1.0/numberOfButtons constant:0];
        wrapperWidth.priority = UILayoutPriorityDefaultHigh;
        [constraints addObject:wrapperWidth];

        NSLayoutConstraint *leadingConstraint;

        NSLayoutConstraint *highlightLeadingConstraint = [NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
        [highlightActivatedConstraints addObject:highlightLeadingConstraint];

        if (isDefaultAction) {

            if (previousView) {
                // The leading constraint to the trailing edge of the previous view is not QUITE required.
                leadingConstraint = [NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:previousView attribute:NSLayoutAttributeRight multiplier:1 constant:0];
                leadingConstraint.priority = UILayoutPriorityRequired - 10;

                // When highlighting the default button, we'll break the leading/trailing constraint to prevent the other buttons from pushing over.
                [highlightDeactivatedConstraints addObject:leadingConstraint];
            }


            // Default action also needs its trailing edge tied to the trailing edge of the container
            [constraints addObject:[NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
        }
        else if (isLastAction) {
            // The last action has its leading edge tied to the leading edge of the view, but we need to be able to break this so we can push all the actions off the screen.
            leadingConstraint = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:wrapper attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
            leadingConstraint.priority = UILayoutPriorityDefaultHigh - 10;

            // When we're highlighting the default button, we're going to deactivate the leading constraint on the last action. This will prevent it from animating all the way over to the left.
            [highlightDeactivatedConstraints addObject:leadingConstraint];
        }
        else if (previousView) {
            // Tie the leading edge of this view to the trailing edge of the previous view.
            leadingConstraint = [NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:previousView attribute:NSLayoutAttributeRight multiplier:1 constant:0];
        }

        if (leadingConstraint)
            [constraints addObject:leadingConstraint];

        if (isLastAction) {
            // Require the left edge of the container to always be to the left of the wrapper.
            NSLayoutConstraint *lastLeft = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationLessThanOrEqual toItem:wrapper attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
            [constraints addObject:lastLeft];
        }

        previousView = wrapper;
        previousButton = button;
    }];


    [NSLayoutConstraint activateConstraints:constraints];
    _editConstraints = constraints;
    _highlightActivatedConstraints = highlightActivatedConstraints;
    _highlightDeactivatedConstraints = highlightDeactivatedConstraints;

    if (_highlightDefaultAction) {
        [NSLayoutConstraint deactivateConstraints:_highlightDeactivatedConstraints];
        [NSLayoutConstraint activateConstraints:_highlightActivatedConstraints];
    }
    else {
        [NSLayoutConstraint deactivateConstraints:_highlightActivatedConstraints];
        [NSLayoutConstraint activateConstraints:_highlightDeactivatedConstraints];
    }
}

- (void)createConstraintsForSecondaryActions
{
    [self removeAllCustomConstraints];

    NSMutableArray *constraints = [NSMutableArray array];
    NSMutableArray *highlightActivatedConstraints = [NSMutableArray array];
    NSMutableArray *highlightDeactivatedConstraints = [NSMutableArray array];

    __block UIView *previousView = nil;
    __block UIButton *previousButton = nil;

    NSUInteger numberOfButtons = self.subviews.count;
    AAPLAction *defaultAction = self.actions.firstObject;

    // Enumerate the subviews in reverse. This means the default action will be the LAST item.
    [self.subviews enumerateObjectsUsingBlock:^(UIView *wrapper, NSUInteger viewIndex, BOOL *stop) {
        UIButton *button = wrapper.subviews.firstObject;
        AAPLAction *action = [self actionFromButton:button];

        BOOL isDefaultAction = (action == defaultAction);
        BOOL isLastAction = (viewIndex == 0);

        // Set the height and vertical alignment of the wrapper
        [constraints addObject:[NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

        // Constrain the vertical size & position of the button within the wrapper
        [constraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:wrapper attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:wrapper attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:wrapper attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
        if (previousButton) {
            NSLayoutConstraint *buttonWidth = [NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:previousButton attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
            [constraints addObject:buttonWidth];
            [highlightDeactivatedConstraints addObject:buttonWidth];
        }

        NSLayoutConstraint *wrapperWidth;
        wrapperWidth = [NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeWidth multiplier:1.0/numberOfButtons constant:0];
        wrapperWidth.priority = UILayoutPriorityDefaultHigh;
        [constraints addObject:wrapperWidth];

        // Wrapper can't get bigger than the button
        NSLayoutConstraint *wrapperMaxWidth = [NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationLessThanOrEqual toItem:button attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
        [constraints addObject:wrapperMaxWidth];

        [highlightDeactivatedConstraints addObject:wrapperMaxWidth];

        NSLayoutConstraint *leadingConstraint;

        if (isDefaultAction) {

            if (previousView) {
                // The leading constraint to the trailing edge of the previous view is not QUITE required.
                leadingConstraint = [NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:previousView attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
                leadingConstraint.priority = UILayoutPriorityRequired - 10;

                // When highlighting the default button, we'll break the leading/trailing constraint to prevent the other buttons from pushing over.
                [highlightDeactivatedConstraints addObject:leadingConstraint];
            }

            NSLayoutConstraint *highlightLeadingConstraint = [NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1 constant:0];
            [highlightActivatedConstraints addObject:highlightLeadingConstraint];

            // Default action also needs its trailing edge tied to the trailing edge of the container
            [constraints addObject:[NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
        }
        else if (isLastAction) {
            // The last action has its leading edge tied to the leading edge of the view, but we need to be able to break this so we can push all the actions off the screen.
            leadingConstraint = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:wrapper attribute:NSLayoutAttributeRight multiplier:1 constant:0];
            leadingConstraint.priority = UILayoutPriorityDefaultHigh - 10;

            // When we're highlighting the default button, we're going to deactivate the leading constraint on the last action. This will prevent it from animating all the way over to the left.
            [highlightDeactivatedConstraints addObject:leadingConstraint];
        }
        else if (previousView) {
            // Tie the leading edge of this view to the trailing edge of the previous view.
            leadingConstraint = [NSLayoutConstraint constraintWithItem:wrapper attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:previousView attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
        }

        if (leadingConstraint)
            [constraints addObject:leadingConstraint];

        previousView = wrapper;
        previousButton = button;
    }];


    [NSLayoutConstraint activateConstraints:constraints];
    _editConstraints = constraints;
    _highlightActivatedConstraints = highlightActivatedConstraints;
    _highlightDeactivatedConstraints = highlightDeactivatedConstraints;

    if (_highlightDefaultAction) {
        [NSLayoutConstraint deactivateConstraints:_highlightDeactivatedConstraints];
        [NSLayoutConstraint activateConstraints:_highlightActivatedConstraints];
    }
    else {
        [NSLayoutConstraint deactivateConstraints:_highlightActivatedConstraints];
        [NSLayoutConstraint activateConstraints:_highlightDeactivatedConstraints];
    }
}

- (void)createConstraints
{
    if (self.swipeType == AAPLCollectionViewCellSwipeTypePrimary)
        [self createConstraintsForPrimaryActions];
    else
        [self createConstraintsForSecondaryActions];
}

- (void)setSwipeType:(AAPLCollectionViewCellSwipeType)swipeType
{
    if (_swipeType == swipeType)
        return;

    _swipeType = swipeType;
    [self createConstraints];
}

- (void)setActions:(NSArray *)actions
{
    if (actions == _actions || [actions isEqualToArray:_actions])
        return;

    _actions = [actions copy];

    [self createSubviewsForActions:_actions];
}

- (AAPLAction *)actionFromButton:(UIButton *)button
{
    NSUInteger actionIndex = button.tag;
    AAPLAction *action = self.actions[actionIndex];
    return action;
}

- (void)setHighlightDefaultAction:(BOOL)highlightDefaultAction
{
    if (highlightDefaultAction == _highlightDefaultAction)
        return;

    _highlightDefaultAction = highlightDefaultAction;
    if (_highlightDefaultAction) {
        [NSLayoutConstraint deactivateConstraints:_highlightDeactivatedConstraints];
        [NSLayoutConstraint activateConstraints:_highlightActivatedConstraints];
    }
    else {
        [NSLayoutConstraint deactivateConstraints:_highlightActivatedConstraints];
        [NSLayoutConstraint activateConstraints:_highlightDeactivatedConstraints];
    }
}

- (void)didTapMoreAction:(UIButton *)sender
{
    [self.cell performMoreAction];
}

- (void)didTapEditAction:(UIButton *)sender
{
    AAPLAction *action = [self actionFromButton:sender];
    self.userInteractionEnabled = NO; // is reenabled when shown again
    [self.cell performAction:action];
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
    // reset layout margins
    self.layoutMargins = UIEdgeInsetsMake(8, 15, 8, 15);

    UIView *contentView = [super contentView];

    _privateContentView = [[UIView alloc] initWithFrame:contentView.bounds];
    _privateContentView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:_privateContentView];

    NSMutableArray *constraints = [NSMutableArray array];

    _editActionsView = [[AAPLActionsView alloc] initWithFrame:CGRectZero cell:self];
    _editActionsView.translatesAutoresizingMaskIntoConstraints = NO;

    [constraints addObject:[NSLayoutConstraint constraintWithItem:_privateContentView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];

    _contentHeightConstraint = [NSLayoutConstraint constraintWithItem:_privateContentView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeHeight multiplier:1 constant:0];
    [constraints addObject:_contentHeightConstraint];

    _contentWidthConstraint = [NSLayoutConstraint constraintWithItem:_privateContentView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
    [constraints addObject:_contentWidthConstraint];

    _contentLeftConstraint = [NSLayoutConstraint constraintWithItem:_privateContentView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
    [constraints addObject:_contentLeftConstraint];

    [contentView addConstraints:constraints];

    _topHairline = [AAPLHairlineView hairlineViewForAlignment:AAPLHairlineAlignmentHorizontal];
    _topHairline.translatesAutoresizingMaskIntoConstraints = NO;
    _topHairline.alpha = 0;

    _bottomHairline = [AAPLHairlineView hairlineViewForAlignment:AAPLHairlineAlignmentHorizontal];
    _bottomHairline.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomHairline.alpha = 0;

    _removeImageView = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"AAPLRemoveControl"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _removeImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [_removeImageView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_removeImageView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _reorderImageView = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"AAPLDragGrabber"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _reorderImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [_reorderImageView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_reorderImageView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    contentView.clipsToBounds = YES;
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.deletePending = NO;
    self.swipePastBounds = NO;
    self.editing = NO;
    self.swipeTranslation = 0;
    if (_deletionConstraints) {
        [NSLayoutConstraint deactivateConstraints:_deletionConstraints];
        [NSLayoutConstraint activateConstraints:_actionsConstraints];
        _deletionConstraints = nil;
    }
}

- (void)setLayoutMargins:(UIEdgeInsets)layoutMargins
{
    self.contentView.layoutMargins = layoutMargins;
    [super setLayoutMargins:layoutMargins];
}

- (UIColor *)separatorColor
{
    return _topHairline.backgroundColor;
}

- (void)setSeparatorColor:(UIColor *)separatorColor
{
    _topHairline.backgroundColor = separatorColor;
    _bottomHairline.backgroundColor = separatorColor;
}

- (CGRect)removeControlRect
{
    if (!_removeImageView.superview)
        return CGRectZero;

    CGRect rect = [self convertRect:_removeImageView.bounds fromView:_removeImageView];
    return CGRectInset(rect, -self.layoutMargins.left, -self.layoutMargins.top);
}

- (CGRect)reorderControlRect
{
    if (![self shouldShowReorderControl])
        return CGRectZero;

    CGRect rect = [self convertRect:_reorderImageView.bounds fromView:_reorderImageView];
    return CGRectInset(rect, -self.layoutMargins.right, -self.layoutMargins.top);
}

- (CGRect)actionsViewRect
{
    if (!_editActionsView.superview)
        return CGRectZero;

    CGRect rect = [self convertRect:_editActionsView.bounds fromView:_editActionsView];
    return rect;
}

- (UIView *)contentView
{
    return _privateContentView;
}

- (CGFloat)minimumSwipeTrackingPosition
{
    return -_editActionsView.maximumWidth;
}

- (void)beginSwipeWithPosition:(CGPoint)position velocity:(CGFloat)velocity
{
    self.swipeInitialFramePosition = _privateContentView.frame.origin.x;
    self.swipeStartPosition = position;
    self.swipePastBounds = NO;

    [self showActionsViewWithSwipeType:self.swipeType];
    [self layoutSubviews];
    [UIView performWithoutAnimation:^{
        [self updateSwipeWithPosition:position velocity:velocity];
    }];
}

- (void)updateSwipeWithPosition:(CGPoint)touchPosition velocity:(CGFloat)velocity
{
    NSAssert(!_editing, @"Shouldn't be swiping while editing");

    // Check for full open
    CGRect frame = _privateContentView.frame;
    CGFloat width = CGRectGetWidth(frame);
    CGFloat totalTranslation = touchPosition.x - self.swipeStartPosition.x;

    BOOL highlightingDefaultAction = self.editActionsView.highlightDefaultAction;
    UIEdgeInsets layoutMargins = self.layoutMargins;
    CGFloat leftMargin = layoutMargins.left;

    CGFloat origin = (self.swipePastBounds ? leftMargin - width : _swipeInitialFramePosition);
    CGFloat newTranslation = origin + totalTranslation;

    if (self.swipeType == AAPLCollectionViewCellSwipeTypePrimary) {
        CGFloat translatedRight = width + newTranslation;
        CGFloat leftBuffer = leftMargin;
        CGFloat breakPoint = ABS(self.minimumSwipeTrackingPosition) + leftMargin;

        if (velocity < 0) {
            if (!highlightingDefaultAction) {

                newTranslation = totalTranslation * (1 + log10(translatedRight/breakPoint));

                if (translatedRight < breakPoint || touchPosition.x < leftBuffer) {
                    // Highlight the default button after we swipe past the mid-point and animate all the way over to the left margin
                    self.swipePastBounds = YES;
                    self.originalStartPosition = self.swipeStartPosition;
                    self.swipeStartPosition = touchPosition;
                    newTranslation = leftMargin - width;
                    highlightingDefaultAction = YES;
                }
            }
            else {
                // clamp the translation, because we just don't want things getting out of hand.
                newTranslation = MAX(newTranslation, - (width + leftMargin));
            }
        }
        else if (velocity > 0) {
            if (highlightingDefaultAction) {
                newTranslation = MAX(newTranslation, - (width + leftMargin));

                if (translatedRight > leftMargin) {
                    // We're not going to highlight the default action any more, but leave the translation alone
                    highlightingDefaultAction = NO;
                }
            }
        }
    }
    else if (self.swipeType == AAPLCollectionViewCellSwipeTypeSecondary) {
        CGFloat translatedLeft = newTranslation;
        CGFloat breakPoint = width/2;

        if (velocity > 0 && !highlightingDefaultAction && translatedLeft > breakPoint) {
            highlightingDefaultAction = YES;
        }
        else if (velocity < 0 && highlightingDefaultAction && translatedLeft < breakPoint) {
            highlightingDefaultAction = NO;
        }
    }

    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionLayoutSubviews animations:^{
        self.swipeVelocity = velocity;
        self.editActionsView.highlightDefaultAction = highlightingDefaultAction;
        self.swipeTranslation = newTranslation;
        [self layoutIfNeeded];
    } completion:nil];
}

- (BOOL)endSwipeWithPosition:(CGPoint)position
{
    CGFloat translation = position.x - self.swipeStartPosition.x;

    const CGFloat movementThreshold = 44.0;

    CGFloat velocityX = self.swipeVelocity;
    CGFloat xPosition = self.swipeTranslation;
    CGFloat targetX = self.minimumSwipeTrackingPosition;
    CGFloat adjustedMovementThreshold = movementThreshold * log10(ABS(velocityX));

    BOOL highlightingDefaultAction = self.editActionsView.highlightDefaultAction;

    // If we're still highlighting the default action, perform its action.
    if (highlightingDefaultAction)
        [self performAction:self.editActions.firstObject];

    BOOL keepOpen = NO;

    // We keep the actions open if we've swiped farther than the movement threshold or if the left edge of the actions is past the target X position.
    if (AAPLCollectionViewCellSwipeTypePrimary == self.swipeType)
        keepOpen = ABS(translation) > adjustedMovementThreshold || (targetX > xPosition);
    else
        keepOpen = ABS(translation) > adjustedMovementThreshold || (ABS(targetX) < xPosition);

    return keepOpen && !highlightingDefaultAction;
}

- (void)performMoreAction
{
    [self aapl_sendAction:@selector(presentAlertSheetFromCell:)];
}

- (void)performAction:(AAPLAction *)action
{
    SEL selector = action.selector;
    if (!selector)
        return;

    [self aapl_sendAction:selector];
    [self aapl_sendAction:@selector(didSelectActionFromCell:)];
}

- (void)prepareForInteractiveRemoval
{
    _deletePending = YES;

    CGRect frame = _privateContentView.frame;
    CGFloat width = CGRectGetWidth(frame);
    CGFloat height = CGRectGetHeight(frame);

    UIView *contentView = [super contentView];
    AAPLActionsView *actionView = self.editActionsView;
    NSMutableArray *constraints = [NSMutableArray array];

    [constraints addObject:[NSLayoutConstraint constraintWithItem:actionView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:actionView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:height]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:actionView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeTop multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:actionView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_privateContentView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:height]];
    _deletionConstraints = constraints;

    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionLayoutSubviews animations:^{
        self.contentHeightConstraint.active = NO;
        [NSLayoutConstraint deactivateConstraints:self.actionsConstraints];
        [NSLayoutConstraint activateConstraints:constraints];
        self.editActionsView.highlightDefaultAction = YES;
        self.swipeTranslation = - width;
        [self layoutIfNeeded];
    } completion:nil];
}

- (void)showActionsViewWithSwipeType:(AAPLCollectionViewCellSwipeType)swipeType
{
    // Don't need to do this if the view is already visible
    if (_editActionsView.superview)
        return;

    UIView *contentView = [super contentView];

    if (swipeType != self.editActionsView.swipeType && self.actionsConstraints)
        [contentView removeConstraints:self.actionsConstraints];

    if (AAPLCollectionViewCellSwipeTypeSecondary == swipeType)
        _editActionsView.backgroundColor = self.theme.cellActionBackgroundColor;
    else
        _editActionsView.backgroundColor = self.backgroundColor;

    self.editActionsView.swipeType = swipeType;
    self.editActionsView.highlightDefaultAction = NO;
    [contentView addSubview:_editActionsView];
    [self updateActionsConstraints];
    [contentView addConstraints:self.actionsConstraints];
}

- (void)removeActionsView
{
    [self.editActionsView removeFromSuperview];
    self.actionsConstraints = nil;
}

- (CGFloat)swipeTranslation
{
    CGFloat x = _privateContentView.frame.origin.x;
    if (!_editing)
        return x;

    return x - CGRectGetWidth(_removeImageView.frame) - self.layoutMargins.left;
}

- (void)setSwipeTranslation:(CGFloat)swipeTranslation
{
    if (_editing)
        _contentLeftConstraint.constant = swipeTranslation + CGRectGetWidth(_removeImageView.frame) + self.layoutMargins.left;
    else
        _contentLeftConstraint.constant = swipeTranslation;
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

- (void)updateActionsConstraints
{
    UIView *contentView = [super contentView];
    NSMutableArray *constraints = [NSMutableArray array];

    // Add constraints for editActionsView
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeHeight multiplier:1 constant:0]];

    if (AAPLCollectionViewCellSwipeTypePrimary == _editActionsView.swipeType) {
        // Make the constraint that ties the actions view to the right edge of the content view just a little bit less than required. That way when the swipe pushes the cell off the right edge, we allow this constraint to be unsatisfied.
        NSLayoutConstraint *trailingAnchor = [NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeRight multiplier:1 constant:0];
        trailingAnchor.priority = UILayoutPriorityRequired - 10;
        [constraints addObject:trailingAnchor];

        if (self.editing && [self shouldShowReorderControl])
            [constraints addObject:[NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_reorderImageView attribute:NSLayoutAttributeRight multiplier:1 constant:self.layoutMargins.right]];
        else
            [constraints addObject:[NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_privateContentView attribute:NSLayoutAttributeRight multiplier:1 constant:0]];
    }
    else {
        // Make the constraint tieing the left edge of the actions view to the content view just a little bit less than required. When the swipe pushes the cell off the left edge, we allow this constraint to be unsatisfied.
        NSLayoutConstraint *leftAnchor = [NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:contentView attribute:NSLayoutAttributeLeft multiplier:1 constant:0];
        leftAnchor.priority = UILayoutPriorityRequired - 10;
        [constraints addObject:leftAnchor];

        [constraints addObject:[NSLayoutConstraint constraintWithItem:_editActionsView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_privateContentView attribute:NSLayoutAttributeLeft multiplier:1 constant:0]];
    }

    self.actionsConstraints = constraints;
}

- (NSArray *)editActions
{
    return _editActionsView.actions;
}

- (void)setEditActions:(NSArray *)editActions
{
    _editActionsView.actions = editActions;
}

- (void)showEditActions
{
    self.shouldDisplaySwipeToEditAccessories = YES;
}

- (void)hideEditActions
{
    self.shouldDisplaySwipeToEditAccessories = NO;
}

- (void)animateOutSwipeToEditAccessories
{
    self.shouldDisplaySwipeToEditAccessories = NO;
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

    if ([layoutAttributes isKindOfClass:[AAPLCollectionViewLayoutAttributes class]]) {
        AAPLCollectionViewLayoutAttributes *attributes = (AAPLCollectionViewLayoutAttributes *)layoutAttributes;
        self.theme = attributes.theme;
        if (!UIEdgeInsetsEqualToEdgeInsets(attributes.layoutMargins, UIEdgeInsetsZero))
            self.layoutMargins = attributes.layoutMargins;
        else
            self.layoutMargins = self.theme.listLayoutMargins;

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

- (void)closeActionPaneAnimated:(BOOL)animated completionHandler:(void(^)(BOOL finished))handler
{
    AAPLCollectionViewCellSwipeType swipeType = self.editActionsView.swipeType;
    BOOL shouldRotate = ABS(self.swipeTranslation) > 0;

    if (_deletePending)
        return;

    dispatch_block_t shut = ^{
        self.swipeTranslation = 0;
        if (_editing && shouldRotate)
            [self rotateRemoveControl];
        [self layoutIfNeeded];
    };

    void (^done)(BOOL finished) = ^(BOOL finished) {
        [self hideEditActions];
        [self removeActionsView];
        _privateContentView.userInteractionEnabled = YES;
        _editActionsView.userInteractionEnabled = NO;
        self.editActions = nil;
        self.swipeInitialFramePosition = 0;

        if (handler)
            handler(finished);
    };

    if (animated) {
        CGFloat targetTranslation = (AAPLCollectionViewCellSwipeTypePrimary == swipeType ? -self.swipeTranslation : self.swipeTranslation);

        CGFloat totalDistance = targetTranslation;
        CGFloat duration = 0.25;
        CGFloat springVelocity = ABS(self.swipeVelocity) * duration / totalDistance;

        [UIView animateWithDuration:duration delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:springVelocity options:UIViewAnimationOptionBeginFromCurrentState animations:shut completion:done];
    }
    else {
        shut();
        done(YES);
    }
}

- (void)openActionPaneAnimated:(BOOL)animated completionHandler:(void (^)(BOOL finished))handler
{
    AAPLCollectionViewCellSwipeType swipeType = self.editActionsView.swipeType;

    if (_editing || AAPLCollectionViewCellSwipeTypeNone == swipeType)
        swipeType = AAPLCollectionViewCellSwipeTypePrimary;

    [self showEditActions];
    [self showActionsViewWithSwipeType:swipeType];
    [self setNeedsLayout];
    [self layoutIfNeeded];

    _privateContentView.userInteractionEnabled = NO;
    _editActionsView.userInteractionEnabled = YES;

    CGFloat targetTranslation = (AAPLCollectionViewCellSwipeTypePrimary == swipeType ? self.minimumSwipeTrackingPosition : -self.minimumSwipeTrackingPosition);

    if (animated) {
        CGFloat totalDistance = self.swipeTranslation - targetTranslation;
        CGFloat duration = 0.25;
        CGFloat springVelocity = ABS(self.swipeVelocity) * duration / totalDistance;

        [UIView animateWithDuration:duration delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:springVelocity options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.swipeTranslation = targetTranslation;
            if (_editing)
                [self rotateRemoveControl];
            [self layoutIfNeeded];
        } completion:handler];
    }
    else {
        if (_editing)
            [self rotateRemoveControl];
        self.swipeTranslation = self.minimumSwipeTrackingPosition;
        if (handler)
            handler(YES);
    }
}

- (void)showEditingControls
{
    NSMutableArray *constraints = [NSMutableArray array];

    UIView *superContentView = [super contentView];

    CGFloat editingWidth = 0;
    _removeImageView.tintColor = self.theme.destructiveActionColor;
    [superContentView addSubview:_removeImageView];

    CGFloat removeWidth = _removeImageView.image.size.width;

    [constraints addObject:[NSLayoutConstraint constraintWithItem:_removeImageView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:superContentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_removeImageView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:_privateContentView attribute:NSLayoutAttributeLeading multiplier:1 constant:0]];

    editingWidth += removeWidth + self.layoutMargins.left;

    if ([self shouldShowReorderControl]) {
        _reorderImageView.tintColor = self.theme.lightGreyTextColor;
        [superContentView addSubview:_reorderImageView];

        [constraints addObject:[NSLayoutConstraint constraintWithItem:_reorderImageView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:superContentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:_reorderImageView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:_privateContentView attribute:NSLayoutAttributeTrailing multiplier:1 constant:0]];

        editingWidth += _reorderImageView.image.size.width + self.layoutMargins.right;
    }

    _editingConstraints = constraints;
    [superContentView addConstraints:constraints];

    [self setNeedsLayout];
    [self layoutIfNeeded];

    _contentLeftConstraint.constant = removeWidth + self.layoutMargins.left;
    _contentWidthConstraint.constant = -editingWidth;
    [self setNeedsLayout];

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

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    if (![layoutAttributes isKindOfClass:[AAPLCollectionViewLayoutAttributes class]])
        return layoutAttributes;

    AAPLCollectionViewLayoutAttributes *attributes = (AAPLCollectionViewLayoutAttributes *)layoutAttributes;
    if (!attributes.shouldCalculateFittingSize)
        return layoutAttributes;

    [self layoutSubviews];
    CGRect frame = attributes.frame;

    CGSize fittingSize = CGSizeMake(frame.size.width, UILayoutFittingCompressedSize.height);
    frame.size = [self systemLayoutSizeFittingSize:fittingSize withHorizontalFittingPriority:UILayoutPriorityDefaultHigh verticalFittingPriority:UILayoutPriorityFittingSizeLevel];

    AAPLCollectionViewLayoutAttributes *newAttributes = [attributes copy];
    newAttributes.frame = frame;
    return newAttributes;
}

- (void)invalidateCollectionViewLayout
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(appl_invalidateCollectionViewLayout) object:nil];
    [self performSelector:@selector(appl_invalidateCollectionViewLayout) withObject:nil afterDelay:0.0];
}

- (void)appl_invalidateCollectionViewLayout
{
    UICollectionView *collectionView = (UICollectionView *)self.superview;
    
    while (collectionView && ![collectionView isKindOfClass:[UICollectionView class]])
        collectionView = (UICollectionView *)collectionView.superview;
    
    if (!collectionView)
        return;
    
    UICollectionViewLayout *layout = collectionView.collectionViewLayout;
    
    NSIndexPath *indexPath = [collectionView indexPathForCell:self];
    if (!indexPath)
        return;
    
    AAPLCollectionViewLayoutInvalidationContext *context = [[[[layout class] invalidationContextClass] alloc] init];
    context.invalidateMetrics = YES;
    [context invalidateItemsAtIndexPaths:@[indexPath]];
    [layout invalidateLayoutWithContext:context];
}
@end
