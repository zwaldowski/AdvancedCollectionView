//
//  CollectionViewLayout.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/22/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

// TODO: get rid of proxy, make these extensions on UICollectionView
public func register<CV: UICollectionView, V: UICollectionViewCell>(typeForCell type: V.Type, #collectionView: CV, reuseIdentifier identifier: String = NSStringFromClass(V)) {
    collectionView.registerClass(type, forCellWithReuseIdentifier: identifier)
}

public func dequeue<CV: UICollectionView, V: UICollectionViewCell>(cellOfType type: V.Type, #collectionView: CV, #indexPath: NSIndexPath, reuseIdentifier identifier: String = NSStringFromClass(V)) -> V {
    return collectionView.dequeueReusableCellWithReuseIdentifier(identifier, forIndexPath: indexPath) as V
}

extension UICollectionView {
    
    func registerClass<T: RawRepresentable, V: UICollectionReusableView where T.RawValue == String>(viewClass: V.Type, forSupplement kind: T, reuseIdentifier: String = NSStringFromClass(V)) {
        registerClass(viewClass, forSupplementaryViewOfKind: kind.rawValue, withReuseIdentifier: reuseIdentifier)
    }
    
    func registerNib<T: RawRepresentable where T.RawValue == String>(nib: UINib?, forSupplement kind: T, reuseIdentifier: String) {
        registerNib(nib, forSupplementaryViewOfKind: kind.rawValue, withReuseIdentifier: reuseIdentifier)
    }
    
    func dequeueReusableSupplement<T: RawRepresentable, V: UICollectionReusableView where T.RawValue == String>(#kind: T, reuseIdentifier: String = NSStringFromClass(V), indexPath: NSIndexPath, type: V.Type) -> V {
        return dequeueReusableSupplementaryViewOfKind(kind.rawValue, withReuseIdentifier: reuseIdentifier, forIndexPath: indexPath) as V
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

extension UICollectionViewLayoutAttributes {

    convenience init<T: RawRepresentable where T.RawValue == String>(forSupplement element: T, indexPath: NSIndexPath) {
        self.init(forSupplementaryViewOfKind: element.rawValue, withIndexPath: indexPath)
    }

    convenience init<T: RawRepresentable where T.RawValue == String>(forDecoration element: T, indexPath: NSIndexPath) {
        self.init(forDecorationViewOfKind: element.rawValue, withIndexPath: indexPath)
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
