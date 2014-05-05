#import "XTRepository+Parsing.h"

@class XTFileChange;
@class XTFileViewController;
@class XTRepository;

/**
  Abstract base class for file list data sources.
 */
@interface XTFileListDataSourceBase :
    NSObject<NSOutlineViewDataSource, NSOutlineViewDelegate>

@property IBOutlet XTFileViewController *controller;
@property(nonatomic) XTRepository *repository;
@property(readonly, nonatomic) BOOL isHierarchical;

- (void)reload;
- (XTFileChange*)fileChangeAtRow:(NSInteger)row;
- (NSString*)pathForItem:(id)item;
- (XitChange)changeForItem:(id)item;

@end


/**
  Cell view with additional images for changed files.
 */
@interface XTFileCellView : NSTableCellView

@property IBOutlet NSImageView *changeImage;
@property XitChange change;

@end