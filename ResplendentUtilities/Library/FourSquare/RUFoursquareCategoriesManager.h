//
//  RUFoursquareCategoriesManager.h
//  Pineapple
//
//  Created by Benjamin Maer on 6/16/13.
//  Copyright (c) 2013 Pineapple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RUSynthesizeUserDefaultMethods.h"
#import "RUSingleton.h"
#import "RUFourSquareRequestProtocols.h"

@class RUFourSquareVenueCategoriesRequest;

@interface RUFoursquareCategoriesManager : NSObject <RUFourSquareRequestDelegate>
{
    RUFourSquareVenueCategoriesRequest* _categoriesRequest;
}

-(void)checkIfNewUpdateNeeded;

+(BOOL)isDataAvailable;

+(NSString*)mostParentCategoryOfCategoryId:(NSString*)categoryId;
+(NSDictionary*)getCategoryDictFromId:(NSString*)categoryId;
+(NSString*)getNameOfCategoryId:(NSString*)categoryId;

RU_SYNTHESIZE_SINGLETON_DECLARATION_FOR_CLASS_WITH_ACCESSOR(RUFoursquareCategoriesManager, sharedInstance);

@end
