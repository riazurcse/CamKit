#
# Be sure to run `pod lib lint CamKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'CamKit'
  s.version          = '1.0.0'
  s.summary          = 'CamKit helps you to add reliable camera to your app quickly, which can take pictures & capture videos.'
  s.description = 'CamKit helps you to add reliable camera to your app quickly & easily. This open source camera platform provides consistent capture results while capturing photos & videos.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.homepage         = 'https://github.com/riazurcse/CamKit'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'riazurcse' => 'riazur90bd@gmail.com' }
  s.source           = { :git => 'https://github.com/riazurcse/CamKit.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
  s.swift_version = '5.0'
  s.platform = :ios, '11.0'
  s.ios.deployment_target = '11.0'

  s.source_files = 'CamKit/Classes/**/*'
  
  s.resource_bundles = {
    'Resources' => ['CamKit/Assets/*{.png,xib,storyboard,xcassets}']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'AVFoundation', 'Foundation'
  # s.dependency 'AFNetworking', '~> 2.3'
end
