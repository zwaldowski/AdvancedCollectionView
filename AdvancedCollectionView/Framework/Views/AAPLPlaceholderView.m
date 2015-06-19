/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Various placeholder views.
 */

#import "AAPLPlaceholderView.h"
#import "AAPLCollectionViewLayout_Private.h"
#import "AAPLTheme.h"

@interface AAPLPlaceholderView ()
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) NSArray *constraints;
@end

@implementation AAPLPlaceholderView

- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title message:(NSString *)message image:(UIImage *)image buttonTitle:(NSString *)buttonTitle buttonAction:(dispatch_block_t)buttonAction
{
    self = [super initWithFrame:frame];
    if (!self)
        return self;

    _title = [title copy];
    _message = [message copy];
    _image = image;

    if (buttonTitle && buttonAction) {
        NSAssert(message != nil, @"a message must be provided when using a button");
        _buttonTitle = [buttonTitle copy];
        _buttonAction = [buttonAction copy];
    }
    
    self.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    _containerView = [[UIView alloc] initWithFrame:CGRectZero];
    _containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_containerView];
    
    _imageView = [[UIImageView alloc] initWithImage:_image];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_imageView];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.backgroundColor = nil;
    _titleLabel.opaque = NO;
    _titleLabel.font = [UIFont systemFontOfSize:27];
    _titleLabel.numberOfLines = 0;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_titleLabel];

    _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.opaque = NO;
    _messageLabel.backgroundColor = nil;
    _messageLabel.numberOfLines = 0;
    _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_containerView addSubview:_messageLabel];

    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _actionButton.contentEdgeInsets = UIEdgeInsetsMake(4, 16, 4, 16);
    _actionButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    UIImage *backgroudImage = [UIImage imageNamed:@"BorderedButtonBackground" inBundle:bundle compatibleWithTraitCollection:nil];
    [_actionButton setBackgroundImage:backgroudImage forState:UIControlStateNormal];
    [_actionButton addTarget:self action:@selector(actionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_actionButton];

    [self updateViewHierarchy];

    // Constrain the container to the host view. The height of the container will be determined by the contents.
    NSMutableArray *constraints = [NSMutableArray array];

    [constraints addObject:[NSLayoutConstraint constraintWithItem:_containerView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_containerView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0]];
    [constraints addObject:[NSLayoutConstraint constraintWithItem:_actionButton attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:124]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        // _containerView should be no more than 418pt and the left and right padding should be no less than 30pt on both sides
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=30)-[_containerView(<=418)]-(>=30)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_containerView)]];
    else
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-30-[_containerView]-30-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_containerView)]];

    [self addConstraints:constraints];
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame title:nil message:nil image:nil buttonTitle:nil buttonAction:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [super initWithCoder:aDecoder];
}

- (void)updateViewHierarchy
{
    if (_image) {
        [_containerView addSubview:_imageView];
        _imageView.image = _image;
    }
    else
        [_imageView removeFromSuperview];

    if (_title) {
        [_containerView addSubview:_titleLabel];
        _titleLabel.text = _title;
    }
    else
        [_titleLabel removeFromSuperview];

    if (_message) {
        [_containerView addSubview:_messageLabel];
        _messageLabel.text = _message;
    }
    else
        [_messageLabel removeFromSuperview];

    if (_buttonTitle) {
        [_containerView addSubview:_actionButton];
        [_actionButton setTitle:_buttonTitle forState:UIControlStateNormal];
    }
    else {
        [_actionButton removeFromSuperview];
    }

    if (_constraints)
        [_containerView removeConstraints:_constraints];
    _constraints = nil;
    [self setNeedsUpdateConstraints];
}

- (void)setImage:(UIImage *)image
{
    if ([image isEqual:_image])
        return;

    _image = image;
    [self updateViewHierarchy];
}

- (void)setTitle:(NSString *)title
{
    NSAssert(title && [title length], @"Title cannot be nil or empty");

    if ([title isEqualToString:_title])
        return;

    _title = [title copy];

    [self updateViewHierarchy];
}

