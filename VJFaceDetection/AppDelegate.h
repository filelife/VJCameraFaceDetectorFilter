//
//  AppDelegate.h
//  VJFaceDetection
//
//  Created by Vincent·Ge on 2018/6/14.
//  Copyright © 2018年 Filelife. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

