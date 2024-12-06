#import "RNSaveDialog.h"

#import <MobileCoreServices/MobileCoreServices.h>

#import <React/RCTConvert.h>
#import <React/RCTBridge.h>
#import <React/RCTUtils.h>
#import "RNCPromiseWrapper.h"
#import "RCTConvert+RNSaveDialog.h"

static NSString *const E_SAVE_DIALOG_CANCELED = @"SAVE_DIALOG_CANCELED";
static NSString *const E_INVALID_DATA_RETURNED = @"INVALID_DATA_RETURNED";

static NSString *const OPTION_TYPE = @"type";
static NSString *const OPTION_MULTIPLE = @"allowMultiSelection";

static NSString *const FIELD_URI = @"uri";
static NSString *const FIELD_FILE_COPY_URI = @"fileCopyUri";
static NSString *const FIELD_COPY_ERR = @"copyError";
static NSString *const FIELD_NAME = @"name";
static NSString *const FIELD_TYPE = @"type";
static NSString *const FIELD_SIZE = @"size";


@interface RNSaveDialog () <UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate>
@end

@implementation RNSaveDialog {
    NSString *saveDestination;
    NSString *copyDestination;
    RNCPromiseWrapper* promiseWrapper;
}

- (instancetype)init
{
    if ((self = [super init])) {
        promiseWrapper = [RNCPromiseWrapper new];
    }
    return self;
}

- (void)dealloc
{
    
}

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(pick:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    UIDocumentPickerMode mode = UIDocumentPickerModeOpen;

    UIModalPresentationStyle presentationStyle = [RCTConvert UIModalPresentationStyle:options[@"presentationStyle"]];
    UIModalTransitionStyle transitionStyle = [RCTConvert UIModalTransitionStyle:options[@"transitionStyle"]];

    [promiseWrapper setPromiseWithInProgressCheck:resolve rejecter:reject fromCallSite:@"pick"];

    NSArray *allowedUTIs = [RCTConvert NSArray:options[OPTION_TYPE]];
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:allowedUTIs inMode:mode];

    documentPicker.modalPresentationStyle = presentationStyle;
    documentPicker.modalTransitionStyle = transitionStyle;
    documentPicker.delegate = self;
    documentPicker.presentationController.delegate = self;
    documentPicker.allowsMultipleSelection = [RCTConvert BOOL:options[OPTION_MULTIPLE]];

    UIViewController *rootViewController = RCTPresentedViewController();

    [rootViewController presentViewController:documentPicker animated:YES completion:nil];
}

RCT_EXPORT_METHOD(saveFile:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    saveDestination = options[@"saveTo"];
    UIModalPresentationStyle presentationStyle = [RCTConvert UIModalPresentationStyle:options[@"presentationStyle"]];
    UIModalTransitionStyle transitionStyle = [RCTConvert UIModalTransitionStyle:options[@"transitionStyle"]];
    [promiseWrapper setPromiseWithInProgressCheck:resolve rejecter:reject fromCallSite:@"saveFile"];

    UIDocumentPickerViewController *documentPicker;
    NSURL *path = [NSURL fileURLWithPath:options[@"path"]];

    documentPicker = [[UIDocumentPickerViewController alloc] initWithURL:path inMode:UIDocumentPickerModeExportToService];

    documentPicker.modalPresentationStyle = presentationStyle;
    documentPicker.modalTransitionStyle = transitionStyle;

    documentPicker.delegate = self;
    documentPicker.presentationController.delegate = self;
    documentPicker.directoryURL = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;

    UIViewController *rootViewController = RCTPresentedViewController();

    [rootViewController presentViewController:documentPicker animated:YES completion:nil];
}


- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    // Handle the picked documents here
    NSMutableArray *results = [NSMutableArray array];
    for (NSURL *url in urls) {
        // Save the picked document to the documents directory
        NSError *error;
        NSMutableDictionary *result = [self getMetadataForUrl:url error:&error];
        
        if(saveDestination) {
            NSData *fileData = [NSData dataWithContentsOfURL:url];
            NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:url.lastPathComponent];
            [fileData writeToFile:filePath atomically:YES];
        }

        if (result) {
            [results addObject:result];
        } else {
            [promiseWrapper reject:E_INVALID_DATA_RETURNED withError:error];
            return;
        }
    }

    [promiseWrapper resolve:results];
}

