//
//  FeedItemService.h
//  RSSReader
//
//  Created by Dzmitry Noska on 9/13/19.
//  Copyright © 2019 Dzmitry Noska. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FeedItem.h"
#import "FeedResource.h"

@interface FeedItemService : NSObject
+(instancetype) sharedFeedItemService;

- (NSMutableArray<FeedItem *>*) cleanSaveFeedItems:(NSMutableArray<FeedItem *>*) items;
//- (FeedItem *) addFeedItem:(FeedItem *) item;
- (NSMutableArray<FeedItem *>*) feedItemsForResource:(FeedResource *) resource;
- (void) updateFeedItem:(FeedItem *) item;//reactive for favoritesVC (remove item)
- (void) removeFeedItem:(FeedItem *) item;
- (NSMutableArray<FeedItem *>*) favoriteFeedItems;
- (NSMutableArray<NSString *>*) favoriteFeedItemLinks;
- (NSMutableArray<NSString *>*) readingInProgressFeedItemLinks;
- (NSMutableArray<NSString *>*) readingCompliteFeedItemLinks;
@end

