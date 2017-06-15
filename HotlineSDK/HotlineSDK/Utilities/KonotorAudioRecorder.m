//
//  KonotorAudioRecorder.m
//  Konotor
//
//  Created by Vignesh G on 11/07/13.
//  Copyright (c) 2013 Vignesh G. All rights reserved.
//

#import "KonotorAudioRecorder.h"
#import "KonotorDataManager.h"
#import "Message.h"
#import "KonotorMessageBinary.h"
#import "FDUtilities.h"
#import "HLMacros.h"
#import "HLMessageServices.h"
#import "FDLocalNotification.h"

@implementation KonotorAlertView

@end 

KonotorAudioRecorder *gkAudioRecorder;
NSURL *pFileToUpload;

KonotorAlertView *pAlert;
static NSString *beforeRecordCategory;

@implementation KonotorAudioRecorder

+(BOOL)startRecording{
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted){
            [FDLocalNotification post:HOTLINE_WILL_PLAY_AUDIO_MESSAGE];
            dispatch_async(dispatch_get_main_queue(), ^{
                [KonotorAudioRecorder startRecordingA];
            });
        }
    }];
    return YES;
}

+(BOOL) startRecordingA{
    
    NSError *error;
    
    AVAudioSession * audioSession = [AVAudioSession sharedInstance];
    beforeRecordCategory = audioSession.category;
    
    [audioSession setActive:NO error:&error];
    
    [audioSession setCategory:AVAudioSessionCategoryRecord error: &error];
    
    
    if(error){
        
        return NO;
        
    }
    
    [audioSession setActive:YES error:&error];
    
    if(error)
        return NO;
    
    
    UInt32 allowBluetoothInput = 1;
    AudioSessionSetProperty (
                             kAudioSessionProperty_OverrideCategoryEnableBluetoothInput,
                             sizeof (allowBluetoothInput),
                             &allowBluetoothInput
                             );
    
    
    
    
    NSTimeInterval  today = [[NSDate date] timeIntervalSince1970];
    NSString *intervalString = [NSString stringWithFormat:@"%.0f", today];
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    
    NSString *recordFile = [documentsDirectory stringByAppendingPathComponent: intervalString];
    
    
    NSURL *recordedTmpFile = [NSURL fileURLWithPath:[recordFile stringByAppendingString:@".m4a"]];
    
    pFileToUpload = recordedTmpFile;
    
    NSMutableDictionary* recordSetting = [[NSMutableDictionary alloc] init];
    [recordSetting setValue :[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:8000.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt: 1] forKey:AVNumberOfChannelsKey];
    [recordSetting setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVSampleRateConverterAudioQualityKey];
    
    
    //Setup the recorder to use this file and record to it.
    gkAudioRecorder = [[ KonotorAudioRecorder alloc] initWithURL:recordedTmpFile settings:recordSetting error:&error];
    
    [gkAudioRecorder setMeteringEnabled:YES];
    gkAudioRecorder.pFileDest = recordedTmpFile;
    
    
    
    if(error)
    {
        //ALog(@"%@", @"Error in setting recording settings in Audio Recorder");
        return NO;
    }
    BOOL err =  [gkAudioRecorder prepareToRecord];
    if(err == NO)
    {
        //ALog(@"%@", @"Error in pAudioRecorder prepareToRecord in Audio Recorder");
        return NO;
    }
    [[ UIApplication sharedApplication ] setIdleTimerDisabled: YES ];
    
    err = [gkAudioRecorder record];
    
    if(err == NO)
    {
        if(![gkAudioRecorder record])
        {
            //ALog(@"%@", @"Error in pAudioRecorder record in Audio Recorder");
            [[ UIApplication sharedApplication ] setIdleTimerDisabled: NO ];
            
            [audioSession setActive:NO error:&error];
            
            BOOL retrySuccess=[KonotorAudioRecorder retrySetupForRecording];
            
            if(!retrySuccess) return NO;
            
        }
    }
   
    
    
    return YES;

}

