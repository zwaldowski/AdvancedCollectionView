//
//  CollectionViewLayout.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/22/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

extension UICollectionView {
    
    public func dequeue<V: UICollectionViewCell>(cellOfType type: V.Type, indexPath: NSIndexPath, reuseIdentifier: String? = nil) -> V {
        let identifier = reuseIdentifier ?? NSStringFromClass(type)!
        return dequeueReusableCellWithReuseIdentifier(identifier, forIndexPath: indexPath) as! V
    }
    
    func dequeue<V: UICollectionReusableView>(supplementOfType type: V.Type, ofRawKind kind: String, indexPath: NSIndexPath, reuseIdentifier: String? = nil) -> V {
        let identifier = reuseIdentifier ?? NSStringFromClass(type)!
        return dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: identifier, forIndexPath: indexPath) as! V
    }
    
    public func dequeue<V: UICollectionReusableView, T: RawRepresentable where T.RawValue == String>(supplementOfType type: V.Type, ofKind kind: T, indexPath: NSIndexPath, reuseIdentifier: String? = nil) -> V {
        return dequeue(supplementOfType: type, ofRawKind: kind.rawValue, indexPath: indexPath, reuseIdentifier: reuseIdentifier)
    }
    
    public func register(typeForCell type: UICollectionViewCell.Type, reuseIdentifier: String? = nil) {
        let identifier = reuseIdentifier ?? NSStringFromClass(type)!
        registerClass(type, forCellWithReuseIdentifier: identifier)
    }
    
    func register(typeForSupplement type: UICollectionReusableView.Type, ofRawKind kind: String, reuseIdentifier: String? = nil) {
        let identifier = reuseIdentifier ?? NSStringFromClass(type)!
        registerClass(type, forSupplementaryViewOfKind: kind, withReuseIdentifier: identifier)
    }
    
    public func register<T: RawRepresentable where T.RawValue == String>(typeForSupplement type: UICollectionReusableView.Type, ofKind kind: T, reuseIdentifier: String? = nil) {
        register(typeForSupplement: type, ofRawKind: kind.rawValue, reuseIdentifier: reuseIdentifier)
    }
    
}

extension UICollectionViewLayout {
    
    func register(typeForDecoration type: UICollectionReusableView.Type, ofRawKind kind: String) {
        registerClass(type, forDecorationViewOfKind: kind)
    }
    
    public func register<T: RawRepresentable where T.RawValue == String>(typeForDecoration type: UICollectionReusableView.Type, ofKind kind: T) {
        register(typeForDecoration: type, ofRawKind: kind.rawValue)
    }
    
}

extension UICollectionViewLayoutAttributes {
    
    convenience init(forElement element: ElementKey) {
        switch element {
        case .Cell(let indexPath):
            self.init(forCellWithIndexPath: indexPath)
        case .Supplement(let indexPath, let kind):
            self.init(forSupplementaryViewOfKind: kind, withIndexPath: indexPath)
        case .Decoration(let indexPath, let kind):
            self.init(forDecorationViewOfKind: kind, withIndexPath: indexPath)
        }
    }
    
}

func height<S: SequenceType where S.Generator.Element: UICollectionViewLayoutAttributes>(ofAttributes attributes: S) -> CGFloat {
    let (minY, maxY) = reduce(attributes, (nil, nil)) {
        (min($0.0 ?? CGFloat.max, $1.frame.minY), max($0.1 ?? CGFloat.min, $1.frame.maxY))
    }
    
    if let min = minY, max = maxY {
        return max - min
    } else {
        return 0
    }
}
