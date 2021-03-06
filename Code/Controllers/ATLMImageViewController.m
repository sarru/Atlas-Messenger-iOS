//
//  ATLMImageViewController.m
//  Atlas Messenger
//
//  Created by Ben Blakley on 1/16/15.
//  Copyright (c) 2015 Layer, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "ATLMImageViewController.h"
#import <Atlas/Atlas.h>

static NSTimeInterval const ATLMImageViewControllerAnimationDuration = 0.75f;
static NSTimeInterval const ATLMImageViewControllerProgressBarHeight = 2.00f;

@interface ATLMImageViewController () <UIScrollViewDelegate, LYRProgressDelegate>

@property (nonatomic) LYRMessage *message;
@property (nonatomic) UIImage *lowResImage;
@property (nonatomic) UIImage *fullResImage;
@property (nonatomic) CGSize fullResImageSize;
@property (nonatomic) CGRect imageViewFrame;
@property (nonatomic) UIScrollView *scrollView;
@property (nonatomic) UIImageView *lowResImageView;
@property (nonatomic) UIImageView *fullResImageView;
@property (nonatomic) UIProgressView *progressView;

@end

@implementation ATLMImageViewController

- (instancetype)initWithMessage:(LYRMessage *)message
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _message = message;
    }
    return self;
}

- (void)dealloc
{
    self.scrollView.delegate = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.fullResImageSize = CGSizeZero;
    self.view.backgroundColor = [UIColor whiteColor];

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.delegate = self;
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height);
    [self.view addSubview:self.scrollView];

    self.lowResImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    [self.scrollView addSubview:self.lowResImageView];
    
    self.fullResImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.fullResImageView.alpha = 0.0f; // hide the full-res image view at the beginning.
    [self.scrollView addSubview:self.fullResImageView];
    
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.alpha = 0.0;
    self.progressView.tintColor = ATLBlueColor();
    self.progressView.trackTintColor = [UIColor clearColor];
    [self.navigationController.navigationBar addSubview:self.progressView];
    [self.progressView setProgress:0];
    
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapRecognized:)];
    recognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:recognizer];

    UIBarButtonItem *shareBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share:)];
    self.navigationItem.rightBarButtonItem = shareBarButtonItem;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    UIBarButtonItem *doneButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
    self.navigationItem.leftBarButtonItem = doneButtonItem;

    self.title = @"Image";
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self loadLowResImages];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self downloadFullResImageIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.progressView removeFromSuperview];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self configureForAvailableSpace];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    self.progressView.frame = CGRectMake(0, self.navigationController.navigationBar.frame.size.height - ATLMImageViewControllerProgressBarHeight, self.view.frame.size.width, ATLMImageViewControllerProgressBarHeight);
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.lowResImageView;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self configureForAvailableSpace];
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    [self configureForAvailableSpace];
}

#pragma mark - Gesture Recognizer Handler

- (void)doubleTapRecognized:(UIGestureRecognizer *)gestureRecognizer
{
    if (self.scrollView.minimumZoomScale == self.scrollView.maximumZoomScale) return;

    if (self.scrollView.zoomScale == self.scrollView.minimumZoomScale) {
        CGPoint tappedPoint;
        tappedPoint = [gestureRecognizer locationInView:self.lowResImageView];
        CGRect tappedRect = CGRectMake(tappedPoint.x, tappedPoint.y, 0, 0);
        [self.scrollView zoomToRect:tappedRect animated:YES];
    } else {
        [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:YES];
    }
}

#pragma mark - Actions

- (void)share:(id)sender
{
    if (self.fullResImage) {
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[self.fullResImage] applicationActivities:nil];
        [self presentViewController:activityViewController animated:YES completion:nil];
    }
}

