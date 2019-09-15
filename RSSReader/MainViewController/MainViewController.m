//
//  MainViewController.m
//  RSSReader
//
//  Created by Dzmitry Noska on 8/26/19.
//  Copyright © 2019 Dzmitry Noska. All rights reserved.
//

#import "MainViewController.h"
#import "WebViewController.h"
#import "MainTableViewCell.h"
#import "DetailsViewController.h"
#import "FeedItem.h"
#import "RSSParser.h"
#import "MenuViewController.h"
#import "FileManager.h"
#import "ReachabilityStatusChecker.h"
#import "FeedResourceService.h"
#import "FeedItemService.h"

@interface MainViewController () <UITableViewDataSource, UITableViewDelegate, MainTableViewCellListener, WebViewControllerListener>
@property (strong, nonatomic) UITableView* tableView;
@property (strong, nonatomic) NSMutableArray<FeedItem *>* displayedFeeds;
@property (strong, nonatomic) NSMutableArray<FeedItem *>* parsedFeeds;
@property (strong, nonatomic) UIVisualEffectView* settingsView;
@property (strong, nonatomic) UIBlurEffect* blurEffect;
@property (strong, nonatomic) RSSParser* rssParser;
@property (strong, nonatomic) NSMutableDictionary<NSURL*, FeedResource*>* feedResourceByURL;
@property (strong, nonatomic) NSMutableArray<NSString *>* readingCompliteItemsLinks;
@property (strong, nonatomic) NSMutableArray<NSString *>* readingInProgressItemsLinks;
@property (strong, nonatomic) NSMutableArray<NSString *>* favoriteItemsLinks;
@property (strong, nonatomic) NSIndexPath* selectedFeedItemIndexPath;
@property (assign, nonatomic) BOOL isSelectedEditButton;
@property (strong, nonatomic) UISegmentedControl* switchDateSegmentController;
@property (strong, nonatomic) UISegmentedControl* switchStorageSegmentController;
@end

static NSString* CELL_IDENTIFIER = @"Cell";
static NSString* PATTERN_FOR_VALIDATION = @"<\/?[A-Za-z]+[^>]*>";
static NSString* URL_TO_PARSE = @"https://news.tut.by/rss/index.rss";
static NSString* FAVORITES_NEWS_FILE_NIME = @"favoritiesNews.txt";
static NSString* TUT_BY_NEWS_FILE_NAME = @"tutbyportal";
static NSString* TXT_FORMAT_NAME = @".txt";
static NSString* READED_NEWS = @"readedNews.txt";
static NSString* READING_IN_PROGRESS = @"readingInProgressNews.txt";
static NSString* FAVORITES_NEWS_LINKS = @"favoritiesNewsLinks.txt";

@implementation MainViewController

