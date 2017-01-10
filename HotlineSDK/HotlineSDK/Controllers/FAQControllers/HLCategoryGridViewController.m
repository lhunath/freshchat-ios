//
//  HLCollectionView.m
//  HotlineSDK
//
//  Created by kirthikas on 22/09/15.
//  Copyright © 2015 Freshdesk. All rights reserved.
//

#import "HLCategoryGridViewController.h"
#import "HLGridViewCell.h"
#import "HLContainerController.h"
#import "HLArticlesController.h"
#import "KonotorDataManager.h"
#import "HLMacros.h"
#import "FDRanking.h"
#import "FDLocalNotification.h"
#import "HLCategory.h"
#import "FDSolutionUpdater.h"
#import "HLTheme.h"
#import "HLSearchViewController.h"
#import "FDSearchBar.h"
#import "FDUtilities.h"
#import "Hotline.h"
#import "HLLocalization.h"
#import "FDBarButtonItem.h"
#import "HLEmptyResultView.h"
#import "FDCell.h"
#import "FDAutolayoutHelper.h"
#import "FDReachabilityManager.h"
#import "HLFAQUtil.h"
#import "HLTagManager.h"
#import "HLEventManager.h"
#import "HLCategoryViewBehaviour.h"
#import "FDControllerUtils.h"

@interface HLCategoryGridViewController () <UIScrollViewDelegate,UISearchBarDelegate,FDMarginalViewDelegate,HLCategoryViewBehaviourDelegate>

@property (nonatomic, strong) NSArray *categories;
@property (nonatomic, strong) FDSearchBar *searchBar;
@property (nonatomic, strong) FDMarginalView *footerView;
@property (nonatomic, strong) UILabel  *noSolutionsLabel;
@property (nonatomic, strong) HLTheme *theme;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) HLEmptyResultView *emptyResultView;
@property (nonatomic, strong) FAQOptions *faqOptions;
@property (nonatomic, strong) HLCategoryViewBehaviour *categoryViewBehaviour;

@end

@implementation HLCategoryGridViewController

-(void) setFAQOptions:(FAQOptions *)options{
    self.faqOptions = options;
}

-(HLCategoryViewBehaviour*)categoryViewBehaviour {
    if(_categoryViewBehaviour == nil){
        _categoryViewBehaviour = [[HLCategoryViewBehaviour alloc] initWithViewController:self andFaqOptions:self.faqOptions];
    }
    return _categoryViewBehaviour;
}

-(BOOL)isEmbedded {
    return self.embedded;
}

-(void)willMoveToParentViewController:(UIViewController *)parent{
    parent.navigationItem.title = HLLocalizedString(LOC_FAQ_TITLE_TEXT);
    self.theme = [HLTheme sharedInstance];
    self.view.backgroundColor = [UIColor whiteColor];
    [self setupSubviews];
    [self adjustUIBounds];
    [self theming];
    [self updateResultsView:YES];
    [self addLoadingIndicator];
    
}

-(void)addLoadingIndicator{
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = false;
    [self.view insertSubview:self.activityIndicator aboveSubview:self.collectionView];
    [self.activityIndicator startAnimating];
    [FDAutolayoutHelper centerX:self.activityIndicator onView:self.view M:1 C:0];
    [FDAutolayoutHelper centerY:self.activityIndicator onView:self.view M:1.5 C:0];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.categoryViewBehaviour load];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [[HLEventManager sharedInstance] submitSDKEvent:HLEVENT_FAQ_LAUNCH withBlock:^(HLEvent *event) {
        [event propKey:HLEVENT_PARAM_SOURCE andVal:HLEVENT_LAUNCH_SOURCE_DEFAULT];
    }];
    [FDControllerUtils configureGestureDelegate:nil forController:self withEmbedded:[self isEmbedded]];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.categoryViewBehaviour unload];
}

-(void)setupSubviews{
    [self setupCollectionView];
    [self setupSearchBar];
}

-(void)viewWillLayoutSubviews{
    self.searchBar.frame= CGRectMake(0, 0, self.view.frame.size.width, 65);
}

-(void)theming{
    [self.searchDisplayController.searchResultsTableView setBackgroundColor:[self.theme backgroundColorSDK]];
}

-(HLEmptyResultView *)emptyResultView
{
    if (!_emptyResultView) {
        _emptyResultView = [[HLEmptyResultView alloc]initWithImage:[self.theme getImageWithKey:IMAGE_FAQ_ICON] andText:@""];
        _emptyResultView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _emptyResultView;
}

-(void)setupSearchBar{
    self.searchBar = [[FDSearchBar alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = HLLocalizedString(@"Search Placeholder");
    self.searchBar.showsCancelButton=YES;
    
    [self.view addSubview:self.searchBar];

    UIView *mainSubView = [self.searchBar.subviews lastObject];
    
    for (id subview in mainSubView.subviews) {
        if ([subview isKindOfClass:[UITextField class]]) {
            UITextField *textField = (UITextField *)subview;
            textField.backgroundColor = [self.theme searchBarInnerBackgroundColor];
        }
    }
    
    self.searchBar.hidden = YES;
}

-(void)adjustUIBounds{
    self.edgesForExtendedLayout=UIRectEdgeNone;
    self.navigationController.view.backgroundColor = [self.theme searchBarOuterBackgroundColor];
}

- (void) onCategoriesUpdated:(NSArray<HLCategory *> *)categories {
    BOOL refreshData = NO;
    if(self.categories) {
        refreshData = YES;
    }
    self.categories = categories;
    [self.categoryViewBehaviour setNavigationItem];
    refreshData = refreshData || (self.categories.count > 0);
    if ( ![[FDReachabilityManager sharedInstance] isReachable] || refreshData ) {
        [self updateResultsView:NO];
    }
    [self.collectionView reloadData];
}

-(void)updateResultsView:(BOOL)isLoading{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.categories.count == 0) {
            NSString *message;
            if(isLoading){
                message = HLLocalizedString(LOC_LOADING_FAQ_TEXT);
            }
            else if(![[FDReachabilityManager sharedInstance] isReachable]){
                message = HLLocalizedString(LOC_OFFLINE_INTERNET_MESSAGE);
                [self removeLoadingIndicator];
            }
            else {
                message = HLLocalizedString(LOC_EMPTY_FAQ_TEXT);
                [self removeLoadingIndicator];
            }
            self.emptyResultView.emptyResultLabel.text = message;
            [self.view addSubview:self.emptyResultView];
            [FDAutolayoutHelper center:self.emptyResultView onView:self.view];
        }
        else{
            self.emptyResultView.frame = CGRectZero;
            [self.emptyResultView removeFromSuperview];
            [self removeLoadingIndicator];
        }
    });
}

