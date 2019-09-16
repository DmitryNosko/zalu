//
//  MenuViewController.m
//  RSSReader
//
//  Created by Dzmitry Noska on 8/29/19.
//  Copyright © 2019 Dzmitry Noska. All rights reserved.
//

#import "MenuViewController.h"
#import "MenuTableViewCell.h"
#import "MenuHeaderView.h"
#import "RSSURLValidator.h"
#import "FeedResource.h"
#import "FileManager.h"
#import "ReachabilityStatusChecker.h"
#import "SQLFeedResourceService.h"

@interface MenuViewController () <UITableViewDataSource, UITableViewDelegate, MenuHeaderViewListener, MenuTableViewCellListener>
@property (strong, nonatomic) UITableView* tableView;
@property (strong, nonatomic) NSMutableArray<FeedResource *>* feedsResources;
@property (strong, nonatomic) RSSURLValidator* urlValidator;
@property (strong, nonatomic) NSMutableArray<NSIndexPath *>* selectedCheckBoxes;
@end

static NSString* const URL_TO_PARSE = @"https://news.tut.by/rss/index.rss";
static NSString* const CELL_IDENTIFIER = @"Cell";
static NSString* const HEADER_IDENTIFIER = @"header";
//static NSString* const MENU_FILE_NAME = @"MainMenuFile.txt";
static NSString* const DEFAULT_RESOURCE_FILE_NAME = @"tutbyportal";

@implementation MenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor darkGrayColor];
    [self tableViewSetUp];
    self.urlValidator = [[RSSURLValidator alloc] init];
    self.selectedCheckBoxes = [[NSMutableArray alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSMutableArray<FeedResource *>* savedFeedResources = [[SQLFeedResourceService sharedFeedResourceService] feedResources];
    //NSMutableArray<FeedResource *>* savedFeedResources = [[FileManager sharedFileManager] readFeedResourceFile:MENU_FILE_NAME];
    if ([savedFeedResources count] == 0) {
        FeedResource* defaultResource = [[FeedResource alloc] initWithName:DEFAULT_RESOURCE_FILE_NAME url:[NSURL URLWithString:URL_TO_PARSE]];
        [[SQLFeedResourceService sharedFeedResourceService] addFeedResource:defaultResource];
        //[[FileManager sharedFileManager] saveFeedResource:defaultResource toFileWithName:MENU_FILE_NAME];
        self.feedsResources = [[NSMutableArray alloc] initWithObjects:defaultResource, nil];
    } else {
        self.feedsResources = savedFeedResources;
    }
}

- (void) tableViewSetUp {
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    [self.tableView registerClass:[MenuTableViewCell class] forCellReuseIdentifier:CELL_IDENTIFIER];
    [self.tableView registerClass:[MenuHeaderView class] forHeaderFooterViewReuseIdentifier:HEADER_IDENTIFIER];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    self.tableView.rowHeight = 90;
    self.tableView.backgroundColor = [UIColor darkGrayColor];
    [self.view addSubview:self.tableView];
    
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
                                              [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-140],
                                              [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor]
                                              ]];
    
    self.fetchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.fetchButton setTitle:@"Fetch data" forState:UIControlStateNormal];
    [self.fetchButton addTarget:self action:@selector(pushToFetchButton:) forControlEvents:UIControlEventTouchUpInside];
    self.fetchButton.backgroundColor = [UIColor lightGrayColor];
    self.fetchButton.hidden = YES;
    [self.view addSubview:self.fetchButton];
    
    self.fetchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
                                              [self.fetchButton.trailingAnchor constraintEqualToAnchor:self.tableView.trailingAnchor constant:-20],
                                              [self.fetchButton.leadingAnchor constraintEqualToAnchor:self.tableView.leadingAnchor constant:20],
                                              [self.fetchButton.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
                                              [self.fetchButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20]
                                              ]];
    
    [NSLayoutConstraint activateConstraints:@[
                                              [self.tableView.bottomAnchor constraintEqualToAnchor:self.fetchButton.topAnchor]
                                              ]];
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.feedsResources count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MenuTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CELL_IDENTIFIER forIndexPath:indexPath];
    cell.listener = self;
    cell.newsLabel.text = self.feedsResources[indexPath.row].name;
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    MenuHeaderView* menuHeader = (MenuHeaderView*)[tableView dequeueReusableHeaderFooterViewWithIdentifier:HEADER_IDENTIFIER];
    menuHeader.listener = self;
    return menuHeader;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    FeedResource* resource = [self.feedsResources objectAtIndex:indexPath.row];
    self.feedResourceWasChosenHandler(resource);
}