- (NSMutableDictionary *)getMetadataForUrl:(NSURL *)url error:(NSError **)error
{
    __block NSMutableDictionary *result = [NSMutableDictionary dictionary];
    
    // TODO handle error
    [url startAccessingSecurityScopedResource];

    NSFileCoordinator *coordinator = [NSFileCoordinator new];
    NSError *fileError;

    // TODO double check this implemenation, see eg. https://developer.apple.com/documentation/foundation/nsfilecoordinator/1412420-prepareforreadingitemsaturls
    [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingResolvesSymbolicLink error:&fileError byAccessor:^(NSURL *newURL) {
        // If the coordinated operation fails, then the accessor block never runs
        result[FIELD_URI] = url.absoluteString;
        
        NSError *copyError;
        NSURL *maybeFileCopyPath = nil;
        if(saveDestination) {
            maybeFileCopyPath = [RNSaveDialog copyToUniqueDestinationFrom:newURL usingDestinationPreset:saveDestination error:&copyError];
        }
        else if(copyDestination) {
            maybeFileCopyPath = [RNSaveDialog copyToUniqueDestinationFrom:newURL usingDestinationPreset:copyDestination error:&copyError];
        }
        
        if (!copyError) {
            result[FIELD_FILE_COPY_URI] = RCTNullIfNil(maybeFileCopyPath.absoluteString);
        } else {
            result[FIELD_COPY_ERR] = copyError.localizedDescription;
            result[FIELD_FILE_COPY_URI] = [NSNull null];
        }

        result[FIELD_NAME] = newURL.lastPathComponent;

        NSError *attributesError = nil;
        NSDictionary *fileAttributes = [NSFileManager.defaultManager attributesOfItemAtPath:newURL.path error:&attributesError];
        if(!attributesError) {
            result[FIELD_SIZE] = fileAttributes[NSFileSize];
        } else {
            result[FIELD_SIZE] = [NSNull null];
            NSLog(@"RNSaveDialog: %@", attributesError);
        }

        if (newURL.pathExtension != nil) {
            CFStringRef extension = (__bridge CFStringRef) newURL.pathExtension;
            CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, extension, NULL);
            CFStringRef mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType);
            if (uti) {
                CFRelease(uti);
            }

            NSString *mimeTypeString = (__bridge_transfer NSString *)mimeType;
            result[FIELD_TYPE] = mimeTypeString;
        } else {
            result[FIELD_TYPE] = [NSNull null];
        }
    }];

    [url stopAccessingSecurityScopedResource];

    if (fileError) {
        *error = fileError;
        return nil;
    } else {
        return result;
    }
}

RCT_EXPORT_METHOD(releaseSecureAccess:(NSArray<NSString *> *)uris
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSMutableArray *discardedItems = [NSMutableArray array];
    resolve(nil);
}

+ (NSURL *)copyToUniqueDestinationFrom:(NSURL *)url usingDestinationPreset:(NSString *)saveToDirectory error:(NSError **)error
{
    NSURL *destinationRootDir = [self getDirectoryForFileCopy:saveToDirectory];
    // we don't want to rename the file so we put it into a unique location
    NSString *uniqueSubDirName = [[NSUUID UUID] UUIDString];
    NSURL *destinationDir = [destinationRootDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/", uniqueSubDirName]];
    NSURL *destinationUrl = [destinationDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@", url.lastPathComponent]];

    [NSFileManager.defaultManager createDirectoryAtURL:destinationDir withIntermediateDirectories:YES attributes:nil error:error];
    if (*error) {
        return nil;
    }
    [NSFileManager.defaultManager copyItemAtURL:url toURL:destinationUrl error:error];
    if (*error) {
        return nil;
    } else {
        return destinationUrl;
    }
}

+ (NSURL *)getDirectoryForFileCopy:(NSString *)copyToDirectory
{
    if ([@"cachesDirectory" isEqualToString:copyToDirectory]) {
        return [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    } else if ([@"documentDirectory" isEqualToString:copyToDirectory]) {
        return [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    }
    // this should not happen as the value is checked in JS, but we fall back to NSTemporaryDirectory()
    return [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    [self rejectAsUserCancellationError];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController
{
    [self rejectAsUserCancellationError];
}

- (void)rejectAsUserCancellationError
{
    // TODO make error nullable?
    NSError* error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
    [promiseWrapper reject:@"user canceled the save dialog" withCode:E_SAVE_DIALOG_CANCELED withError:error];
}

// Thanks to this guard, we won't compile this code when we build for the old architecture.
#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeSaveDialogSpecJSI>(params);
}
#endif

@end
