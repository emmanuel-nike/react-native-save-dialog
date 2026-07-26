require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -Wno-comma -Wno-shorten-64-to-32'

Pod::Spec.new do |s|
  s.name         = "react-native-save-dialog"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "11.0" }
  s.source       = { :git => "https://github.com/emmanuel-nike/react-native-save-dialog.git" }

  s.source_files = "ios/**/*.{h,m,mm}"

  s.dependency "React-Core"

  s.frameworks = 'MobileCoreServices'

  # This guard prevent to install the dependencies when we run `pod install` in the old architecture.
  if ENV['RCT_NEW_ARCH_ENABLED'] == '1' then
      s.compiler_flags = folly_compiler_flags + " -DRCT_NEW_ARCH_ENABLED=1"
      s.pod_target_xcconfig    = {
          "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\"",
          "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
      }

      # install_modules_dependencies registers React-Codegen, RCT-Folly (at the version the
      # installed React Native vendors), RCTRequired, RCTTypeSafety and
      # ReactCommon/turbomodule/core. Declaring "RCT-Folly" manually breaks `pod install` on
      # React Native 0.85+ (Folly 2024.11.18.00), because RCT-Folly is a third-party podspec
      # that is only made resolvable through this helper.
      install_modules_dependencies(s)
  end

end
