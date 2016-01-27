//
//  FDAttachmentImageController.h
//  HotlineSDK
//
//  Created by Aravinth Chandran on 03/12/15.
//  Copyright © 2015 Freshdesk. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FDAttachmentImageController;

@protocol FDAttachmentImageControllerDelegate <NSObject>

@required

-(void)attachmentController:(FDAttachmentImageController *)controller didFinishSelectingImage:(UIImage *)image;

@end

@interface FDAttachmentImageController : UIViewController

-(instancetype)initWithImage:(UIImage *)image;

@property (strong, nonatomic) id<FDAttachmentImageControllerDelegate> delegate;


@end