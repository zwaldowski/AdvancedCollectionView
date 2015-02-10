//
//  Placeholder.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 1/2/15.
//  Copyright (c) 2015 Apple. All rights reserved.
//

import UIKit

public struct PlaceholderContent {
    
    public let title: String?
    public let message: String?
    public let image: UIImage?
    
    public var isEmpty: Bool {
        switch (title, message) {
        case (.Some(let text), _):
            return text.isEmpty
        case (.None, .Some(let text)):
            return text.isEmpty
        default:
            return true
        }
    }
    
    public init(title: String?, message: String? = nil, image: UIImage? = nil) {
        self.title = title
        self.message = message
        self.image = image
    }
    
}

public func ==(lhs: PlaceholderContent, rhs: PlaceholderContent) -> Bool {
    return lhs.title == rhs.title && lhs.message == rhs.message && lhs.image == rhs.image
}

extension PlaceholderContent: Equatable { }

private let cornerRadius = CGFloat(3)
private let continuousCurvesSizeFactor = CGFloat(1.528665)
private let buttonMinWidth = CGFloat(124)
private let buttonMinHeight = CGFloat(29)
private func textColor() -> UIColor {
    return UIColor(white: 0, alpha: 0.325)
}

/// A placeholder view that approximates the standard iOS "no content" view.
public class PlaceholderView: UIView {
    
    public var content: PlaceholderContent = PlaceholderContent(title: nil, message: nil, image: nil) {
        didSet {
            if let image = content.image {
                containerView.addSubview(imageView)
                imageView.image = image
            } else {
                imageView.removeFromSuperview()
            }
            
            if let title = content.title {
                containerView.addSubview(titleLabel)
                titleLabel.text = title
            } else {
                titleLabel.removeFromSuperview()
            }
            
            if let message = content.message {
                containerView.addSubview(messageLabel)
                messageLabel.text = message
            } else {
                messageLabel.removeFromSuperview()
            }
            
            invalidateConstraints()
        }
    }
    
    public var buttonContent: (String, () -> ())? = nil {
        didSet {
            if let (title, _) = buttonContent {
                containerView.addSubview(actionButton)
                actionButton.setTitle(title, forState: .Normal)
            } else {
                actionButton.removeFromSuperview()
            }
            
            invalidateConstraints()
        }
    }
    
    // MARK:
    
    private weak var containerView: UIView!
    private lazy var imageView = UIImageView()
    private lazy var titleLabel = UILabel()
    private lazy var messageLabel = UILabel()
    private lazy var actionButton = UIButton.buttonWithType(.System) as! UIButton

    private func commonInit() {
        setTranslatesAutoresizingMaskIntoConstraints(false)
        
        let container = UIView()
        container.setTranslatesAutoresizingMaskIntoConstraints(false)
        addSubview(container)
        containerView = container
        
        imageView.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        titleLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        titleLabel.textAlignment = .Center
        titleLabel.backgroundColor = nil
        titleLabel.opaque = false
        titleLabel.font = UIFont.systemFontOfSize(22)
        titleLabel.numberOfLines = 0
        titleLabel.textColor = textColor()
        
        messageLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        messageLabel.textAlignment = .Center
        messageLabel.backgroundColor = nil
        messageLabel.opaque = false
        messageLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        messageLabel.numberOfLines = 0
        messageLabel.textColor = textColor()
        
        actionButton.tintColor = textColor()
        actionButton.setTranslatesAutoresizingMaskIntoConstraints(false)
        actionButton.addTarget(self, action: "actionButtonPressed:", forControlEvents: .TouchUpInside)
        actionButton.titleLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        actionButton.setBackgroundImage(buttonBackgroundImage, forState: .Normal)
        actionButton.setTitleColor(textColor(), forState: .Normal)
        
        // Constrain the container to the host view. The height of the container will be determined by the contents.
        addConstraints([
            NSLayoutConstraint(item: container, attribute: .CenterX, relatedBy: .Equal, toItem: self, attribute: .CenterX, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: container, attribute: .CenterY, relatedBy: .Equal, toItem: self, attribute: .CenterY, multiplier: 1, constant: 0),
        ])
        
        // _containerView should be no more than 418pt and the left and right padding should be no less than 30pt on both sides
        let metrics = [ "hPad": 30, "maxWidth": 418 ]
        let views = [ "container": container ]
        bigWidthConstraints = NSLayoutConstraint.constraintsWithVisualFormat("H:|-(>=hPad)-[container(<=maxWidth)]-(>=hPad)-|", options: nil, metrics: metrics, views: views) as! [NSLayoutConstraint]
        smallWidthConstraints = NSLayoutConstraint.constraintsWithVisualFormat("H:|-hPad-[container]-hPad-|", options: nil, metrics: metrics, views: views) as! [NSLayoutConstraint]
    }
    