- (void)done:(id)sender
{
    // Removing the full-resolution image to save GPU resources when
    // animating the view controller POP.
    self.lowResImageView.hidden = NO;
    self.lowResImageView.alpha = 1.0f;
    [self.fullResImageView removeFromSuperview];
    self.fullResImageView = nil;
    self.fullResImage = nil;
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Helpers

- (void)loadLowResImages
{
    LYRMessagePart *lowResImagePart = ATLMessagePartForMIMEType(self.message, ATLMIMETypeImageJPEGPreview);
    LYRMessagePart *imageInfoPart = ATLMessagePartForMIMEType(self.message, ATLMIMETypeImageSize);

    if (!lowResImagePart) {
        // Default back to image/jpeg MIMEType
        lowResImagePart = ATLMessagePartForMIMEType(self.message, ATLMIMETypeImageJPEG);
    }
    
    // Retrieve low-res image from message part
    if (!(lowResImagePart.transferStatus == LYRContentTransferReadyForDownload || lowResImagePart.transferStatus == LYRContentTransferDownloading)) {
        if (lowResImagePart.fileURL) {
            self.lowResImage = [UIImage imageWithContentsOfFile:lowResImagePart.fileURL.path];
        } else {
            self.lowResImage = [UIImage imageWithData:lowResImagePart.data];
        }
        self.lowResImageView.image = self.lowResImage;
    }
    
    // Set the size of the canvas.
    if (imageInfoPart) {
        self.fullResImageSize = ATLImageSizeForJSONData(imageInfoPart.data);
    } else {
        if (self.lowResImage) {
            self.fullResImageSize = self.lowResImage.size;
        } else {
            return;
        }
    }
    
    self.scrollView.contentSize = self.fullResImageSize;
    self.imageViewFrame = CGRectMake(0, 0, self.fullResImageSize.width, self.fullResImageSize.height);
    self.lowResImageView.frame = self.imageViewFrame;
    [self viewDidLayoutSubviews];
}

- (void)loadFullResImages
{
    LYRMessagePart *fullResImagePart = ATLMessagePartForMIMEType(self.message, ATLMIMETypeImageJPEG);
    if (!fullResImagePart) {
        fullResImagePart = ATLMessagePartForMIMEType(self.message, ATLMIMETypeImagePNG);
    }
    
    // Retrieve hi-res image from message part
    if (!(fullResImagePart.transferStatus == LYRContentTransferReadyForDownload || fullResImagePart.transferStatus == LYRContentTransferDownloading)) {
        if (fullResImagePart.fileURL) {
            self.fullResImage = [UIImage imageWithContentsOfFile:fullResImagePart.fileURL.path];
        } else {
            self.fullResImage = [UIImage imageWithData:fullResImagePart.data];
        }
        self.fullResImageView.image = self.fullResImage;
    }
    if (!self.fullResImage) {
        return;
    }
    self.fullResImageView.frame = self.imageViewFrame;
    [UIView animateWithDuration:ATLMImageViewControllerAnimationDuration animations:^{
        self.fullResImageView.alpha = 1.0f; // make the full res image appear.
        self.progressView.alpha = 0.0;
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }];
    [self viewDidLayoutSubviews];
}

- (void)downloadFullResImageIfNeeded
{
    LYRMessagePart *fullResImagePart = ATLMessagePartForMIMEType(self.message, ATLMIMETypeImageJPEG);
    if (!fullResImagePart) {
        fullResImagePart = ATLMessagePartForMIMEType(self.message, ATLMIMETypeImagePNG);
    }
    
    // Download hi-res image from the network
    if (fullResImagePart && (fullResImagePart.transferStatus == LYRContentTransferReadyForDownload || fullResImagePart.transferStatus == LYRContentTransferDownloading)) {
        NSError *error;
        LYRProgress *downloadProgress = [fullResImagePart downloadContent:&error];
        if (!downloadProgress) {
            NSLog(@"problem downloading full resolution photo with %@", error);
            return;
        }
        downloadProgress.delegate = self;
        self.title = @"Downloading Image...";
        [UIView animateWithDuration:ATLMImageViewControllerAnimationDuration animations:^{
            self.progressView.alpha = 1.0f;
        }];
    } else {
        [self loadFullResImages];
    }
}

- (void)configureForAvailableSpace
{
    if (!self.view.superview) return;

    // We want to position and zoom the image based on the available size, i.e. so that it can be seen without being obstructed by the navigation bar or a toolbar.
    CGSize availableSize = self.scrollView.bounds.size;
    availableSize.height -= self.scrollView.contentInset.top;
    availableSize.height -= self.scrollView.contentInset.bottom;

    // We don't want to display the image larger than its native size.
    CGFloat maximumScale;
    if ((self.fullResImageSize.width / [[UIScreen mainScreen] scale] < self.view.frame.size.width) &&
        (self.fullResImageSize.height / [[UIScreen mainScreen] scale] < self.view.frame.size.height)) {
        // Fallback to default image scale;
        maximumScale = 1;
    } else {
        // Force device scale of the image (1:1 pixel mapping).
        maximumScale = 1 / [[UIScreen mainScreen] scale];
    }

    // The smallest we want to display the image is the size that it completely fits onscreen.
    CGFloat xFittedScale = availableSize.width / self.fullResImageSize.width;
    CGFloat yFittedScale = availableSize.height / self.fullResImageSize.height;
    CGFloat fittedScale = MIN(xFittedScale, yFittedScale);

    // If we're dealing with a small image then we only display it at its native size.
    CGFloat minimumScale = MIN(fittedScale, maximumScale);

    // If we're already at the minimum scale, we want to remain at that scale after our adjustments.
    BOOL atMinimumZoomScale = self.scrollView.zoomScale == self.scrollView.minimumZoomScale;
    self.scrollView.maximumZoomScale = maximumScale;
    self.scrollView.minimumZoomScale = minimumScale;
    if (atMinimumZoomScale) {
        self.scrollView.zoomScale = minimumScale;
    }

    CGRect imageViewFrame = self.lowResImageView.frame;

    // If the entire image width is onscreen then we horizontally center the image in the available space.
    if (CGRectGetWidth(imageViewFrame) < availableSize.width) {
        imageViewFrame.origin.x = (availableSize.width - CGRectGetWidth(imageViewFrame)) / 2;
    } else {
        imageViewFrame.origin.x = 0;
    }

    // If the entire image height is onscreen then we vertically center the image in the available space.
    if (CGRectGetHeight(imageViewFrame) < availableSize.height) {
        imageViewFrame.origin.y = (availableSize.height - CGRectGetHeight(imageViewFrame)) / 2;
    } else {
        imageViewFrame.origin.y = 0;
    }

    self.imageViewFrame = imageViewFrame;
    self.lowResImageView.frame = imageViewFrame;
    self.fullResImageView.frame = imageViewFrame;
}

#pragma mark - LYRProgress Delegate Implementation

- (void)progressDidChange:(LYRProgress *)progress
{
    // Queue UI updates onto the main thread, since LYRProgress performs
    // delegate callbacks from a background thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL progressCompleted = progress.fractionCompleted == 1.0f;
        [self.progressView setProgress:progress.fractionCompleted animated:YES];
        // After transfer completes, remove self for delegation.
        if (progressCompleted) {
            progress.delegate = nil;
            self.title = @"Image Downloaded";
            [self loadFullResImages];
        }
    });
}

@end
