# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
target 'ConvertToWebP' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for ConvertToWebP
  pod 'SDWebImage'
  pod 'SDWebImageWebPCoder'
  pod 'libwebp'

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
  end

  target 'ConvertToWebPTests' do
    inherit! :search_paths
    # Pods for testing
    pod 'SDWebImage'
    pod 'SDWebImageWebPCoder'
  end

  target 'ConvertToWebPUITests' do
    # Pods for testing
    pod 'SDWebImage'
    pod 'SDWebImageWebPCoder'
  end

end
