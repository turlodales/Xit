//
//  XTStageViewControllerTest.m
//  Xit
//
//  Created by German Laullon on 09/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "XTStageViewControllerTest.h"
#import "XTUnstagedDataSource.h"
#import "XTStagedDataSource.h"
#import "GITBasic+Xit.h"
#import "XTFileIndexInfo.h"

@implementation XTStageViewControllerTest

- (void) testXTDataSources {
    NSString *mod = [NSString stringWithFormat:@"%@/file_to_mod.txt", repo];
    NSString *mv = [NSString stringWithFormat:@"%@/file_to_move.txt", repo];
    NSString *mvd = [NSString stringWithFormat:@"%@/file_moved.txt", repo];
    NSString *rm = [NSString stringWithFormat:@"%@/file_to_rm.txt", repo];
    NSString *new = [NSString stringWithFormat:@"%@/new_file.txt", repo];

    NSString *txt = @"some text";

    [txt writeToFile:mod atomically:YES encoding:NSASCIIStringEncoding error:nil];
    [txt writeToFile:mv atomically:YES encoding:NSASCIIStringEncoding error:nil];
    [txt writeToFile:rm atomically:YES encoding:NSASCIIStringEncoding error:nil];

    [xit addFile:@"--all"];
    [xit commitWithMessage:@"commit"];

    txt = @"more text";
    [txt writeToFile:mod atomically:YES encoding:NSASCIIStringEncoding error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:mv toPath:mvd error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:rm error:nil];
    [txt writeToFile:new atomically:YES encoding:NSASCIIStringEncoding error:nil];

    XTUnstagedDataSource *ustgds = [[XTUnstagedDataSource alloc] init];
    [ustgds setRepo:xit];
    [ustgds waitUntilReloadEnd];

    NSUInteger nc = [ustgds numberOfRowsInTableView:nil];
    STAssertTrue((nc == 5), @"found %d commits", nc);

    __block NSDictionary *expected = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"M", @"file_to_mod.txt",
                                      @"D", @"file_to_move.txt",
                                      @"?", @"file_moved.txt",
                                      @"D", @"file_to_rm.txt",
                                      @"?", @"new_file.txt",
                                      nil];

    NSArray *items = [ustgds items];
    [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
         XTFileIndexInfo *info = obj;
         NSString *status = [expected objectForKey:info.name];
         STAssertEqualObjects (info.status, status, @"incorrect state file(%lu):%@", idx, info.name);
     }];

    [xit addFile:@"--all"];

    XTStagedDataSource *stgds = [[XTStagedDataSource alloc] init];
    [stgds setRepo:xit];
    [stgds waitUntilReloadEnd];

    nc = [stgds numberOfRowsInTableView:nil];
    STAssertTrue ((nc == 5), @"found %d commits", nc);

    expected = [NSDictionary dictionaryWithObjectsAndKeys:
                @"M", @"file_to_mod.txt",
                @"D", @"file_to_move.txt",
                @"A", @"file_moved.txt",
                @"D", @"file_to_rm.txt",
                @"A", @"new_file.txt",
                nil];

    items = [stgds items];
    [items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL * stop) {
         XTFileIndexInfo *info = obj;
         NSString *status = [expected objectForKey:info.name];
         STAssertEqualObjects (info.status, status, @"incorrect state file(%lu):%@", idx, info.name);
     }];
}

@end
