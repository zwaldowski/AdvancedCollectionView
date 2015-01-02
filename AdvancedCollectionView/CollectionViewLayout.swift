//
//  CollectionViewLayout.swift
//  AdvancedCollectionView
//
//  Created by Zachary Waldowski on 12/22/14.
//  Copyright (c) 2014 Apple. All rights reserved.
//

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

}
