use_frameworks!
platform :ios, '11.0'
inhibit_all_warnings!

# Import CocoaPods sources
source 'https://github.com/CocoaPods/Specs.git'

target 'discord-ios' do
  pod 'SnapKit'
  pod 'Kingfisher'
  pod 'PKHUD'
  pod 'SwiftLint'
  pod 'MJRefresh'
  pod 'TZImagePickerController'
  pod 'HyphenateChat_Circle'
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