    public override init(frame: CGRect = CGRect.zeroRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func awakeFromNib() {
        commonInit()
    }
    
    // MARK:
    
    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsUpdateConstraints()
    }
    
    // MARK:
    
    private var contentConstraints = [NSLayoutConstraint]()
    private var smallWidthConstraints = [NSLayoutConstraint]()
    private var bigWidthConstraints = [NSLayoutConstraint]()
    
    private func invalidateConstraints() {
        for constraint in contentConstraints {
            constraint.active = false
        }
        contentConstraints.removeAll()
        setNeedsUpdateConstraints()
    }
    
    public override func updateConstraints() {
        smallWidthConstraints.map { $0.active = !self.isWideHorizontal }
        bigWidthConstraints.map { $0.active = self.isWideHorizontal }
        
        if !contentConstraints.isEmpty {
            super.updateConstraints()
            return
        }
        
        let views = [
            "imageView": imageView,
            "titleLabel": titleLabel,
            "messageLabel": messageLabel,
            "actionButton": actionButton
        ]
        var last: UIView = containerView
        var lastAttr = NSLayoutAttribute.Top
        var constant = CGFloat(0)
        
        if content.image != nil {
            // Force the container to be at least as wide as the image
            contentConstraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-(>=0)-[imageView]-(>=0)-|", options: nil, metrics: nil, views: views) as! [NSLayoutConstraint]
            // horizontally center the image
            contentConstraints.append(NSLayoutConstraint(item: imageView, attribute: .CenterX, relatedBy: .Equal, toItem: containerView, attribute: .CenterX, multiplier: 1, constant: 0))
            // aligned with the top of the container
            contentConstraints.append(NSLayoutConstraint(item: imageView, attribute: .Top, relatedBy: .Equal, toItem: last, attribute: lastAttr, multiplier: 1, constant: constant))
            
            last = imageView
            lastAttr = .Bottom
            constant = 15 // spec calls for 20pt space, but when set to 20pt, there's 25pts of space between the bottom of the image and the top of the text.
        }
        
        if content.title != nil {
            contentConstraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|[titleLabel]|", options: nil, metrics: nil, views: views) as! [NSLayoutConstraint]
            contentConstraints.append(NSLayoutConstraint(item: titleLabel, attribute: .Top, relatedBy: .Equal, toItem: last, attribute: lastAttr, multiplier: 1, constant: constant))
            
            last = titleLabel
            lastAttr = .Baseline
            constant = 15 // spec calls for 20pt space, but when set to 20pt, there's 25pts of space between the baseline of the title and the message.
        }

        if content.message != nil {
            contentConstraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|[messageLabel]|", options: nil, metrics: nil, views: views) as! [NSLayoutConstraint]
            contentConstraints.append(NSLayoutConstraint(item: messageLabel, attribute: .Top, relatedBy: .Equal, toItem: last, attribute: lastAttr, multiplier: 1, constant: constant))
            
            last = messageLabel
            lastAttr = .Baseline
            constant = 20
        }
        
        if buttonContent != nil {
            contentConstraints.append(NSLayoutConstraint(item: actionButton, attribute: .Top, relatedBy: .Equal, toItem: last, attribute: lastAttr, multiplier: 1, constant: constant))
            contentConstraints.append(NSLayoutConstraint(item: actionButton, attribute: .CenterX, relatedBy: .Equal, toItem: containerView, attribute: .CenterX, multiplier: 1, constant: 0))
            contentConstraints.append(NSLayoutConstraint(item: actionButton, attribute: .Width, relatedBy: .GreaterThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: buttonMinWidth))
            contentConstraints.append(NSLayoutConstraint(item: actionButton, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: buttonMinHeight))
            
            last = actionButton
            lastAttr = .Baseline
            constant = 20
        }

        // link the bottom of the last view with the bottom of the container to provide the size of the container
        if last != containerView {
            contentConstraints.append(NSLayoutConstraint(item: last, attribute: .Bottom, relatedBy: .Equal, toItem: containerView, attribute: .Bottom, multiplier: 1, constant: 0))
        }
        
        for constraint in contentConstraints {
            constraint.active = true
        }
        
        super.updateConstraints()
    }
    