@synthesize listenedItem = _listenedItem;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self configureNavigationBar];
    [self tableViewSetUp];
    [self setUpSettingsView];
    
    NSUInteger timeRange = [[NSUserDefaults standardUserDefaults] integerForKey:@"timeRange"];
    if (!timeRange) {
        [[NSUserDefaults standardUserDefaults] setInteger:30 forKey:@"timeRange"];
        timeRange = 30;
    }
    
    switch (timeRange) {
        case 7:
            [self.switchDateSegmentController setSelectedSegmentIndex:2];
            break;
            
        case 91:
            [self.switchDateSegmentController setSelectedSegmentIndex:0];
            break;
            
        default:
            [self.switchDateSegmentController setSelectedSegmentIndex:1];
            break;
    }
    
    self.displayedFeeds = [[NSMutableArray alloc] init];
    self.parsedFeeds = [[NSMutableArray alloc] init];
    FeedResource* defautlResource = [[FeedResourceService sharedFeedResourceService] resourceByURL:[NSURL URLWithString:URL_TO_PARSE]];
    
    if (!defautlResource) {
        defautlResource = [[FeedResourceService sharedFeedResourceService] addFeedResource:
                           [[FeedResource alloc] initWithName:TUT_BY_NEWS_FILE_NAME url:[NSURL URLWithString:URL_TO_PARSE]]
                           ];
    }
    
    self.feedResourceByURL = [[NSMutableDictionary alloc] initWithObjectsAndKeys:defautlResource, defautlResource.url, nil];
    
    //self.readedItemsLinks = [[FileManager sharedFileManager] readStringsFromFile:READED_NEWS];
    self.readingCompliteItemsLinks = [[FeedItemService sharedFeedItemService] readingCompliteFeedItemLinks];
    
    //self.readingInProgressItemsLinks = [[FileManager sharedFileManager] readStringsFromFile:READING_IN_PROGRESS];
    self.readingInProgressItemsLinks = [[FeedItemService sharedFeedItemService] readingInProgressFeedItemLinks];
    
    self.rssParser = [[RSSParser alloc] init];
    
    __weak MainViewController* weakSelf = self;
    self.rssParser.feedItemDownloadedHandler = ^(FeedItem *item) {
        NSThread* thread = [[NSThread alloc] initWithBlock:^{
            [weakSelf addParsedFeedItemToFeeds:item];
            [weakSelf performSelectorOnMainThread:@selector(reloadDataHandler) withObject:item waitUntilDone:NO];
        }];
        [thread start];
    };
    
    if ([ReachabilityStatusChecker hasInternerConnection]) {
        [self.rssParser rssParseWithURL:[NSURL URLWithString:URL_TO_PARSE]];
    } else {
        [self showNotInternerConnectionAlert];
        self.displayedFeeds = [[FeedItemService sharedFeedItemService] feedItemsForResource:defautlResource];
        //self.displayedFeeds = [[FileManager sharedFileManager] readFeedItemsFile:TUT_BY_NEWS_FILE_NAME];
    }
    
    [self itemsLoaded];
    [self feedResourceWasChosenHandlerMethod];
    [self feedResourceWasAddedHandlerMethod];
    [self fetchButtonWasPressefHandlerMethod];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    //self.displayedFeeds = [[FeedItemService sharedFeedItemService] feedItems];
    self.favoriteItemsLinks = [[FeedItemService sharedFeedItemService] favoriteFeedItemLinks];
    //self.favoritesItemsLinks = [[FileManager sharedFileManager] readStringsFromFile:FAVORITES_NEWS_LINKS];// create handler for this
    [self.tableView reloadData];
}

- (void)handlemenuToggle {
    [self.delegate handleMenuToggle];
}

- (void)chouseNewsDate {
    
    self.isSelectedEditButton = !self.isSelectedEditButton;
    
    if (self.isSelectedEditButton) {
        self.settingsView.hidden = NO;
        self.tableView.scrollEnabled = NO;
        self.tableView.userInteractionEnabled = NO;
    } else {
        self.settingsView.hidden = YES;
        self.tableView.scrollEnabled = YES;
        self.tableView.userInteractionEnabled = YES;
        NSUInteger timeRange = [[NSUserDefaults standardUserDefaults] integerForKey:@"timeRange"];
        
        [self.displayedFeeds removeAllObjects];
        
        for (FeedItem* item in self.parsedFeeds) {
            if (ABS([item.pubDate timeIntervalSinceNow]) < 60 * 60 * 24 * timeRange) {
                [self.displayedFeeds addObject:item];
            }
        }
        [self.tableView reloadData];
    }
}

