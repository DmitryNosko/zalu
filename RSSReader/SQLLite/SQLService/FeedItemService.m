//
//  FeedItemService.m
//  RSSReader
//
//  Created by Dzmitry Noska on 9/13/19.
//  Copyright © 2019 Dzmitry Noska. All rights reserved.
//

#import "FeedItemService.h"
#import "FeedItemRepository.h"

@interface FeedItemService()
@property (strong, nonatomic) FeedItemRepository* feedItemRepository;
@end

@implementation FeedItemService

static FeedItemService* shared;

+(instancetype) sharedFeedItemService {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [FeedItemService new];
        shared.feedItemRepository = [FeedItemRepository sharedFeedItemRepository];
    });
    return shared;
}

- (NSMutableArray<FeedItem *>*) cleanSaveFeedItems:(NSMutableArray<FeedItem *>*) items {
    //[self.feedItemRepository removeAllFeedItems];
    FeedResource* resource = [items firstObject].resource;
    [self.feedItemRepository removeFeedItemForResource:resource.identifier];
    NSMutableArray<FeedItem *>* createdItems = [self addFeedItems:items];
    return createdItems;
}

- (NSMutableArray<FeedItem *> *) addFeedItems:(NSMutableArray<FeedItem *>*) items {
    
    NSMutableArray<FeedItem *>* resultItems = [[NSMutableArray alloc] init];
    for (FeedItem* item in items) {
        [resultItems addObject:[self addFeedItem:item]];
    }
    
    return resultItems;
}

- (FeedItem *) addFeedItem:(FeedItem *) item {
    return [self.feedItemRepository addFeedItem:item];
}

- (NSMutableArray<FeedItem *>*) feedItemsForResource:(FeedResource *) resource; {
    return [self.feedItemRepository feedItemsForResource:resource.identifier];
}

- (void)updateFeedItem:(FeedItem *)item {
    [self.feedItemRepository updateFeedItem:item];
}

- (void) removeFeedItem:(FeedItem *) item {
    [self.feedItemRepository removeFeedItem:item];
}

- (NSMutableArray<FeedItem *>*) favoriteFeedItems {
    return [self.feedItemRepository favoriteFeedItems];
}

- (NSMutableArray<NSString *>*) favoriteFeedItemLinks{
    return [self.feedItemRepository favoriteFeedItemLinks];
}

- (NSMutableArray<NSString *>*) readingInProgressFeedItemLinks {
    return [self.feedItemRepository readingInProgressFeedItemLinks];
}

- (NSMutableArray<NSString *>*) readingCompliteFeedItemLinks {
    return [self.feedItemRepository readingCompliteFeedItemLinks];
}

@end