+(BOOL) retrySetupForRecording
{
    NSError *error;
    
    AVAudioSession * audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:NO error:&error];
    
    [audioSession setCategory:AVAudioSessionCategoryRecord error: &error];
    
    
    if(error){
        
        return NO;
        
    }
    
    [audioSession setActive:YES error:&error];
    
    if(error)
        return NO;
    
    
    UInt32 allowBluetoothInput = 1;
    AudioSessionSetProperty (
                             kAudioSessionProperty_OverrideCategoryEnableBluetoothInput,
                             sizeof (allowBluetoothInput),
                             &allowBluetoothInput
                             );
    
    
    
    
    NSTimeInterval  today = [[NSDate date] timeIntervalSince1970];
    NSString *intervalString = [NSString stringWithFormat:@"%.0f", today];
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
       NSString *recordFile = [documentsDirectory stringByAppendingPathComponent: intervalString];
    
    
    NSURL *recordedTmpFile = [NSURL fileURLWithPath:[recordFile stringByAppendingString:@".m4a"]];
    
    pFileToUpload = recordedTmpFile;
    
    NSMutableDictionary* recordSetting = [[NSMutableDictionary alloc] init];
    [recordSetting setValue :[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:8000.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt: 1] forKey:AVNumberOfChannelsKey];
    [recordSetting setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVSampleRateConverterAudioQualityKey];
    
    
    //Setup the recorder to use this file and record to it.
    gkAudioRecorder = [[ KonotorAudioRecorder alloc] initWithURL:recordedTmpFile settings:recordSetting error:&error];
    
    [gkAudioRecorder setMeteringEnabled:YES];
    gkAudioRecorder.pFileDest = recordedTmpFile;
    
    
    if(error)
    {
        //ALog(@"%@", @"Retry of Audio recorder set up failed");
        return NO;
    }
    BOOL err =  [gkAudioRecorder prepareToRecord];
    if(err == NO)
    {
        //ALog(@"%@", @"Retry of Audio recorder set up failed");

        return NO;
    }
    [[ UIApplication sharedApplication ] setIdleTimerDisabled: YES ];
    
    err = [gkAudioRecorder record];
    if(err == NO)
    {
        if(![gkAudioRecorder record])
        {
            //ALog(@"%@", @"Retry of Audio recorder set up failed");

            [[ UIApplication sharedApplication ] setIdleTimerDisabled: NO ];
            
            return NO;
            
        }
    }
    return YES;
}

+ (NSTimeInterval) getTimeElapsedSinceStartOfRecording
{
    if(gkAudioRecorder)
        return [gkAudioRecorder currentTime];
    else
        return 0;
}

+(NSString *) stopRecording
{
    NSString *messageID = nil;
    if(gkAudioRecorder)
    {
         messageID = [Message generateMessageID];
        gkAudioRecorder.messageID = messageID;
        
        [gkAudioRecorder stop];
        
        [KonotorAudioRecorder SaveAudioMessageInCoreData:gkAudioRecorder];
        
        gkAudioRecorder = nil;
    }
    
    [KonotorAudioRecorder UnInitRecorder];
    
    [[ UIApplication sharedApplication ] setIdleTimerDisabled: NO ];
    
    return messageID;

}

+(NSString *) stopRecordingOnConversation:(KonotorConversation*)conversation
{
    NSString *messageID = nil;
    if(gkAudioRecorder)
    {
        messageID = [Message generateMessageID];
        gkAudioRecorder.messageID = messageID;
        
        [gkAudioRecorder stop];
        
        [KonotorAudioRecorder SaveAudioMessageInCoreData:gkAudioRecorder onConversation:conversation];
        
        
    }
    
    [KonotorAudioRecorder UnInitRecorder];
    
    [[ UIApplication sharedApplication ] setIdleTimerDisabled: NO ];
    
    return messageID;
    
}


