//
//  RUFoursquareCategoriesManager.m
//  Pineapple
//
//  Created by Benjamin Maer on 6/16/13.
//  Copyright (c) 2013 Pineapple. All rights reserved.
//

#import "RUFoursquareCategoriesManager.h"

#import "RUConstants.h"
#import "RUClassOrNilUtil.h"
#import "RUFourSquareVenueCategoriesRequest.h"
#import "RUFourSquareVenueCategoriesResponse.h"
#import "NSDictionary+RUFourSquareVenueCategory.h"

NSString* const kRUFoursquareCategoriesManagerUserDefaultsKeyLastUpdated = @"kRUFoursquareCategoriesManagerUserDefaultsKeyLastUpdated";
NSString* const kRUFoursquareCategoriesManagerUserDefaultsKeyCategoryUidLookup = @"kRUFoursquareCategoriesManagerUserDefaultsKeyCategoryUidLookup";
NSString* const kRUFoursquareCategoriesManagerUserDefaultsKeyCategoryParentLookup = @"kRUFoursquareCategoriesManagerUserDefaultsKeyCategoryParentLookup";
NSString* const kRUFoursquareCategoriesManagerUserDefaultsKeyCategoryChildrenLookup = @"kRUFoursquareCategoriesManagerUserDefaultsKeyCategoryChildrenLookup";

NSTimeInterval const kRUFoursquareCategoriesManagerTimeIntervalForUpdate = 60 * 60 * 24 * 7; //one week

@interface RUFoursquareCategoriesManager ()

-(void)fetchCategories;
-(void)cancelCategoriesFetch;

-(void)addCategoryInfoToUidLookup:(NSMutableDictionary*)categoryUidLookup parentLookup:(NSMutableDictionary*)parentLookup childrenLookup:(NSMutableDictionary*)childrenLookup fromCategories:(NSArray*)categories fromParentUid:(NSString*)parentUid;
-(void)updateCategoryInfoFromCategories:(NSArray*)categories;

+(NSString*)getParentCategoryIdOfCategoryId:(NSString*)categoryId;

@end

@implementation RUFoursquareCategoriesManager

-(void)dealloc
{
    [self cancelCategoriesFetch];
}

#pragma mark - Getters
+(BOOL)isDataAvailable
{
    return [self categoryChildrenLookup].count && [self categoryParentLookup].count && [self categoryUidLookup].count;
}

+(NSString*)mostParentCategoryOfCategoryId:(NSString*)categoryId
{
    NSString* parentId = [RUFoursquareCategoriesManager getParentCategoryIdOfCategoryId:categoryId];
    if (parentId)
    {
        return [self mostParentCategoryOfCategoryId:parentId];
    }

    return categoryId;
}

+(NSDictionary*)getCategoryDictFromId:(NSString*)categoryId
{
    return [[self categoryUidLookup]objectForKey:categoryId];
}

+(NSString*)getNameOfCategoryId:(NSString*)categoryId
{
    return [self getCategoryDictFromId:categoryId].ruFourSquareVenueCategoryName;
}

+(NSString*)getParentCategoryIdOfCategoryId:(NSString*)categoryId
{
    return [[self categoryParentLookup]objectForKey:categoryId];
}

#pragma mark - Public
-(void)checkIfNewUpdateNeeded
{
    NSDate* date = [RUFoursquareCategoriesManager lastUpdated];
    NSDate* now = [NSDate date];
    BOOL needToUpdate = YES;

    if (date)
    {
        if ([now timeIntervalSinceDate:date] < kRUFoursquareCategoriesManagerTimeIntervalForUpdate)
        {
            needToUpdate = NO;
        }
    }

    if (needToUpdate)
    {
        [self fetchCategories];
    }
}

#pragma mark - Server
-(void)fetchCategories
{
    RUDLog(@"");

    [self cancelCategoriesFetch];

    _categoriesRequest = [RUFourSquareVenueCategoriesRequest new];
    [_categoriesRequest setDelegate:self];
    [_categoriesRequest fetch];
}

-(void)cancelCategoriesFetch
{
    if (_categoriesRequest)
    {
        [_categoriesRequest cancel];
        _categoriesRequest = nil;
    }
}

