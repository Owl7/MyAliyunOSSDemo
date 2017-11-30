//
//  ViewController.h
//  MyAliyunOSSDemo
//
//  Created by Crack on 2017/11/28.
//  Copyright © 2017年 Crack. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController<UINavigationControllerDelegate, UIImagePickerControllerDelegate>

- (void)showMessage:(NSString*)putType
       inputMessage:(NSString*)message;

- (void)saveAndDisplayImage:(NSData *)objectData
          downloadObjectKey:(NSString *)objectKey;

@end