+(BOOL) deleteRecordingWithMessageID:(NSString *) messageID
{
    return YES;
}

+(BOOL) isRecording{
    
    if(gkAudioRecorder)
        return YES;
    return NO;
}

+(BOOL) cancelRecording
{
    if(gkAudioRecorder)
    {
        [gkAudioRecorder stop];
        [gkAudioRecorder deleteRecording];
        gkAudioRecorder = nil;
    }
    
    [KonotorAudioRecorder UnInitRecorder];
    
    [[ UIApplication sharedApplication ] setIdleTimerDisabled: NO ];
    
    AVAudioSession * audioSession = [AVAudioSession sharedInstance];
    NSError *error;
    [audioSession setCategory:beforeRecordCategory error:&error];
    if(error){
        ALog(@"Failed to set audio session category");
        return NO;
    }
    [FDLocalNotification post:HOTLINE_DID_FINISH_PLAYING_AUDIO_MESSAGE];
    return YES;
}
+(BOOL) SendRecordingWithMessageID:(NSString *)messageID
{
    return [KonotorAudioRecorder SendRecordingWithMessageID:messageID toConversationID:nil];
    
}

+(BOOL) SendRecordingWithMessageID:(NSString *)messageID toConversationID:(NSString *) conversationID
{
    KonotorConversation *conversation = nil;
    Message *message = [Message retriveMessageForMessageId:messageID];
    
    if(conversationID)
       conversation = [KonotorConversation RetriveConversationForConversationId:conversationID];
    
    if(!message)
        return NO;
    
    
    float audioDurationSeconds = 0.0f;
    //[[message durationInSecs]floatValue];
    if(audioDurationSeconds < 0.5)
    {
        
        KonotorAlertView *alert = [[KonotorAlertView alloc]
                              initWithTitle: @"Message too short"
                              message: @"The message you are trying to send is less than half a second, Are you sure you want to send?"
                              delegate: nil
                              cancelButtonTitle:@"No"
                              otherButtonTitles:@"Send it",nil];
        alert.messageToBeSent = message;
        alert.conversation = conversation;
        
        [alert setDelegate:gkAudioRecorder];
        [alert show];
        pAlert = alert;
        
        return YES;
        
    }
    
    else if(audioDurationSeconds >120)
    {
        
        KonotorAlertView *alert = [[KonotorAlertView alloc]
                              initWithTitle: @"Was it intentional?"
                              message: @"The message you are trying to send is more than 2 minutes, Are you sure you want to send?"
                              delegate: nil
                              cancelButtonTitle:@"No"
                              otherButtonTitles:@"Send it",nil];
        
        alert.messageToBeSent = message;
        alert.conversation = conversation;
        
        [alert setDelegate:gkAudioRecorder];
        [alert show];
        pAlert = alert;
        
        return YES;
        
    }
    
    
    else
    {
        [HLMessageServices uploadMessage:message toConversation:conversation onChannel:nil];
        return YES;
        
    }
    
}

+(BOOL) SendRecordingWithMessageID:(NSString *)messageID toConversationID:(NSString *) conversationID onChannel:(HLChannel*)channel
{
    KonotorConversation *conversation = nil;
    Message *message = [Message retriveMessageForMessageId:messageID];
    
    [channel addMessagesObject:message];
    
    if(conversationID)
        conversation = [KonotorConversation RetriveConversationForConversationId:conversationID];
    
    if(!message)
        return NO;
    
    [HLMessageServices uploadMessage:message toConversation:conversation onChannel:channel];
        return YES;
    
}

+(void) UnInitRecorder{
    AudioSessionSetActiveWithFlags ( false, AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation);
}


