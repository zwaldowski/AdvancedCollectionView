/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A cell for displaying key value items.
 */

#import "AAPLKeyValueCell.h"
#import "UIView+Helpers.h"
#import "AAPLLabel.h"
#import "AAPLTheme.h"

#define TITLE_WIDTH_PHONE 80
#define TITLE_WIDTH_PAD 120
#define TITLE_TRAILING_MARGIN 15
#define MAX_NUMBER_OF_VALUE_LINES 3

@interface AAPLKeyValueCell () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) AAPLLabel *valueLabel;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic) BOOL shouldLayoutRTL;
@property (nonatomic, strong) NSArray *constraints;
@property (nonatomic, strong) UITapGestureRecognizer *recognizer;
@property (nonatomic) SEL action;
@end

@implementation AAPLKeyValueCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeCurrentLocaleDidChangeNotification:) name:NSCurrentLocaleDidChangeNotification object:nil];

    // Need to know whether we're dealing with a RTL language in order to know whether the label should be right aligned or left aligned. Unfortunately, there is no anti-natural alignment.
    [self updateShouldLayoutRTL];

    UIView *contentView = self.contentView;

    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);

    // Initial value for title column width.
    _titleColumnWidth = (isPad ? TITLE_WIDTH_PAD : TITLE_WIDTH_PHONE);

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.textAlignment = _shouldLayoutRTL ? NSTextAlignmentLeft : NSTextAlignmentRight;
    _titleLabel.numberOfLines = 1;
    [contentView addSubview:_titleLabel];

    _valueLabel = [[AAPLLabel alloc] initWithFrame:CGRectZero];
    _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _valueLabel.textAlignment = _shouldLayoutRTL ? NSTextAlignmentRight : NSTextAlignmentLeft;
    _valueLabel.numberOfLines = MAX_NUMBER_OF_VALUE_LINES;
    _valueLabel.lineBreakMode = NSLineBreakByWordWrapping;

    _button = [UIButton buttonWithType:UIButtonTypeSystem];
    _button.translatesAutoresizingMaskIntoConstraints = NO;
    _button.titleLabel.font = _titleLabel.font;
    [_button setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    _recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(urlTapped:)];
    _recognizer.enabled = NO;
    _recognizer.delegate = self;
    [self addGestureRecognizer:_recognizer];

    return self;
}

- (void)dealloc
{
    _recognizer.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSCurrentLocaleDidChangeNotification object:nil];
}

- (void)updateShouldLayoutRTL
{
    _shouldLayoutRTL = ([NSLocale characterDirectionForLanguage:[NSLocale preferredLanguages][0]] == NSLocaleLanguageDirectionRightToLeft);
}

- (void)observeCurrentLocaleDidChangeNotification:(NSNotification *)notification
{
    [self updateShouldLayoutRTL];
    [self setNeedsLayout];
}

- (void)setTheme:(AAPLTheme *)theme
{
    AAPLTheme *oldTheme = self.theme;
    [super setTheme:theme];

    // If it didn't change, don't change anything
    if (oldTheme == theme)
        return;

    _titleLabel.font = theme.bodyFont;
    _titleLabel.textColor = theme.mediumGreyTextColor;

    _valueLabel.font = theme.bodyFont;
    _valueLabel.textColor = theme.darkGreyTextColor;

    _button.titleLabel.font = theme.bodyFont;
}