- (void)setMessage:(NSString *)message
{
    if ([message isEqualToString:_message])
        return;

    _message = [message copy];

    [self updateViewHierarchy];
}

- (void)setButtonTitle:(NSString *)buttonTitle
{
    if ([buttonTitle isEqualToString:_buttonTitle])
        return;

    _buttonTitle = [buttonTitle copy];

    [self updateViewHierarchy];
}

- (void)setTheme:(AAPLTheme *)theme
{
    if (_theme == theme) { return; }
    _theme = theme;
    
    UIColor *tintColor = theme.lightGreyTextColor;
    
    self.titleLabel.textColor = theme.lightGreyTextColor;
    
    self.messageLabel.textColor = tintColor;
    self.messageLabel.font = theme.largeBodyFont;
    
    self.actionButton.tintColor = tintColor;
    self.actionButton.titleLabel.font = theme.sectionHeaderSmallFont;
}

- (void)actionButtonPressed:(id)sender
{
    if (self.buttonAction)
        self.buttonAction();
}

- (void)updateConstraints
{
    if (_constraints) {
        [super updateConstraints];
        return;
    }

    NSMutableArray *constraints = [NSMutableArray array];

    NSDictionary *views = NSDictionaryOfVariableBindings(_imageView, _titleLabel, _messageLabel, _actionButton);
    UIView *last = _containerView;
    NSLayoutAttribute lastAttr = NSLayoutAttributeTop;
    CGFloat constant = 0;

    if (_imageView.superview) {
        // Force the container to be at least as wide as the image
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(>=0)-[_imageView]-(>=0)-|" options:0 metrics:nil views:views]];
        // horizontally center the image
        [constraints addObject:[NSLayoutConstraint constraintWithItem:_imageView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_containerView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
        // aligned with the top of the container
        [constraints addObject:[NSLayoutConstraint constraintWithItem:_imageView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_containerView attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];

        last = _imageView;
        lastAttr = NSLayoutAttributeBottom;
        constant = 12; // spec calls for 20pt space, but when set to 20pt, there's 25pts of space between the bottom of the image and the top of the text.
    }

    if (_titleLabel.superview) {
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_titleLabel]|" options:0 metrics:nil views:views]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:_titleLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:last attribute:lastAttr multiplier:1.0 constant:constant]];

        last = _titleLabel;
        lastAttr = NSLayoutAttributeBaseline;
        constant = 12; // spec calls for 20pt space, but when set to 20pt, there's 25pts of space between the baseline of the title and the message.
    }

    if (_messageLabel.superview) {
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_messageLabel]|" options:0 metrics:nil views:views]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:_messageLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:last attribute:lastAttr multiplier:1.0 constant:constant]];

        last = _messageLabel;
        lastAttr = NSLayoutAttributeBaseline;
        constant = 30;
    }

    if (_actionButton.superview) {
        [constraints addObject:[NSLayoutConstraint constraintWithItem:_actionButton attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:last attribute:lastAttr multiplier:1.0 constant:constant]];
        [constraints addObject:[NSLayoutConstraint constraintWithItem:_actionButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_containerView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];

        last = _actionButton;
    }

    // link the bottom of the last view with the bottom of the container to provide the size of the container
    [constraints addObject:[NSLayoutConstraint constraintWithItem:last attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_containerView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];

    [_containerView addConstraints:constraints];
    _constraints = constraints;

    [super updateConstraints];
}

@end


@interface AAPLCollectionPlaceholderView ()
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, strong) AAPLPlaceholderView *placeholderView;
@end

@implementation AAPLCollectionPlaceholderView

- (void)showActivityIndicator:(BOOL)show
{
    if (!_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _activityIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
        _activityIndicatorView.color = [UIColor lightGrayColor];
        // The activity indicator can expand but not compress
        [_activityIndicatorView setContentHuggingPriority:UILayoutPriorityFittingSizeLevel forAxis:UILayoutConstraintAxisHorizontal];
        [_activityIndicatorView setContentHuggingPriority:UILayoutPriorityFittingSizeLevel forAxis:UILayoutConstraintAxisVertical];

        [self addSubview:_activityIndicatorView];
        NSMutableArray *constraints = [NSMutableArray array];
        NSDictionary *views = NSDictionaryOfVariableBindings(_activityIndicatorView);

        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_activityIndicatorView]|" options:0 metrics:nil views:views]];
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_activityIndicatorView]|" options:0 metrics:nil views:views]];

        [self addConstraints:constraints];
    }

    _activityIndicatorView.hidden = !show;

    if (show)
        [_activityIndicatorView startAnimating];
    else
        [_activityIndicatorView stopAnimating];
}

