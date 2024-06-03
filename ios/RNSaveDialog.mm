#import "RNSaveDialog.h"

#import <MobileCoreServices/MobileCoreServices.h>

#import <React/RCTConvert.h>
#import <React/RCTBridge.h>
#import <React/RCTUtils.h>
#import "RNCPromiseWrapper.h"
#import "RCTConvert+RNSaveDialog.h"

static NSString *const E_SAVE_DIALOG_CANCELED = @"SAVE_DIALOG_CANCELED";
static NSString *const E_INVALID_DATA_RETURNED = @"INVALID_DATA_RETURNED";

static NSString *const FIELD_URI = @"uri";
static NSString *const FIELD_FILE_COPY_URI = @"fileCopyUri";
static NSString *const FIELD_COPY_ERR = @"copyError";
static NSString *const FIELD_NAME = @"name";
static NSString *const FIELD_TYPE = @"type";
static NSString *const FIELD_SIZE = @"size";


@interface RNSaveDialog () <UISaveDialogDelegate, UIAdaptivePresentationControllerDelegate>
@end

@implementation RNSaveDialog {
    NSString *saveDestination;
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
    for (NSURL *url in urlsInOpenMode) {
        [url stopAccessingSecurityScopedResource];
    }
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

RCT_EXPORT_METHOD(saveFile:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    saveDestination = options[@"saveTo"];
    UIModalPresentationStyle presentationStyle = [RCTConvert UIModalPresentationStyle:options[@"presentationStyle"]];
    UIModalTransitionStyle transitionStyle = [RCTConvert UIModalTransitionStyle:options[@"transitionStyle"]];
    [promiseWrapper setPromiseWithInProgressCheck:resolve rejecter:reject fromCallSite:@"saveFile"];

    UIDocumentPickerViewController *documentPicker;
    NSURL *path = [NSURL fileURLWithPath:options[OPTION_PATH]];

    mode = UIDocumentPickerModeExportToService;
    documentPicker = [[UIDocumentPickerViewController alloc] initWithURL:path inMode:mode];

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

        NSData *fileData = [NSData dataWithContentsOfURL:url];
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *filePath = [documentsDirectory stringByAppendingPathComponent:url.lastPathComponent];
        [fileData writeToFile:filePath atomically:YES];

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

    if (mode == UISaveDialogModeOpen) {
        [urlsInOpenMode addObject:url];
    }

    // TODO handle error
    [url startAccessingSecurityScopedResource];

    NSFileCoordinator *coordinator = [NSFileCoordinator new];
    NSError *fileError;

    // TODO double check this implemenation, see eg. https://developer.apple.com/documentation/foundation/nsfilecoordinator/1412420-prepareforreadingitemsaturls
    [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingResolvesSymbolicLink error:&fileError byAccessor:^(NSURL *newURL) {
        // If the coordinated operation fails, then the accessor block never runs
        result[FIELD_URI] = ((mode == UISaveDialogModeOpen) ? url : newURL).absoluteString;

        NSError *copyError;
        NSURL *maybeFileCopyPath = copyDestination ? [RNSaveDialog copyToUniqueDestinationFrom:newURL usingDestinationPreset:copyDestination error:&copyError] : nil;

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

    if (mode != UISaveDialogModeOpen) {
        [url stopAccessingSecurityScopedResource];
    }

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
    for (NSString *uri in uris) {
        for (NSURL *url in urlsInOpenMode) {
            if ([url.absoluteString isEqual:uri]) {
                [url stopAccessingSecurityScopedResource];
                [discardedItems addObject:url];
                break;
            }
        }
    }
    [urlsInOpenMode removeObjectsInArray:discardedItems];
    resolve(nil);
}

- (void)SaveDialogWasCancelled:(UISaveDialogViewController *)controller
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
    [promiseWrapper reject:@"user canceled the document picker" withCode:E_DOCUMENT_PICKER_CANCELED withError:error];
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