- (void)updateConstraints
{
    if (_constraints) {
        [super updateConstraints];
        return;
    }

    UIView *contentView = self.contentView;
    UIEdgeInsets layoutMargins = self.layoutMargins;

    NSDictionary *views = NSDictionaryOfVariableBindings(_titleLabel, _valueLabel, _button);
    NSDictionary *metrics = @{
                              @"titleLeading" : @(layoutMargins.left),
                              @"titleWidth" : @(_titleColumnWidth),
                              @"titleTrailing" : @(TITLE_TRAILING_MARGIN),
                              @"valueTrailing" : @(layoutMargins.right)
                              };
    NSMutableArray *constraints = [NSMutableArray array];

    if (_valueLabel.superview) {
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-titleLeading-[_titleLabel(==titleWidth)]-titleTrailing-[_valueLabel]-valueTrailing-|" options:NSLayoutFormatAlignAllFirstBaseline metrics:metrics views:views]];
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-3-[_valueLabel]-3-|" options:0 metrics:metrics views:views]];
    }
    else if (_button.superview) {
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-3-[_titleLabel]-(>=3)-|" options:0 metrics:metrics views:views]];
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-titleLeading-[_titleLabel(==titleWidth)]-titleTrailing-[_button]-(>=valueTrailing)-|" options:NSLayoutFormatAlignAllBaseline metrics:metrics views:views]];
        [constraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_button]|" options:0 metrics:metrics views:views]];
    }
    [contentView addConstraints:constraints];
    _constraints = constraints;

    [super updateConstraints];
}

- (BOOL)shouldTruncateValue
{
    return _valueLabel.numberOfLines != 0;
}

- (void)setShouldTruncateValue:(BOOL)shouldTruncatedValue
{
    if (shouldTruncatedValue)
        _valueLabel.numberOfLines = MAX_NUMBER_OF_VALUE_LINES;
    else
        _valueLabel.numberOfLines = 0;
    [self setNeedsLayout];
}

- (void)setNeedsUpdateConstraints
{
    if (_constraints)
        [self.contentView removeConstraints:_constraints];
    _constraints = nil;
    [super setNeedsUpdateConstraints];
}

- (void)setTitleColumnWidth:(CGFloat)titleColumnWidth
{
    _titleColumnWidth = titleColumnWidth;
    [self setNeedsUpdateConstraints];
}

- (void)configureWithTitle:(NSString *)title value:(NSString *)value
{
    _titleLabel.text = title;
    _valueLabel.text = value;
    _valueLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _valueLabel.numberOfLines = MAX_NUMBER_OF_VALUE_LINES;
    _recognizer.enabled = NO;

    UIView *contentView = self.contentView;
    [contentView addSubview:_valueLabel];
    [_button removeFromSuperview];
    [self setNeedsUpdateConstraints];
}

- (void)configureWithTitle:(NSString *)title buttonTitle:(NSString *)buttonTitle buttonImage:(UIImage *)image action:(SEL)action
{
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    _titleLabel.text = title;
    _recognizer.enabled = NO;

    [_button setTitle:buttonTitle forState:UIControlStateNormal];
    [_button setImage:image forState:UIControlStateNormal];
    [_button removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [_button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    _action = action;
    _button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _button.titleEdgeInsets = UIEdgeInsetsMake(0, 5, 0, -5);
    UIView *contentView = self.contentView;
    [contentView addSubview:_button];
    [_valueLabel removeFromSuperview];
    [self setNeedsUpdateConstraints];
}

- (void)configureWithTitle:(NSString *)title URL:(NSString *)url
{
    _titleLabel.text = title;
    _valueLabel.attributedText = [[NSAttributedString alloc] initWithString:url attributes:@{ NSForegroundColorAttributeName : self.tintColor }];
    _valueLabel.textColor = self.tintColor;
    _valueLabel.numberOfLines = 0;
    _valueLabel.lineBreakMode = NSLineBreakByCharWrapping;
    _recognizer.enabled = YES;

    UIView *contentView = self.contentView;
    [contentView addSubview:_valueLabel];
    [_button removeFromSuperview];
    [self setNeedsUpdateConstraints];
}

- (void)urlTapped:(id)sender
{
    NSURL *url = [NSURL URLWithString:_valueLabel.text];
    [[UIApplication sharedApplication] openURL:url];
}

- (void)buttonTapped:(id)sender
{
    if (_action)
        [_button aapl_sendAction:_action];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint point = [gestureRecognizer locationInView:_valueLabel];
    return CGRectContainsPoint(_valueLabel.bounds, point);
}
@end