#pragma mark - Update Data
-(void)addCategoryInfoToUidLookup:(NSMutableDictionary*)categoryUidLookup parentLookup:(NSMutableDictionary*)parentLookup childrenLookup:(NSMutableDictionary*)childrenLookup fromCategories:(NSArray*)categories fromParentUid:(NSString*)parentUid
{
    for (NSDictionary* category in categories)
    {
        [self addCategoryInfoToUidLookup:categoryUidLookup parentLookup:parentLookup childrenLookup:childrenLookup  fromCategories:category.ruFourSquareVenueCategoryCategories fromParentUid:category.ruFourSquareVenueCategoryUid];

        if (category.ruFourSquareVenueCategoryCategories.count)
        {
            NSMutableArray* childrenIds = [NSMutableArray arrayWithCapacity:category.ruFourSquareVenueCategoryCategories.count];
            
            for (NSDictionary* childCategory in category.ruFourSquareVenueCategoryCategories)
            {
                [childrenIds addObject:childCategory.ruFourSquareVenueCategoryUid];
            }

            [childrenLookup setObject:childrenIds forKey:category.ruFourSquareVenueCategoryUid];
        }

//        if ([category.ruFourSquareVenueCategoryUid isEqualToString:@"4bf58dd8d48988d103951735"])
//        {
//            RUDLog(@"!!");
//        }
        NSMutableDictionary* categoryWithoutChildren = [NSMutableDictionary dictionaryWithDictionary:category];
        [categoryWithoutChildren removeObjectForKey:kRUFourSquareVenueCategoryNSDictionaryCategoriesKey];

        [categoryUidLookup setObject:categoryWithoutChildren forKey:category.ruFourSquareVenueCategoryUid];

        if (parentUid)
        {
            [parentLookup setObject:parentUid forKey:category.ruFourSquareVenueCategoryUid];
        }
    }
}

-(void)updateCategoryInfoFromCategories:(NSArray*)categories
{
//    RUDLog(@"categories: %@",categories);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSMutableDictionary* uidLookup = [NSMutableDictionary dictionary];
        NSMutableDictionary* parentLookup = [NSMutableDictionary dictionary];
        NSMutableDictionary* childrenLookup = [NSMutableDictionary dictionary];

        [self addCategoryInfoToUidLookup:uidLookup parentLookup:parentLookup childrenLookup:childrenLookup fromCategories:categories fromParentUid:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            [RUFoursquareCategoriesManager setCategoryUidLookup:uidLookup];
            [RUFoursquareCategoriesManager setCategoryParentLookup:parentLookup];
            [RUFoursquareCategoriesManager setCategoryChildrenLookup:childrenLookup];

            [RUFoursquareCategoriesManager setLastUpdated:[NSDate date]];

//            RUDLog(@"[RUFoursquareCategoriesManager categoryUidLookup]: %@",[RUFoursquareCategoriesManager categoryUidLookup]);
//            RUDLog(@"[RUFoursquareCategoriesManager categoryParentLookup]: %@",[RUFoursquareCategoriesManager categoryParentLookup]);
//            RUDLog(@"[RUFoursquareCategoriesManager categoryChildrenLookup]: %@",[RUFoursquareCategoriesManager categoryChildrenLookup]);
        });
    });
}

#pragma mark - RUFourSquareRequestDelegate methods
-(void)fourSquareRequest:(RUFourSquareRequest *)request didFinishWithResponse:(RUFourSquareResponse *)response
{
    if (kRUClassOrNil(response, RUFourSquareVenueCategoriesResponse))
    {
        if (request == _categoriesRequest)
        {
            _categoriesRequest = nil;

            RUFourSquareVenueCategoriesResponse* categoriesResponse = kRUClassOrNil(response, RUFourSquareVenueCategoriesResponse);

            if (categoriesResponse.successfulResponse)
            {
                [self updateCategoryInfoFromCategories:categoriesResponse.categories];
            }
            else
            {
                RUDLog(@"%@",response);

                if (response.error)
                {
                    RUDLog(@"%@",response.error);
                }
            }
        }
        else
        {
            RUDLog(@"request %@ should be internal request %@",request,_categoriesRequest);
        }
    }
    else
    {
        RUDLog(@"unhandled response %@",response);
    }
}

#pragma mark - Static
RU_SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(RUFoursquareCategoriesManager, sharedInstance);
RUSynthesizeStaticSetGetUserDefaultsMethod(LastUpdated, lastUpdated, NSDate, kRUFoursquareCategoriesManagerUserDefaultsKeyLastUpdated);
RUSynthesizeStaticSetGetUserDefaultsMethod(CategoryUidLookup, categoryUidLookup, NSMutableDictionary, kRUFoursquareCategoriesManagerUserDefaultsKeyCategoryUidLookup);
RUSynthesizeStaticSetGetUserDefaultsMethod(CategoryParentLookup, categoryParentLookup, NSMutableDictionary, kRUFoursquareCategoriesManagerUserDefaultsKeyCategoryParentLookup);
RUSynthesizeStaticSetGetUserDefaultsMethod(CategoryChildrenLookup, categoryChildrenLookup, NSMutableDictionary, kRUFoursquareCategoriesManagerUserDefaultsKeyCategoryChildrenLookup);

@end
