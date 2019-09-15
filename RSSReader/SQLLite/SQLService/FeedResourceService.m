//
//  FeedResourceService.m
//  RSSReader
//
//  Created by Dzmitry Noska on 9/13/19.
//  Copyright © 2019 Dzmitry Noska. All rights reserved.
//

#import "FeedResourceService.h"
#import "FeedResourceRepository.h"

@interface FeedResourceService()
@property (strong, nonatomic) FeedResourceRepository* feedResourceRepository;
@end

@implementation FeedResourceService


static FeedResourceService* shared;

+(instancetype) sharedFeedResourceService {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [FeedResourceService new];
        shared.feedResourceRepository = [FeedResourceRepository sharedFeedResourceRepository];
    });
    return shared;
}


- (FeedResource *) addFeedResource:(FeedResource *) resource {
    return [self.feedResourceRepository addFeedResource:resource];
}

- (void) removeFeedResource:(FeedResource *) resource {
    [self.feedResourceRepository removeFeedResource:resource];
}

- (NSMutableArray<FeedResource *>*) feedResources {
    return [self.feedResourceRepository feedResources];
}

- (FeedResource *) resourceByURL:(NSURL *) url {
    return [self.feedResourceRepository resourceByURL:url];
}

@end
