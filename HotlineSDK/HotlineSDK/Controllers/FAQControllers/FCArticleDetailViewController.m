//
//  HLArticleDetailViewController.m
//  HotlineSDK
//
//  Created by kirthikas on 21/09/15.
//  Copyright © 2015 Freshdesk. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "FCArticleDetailViewController.h"
#import "FCVotingManager.h"
#import "FCSecureStore.h"
#import "FCMacros.h"
#import "FCTheme.h"
#import "FCLocalNotification.h"
#import "FreshchatSDK.h"
#import "FCLocalization.h"
#import "FCReachabilityManager.h"
#import "FCStringUtil.h"
#import "FCBarButtonItem.h"
#import "FCAutolayoutHelper.h"
#import "FCArticles.h"
#import "FCDataManager.h"
#import "FCFAQUtil.h"
#import "FCTagManager.h"
#import "FCControllerUtils.h"
#import "FCContainerController.h"
#import "FCUtilities.h"

@interface FCArticleDetailViewController () <UIGestureRecognizerDelegate>

@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) FCSecureStore *secureStore;
@property (strong, nonatomic) FCVotingManager *votingManager;
@property (strong,nonatomic) FCYesNoPromptView *articleVotePromptView;
@property (strong, nonatomic) FCAlertView *thankYouPromptView;
@property (strong, nonatomic) UIView *bottomView;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) NSString *appAudioCategory;
@property (strong, nonatomic) NSLayoutConstraint *bottomViewHeightConstraint;
@property (nonatomic, strong) FAQOptions *faqOptions;
@property  BOOL isFilteredView;

@end

@implementation FCArticleDetailViewController

#pragma mark - Lazy Instantiations

- (instancetype)init{
    self = [super init];
    if (self) {
         _secureStore = [FCSecureStore sharedInstance];
         _votingManager = [FCVotingManager sharedInstance];
    }
    return self;
}

-(void) setFAQOptions:(FAQOptions *)options{
    self.faqOptions = options;
    self.isFilteredView = [FCFAQUtil hasTags:self.faqOptions];
}

-(NSString *)embedHTML{
    NSString *article = [self fixLinksForiOS9:self.articleDescription];
    return [NSString stringWithFormat:@""
            "<html>"
            "<style type=\"text/css\">"
            "%@" // CSS Content
            "</style>"
            "<bdi>" //For bidirection text
            "<body>"
            "<div class='article-title'><h3>"
            "%@" // Article Title
            "</h3></div>"
            "%@" // Offline warning message
            "<div class='article-body'>"
            "%@" // Article Content
            "</div>"
            "</body>"
            "</bdi>"
            "</html>", [self normalizeCssContent],self.articleTitle, [self offLineMessageForContent:article],article];
}

-(NSString *)fixLinksForiOS9:(NSString *) content{
    NSString *fixedContent = [content stringByReplacingOccurrencesOfString:@"src=\"//" withString:@"src=\"https://"];
    fixedContent = [fixedContent stringByReplacingOccurrencesOfString:@"value=\"//" withString:@"value=\"https://"];
    return fixedContent;
}

-(NSString *)offLineMessageForContent:(NSString *) content{
    if([[FCReachabilityManager sharedInstance] isReachable] ||
       ![FCStringUtil checkRegexPattern:@"<\\s*(img|iframe).*?src\\s*=[ '\"]+http[s]?:\\/\\/.*?>" inString:content]){
        return @"";
    }
    //Offline message
    return [NSString stringWithFormat:@""
                        "<div class='offline-article-message'>"
                        "%@"
                        "</div>"
            , HLLocalizedString(LOC_OFFLINE_MISSING_CONTENT_TEXT)];
}

-(NSString *)normalizeCssContent{
    FCTheme *theme = [FCTheme sharedInstance];
    return [theme getCssFileContent:[theme getArticleDetailCSSFileName]];
}
#pragma mark - Life cycle methods

-(void)willMoveToParentViewController:(UIViewController *)parent{
    if([FCFAQUtil hasFilteredViewTitle:self.faqOptions]){
        if(self.faqOptions.filteredType == ARTICLE){
            parent.navigationItem.title = self.faqOptions.filteredViewTitle;
        }
        else{
            parent.navigationItem.title = self.categoryTitle;
        }
    }
    else{
        parent.navigationItem.title = self.categoryTitle;
    }
    [self setNavigationItem];
    [self registerAppAudioCategory];
    [self theming];
    FCContainerController *containerCtr =  (FCContainerController*)self.parentViewController;
    [containerCtr.footerView setViewColor:[FCTheme sharedInstance].dialogueBackgroundColor];
    [self setSubviews];
    [self fixAudioPlayback];
    [self handleArticleVoteAfterSometime];
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self localNotificationSubscription];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HOTLINE_NETWORK_REACHABLE object:nil];
}

