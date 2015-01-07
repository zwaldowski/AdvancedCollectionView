//
//  CollectionViewLayout.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/22/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

// TODO: get rid of proxy!

extension UICollectionView {
    
    public func dequeue<V: UICollectionViewCell>(cellOfType type: V.Type, indexPath: NSIndexPath, reuseIdentifier: String? = nil) -> V {
        let identifier = reuseIdentifier ?? NSStringFromClass(V)!
        return dequeueReusableCellWithReuseIdentifier(identifier, forIndexPath: indexPath) as V
    }
    
    func dequeue<V: UICollectionReusableView>(supplementOfType type: V.Type, ofRawKind kind: String, indexPath: NSIndexPath, reuseIdentifier: String? = nil) -> V {
        let identifier = reuseIdentifier ?? NSStringFromClass(V)!
        return dequeueReusableSupplementaryViewOfKind(kind, withReuseIdentifier: identifier, forIndexPath: indexPath) as V
    }
    
    public func dequeue<V: UICollectionReusableView, T: RawRepresentable where T.RawValue == String>(supplementOfType type: V.Type, ofKind kind: T, indexPath: NSIndexPath, reuseIdentifier: String? = nil) -> V {
        return dequeue(supplementOfType: type, ofRawKind: kind.rawValue, indexPath: indexPath, reuseIdentifier: reuseIdentifier)
    }
    
    public func register<V: UICollectionViewCell>(typeForCell type: V.Type, reuseIdentifier: String? = nil) {
        let identifier = reuseIdentifier ?? NSStringFromClass(V)!
        registerClass(type, forCellWithReuseIdentifier: identifier)
    }
    
    func register<V: UICollectionReusableView>(typeForSupplement type: V.Type, ofRawKind kind: String, reuseIdentifier: String? = nil) {
        let identifier = reuseIdentifier ?? NSStringFromClass(V)!
        registerClass(type, forSupplementaryViewOfKind: kind, withReuseIdentifier: identifier)
    }
    
    public func register<T: RawRepresentable, V: UICollectionReusableView where T.RawValue == String>(typeForSupplement type: V.Type, ofKind kind: T, reuseIdentifier: String? = nil) {
        register(typeForSupplement: type, ofRawKind: kind.rawValue, reuseIdentifier: reuseIdentifier)
    }
    
}

extension UICollectionViewLayout {
    
    func registerClass<T: RawRepresentable where T.RawValue == String>(viewClass: UICollectionReusableView.Type?, forDecorationView kind: T) {
        registerClass(viewClass, forDecorationViewOfKind: kind.rawValue)
    }
    
    func registerNib<T: RawRepresentable where T.RawValue == String>(nib: UINib?, forDecorationView kind: T) {
        registerNib(nib, forDecorationViewOfKind: kind.rawValue)
    }
    
}

func height<S: SequenceType where S.Generator.Element: UICollectionViewLayoutAttributes>(ofAttributes attributes: S) -> CGFloat {
    let (minY, maxY) = reduce(attributes, (nil, nil)) {
        (min($0.0 ?? CGFloat.max, $1.frame.minY), max($0.1 ?? CGFloat.min, $1.frame.maxY))
    }

    switch (minY, maxY) {
    case (.Some(let min), .Some(let max)):
        return max - min
    default:
        return 0
    }
}