- (void) timeRangeChanged {
    switch ([self.switchDateSegmentController selectedSegmentIndex]) {
        case 0:
            [[NSUserDefaults standardUserDefaults] setInteger:91 forKey:@"timeRange"];
            break;
        case 1:
            [[NSUserDefaults standardUserDefaults] setInteger:30 forKey:@"timeRange"];
            break;
        case 2:
            [[NSUserDefaults standardUserDefaults] setInteger:7 forKey:@"timeRange"];
            break;
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.displayedFeeds count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MainTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CELL_IDENTIFIER forIndexPath:indexPath];
    cell.listener = self;
    cell.titleLabel.text = [self.displayedFeeds objectAtIndex:indexPath.row].itemTitle;
    
    FeedItem* item = [self.displayedFeeds objectAtIndex:indexPath.row];
    
    if (item.isReadingInProgress) {
        cell.stateLabel.text = @"readind";
    }
    
    if ([self.favoriteItemsLinks containsObject:item.link]) {
        [cell.favoritesButton setImage:[UIImage imageNamed:@"fullStar"] forState:UIControlStateNormal];
    }
    
//    if ([self.favoritesItemsLinks containsObject:item.link]) {
//        [cell.favoritesButton setImage:[UIImage imageNamed:@"fullStar"] forState:UIControlStateNormal];
//    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([ReachabilityStatusChecker hasInternerConnection]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        FeedItem* item = [self.displayedFeeds objectAtIndex:indexPath.row];
        FeedResource* resource = [self.feedResourceByURL objectForKey:item.resourceURL];
        item.isReadingInProgress = YES;
        item.resource = resource;
        NSThread* thread = [[NSThread alloc] initWithBlock:^{
            [[FeedItemService sharedFeedItemService] updateFeedItem:item];
            [self.readingInProgressItemsLinks addObject:item.link];
            //[[FileManager sharedFileManager] saveString:item.link toFile:READING_IN_PROGRESS];
            //[[FileManager sharedFileManager] updateFeedItem:item atIndex:indexPath.row inFile:[NSString stringWithFormat:@"%@%@", resource.name, TXT_FORMAT_NAME]];
        }];
        [thread start];
        self.listenedItem = item;
        WebViewController* dvc = [[WebViewController alloc] init];
        dvc.listener = self;
        self.selectedFeedItemIndexPath = indexPath;
        NSString* string = [self.displayedFeeds objectAtIndex:indexPath.row].link;
        NSString *stringForURL = [string substringWithRange:NSMakeRange(0, [string length]-6)];
        NSURL* url = [NSURL URLWithString:stringForURL];
        dvc.newsURL = url;
        [self.navigationController pushViewController:dvc animated:YES];
    } else {
        [self showNotInternerConnectionAlert];
    }
    
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 80.f;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return UITableViewAutomaticDimension;
}

- (NSString*) correctDescription:(NSString *) string {
    NSRegularExpression* regularExpression = [NSRegularExpression regularExpressionWithPattern:PATTERN_FOR_VALIDATION
                                                                                       options:NSRegularExpressionCaseInsensitive
                                                                                         error:nil];
    string = [regularExpression stringByReplacingMatchesInString:string
                                                         options:0
                                                           range:NSMakeRange(0, [string length])
                                                    withTemplate:@""];
    return string;
}

- (BOOL) hasRSSLink:(NSString*) link {
    return [[link substringWithRange:NSMakeRange(link.length - 4, 4)] isEqualToString:@".rss"];
}

#pragma mark - MainTableViewCellListener

- (void)didTapOnInfoButton:(MainTableViewCell *)infoButton {
    
    NSIndexPath* indexPath = [self.tableView indexPathForCell:infoButton];
    FeedItem* item = [self.displayedFeeds objectAtIndex:indexPath.row];
    
    DetailsViewController* dvc = [[DetailsViewController alloc] init];
    
    if ([ReachabilityStatusChecker hasInternerConnection]) {
        dvc.hasInternetConnection = YES;
        dvc.itemTitleString = item.itemTitle;
        dvc.itemDateString = [self dateToString:item.pubDate];
        dvc.itemURLString = item.imageURL;
        dvc.itemDescriptionString = [self correctDescription:item.itemDescription];
        
        [self.navigationController pushViewController:dvc animated:YES];
    } else {
        dvc.hasInternetConnection = NO;
        dvc.itemTitleString = item.itemTitle;
        dvc.itemDescriptionString = [self correctDescription:item.itemDescription];
        
        [self.navigationController pushViewController:dvc animated:YES];
    }
    
}

- (NSString *) dateToString:(NSDate *) date {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:[[NSLocale preferredLanguages] objectAtIndex:0]]];
    [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
    return [dateFormatter stringFromDate:date];
}

- (void)didTapOnFavoritesButton:(MainTableViewCell *) favoritesButton {
    
    NSIndexPath* indexPath = [self.tableView indexPathForCell:favoritesButton];
    
    FeedItem* item = [self.displayedFeeds objectAtIndex:indexPath.row];
    //FeedResource* resource = [self.feedResourceByURL objectForKey:item.resourceURL];
    
    if (item.isFavorite) {
        item.isFavorite = NO;
        [self.favoriteItemsLinks removeObject:item.link];
        NSThread* thread = [[NSThread alloc] initWithBlock:^{
            [[FeedItemService sharedFeedItemService] updateFeedItem:item];
//            [[FileManager sharedFileManager] removeFeedItem:item fromFile:FAVORITES_NEWS_FILE_NIME];
//            [[FileManager sharedFileManager] removeString:item.link fromFile:FAVORITES_NEWS_LINKS];
//            [[FileManager sharedFileManager] updateFeedItem:item atIndex:indexPath.row inFile:[NSString stringWithFormat:@"%@%@", resource.name, TXT_FORMAT_NAME]];
        }];
        [thread start];
        
    } else {
        item.isFavorite = YES;
        [self.favoriteItemsLinks addObject:item.link];
        NSThread* thread = [[NSThread alloc] initWithBlock:^{
            [[FeedItemService sharedFeedItemService] updateFeedItem:item];
//            [[FileManager sharedFileManager] saveFeedItem:item toFileWithName:FAVORITES_NEWS_FILE_NIME];
//            [[FileManager sharedFileManager] saveString:item.link toFile:FAVORITES_NEWS_LINKS];
//            [[FileManager sharedFileManager] updateFeedItem:item atIndex:indexPath.row inFile:[NSString stringWithFormat:@"%@%@", resource.name, TXT_FORMAT_NAME]];
        }];
        [thread start];
    }
    [self.tableView reloadData];
}

