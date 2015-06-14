/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A truncating version of UILabel that draws a more… link at the end of the text.
 */

@import UIKit;
@import CoreText;

#import "AAPLLabel.h"


@interface AAPLLabel ()
@property (nonatomic, readonly, assign) CTFramesetterRef framesetter;
@property (nonatomic) BOOL determiningSize;
@end

@implementation AAPLLabel {
    CTFramesetterRef _framesetter;
}

- (void)dealloc
{
    if (_framesetter)
        CFRelease(_framesetter);
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self)
        return nil;
    [self commonInitAAPLLabel];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (!self)
        return nil;
    [self commonInitAAPLLabel];
    return self;
}

- (void)commonInitAAPLLabel
{
    _truncationText = NSLocalizedString(@"more", @"Default text to display after truncated text");
}

- (CTFramesetterRef)framesetter
{
    if (_framesetter)
        return _framesetter;

    _framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.attributedText);
    return _framesetter;
}

- (void)setNeedsFramesetter
{
    if (_framesetter)
        CFRelease(_framesetter);
    _framesetter = nil;
}

- (void)setText:(NSString *)text
{
    [self setNeedsFramesetter];
    [super setText:text];
}

- (void)setAttributedText:(NSAttributedString *)attributedText
{
    [self setNeedsFramesetter];
    [super setAttributedText:attributedText];
}

- (void)setFont:(UIFont *)font
{
    [self setNeedsFramesetter];
    [super setFont:font];
}

- (void)setTextColor:(UIColor *)textColor
{
    [self setNeedsFramesetter];
    [super setTextColor:textColor];
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment
{
    [self setNeedsFramesetter];
    [super setTextAlignment:textAlignment];
}

- (void)setLineBreakMode:(NSLineBreakMode)lineBreakMode
{
    [self setNeedsFramesetter];
    [super setLineBreakMode:lineBreakMode];
}

- (void)setTruncationText:(NSString *)truncationText
{
    if ([_truncationText isEqualToString:truncationText])
        return;
    _truncationText = [truncationText copy];
    if (_truncationText)
        _truncationText = NSLocalizedString(@"more", @"Default text to display after truncated text");
    [self setNeedsDisplay];
}

- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines
{
    bounds.size = [self aapl_sizeFittingSize:bounds.size attributedString:self.attributedText numberOfLines:self.numberOfLines];
    return bounds;
}

- (void)drawTextInRect:(CGRect)rect
{
    if (CGRectIsEmpty(rect) || !rect.size.width || !rect.size.height || !self.attributedText)
        return;

    CGContextRef context = UIGraphicsGetCurrentContext();
    NSDictionary *textAttributes = @{ NSFontAttributeName : self.font, NSForegroundColorAttributeName : self.textColor };
    NSDictionary *truncationAttributes = @{ NSFontAttributeName : self.font, NSForegroundColorAttributeName : self.tintColor };

    NSAttributedString *textAttributedString = self.attributedText;

    NSAttributedString *ellipsisString = nil;
    NSAttributedString *moreString = nil;

    if (self.numberOfLines) {
        ellipsisString = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"…", @"Ellipsis used for truncation") attributes:textAttributes];

        NSMutableAttributedString *truncationString = [[NSMutableAttributedString alloc] initWithAttributedString:ellipsisString];
        [truncationString appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:textAttributes]];
        [truncationString appendAttributedString:[[NSAttributedString alloc] initWithString:_truncationText attributes:truncationAttributes]];
        moreString = truncationString;
    }

    [self aapl_drawString:textAttributedString ellipsisString:ellipsisString moreString:moreString rect:rect context:context];
}

- (CGSize)aapl_sizeFittingSize:(CGSize)size attributedString:(NSAttributedString *)attributedString
{
    CFRange fullStringRange = CFRangeMake(0, CFAttributedStringGetLength((CFAttributedStringRef)attributedString));
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(self.framesetter, fullStringRange, NULL, size, NULL);
    return suggestedSize;
}

- (CGSize)aapl_sizeFittingSize:(CGSize)size attributedString:(NSAttributedString *)attributedString numberOfLines:(NSUInteger)numberOfLines
{
    if (!attributedString)
        return CGSizeZero;

    CFRange rangeToSize = CFRangeMake(0, (CFIndex)[attributedString length]);
    CGSize constraints = CGSizeMake(size.width, CGFLOAT_MAX);
    CTFramesetterRef framesetter = self.framesetter;

    if (numberOfLines > 0) {
        // If the line count of the label more than 1, limit the range to size to the number of lines that have been set
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathAddRect(path, NULL, CGRectMake(0.0f, 0.0f, constraints.width, CGFLOAT_MAX));
        CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
        CFRelease(path);

        if (!frame)
            return CGSizeZero;

        CFArrayRef lines = CTFrameGetLines(frame);

        if (lines && CFArrayGetCount(lines) > 0) {
            NSInteger lastVisibleLineIndex = MIN((CFIndex)numberOfLines, CFArrayGetCount(lines)) - 1;
            CTLineRef lastVisibleLine = CFArrayGetValueAtIndex(lines, lastVisibleLineIndex);

            CFRange rangeToLayout = CTLineGetStringRange(lastVisibleLine);
            rangeToSize = CFRangeMake(0, rangeToLayout.location + rangeToLayout.length);
        }

        CFRelease(frame);
    }

    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, rangeToSize, NULL, constraints, NULL);

    return CGSizeMake(ceilf(suggestedSize.width), ceilf(suggestedSize.height));
}

