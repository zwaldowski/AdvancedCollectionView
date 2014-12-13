/*
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 
  A UICollectionViewLayout subclass that works with AAPLDataSource instances to render content in a manner similar to UITableView but with such additional features as multiple columns, pinning headers, and placeholder views.
  
  These properties and methods are used for internal communication between the AAPLDataSource  AAPLSwipeToEditStateMachine and the AAPLCollectionViewGridLayout. Using these classes doesn't require using these methods and properties.
  
 */

#import "AAPLCollectionViewGridLayout.h"
#import "AAPLCollectionViewGridLayoutAttributes_Private.h"
#import "AAPLDataSource_Private.h"

/// Drag & Drop additions
@interface AAPLCollectionViewGridLayout ()

/// Start dragging a cell at the specified index path
- (void)beginDraggingItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)endDragging;
- (void)cancelDragging;

/// drag the cell based on the information provided by the gesture recognizer
- (void)handlePanGesture:(UIPanGestureRecognizer *)gestureRecognizer;

// Data source delegate methods that are helpful for performing animation
- (void)dataSource:(AAPLDataSource *)dataSource didInsertSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)dataSource:(AAPLDataSource *)dataSource didRemoveSections:(NSIndexSet *)sections direction:(AAPLDataSourceSectionOperationDirection)direction;
- (void)dataSource:(AAPLDataSource *)dataSource didMoveSection:(NSInteger)section toSection:(NSInteger)newSection direction:(AAPLDataSourceSectionOperationDirection)direction;

@end