-(void)localNotificationSubscription{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkReachable)
                                                 name:HOTLINE_NETWORK_REACHABLE object:nil];
}

-(void)networkReachable{
    [self.webView loadHTMLString:self.embedHTML baseURL:nil];
    [self handleArticleVoteAfterSometime];
}

-(void)handleArticleVoteAfterSometime{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self handleArticleVotePrompt];
    });
}

-(void)theming{
    self.view.backgroundColor = [[FCTheme sharedInstance] articleListBackgroundColor];
    
}

-(void)setNavigationItem{
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:self.activityIndicator];
    self.parentViewController.navigationItem.rightBarButtonItem = rightBarButton;
    
    if(self.isFilteredView){
        [[FCTagManager sharedInstance] getArticlesForTags:self.faqOptions.tags inContext:[FCDataManager sharedInstance].mainObjectContext withCompletion:^(NSArray *articleIds) {
            if([articleIds count] == 1){
                if(!self.embedded){
                    UIBarButtonItem *closeButton = [[FCBarButtonItem alloc]initWithTitle:HLLocalizedString(LOC_FAQ_CLOSE_BUTTON_TEXT) style:UIBarButtonItemStylePlain target:self action:@selector(closeButton:)];
                    self.parentViewController.navigationItem.leftBarButtonItem = closeButton;
                }
            }
            else {
                [self configureBackButton];
            }
        }];
    }
    else {
        [self configureBackButton];
    }
}

-(UIViewController<UIGestureRecognizerDelegate> *)gestureDelegate{
    return (self.isFromSearchView? nil : self);
}

-(void)closeButton:(id)sender{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)setSubviews{
    self.webView = [[UIWebView alloc]init];
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    self.webView.delegate = self;
    self.webView.dataDetectorTypes = UIDataDetectorTypeAll;
    self.webView.scrollView.scrollEnabled = YES;
    self.webView.scrollView.delegate = self;
    [self.webView loadHTMLString:self.embedHTML baseURL:nil];
    [self.view addSubview:self.webView];
    [self.webView setBackgroundColor:[UIColor whiteColor]];
    
    self.bottomView = [[UIView alloc]init];
    self.bottomView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.bottomView];
    
    self.bottomViewHeightConstraint = [FCAutolayoutHelper setHeight:0 forView:self.bottomView inView:self.view];
    
    //Article Vote Prompt View
    self.articleVotePromptView = [[FCYesNoPromptView alloc] initWithDelegate:self andKey:LOC_ARTICLE_VOTE_PROMPT_PARTIAL];
    self.articleVotePromptView.delegate = self;
    self.articleVotePromptView.translatesAutoresizingMaskIntoConstraints = NO;

    //Thank you prompt view
    self.thankYouPromptView = [[FCAlertView alloc] initWithDelegate:self andKey:LOC_THANK_YOU_PROMPT_PARTIAL];
    self.thankYouPromptView.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSDictionary *views = @{@"webView" : self.webView, @"bottomView" : self.bottomView};
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[webView]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bottomView]|" options:0 metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[webView][bottomView]|" options:0 metrics:nil views:views]];
}

-(void)modifyConstraint:(NSLayoutConstraint *)constraint withHeight:(CGFloat)height{
    constraint.constant = height;
}

#pragma mark - Webview delegate

-(BOOL)webView:(UIWebView *)inWeb shouldStartLoadWithRequest:(NSURLRequest *)inRequest navigationType:(UIWebViewNavigationType)inType {
    if (inType == UIWebViewNavigationTypeLinkClicked){
        if([[[inRequest URL] scheme] caseInsensitiveCompare:@"faq"] == NSOrderedSame){
            NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
            NSNumber *articleId = [f numberFromString:[[inRequest URL] host]]; // host returns articleId since the URL is of pattern "faq://<articleId>
            [FCFAQUtil launchArticleID:articleId withNavigationCtlr:self.navigationController andFaqOptions:self.faqOptions];
            return NO;
        }
        [[UIApplication sharedApplication] openURL:[inRequest URL]];
        return NO;
    }
    return YES;
}