- (void)hidePlaceholderAnimated:(BOOL)animated
{
    AAPLPlaceholderView *placeholderView = _placeholderView;

    if (!placeholderView)
        return;

    if (animated) {

        [UIView animateWithDuration:0.25 animations:^{
            placeholderView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [placeholderView removeFromSuperview];
            // If it's still the current placeholder, get rid of it
            if ([self.placeholderView isEqual:placeholderView]) {
                self.placeholderView = nil;
            }
        }];
    }
    else {
        [UIView performWithoutAnimation:^{
            [placeholderView removeFromSuperview];
            if ([self.placeholderView isEqual:placeholderView]) {
                self.placeholderView = nil;
            }
        }];
    }
}

- (void)showPlaceholderWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image animated:(BOOL)animated
{
    AAPLPlaceholderView *oldPlaceHolder = self.placeholderView;

    if (oldPlaceHolder && [oldPlaceHolder.title isEqualToString:title] && [oldPlaceHolder.message isEqualToString:message])
        return;

    [self showActivityIndicator:NO];
    
    AAPLPlaceholderView *newPlaceholderView = [[AAPLPlaceholderView alloc] initWithFrame:CGRectZero title:title message:message image:image buttonTitle:@"Test" buttonAction:^{
        NSLog(@"UGh");
    }];
    newPlaceholderView.alpha = 0.0;
    newPlaceholderView.translatesAutoresizingMaskIntoConstraints = NO;
    [self insertSubview:newPlaceholderView atIndex:0];
    self.placeholderView = newPlaceholderView;

    NSMutableArray *constraints = [NSMutableArray array];
    NSDictionary *views = NSDictionaryOfVariableBindings(_placeholderView);

    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_placeholderView]|" options:0 metrics:nil views:views]];
    [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_placeholderView]|" options:0 metrics:nil views:views]];

    [NSLayoutConstraint activateConstraints:constraints];

    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{
            newPlaceholderView.alpha = 1.0;
            oldPlaceHolder.alpha = 0.0;
        } completion:^(BOOL finished) {
            [oldPlaceHolder removeFromSuperview];
        }];
    }
    else {
        [UIView performWithoutAnimation:^{
            newPlaceholderView.alpha = 1.0;
            oldPlaceHolder.alpha = 0.0;
            [oldPlaceHolder removeFromSuperview];
        }];
    }
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    [super applyLayoutAttributes:layoutAttributes];
    self.hidden = layoutAttributes.hidden;
    
    if ([layoutAttributes isKindOfClass:AAPLCollectionViewLayoutAttributes.class]) {
        AAPLCollectionViewLayoutAttributes *attributes = (AAPLCollectionViewLayoutAttributes *)layoutAttributes;
        self.placeholderView.theme = attributes.theme;
    }
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    if (![layoutAttributes isKindOfClass:[AAPLCollectionViewLayoutAttributes class]])
        return layoutAttributes;

    AAPLCollectionViewLayoutAttributes *attributes = (AAPLCollectionViewLayoutAttributes *)layoutAttributes;

    [self layoutIfNeeded];
    CGRect frame = attributes.frame;

    CGSize fittingSize = CGSizeMake(frame.size.width, UILayoutFittingCompressedSize.height);
    frame.size = [self systemLayoutSizeFittingSize:fittingSize withHorizontalFittingPriority:UILayoutPriorityDefaultHigh verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    
    AAPLCollectionViewLayoutAttributes *newAttributes = [attributes copy];
    newAttributes.frame = frame;
    return newAttributes;
}
@end

