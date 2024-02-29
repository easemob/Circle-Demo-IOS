use_frameworks!
platform :ios, '11.0'
inhibit_all_warnings!

# Import CocoaPods sources
source 'https://github.com/CocoaPods/Specs.git'

target 'discord-ios' do
  post_install do |installer|
        installer.generated_projects.each do |project|
          project.targets.each do |target|
              target.build_configurations.each do |config|
                  config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "13.0"
                  config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
               end
          end
        end
      end
  pod 'SnapKit'
  pod 'Kingfisher'
  pod 'PKHUD'
  pod 'SwiftLint'
  pod 'MJRefresh'
  pod 'TZImagePickerController'
  pod 'AgoraRtcEngine_iOS/RtcBasic', '4.1.0'
  pod 'HyphenateChat_Circle', "3.9.9.2"
  pod 'Bugly'
end

pre_install do |installer|
    remove_swiftui()
end

def remove_swiftui
  # 解决 xcode13 Release模式下SwiftUI报错问题
  system("rm -rf ./Pods/Kingfisher/Sources/SwiftUI")
  code_file = "./Pods/Kingfisher/Sources/General/KFOptionsSetter.swift"
  code_text = File.read(code_file)
  code_text.gsub!(/#if canImport\(SwiftUI\) \&\& canImport\(Combine\)(.|\n)+#endif/,'')
  system("rm -rf " + code_file)
  aFile = File.new(code_file, 'w+')
  aFile.syswrite(code_text)
  aFile.close()
end
