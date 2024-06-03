package com.reactnativesavedialog;

import androidx.annotation.Nullable;

import com.facebook.react.TurboReactPackage;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.module.model.ReactModuleInfo;
import com.facebook.react.module.model.ReactModuleInfoProvider;

import java.util.HashMap;
import java.util.Map;

public class RNSaveDialogPackage extends TurboReactPackage {

  @Nullable
  @Override
  public NativeModule getModule(String name, ReactApplicationContext reactContext) {
    if (name.equals(RNSaveDialogModule.NAME)) {
      return new RNSaveDialogModule(reactContext);
    } else {
      return null;
    }
  }

  @Override
  public ReactModuleInfoProvider getReactModuleInfoProvider() {
    return () -> {
      boolean isTurboModule = BuildConfig.IS_NEW_ARCHITECTURE_ENABLED;
      final Map<String, ReactModuleInfo> moduleInfos = new HashMap<>();
      moduleInfos.put(
        RNSaveDialogModule.NAME,
        new ReactModuleInfo(
          RNSaveDialogModule.NAME,
          RNSaveDialogModule.NAME,
//          "SaveDialogModule",
          false, // canOverrideExistingModule
          false, // needsEagerInit
          true, // hasConstants
          false, // isCxxModule
          isTurboModule // isTurboModule
        ));
      return moduleInfos;
    };
  }
}