-(void)webViewDidStartLoad:(UIWebView *)webView{
    [self.activityIndicator startAnimating];
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    [self.activityIndicator stopAnimating];
}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
    [self.activityIndicator stopAnimating];
}

//Hack for playing audio on WebView
-(void)registerAppAudioCategory{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    self.appAudioCategory = audioSession.category;
}

-(void) fixAudioPlayback {
    if([ self needAudioFix] ) {
        [self setAudioCategory:AVAudioSessionCategoryPlayback];
    }
}

-(BOOL) needAudioFix {
    return (self.appAudioCategory &&
            ( self.appAudioCategory != AVAudioSessionCategoryPlayAndRecord
             && self.appAudioCategory != AVAudioSessionCategoryPlayback ) );
}

-(void)resetAudioPlayback{
    if([self needAudioFix]) {
        [self setAudioCategory:self.appAudioCategory];
    }
}

-(void)setAudioCategory:(NSString *) audioSessionCategory{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *setCategoryError = nil;
    
    if (![audioSession setCategory:audioSessionCategory error:&setCategoryError]) {
        FDLog(@"%s setCategoryError=%@", __PRETTY_FUNCTION__, setCategoryError);
    }
    
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    [self handleArticleVotePrompt];
}


-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    if(self.webView.scrollView.contentOffset.y >= 0 && self.webView.scrollView.contentOffset.y < (self.webView.scrollView.contentSize.height - self.webView.scrollView.frame.size.height)){
        if(self.bottomViewHeightConstraint.constant > 0 ) {
            [self hideBottomView]; // only hide when necessary
        }
    }
}

-(void)handleArticleVotePrompt{
    if (self.webView.scrollView.contentOffset.y >= ((self.webView.scrollView.contentSize.height-20) - self.webView.scrollView.frame.size.height)) {
        if(self.bottomViewHeightConstraint.constant == 0 ) {
            BOOL isArticleVoted = [self.votingManager isArticleVoted:self.articleID];
            BOOL articleVote = [self.votingManager getArticleVoteFor:self.articleID];
            if (!isArticleVoted) {
                [self showArticleRatingPrompt];
            }
            else{
                if (articleVote == NO) {
                    [self showContactUsPrompt];
                }
            }
        }
    }
}

-(void) showArticleRatingPrompt{
    [self updateBottomViewWith:self.articleVotePromptView];
}

-(void)showContactUsPrompt{
    if(self.faqOptions && ![self.faqOptions showContactUsOnFaqScreens]){
        self.thankYouPromptView.Button1.hidden = YES;
    }
    else{
        self.thankYouPromptView.Button1.hidden = NO;
    }
    [self updateBottomViewWith:self.thankYouPromptView];
}

-(void)showThankYouPrompt{
    self.thankYouPromptView.Button1.hidden = YES;
    [self updateBottomViewWith:self.thankYouPromptView];
}

-(void)hideBottomView{
        self.bottomViewHeightConstraint.constant = 0;
        [[self.bottomView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

-(void)updateBottomViewWith:(FCPromptView *)view{
    FDLog(@"Show View Called");
    [[self.bottomView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    [self.bottomView addSubview:view];
    
    NSDictionary *views = @{ @"bottomInputView" : view };
    [self.bottomView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[bottomInputView]|" options:0 metrics:nil views:views]];
    [self.bottomView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[bottomInputView]|" options:0 metrics:nil views:views]];
    
    [UIView animateWithDuration:.5 animations:^{
        self.bottomViewHeightConstraint.constant = [view getPromptHeight];
    }];
}

-(void)yesButtonClicked:(id)sender{
    [self showThankYouPrompt];
    [self.votingManager upVoteForArticle:self.articleID inCategory:self.categoryID withCompletion:^(NSError *error) {
        FDLog(@"UpVoting Completed");
    }];
}

-(void)noButtonClicked:(id)sender{
    [self showContactUsPrompt];
    [self.votingManager downVoteForArticle:self.articleID inCategory:self.categoryID withCompletion:^(NSError *error) {
        FDLog(@"DownVoting Completed");
    }];
}

-(void)buttonClickedEvent:(id)sender{
    [self hideBottomView];
    if([FCFAQUtil hasContactUsTags:self.faqOptions]){
        ConversationOptions *options = [ConversationOptions new];
        [options filterByTags:self.faqOptions.contactUsTags withTitle:self.faqOptions.contactUsTitle];
        [[Freshchat sharedInstance] showConversations:self withOptions:options];
    }
    else{
        [[Freshchat sharedInstance] showConversations:self];
    }
}

@end