- (void)aapl_drawString:(NSAttributedString *)attributedString ellipsisString:(NSAttributedString *)ellipsisString moreString:(NSAttributedString *)moreString rect:(CGRect)frameRect context:(CGContextRef)context
{
    BOOL shouldTruncate = (ellipsisString && moreString);

    CGContextSaveGState(context);

    // Flip the coordinate system
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextTranslateCTM(context, 0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGFontRef fontRef = CGFontCreateWithFontName((CFStringRef)self.font.fontName);
    CGContextSetFont(context, fontRef);
    CGContextSetFontSize(context, self.font.pointSize);
    CFRelease(fontRef);

    // Create a path to render text in
    // don't set any line break modes, etc, just let the frame draw as many full lines as will fit
    CGMutablePathRef framePath = CGPathCreateMutable();
    CGPathAddRect(framePath, nil, frameRect);
    CTFramesetterRef framesetter = self.framesetter;
    CFRange fullStringRange = CFRangeMake(0, CFAttributedStringGetLength((CFAttributedStringRef)attributedString));
    CTFrameRef frameRef = CTFramesetterCreateFrame(framesetter, fullStringRange, framePath, NULL);
    CFRelease(framePath);

    CFArrayRef lines = CTFrameGetLines(frameRef);
    CFIndex numberOfLines = CFArrayGetCount(lines);
    CGPoint *origins = malloc(sizeof(CGPoint)*numberOfLines);
    CTFrameGetLineOrigins(frameRef, CFRangeMake(0, numberOfLines), origins);

    CFIndex numberOfUntruncatedLines = shouldTruncate ? numberOfLines - 1 : numberOfLines;

    for (CFIndex lineIndex = 0; lineIndex < numberOfUntruncatedLines; ++lineIndex) {
        // draw each line in the correct position as-is
        CGContextSetTextPosition(context, origins[lineIndex].x + frameRect.origin.x, origins[lineIndex].y + frameRect.origin.y);
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, lineIndex);
        CTLineDraw(line, context);
    }

    // truncate the last line before drawing it
    if (numberOfLines && shouldTruncate) {
        CGPoint lastOrigin = origins[numberOfLines-1];
        CTLineRef lastLine = CFArrayGetValueAtIndex(lines, numberOfLines-1);

        // truncation token is a CTLineRef itself… use the ellipsis for single line and the more string for multiline
        CTLineRef truncationToken = CTLineCreateWithAttributedString((CFAttributedStringRef)(numberOfLines > 1 ? moreString : ellipsisString));
        CTLineRef truncated;

        // now create the truncated line -- need to grab extra characters from the source string,
        // or else the system will see the line as already fitting within the given width and
        // will not truncate it.
        CFRange lastLineRange = CTLineGetStringRange(lastLine);
        if (1 == lastLineRange.length && '\n' == [attributedString.string characterAtIndex:lastLineRange.location]) {
            truncated = truncationToken;
        }
        else {
            // range to cover everything from the start of lastLine to the end of the string
            NSRange rng = NSMakeRange(CTLineGetStringRange(lastLine).location, 0);
            rng.length = attributedString.length - rng.location;

            // substring with that range
            NSMutableAttributedString *longString = [[NSMutableAttributedString alloc] initWithAttributedString:[attributedString attributedSubstringFromRange:rng]];
            // <rdar://problem/16392462> Need to reset the text color for the final line, it seems to get lost for some reason
            [longString addAttribute:NSForegroundColorAttributeName value:self.textColor range:NSMakeRange(0, longString.length)];

            // line for that string
            CTLineRef longLine = CTLineCreateWithAttributedString((CFAttributedStringRef)longString);

            truncated = CTLineCreateTruncatedLine(longLine, frameRect.size.width, kCTLineTruncationEnd, truncationToken);

            // If the truncation call fails, we'll use the last line.
            if (!truncated)
                truncated = (CTLineRef)CFRetain(lastLine);

            CFRelease(longLine);
            CFRelease(truncationToken);
        }

        // draw it at the same offset as the non-truncated version
        CGContextSetTextPosition(context, lastOrigin.x + frameRect.origin.x, lastOrigin.y + frameRect.origin.y);
        CTLineDraw(truncated, context);
        CFRelease(truncated);
    }
    free(origins);
    
    CFRelease(frameRef);
    CGContextRestoreGState(context);
}

@end
