//
//  KonotorImageInput.m
//  KonotorDemo
//
//  Created by Srikrishnan Ganesan on 10/03/14.
//  Copyright (c) 2014 Demach. All rights reserved.
//

#import "KonotorImageInput.h"
#import <QuartzCore/QuartzCore.h>
#import "FDAttachmentImageController.h"
#import "HLMacros.h"
#import "HLLocalization.h"


@interface KonotorImageInput () <FDAttachmentImageControllerDelegate>

@property (strong, nonatomic) UIView* sourceView;
@property (strong, nonatomic) UIViewController* sourceViewController;
@property (strong, nonatomic) UIImage* imagePicked;
@property (strong, nonatomic) UIPopoverController* popover;

@property (nonatomic, strong) KonotorConversation *conversation;
@property (nonatomic, strong) HLChannel *channel;
@property (nonatomic, strong) FDAttachmentImageController *imageController;

@end

@implementation KonotorImageInput

@synthesize sourceView,sourceViewController,imagePicked,popover;

- (instancetype)initWithConversation:(KonotorConversation *)conversation onChannel:(HLChannel *)channel{
    self = [super init];
    if (self) {
        self.conversation = conversation;
        self.channel = channel;
    }
    return self;
}

- (void) showInputOptions:(UIViewController*) viewController{
    UIActionSheet* inputOptions=[[UIActionSheet alloc] initWithTitle:HLLocalizedString(LOC_IMAGE_ATTACHMENT_OPTIONS) delegate:nil cancelButtonTitle:HLLocalizedString(LOC_IMAGE_ATTACHMENT_CANCEL_BUTTON_TEXT)
                                              destructiveButtonTitle:nil otherButtonTitles:HLLocalizedString(LOC_IMAGE_ATTACHMENT_EXISTING_IMAGE_BUTTON_TEXT),HLLocalizedString(LOC_IMAGE_ATTACHMENT_NEW_IMAGE_BUTTON_TEXT),nil];
    inputOptions.delegate = self;
    self.sourceViewController=viewController;
    self.sourceView=viewController.view;
    [inputOptions showInView:self.sourceView];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    switch (buttonIndex) {
        case 0:
            [self showImagePicker];
            break;
        case 1:
            [self showCamPicker];
            break;
        default:
            break;
    }
}

- (void)showImagePicker{
    UIImagePickerController* imagePicker=[[UIImagePickerController alloc] init];
    imagePicker.delegate=self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.allowsEditing = NO;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
        popover=[[UIPopoverController alloc] initWithContentViewController:imagePicker];
        dispatch_async(dispatch_get_main_queue(), ^ {
            [popover presentPopoverFromRect:CGRectMake(self.sourceViewController.view.frame.origin.x,self.sourceViewController.view.frame.origin.y+sourceViewController.view.frame.size.height-20,40,40) inView:self.sourceViewController.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        });
    }else{
        [self.sourceViewController presentViewController:imagePicker animated:YES completion:NULL];
    }
}

- (void)showCamPicker{
    
    UIImagePickerController* imagePicker=[[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    imagePicker.allowsEditing = NO;
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]){
        [imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
        dispatch_async(dispatch_get_main_queue(), ^ {
            [self.sourceViewController presentViewController:imagePicker animated:YES completion:NULL];
        });
    }else{
        UIAlertView *alertview=[[UIAlertView alloc] initWithTitle:HLLocalizedString(LOC_CAMERA_UNAVAILABLE_TITLE) message:HLLocalizedString(LOC_CAMERA_UNAVAILABLE_DESCRIPTION) delegate:nil
                                                cancelButtonTitle:HLLocalizedString(LOC_CAMERA_UNAVAILABLE_OK_BUTTON) otherButtonTitles:nil];
        [alertview show];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    
    [picker dismissViewControllerAnimated:NO completion:nil];
    UIImage* selectedImage = info[UIImagePickerControllerOriginalImage];
    self.imageController = [[FDAttachmentImageController alloc]initWithImage:selectedImage];
    self.imageController.delegate = self;
    self.imagePicked = selectedImage;
    UINavigationController *navcontroller = [[UINavigationController alloc] initWithRootViewController:self.imageController];
    [self.sourceViewController presentViewController:navcontroller animated:YES completion:nil];
}

-(void)attachmentController:(FDAttachmentImageController *)controller didFinishSelectingImage:(UIImage *)image{
    [Konotor uploadImage:self.imagePicked onConversation:self.conversation onChannel:self.channel];
}

@end