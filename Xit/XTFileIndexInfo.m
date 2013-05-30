#import "XTFileIndexInfo.h"

@implementation XTFileIndexInfo

@synthesize name;
@synthesize status;

- (id)initWithName:(NSString *)theName andStatus:(NSString *)theStatus
{
  self = [super init];
  if (self) {
    self.name = theName;
    self.status = theStatus;
  }

  return self;
}

@end