-(void)removeLoadingIndicator{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.activityIndicator removeFromSuperview];
    });
}

-(void)setupCollectionView{
    
    UICollectionViewFlowLayout* flowLayout = [[UICollectionViewFlowLayout alloc]init];
    self.collectionView = [[UICollectionView alloc]initWithFrame:CGRectZero collectionViewLayout:flowLayout];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.collectionView.backgroundColor = [UIColor whiteColor];
    
    self.footerView = [[FDMarginalView alloc] initWithDelegate:self];
    
    [self.view addSubview:self.footerView];
    [self.view addSubview:self.collectionView];
    
    NSDictionary *views = @{ @"collectionView" : self.collectionView, @"footerView" : self.footerView};
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[collectionView]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[footerView]|" options:0 metrics:nil views:views]];
    if([self canDisplayFooterView]){
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[collectionView][footerView(40)]|" options:0 metrics:nil views:views]];
    }
    else {
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[collectionView][footerView(0)]|" options:0 metrics:nil views:views]];
    }
    
    //Collection view subclass
    [self.collectionView registerClass:[HLGridViewCell class] forCellWithReuseIdentifier:@"FAQ_GRID_CELL"];
    [self.collectionView setBackgroundColor:[self.theme backgroundColorSDK]];
}

-(void)marginalView:(FDMarginalView *)marginalView handleTap:(id)sender{
    [self.categoryViewBehaviour launchConversations];
}

#pragma mark - Collection view delegate

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section{
    return CGSizeMake(self.collectionView.bounds.size.width, 44);
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return (self.categories) ? self.categories.count : 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    HLGridViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"FAQ_GRID_CELL" forIndexPath:indexPath];
    if (!cell) {
        CGFloat cellSize = [UIScreen mainScreen].bounds.size.width/2;
        cell = [[HLGridViewCell alloc] initWithFrame:CGRectMake(0, 0, cellSize, cellSize)];
    }
    if (indexPath.row < self.categories.count){
        HLCategory *category = self.categories[indexPath.row];
        cell.label.text = category.title;
        cell.backgroundColor = [self.theme gridViewCellBackgroundColor];
        cell.layer.borderWidth=0.3f;
        cell.layer.borderColor=[self.theme gridViewCellBorderColor].CGColor;
        cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
        if (!category.icon){
            cell.imageView.image = [FDCell generateImageForLabel:category.title];
        }else{
            cell.imageView.image = [UIImage imageWithData:category.icon];
        }
    }
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    if (IS_IPAD) {
        return CGSizeMake( ([UIScreen mainScreen].bounds.size.width/3), ([UIScreen mainScreen].bounds.size.width/4));
    }
    if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation)) {
        return CGSizeMake( ([UIScreen mainScreen].bounds.size.width/3), ([UIScreen mainScreen].bounds.size.height/2));
    }
    return CGSizeMake( ([UIScreen mainScreen].bounds.size.width/2), ([UIScreen mainScreen].bounds.size.height/4));
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.row < self.categories.count) {
        HLCategory *category = self.categories[indexPath.row];
        HLArticlesController *articleController = [[HLArticlesController alloc] initWithCategory:category];
        [HLFAQUtil setFAQOptions:self.faqOptions andViewController:articleController];
        HLContainerController *container = [[HLContainerController alloc]initWithController:articleController andEmbed:NO];
        NSString *eventCategoryTitle = category.title;
        NSString *eventCategoryId = [category.categoryID stringValue];
        [[HLEventManager sharedInstance] submitSDKEvent:HLEVENT_FAQ_OPEN_CATEGORY withBlock:^(HLEvent *event) {
            [event propKey:HLEVENT_PARAM_CATEGORY_NAME andVal:eventCategoryTitle];
            [event propKey:HLEVENT_PARAM_CATEGORY_ID andVal:eventCategoryId];
        }];
        [self.navigationController pushViewController:container animated:YES];
    }
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0f;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0f;
}

// Layout: Set Edges
- (UIEdgeInsets)collectionView:
(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0,0,0,0);  // top, left, bottom, right
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    [self.categoryViewBehaviour setNavigationItem];
    [self.collectionView reloadData];
}

-(BOOL)canDisplayFooterView{
    return [self.categoryViewBehaviour canDisplayFooterView];
}

@end
