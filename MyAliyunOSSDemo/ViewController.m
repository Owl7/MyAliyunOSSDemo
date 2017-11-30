//
//  ViewController.m
//  MyAliyunOSSDemo
//
//  Created by Crack on 2017/11/28.
//  Copyright © 2017年 Crack. All rights reserved.
//

#import "ViewController.h"
#import "OssService.h"
#import "ImageService.h"

@interface ViewController ()
{
    OssService * service;
    OssService * imageService;
    ImageService * imageOperation;
    NSString * uploadFilePath;
    int originConstraintValue;
}

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UITextField *fileNameTextField;
@property (weak, nonatomic) IBOutlet UITextField *textWaterMarkTextField;
@property (weak, nonatomic) IBOutlet UITextField *textSizeTextField;
- (IBAction)selectFileBtn:(UIButton *)sender;
- (IBAction)uploadFileBtn:(UIButton *)sender;
- (IBAction)downloadFileBtn:(UIButton *)sender;
- (IBAction)textWaterMarkBtn:(UIButton *)sender;
- (IBAction)resumableUploadBtn:(UIButton *)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSLog(@"%@", path);
    
    service = [[OssService alloc] initWithViewController:self withEndPoint:endPoint];
    imageService = [[OssService alloc] initWithViewController:self withEndPoint:imageEndPoint];
    imageOperation = [[ImageService alloc] initImageService:imageService];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)saveImage:(UIImage *)currentImage withName:(NSString *)imageName {
    NSData *imageData = UIImageJPEGRepresentation(currentImage, 0.5);
    NSString *fullPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:imageName];
    [imageData writeToFile:fullPath atomically:NO];
    uploadFilePath = fullPath;
    NSLog(@"uploadFilePath : %@", uploadFilePath);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:^{}];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:^{}];
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    NSLog(@"image width:%f, height:%f", image.size.width, image.size.height);
    [self saveImage:image withName:@"currentImage"];
    [self.imageView setImage:image];
    self.imageView.tag = 100;
}

- (BOOL)verifyFileName {
    if (_fileNameTextField.text == nil || [_fileNameTextField.text length] == 0) {
        [self showMessage:@"填写错误" inputMessage:@"文件名不能为空！"];
        return NO;
    }
    return YES;
}

- (IBAction)selectFileBtn:(UIButton *)sender {
    NSString * title = @"选择";
    NSString * cancelButtonTitle = @"取消";
    NSString * picButtonTitle = @"拍照";
    NSString * photoButtonTitle = @"从相册选择";
    
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction * cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction * picAction = [UIAlertAction actionWithTitle:picButtonTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
        imagePickerController.delegate = self;
        imagePickerController.allowsEditing = YES;
        imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentViewController:imagePickerController animated:YES completion:^{}];
    }];
    UIAlertAction * photoAction = [UIAlertAction actionWithTitle:photoButtonTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
        imagePickerController.delegate = self;
        imagePickerController.allowsEditing = YES;
        imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:imagePickerController animated:YES completion:^{}];
    }];
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [alert addAction:cancelAction];
        [alert addAction:picAction];
        [alert addAction:photoAction];
    } else {
        [alert addAction:cancelAction];
        [alert addAction:photoAction];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)uploadFileBtn:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _fileNameTextField.text;
    [service asyncPutImage:objectKey localFilePath:uploadFilePath];
}

- (IBAction)downloadFileBtn:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _fileNameTextField.text;
    
//    NSString * base64Text = [OSSUtil calBase64WithData:(UTF8Char*)[_textWaterMarkTextField.text cStringUsingEncoding:NSASCIIStringEncoding]];
//    NSString * queryString = [NSString stringWithFormat:@"@watermark=2&type=%@&text=%@&size=%d",
//                              @"d3F5LXplbmhlaQ==", base64Text, [_textSizeTextField.text intValue]];
//
//    [service asyncGetImage:[NSString stringWithFormat:@"%@%@", objectKey, queryString]];
    
    [service asyncGetImage:objectKey];
}

// 图片水印
- (IBAction)textWaterMarkBtn:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    NSString * objectKey = _fileNameTextField.text;
    NSString * waterMark = _textWaterMarkTextField.text;
    int size = [_textSizeTextField.text intValue];
    [imageOperation textWaterMark:objectKey waterText:waterMark objectSize:size];
}

// 断点续传
- (IBAction)resumableUploadBtn:(UIButton *)sender {
    if (![self verifyFileName]) {
        return;
    }
    [service resumableUpload:_fileNameTextField.text localFilePath:uploadFilePath];
//    [service test:_fileNameTextField.text localFilePath:uploadFilePath];
}

/**
 *    @brief    下载后存储并显示图片
 *
 *    @param     objectData     图片数据
 *    @param     objectKey   文件名设置为objectKey
 */
- (void)saveAndDisplayImage:(NSData *)objectData
          downloadObjectKey:(NSString *)objectKey
{
    NSString *fullPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:objectKey];
    [objectData writeToFile:fullPath atomically:NO];
    UIImage * image = [[UIImage alloc] initWithData:objectData];
    uploadFilePath = fullPath;
    [self.imageView setImage:image];
    
}

- (void)showMessage:(NSString *)putType
       inputMessage:(NSString*)message {
    UIAlertAction * defaultAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:putType message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