#pragma mark - MainTableViewCellListener

- (void)didTapOnDoneButton:(UIBarButtonItem *)doneButton {
    FeedItem* item = [self.displayedFeeds objectAtIndex:self.selectedFeedItemIndexPath.row];
    FeedResource* resource = [self.feedResourceByURL objectForKey:item.resourceURL];
    
    NSThread* thread = [[NSThread alloc] initWithBlock:^{
        [[FileManager sharedFileManager] saveString:self.listenedItem.link toFile:READED_NEWS];
        [[FileManager sharedFileManager] removeFeedItem:self.listenedItem fromFile:[NSString stringWithFormat:@"%@%@", resource.name, TXT_FORMAT_NAME]];
    }];
    [thread start];
    [self.readingCompliteItemsLinks addObject:self.listenedItem.link];// same with file
    item.isReadingComplite = YES;
    [[FeedItemService sharedFeedItemService] updateFeedItem:item];
    
    [self.displayedFeeds removeObjectAtIndex:self.selectedFeedItemIndexPath.row];
    [self.tableView deleteRowsAtIndexPaths:@[self.selectedFeedItemIndexPath] withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView reloadData];
}


#pragma mark - ViewControllerSetUp

- (void) tableViewSetUp {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    [self.tableView registerClass:[MainTableViewCell class] forCellReuseIdentifier:CELL_IDENTIFIER];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [UIView new];
    [self.view addSubview:self.tableView];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
                                              [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
                                              [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
                                              [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
                                              ]];
}
- (void) setUpSettingsView {
    
    self.switchDateSegmentController = [[UISegmentedControl alloc] initWithItems:@[@"3 months", @"1 month", @"1 week"]];
    [self.switchDateSegmentController addTarget:self action:@selector(timeRangeChanged) forControlEvents:UIControlEventValueChanged];
    [self.switchDateSegmentController setSelectedSegmentIndex:0];
    self.switchDateSegmentController.tintColor = [UIColor whiteColor];
    
    self.settingsView = [[UIVisualEffectView alloc] init];
    self.settingsView.layer.cornerRadius = 20;
    self.settingsView.clipsToBounds = YES;
    self.settingsView.hidden = YES;
    [self.settingsView.contentView addSubview:self.switchDateSegmentController];
    self.blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.settingsView.effect = self.blurEffect;
    [self.view addSubview:self.settingsView];
    
    UILabel* chouseDateLabel = [[UILabel alloc] init];
    chouseDateLabel.text = @"Chouse news time interval:";
    chouseDateLabel.textColor = [UIColor whiteColor];
    chouseDateLabel.numberOfLines = 0;
    chouseDateLabel.textAlignment = NSTextAlignmentCenter;
    [self.settingsView.contentView addSubview:chouseDateLabel];
    
    UILabel* chouseLocalDBLabel = [[UILabel alloc] init];
    chouseLocalDBLabel.text = @"Chouse storage for news:";
    chouseLocalDBLabel.textColor = [UIColor whiteColor];
    chouseLocalDBLabel.numberOfLines = 0;
    chouseLocalDBLabel.textAlignment = NSTextAlignmentCenter;
    [self.settingsView.contentView addSubview:chouseLocalDBLabel];
    
    self.switchStorageSegmentController = [[UISegmentedControl alloc] initWithItems:@[@"file", @"dataBase"]];
    [self.switchStorageSegmentController addTarget:self action:@selector(changeStorage) forControlEvents:UIControlEventValueChanged];
    [self.switchStorageSegmentController setSelectedSegmentIndex:0];
    self.switchStorageSegmentController.tintColor = [UIColor whiteColor];
    [self.settingsView.contentView addSubview:self.switchStorageSegmentController];
    
    self.settingsView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [self.settingsView.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
                                              [self.settingsView.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
                                              [self.settingsView.heightAnchor constraintEqualToConstant:450],
                                              [self.settingsView.widthAnchor constraintEqualToConstant:350]
                                              ]];
    
    chouseDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [chouseDateLabel.centerXAnchor constraintEqualToAnchor:self.settingsView.contentView.centerXAnchor],
                                              [chouseDateLabel.topAnchor constraintEqualToAnchor:self.settingsView.contentView.topAnchor constant:30],
                                              [chouseDateLabel.heightAnchor constraintEqualToConstant:20],
                                              [chouseDateLabel.trailingAnchor constraintEqualToAnchor:self.settingsView.contentView.trailingAnchor constant:-10],
                                              [chouseDateLabel.leadingAnchor constraintEqualToAnchor:self.settingsView.contentView.leadingAnchor constant:10]
                                              ]];
    
    self.switchDateSegmentController.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [self.switchDateSegmentController.centerXAnchor constraintEqualToAnchor:self.settingsView.contentView.centerXAnchor],
                                              [self.switchDateSegmentController.topAnchor constraintEqualToAnchor:chouseDateLabel.bottomAnchor constant:10],
                                              [self.switchDateSegmentController.heightAnchor constraintEqualToConstant:30],
                                              [self.switchDateSegmentController.trailingAnchor constraintEqualToAnchor:self.settingsView.contentView.trailingAnchor constant:-10],
                                              [self.switchDateSegmentController.leadingAnchor constraintEqualToAnchor:self.settingsView.contentView.leadingAnchor constant:10]
                                              ]];
    
    chouseLocalDBLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [chouseLocalDBLabel.centerXAnchor constraintEqualToAnchor:self.settingsView.contentView.centerXAnchor],
                                              [chouseLocalDBLabel.topAnchor constraintEqualToAnchor:self.switchDateSegmentController.bottomAnchor constant:50],
                                              [chouseLocalDBLabel.heightAnchor constraintEqualToConstant:20],
                                              [chouseLocalDBLabel.trailingAnchor constraintEqualToAnchor:self.settingsView.contentView.trailingAnchor constant:-10],
                                              [chouseLocalDBLabel.leadingAnchor constraintEqualToAnchor:self.settingsView.contentView.leadingAnchor constant:10]
                                              ]];
    
    self.switchStorageSegmentController.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [self.switchStorageSegmentController.centerXAnchor constraintEqualToAnchor:self.settingsView.contentView.centerXAnchor],
                                              [self.switchStorageSegmentController.topAnchor constraintEqualToAnchor:chouseLocalDBLabel.bottomAnchor constant:10],
                                              [self.switchStorageSegmentController.heightAnchor constraintEqualToConstant:30],
                                              [self.switchStorageSegmentController.trailingAnchor constraintEqualToAnchor:self.settingsView.contentView.trailingAnchor constant:-10],
                                              [self.switchStorageSegmentController.leadingAnchor constraintEqualToAnchor:self.settingsView.contentView.leadingAnchor constant:10]
                                              ]];
}

