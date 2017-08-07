//
//  FDLocaleUtil.m
//  HotlineSDK
//
//  Created by Sanjith J K on 17/02/17.
//  Copyright © 2017 Freshdesk. All rights reserved.
//

#import "FDLocaleUtil.h"
#import "HLUserDefaults.h"
#import "FDUtilities.h"
#import "FDSecureStore.h"
#import "FDConstants.h"

@implementation FDLocaleUtil


+(NSNumber *)getContentLocaleId{
    return [HLUserDefaults getNumberForKey:HOTLINE_DEFAULTS_CONTENT_LOCALEID];
}

+(NSString *)getUserLocale{
    NSString *userLocale = [HLUserDefaults getStringForKey:HOTLINE_DEFAULTS_CONTENT_LOCALE];
    return ( userLocale != nil ) ? userLocale : @"";
}

+(NSArray *)userLocaleParams:(BOOL)voteReq {
    NSString *localLocale = [self getLocalLocale];
    NSMutableArray *params = [[NSMutableArray alloc]init];
    [params addObject:[NSString stringWithFormat:PARAM_LOCALE,localLocale]];
    NSNumber *defaultLocaleId   = [FDLocaleUtil getContentLocaleId];
    if([defaultLocaleId compare:@0] == NSOrderedDescending) {
        if(voteReq) {
            [params addObject:[NSString stringWithFormat:PARAM_LOCALEID,defaultLocaleId]];
        } else {
            [params addObject:[NSString stringWithFormat:PARAM_LAST_LOCALEID,defaultLocaleId]];
        }
    }
    return params;
}

+(NSString *)getLocalLocale{
    NSString *locale = [[NSLocale preferredLanguages] objectAtIndex:0]; //Current configured Locale
    return locale;
}

+(void)updateLocale:(NSString *)locale {
    [HLUserDefaults setObject:locale forKey:HOTLINE_DEFAULTS_CONTENT_LOCALE];
}

+(BOOL)hadLocaleChange {
    NSString *localLocale = [self getLocalLocale];
    NSString *userLocale = [self getUserLocale];
    return !([localLocale isEqualToString:userLocale]);
}

@end