- (void)didTapOnAddResourceButton:(MenuHeaderView *)addResourceButton {
    
    if ([ReachabilityStatusChecker hasInternerConnection]) {
        UIAlertController* addFeedAlert = [UIAlertController alertControllerWithTitle:@"Add new feed"
                                                                              message:@"Enter feed name and URL"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
        
        [addFeedAlert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"Feed name";
        }];
        [addFeedAlert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = @"Feed URL";
        }];
        
        [addFeedAlert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                         style:UIAlertActionStyleCancel handler:nil]];
        [addFeedAlert addAction:[UIAlertAction actionWithTitle:@"Save"
                                                         style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                                             NSArray<UITextField*>* textField = addFeedAlert.textFields;
                                                             UITextField* feedTextField = [textField firstObject];
                                                             UITextField* urlTextField = [textField lastObject];
                                                             
                                                             if (![feedTextField.text isEqualToString:@""] && ![urlTextField.text isEqualToString:@""]) {
                                                                 
                                                                 NSString* inputString = urlTextField.text;
                                                                 NSURL* urlForParse = [self.urlValidator parseFeedResoursecFromURL:[NSURL URLWithString:inputString]];
                                                                 if (urlForParse) {
                                                                     
                                                                     FeedResource* resource = [[SQLFeedResourceService sharedFeedResourceService] addFeedResource:[[FeedResource alloc] initWithName:feedTextField.text url:urlForParse]];
                                                                     //[[FileManager sharedFileManager] saveFeedResource:resource toFileWithName:MENU_FILE_NAME];
                                                                     self.feedsResources = [[SQLFeedResourceService sharedFeedResourceService] feedResources];
                                                                     //self.feedsResources = [[FileManager sharedFileManager] readFeedResourceFile:MENU_FILE_NAME];
                                                                     [self.tableView reloadData];
                                                                     self.feedResourceWasAddedHandler(resource);
                                                                 } else {
                                                                     NSLog(@"exeption");
                                                                 }
                                                             }
                                                         }]];
        
        [self presentViewController:addFeedAlert animated:YES completion:nil];
    } else {
        [self showNotInternerConnectionAlert];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        FeedResource* resource = [self.feedsResources objectAtIndex:indexPath.row];
        [[SQLFeedResourceService sharedFeedResourceService] removeFeedResource:resource];
        //[[FileManager sharedFileManager] removeFeedResource:resource fromFile:MENU_FILE_NAME];
        [self.feedsResources removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationMiddle];
        [self.tableView reloadData];
    }
}

- (void) showNotInternerConnectionAlert {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                   message:@"Check your internet connection"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void) choseResources:(id) sender {
    [self.tableView setEditing:sender animated:YES];
}

#pragma mark - MenuTableViewListener

- (void)didTapOnCheckBoxButton:(MenuTableViewCell *)checkBoxButton {
    
    checkBoxButton.checkBoxButton.selected = !checkBoxButton.checkBoxButton.selected;
    NSIndexPath* indexPath = [self.tableView indexPathForCell:checkBoxButton];
    
    if (checkBoxButton.checkBoxButton.selected) {
        self.fetchButton.hidden = NO;
        
        [self.selectedCheckBoxes addObject:indexPath];
    } else {
        [self.selectedCheckBoxes removeObject:indexPath];
        if (self.selectedCheckBoxes.count == 0) {
            self.fetchButton.hidden = YES;
        }
    }
}

- (void) pushToFetchButton:(id) sender {
    
    NSMutableArray<FeedResource *>* resourcesToLoad = [[NSMutableArray alloc] init];
    
    for (NSIndexPath* ip in [self.selectedCheckBoxes copy]) {
        [resourcesToLoad addObject:[self.feedsResources objectAtIndex:ip.row]];
    }
    
    self.fetchButtonWasPressedHandler(resourcesToLoad);
}

@end
