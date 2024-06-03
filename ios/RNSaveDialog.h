#ifdef RCT_NEW_ARCH_ENABLED
#import <rnsavedialog/rnsavedialog.h>
#else
#import <React/RCTBridgeModule.h>
#endif

#import <UIKit/UIKit.h>

@interface RNSaveDialog : NSObject <
#ifdef RCT_NEW_ARCH_ENABLED
        NativeSaveDialogSpec
#else
        RCTBridgeModule
#endif
    >
@end
