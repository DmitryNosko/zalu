//
//  FileFeedResourceService.m
//  RSSReader
//
//  Created by USER on 9/16/19.
//  Copyright © 2019 Dzmitry Noska. All rights reserved.
//

#import "FileFeedResourceService.h"
#import "FileFeedResourceRepository.h"

@interface FileFeedResourceService ()
@property (strong, nonatomic) FileFeedResourceRepository* fileFeedResourceRepository;
@end

static NSString* const MENU_FILE_NAME = @"MainMenuFile.txt";

@implementation FileFeedResourceService

static FileFeedResourceService* shared;

+(instancetype) sharedFileFeedResourceService {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [FileFeedResourceService new];
        shared.fileFeedResourceRepository = [FileFeedResourceRepository sharedFileFeedResourceRepository];
    });
    return shared;
}

- (FeedResource *) addFeedResource:(FeedResource *) resource {
    [self.fileFeedResourceRepository saveFeedResource:resource toFileWithName:MENU_FILE_NAME];
    return resource;
}

- (void) removeFeedResource:(FeedResource *) resource {
    [self.fileFeedResourceRepository removeFeedResource:resource fromFile:MENU_FILE_NAME];
}

- (NSMutableArray<FeedResource *>*) feedResources {
    return [self.fileFeedResourceRepository feedResources:MENU_FILE_NAME];
}

- (FeedResource *) resourceByURL:(NSURL *) url {
    
    NSMutableArray<FeedResource *>* resources = [self.fileFeedResourceRepository feedResources:MENU_FILE_NAME];
    NSUInteger index = [resources indexOfObjectPassingTest:^BOOL(FeedResource * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj.url isEqual:url];
    }];
    return [resources objectAtIndex:index];
}

@end