- (void) changeStorage {
    NSLog(@"storage");
}

- (void) configureNavigationBar {
    self.navigationController.navigationBar.tintColor = [UIColor darkGrayColor];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    
    self.navigationItem.title = @"RSS Reader";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(handlemenuToggle)];
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Icon-29"] style:UIBarButtonItemStyleDone target:self action:@selector(chouseNewsDate)];
    self.navigationItem.rightBarButtonItem.tintColor = [UIColor whiteColor];
    
}

#pragma mark - Shake gesture

- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    
    [self.displayedFeeds removeAllObjects];
    
    
    __weak MainViewController* weakSelf = self;
    self.rssParser.feedItemDownloadedHandler = ^(FeedItem *item) {
        NSThread* thread = [[NSThread alloc] initWithBlock:^{
            [weakSelf addParsedFeedItemToFeeds:item];
            [weakSelf performSelectorOnMainThread:@selector(reloadDataHandler) withObject:item waitUntilDone:NO];
        }];
        [thread start];
    };
    
    for (NSURL* url in [self.feedResourceByURL allKeys]) {
        [self.rssParser rssParseWithURL:url];
    }
    
}

#pragma mark - MenuViewControllerHandlers

- (void) feedResourceWasAddedHandlerMethod {
    __weak MainViewController* weakSelf = self;
    self.feedResourceWasAddedHandler = ^(FeedResource *resource) {
        [weakSelf.displayedFeeds removeAllObjects];
        
        [weakSelf.feedResourceByURL setObject:resource forKey:resource.url];
        
        weakSelf.rssParser.feedItemDownloadedHandler = ^(FeedItem *item) {
            NSThread* thread = [[NSThread alloc] initWithBlock:^{
                [weakSelf addParsedFeedItemToFeeds:item];
                [weakSelf performSelectorOnMainThread:@selector(reloadDataHandler) withObject:item waitUntilDone:NO];
            }];
            [thread start];
        };
        
        [weakSelf.rssParser rssParseWithURL:resource.url];
    };
}



