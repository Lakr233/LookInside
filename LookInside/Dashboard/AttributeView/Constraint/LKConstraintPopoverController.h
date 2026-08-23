//
//  LKConstraintPopoverController.h
//  Lookin
//
//  Created by Li Kai on 2019/9/28.
//  https://lookin.work
//

#import "LKBaseViewController.h"

@class LookinAutoLayoutConstraint, LKHierarchyDataSource, LookinObject;

@interface LKConstraintPopoverController : LKBaseViewController

/// canJumpToObject decides at render time whether an endpoint's jump button
/// is enabled — a target can be absent from the current tree (released,
/// not captured, or data predating oid identity). Pass nil to enable all.
- (instancetype)initWithConstraint:(LookinAutoLayoutConstraint *)constraint
                   canJumpToObject:(BOOL (^)(LookinObject *lookinObj))canJumpToObject;

- (NSSize)contentSize;

@property(nonatomic, copy) void (^requestJumpingToObject)(LookinObject *lookinObj);

@end