- (void)alertView:(KonotorAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex

{
    
    if(buttonIndex ==0)
    {
        [gkAudioRecorder deleteRecording];
        gkAudioRecorder = nil;
        
        return;
    }
    
    else
    {
        [HLMessageServices uploadMessage:[alertView messageToBeSent] toConversation:[alertView conversation] onChannel:[alertView channel]];
        gkAudioRecorder = nil;

    }
    pAlert = nil;
}

float gKonoDecibels;

+ (Float32) getDecibelLevel
{
    [gkAudioRecorder updateMeters];
    gKonoDecibels =  [gkAudioRecorder peakPowerForChannel:0];
    gKonoDecibels+=60;
    return gKonoDecibels;
}

+(void) SaveAudioMessageInCoreData:(KonotorAudioRecorder *)pRec{
    KonotorDataManager *datamanager = [KonotorDataManager sharedInstance];
    NSManagedObjectContext *context = [datamanager mainObjectContext];
    
    Message *message = (Message *)[NSEntityDescription insertNewObjectForEntityForName:HOTLINE_MESSAGE_ENTITY inManagedObjectContext:context];
    
    //[message setMessageUserId:USER_TYPE_MOBILE];
    [message setMessageAlias:pRec.messageID];
    //[message setMessageType:[NSNumber numberWithInt:2]];
    //[message setMessageRead:YES];
    [message setCreatedMillis:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]*1000]];

    
    KonotorMessageBinary *messageBinary = (KonotorMessageBinary *)[NSEntityDescription insertNewObjectForEntityForName:HOTLINE_MESSAGE_BINARY_ENTITY inManagedObjectContext:context];

    NSString *path = [pRec.pFileDest path];
    NSData *data = [NSData dataWithContentsOfFile:path];

    AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:pRec.pFileDest options:nil];
    
    CMTime audioDuration = audioAsset.duration;
    float audioDurationSeconds = CMTimeGetSeconds(audioDuration);
    //[message setDurationInSecs:[NSNumber numberWithFloat:audioDurationSeconds]];

    
    [messageBinary setBinaryAudio:data];
    [messageBinary setValue:message forKey:@"belongsToMessage"];
    
    
    
    [message setValue:messageBinary forKey:@"hasMessageBinary"];

    
    [datamanager save];
    
    return;

}

+(void) SaveAudioMessageInCoreData:(KonotorAudioRecorder *)pRec onConversation:(KonotorConversation*)conversation
{
    KonotorDataManager *datamanager = [KonotorDataManager sharedInstance];
    NSManagedObjectContext *context = [datamanager mainObjectContext];
    
    Message *message = (Message *)[NSEntityDescription insertNewObjectForEntityForName:HOTLINE_MESSAGE_ENTITY inManagedObjectContext:context];
    
    //[message setMessageUserId:USER_TYPE_MOBILE];
    [message setMessageAlias:pRec.messageID];
    //[message setMessageType:[NSNumber numberWithInt:2]];
    [message setIsRead:YES];
    [message setCreatedMillis:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]*1000]];
    message.belongsToConversation=conversation;
    
    
    KonotorMessageBinary *messageBinary = (KonotorMessageBinary *)[NSEntityDescription insertNewObjectForEntityForName:HOTLINE_MESSAGE_BINARY_ENTITY inManagedObjectContext:context];
    
    NSString *path = [pRec.pFileDest path];
    NSData *data = [NSData dataWithContentsOfFile:path];
    
    AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:pRec.pFileDest options:nil];
    
    CMTime audioDuration = audioAsset.duration;
    float audioDurationSeconds = CMTimeGetSeconds(audioDuration);
    //[message setDurationInSecs:[NSNumber numberWithFloat:audioDurationSeconds]];
    
    
    [messageBinary setBinaryAudio:data];
    [messageBinary setValue:message forKey:@"belongsToMessage"];
    
    
    
    [message setValue:messageBinary forKey:@"hasMessageBinary"];
    
    
    [datamanager save];
    
    return;
    
}


@end