- (void) feedResourceWasChosenHandlerMethod {
    __weak MainViewController* weakSelf = self;
    self.feedResourceWasChosenHandler = ^(FeedResource *resource) {
        //NSString* str = [NSString stringWithFormat:@"%@%@", resource.name, TXT_FORMAT_NAME];
        //NSMutableArray<FeedItem*>* items = [[FileManager sharedFileManager] readFeedItemsFile:str];
        NSMutableArray<FeedItem*>* items = [[FeedItemService sharedFeedItemService] feedItemsForResource:resource];
        weakSelf.displayedFeeds = items;
        [weakSelf.tableView reloadData];
    };
}

- (void) addParsedFeedItemToFeeds:(FeedItem* ) item {
    if (item) {
        item.resource = [self.feedResourceByURL objectForKey:item.resourceURL];
        if (![self.readingCompliteItemsLinks containsObject:item.link]) {
            item.isReadingInProgress = [self.readingInProgressItemsLinks containsObject:item.link];
            item.isFavorite = [self.favoriteItemsLinks containsObject:item.link];
            [self.displayedFeeds addObject:item];
            [self.parsedFeeds addObject:item];
        }
    }
}

- (void) reloadDataHandler {
    [self.tableView reloadData];
}


- (void) itemsLoaded {
    __weak MainViewController* weakSelf = self;
    self.rssParser.parserDidEndDocumentHandler = ^{
        [weakSelf.displayedFeeds sortUsingComparator:^NSComparisonResult(FeedItem* obj1, FeedItem* obj2) {
            return [obj2.pubDate compare:obj1.pubDate];
        }];
        
        //FeedItem* item = [weakSelf.displayedFeeds firstObject];
        //FeedResource* resource = [weakSelf.feedResourceByURL objectForKey:item.resourceURL];
        
        //[[FileManager sharedFileManager] createAndSaveFeedItems:weakSelf.displayedFeeds toFileWithName:[NSString stringWithFormat:@"%@%@", resource.name, TXT_FORMAT_NAME]];
        
        NSMutableArray<FeedItem *>* contextItems = [[FeedItemService sharedFeedItemService] cleanSaveFeedItems:weakSelf.displayedFeeds];
        weakSelf.displayedFeeds = contextItems;
        weakSelf.parsedFeeds = contextItems;
        [weakSelf performSelectorOnMainThread:@selector(reloadDataHandler) withObject:nil waitUntilDone:NO];
    };
}

- (void) fetchButtonWasPressefHandlerMethod {
    __weak MainViewController* weakSelf = self;
    self.fetchButtonWasPressedHandler = ^(NSMutableArray<FeedResource *> *resource) {
        [weakSelf.displayedFeeds removeAllObjects];
        [weakSelf.parsedFeeds removeAllObjects];
        
        weakSelf.rssParser.feedItemDownloadedHandler = ^(FeedItem *item) {
            NSThread* thread = [[NSThread alloc] initWithBlock:^{
                [weakSelf addParsedFeedItemToFeeds:item];
                [weakSelf performSelectorOnMainThread:@selector(reloadDataHandler) withObject:item waitUntilDone:NO];
            }];
            [thread start];
        };
        
        for (FeedResource* fr in [resource copy]) {
            [weakSelf.rssParser rssParseWithURL:fr.url];
        }
    };
}


- (void) showNotInternerConnectionAlert {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                   message:@"Check your internet connection"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

