#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSUInteger, XTRefType) {
  XTRefTypeBranch,
  XTRefTypeActiveBranch,
  XTRefTypeRemoteBranch,
  XTRefTypeTag,
  XTRefTypeRemote,
  XTRefTypeUnknown
};

typedef NS_ENUM(NSInteger, XTGroupIndex) {
  XTGroupIndexWorkspace,
  XTGroupIndexBranches,
  XTGroupIndexRemotes,
  XTGroupIndexTags,
  XTGroupIndexStashes,
  XTGroupIndexSubmodules,
};

typedef NS_ENUM(NSUInteger, XTError) {
  XTErrorWriteLock = 1,
  XTErrorUnexpectedObject,
};

extern NSString *XTErrorDomainXit, *XTErrorDomainGit;

/// Fake value for seleting staging view.
extern NSString * const XTStagingSHA;

/// There is a new selection to be displayed.
extern NSString * const XTSelectedModelChangedNotification;

/// The selection has been clicked again. Make sure it is visible.
extern NSString * const XTReselectModelNotification;

/// TeamCity build status has been downloaded/refreshed.
extern NSString * const XTTeamCityStatusChangedNotification;