    // MARK:
    
    private lazy var buttonBackgroundImage: UIImage = {
        let cap = ceil(cornerRadius * continuousCurvesSizeFactor)
        let length = (2 * cap) + 1
        
        let rect = CGRect(x: 0, y: 0, width: length, height: length)
        let hair = self.hairline
        
        let pathRect = rect.rectByInsetting(dx: hair, dy: hair)
        let path = UIBezierPath(roundedRect: pathRect, cornerRadius: cornerRadius - hair)
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        
        UIColor.blackColor().set()
        path.stroke()
        
        let backgroundImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return backgroundImage.resizableImageWithCapInsets(UIEdgeInsets(top: cap, left: cap, bottom: cap, right: cap)).imageWithRenderingMode(.AlwaysTemplate)
    }()
    
    @objc private func actionButtonPressed(sender: UIButton) {
        if let (_, action) = buttonContent {
            action()
        }
    }
    
}

/// A placeholder view for use in a collection view. This placeholder includes the loading indicator.
public class CollectionPlaceholderView: GridCell {
    
    private(set) public weak var activityIndicatorView: UIActivityIndicatorView!
    private(set) public var placeholderView: PlaceholderView?
    
    public var showsActivityIndicator: Bool = false {
        didSet {
            activityIndicatorView.hidden = !showsActivityIndicator
            if showsActivityIndicator {
                activityIndicatorView.startAnimating()
            } else {
                activityIndicatorView.stopAnimating()
            }
        }
    }
    
    public override func commonInit() {
        super.commonInit()
        
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
        indicator.setTranslatesAutoresizingMaskIntoConstraints(false)
        indicator.color = UIColor.lightGrayColor()
        contentView.addSubview(indicator)
        activityIndicatorView = indicator
        
        contentView.addConstraints([
            NSLayoutConstraint(item: indicator, attribute: .CenterX, relatedBy: .Equal, toItem: contentView, attribute: .CenterX, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: indicator, attribute: .CenterY, relatedBy: .Equal, toItem: contentView, attribute: .CenterY, multiplier: 1, constant: 0),
        ])
    }
    
    public func showPlaceholder(#content: PlaceholderContent, animated: Bool = false) {
        let oldPlaceholder = placeholderView
        if oldPlaceholder?.content == content {
            return
        }
        
        showsActivityIndicator = false
        
        let newPlaceholder = PlaceholderView()
        newPlaceholder.setTranslatesAutoresizingMaskIntoConstraints(false)
        newPlaceholder.alpha = 0
        newPlaceholder.content = content
        contentView.insertSubview(newPlaceholder, atIndex: 0)
        placeholderView = newPlaceholder
        
        let views = [ "placeholder": newPlaceholder ]
        
        var constraints = [NSLayoutConstraint]()
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|[placeholder]|", options: nil, metrics: nil, views: views) as! [NSLayoutConstraint]
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("V:|[placeholder]|", options: nil, metrics: nil, views: views) as! [NSLayoutConstraint]
        contentView.addConstraints(constraints)

        let animation: () -> () = { _ in
            newPlaceholder.alpha = 1
            oldPlaceholder?.alpha = 0
        }
        
        let completion: Bool -> () = { _ in
            oldPlaceholder?.removeFromSuperview()
            return
        }
        
        if animated {
            UIView.animateWithDuration(0.25, animations: animation, completion: completion)
        } else {
            UIView.performWithoutAnimation {
                animation()
                completion(true)
            }
        }
    }
    
    public func hidePlaceholder(animated: Bool = false) {
        if let placeholder = placeholderView {
            let completion: Bool -> () = { _ in
                placeholder.removeFromSuperview()
                
                // If it's still the current placeholder, get rid of it
                if self.placeholderView == placeholder {
                    self.placeholderView = nil
                }
            }
            
            if animated {
                UIView.animateWithDuration(0.25, animations: {
                    placeholder.alpha = 0
                }, completion: completion)
            } else {
                UIView.performWithoutAnimation {
                    completion(true)
                }
            }
        }
    }
    
}
