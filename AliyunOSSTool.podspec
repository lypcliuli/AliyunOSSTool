Pod::Spec.new do |s|
  s.name         = "AliyunOSSTool"
  s.version      = "1.0.0"
  s.summary      = "集成阿里云OSS服务"
  s.homepage     = 'https://git.oschina.net/ct5621/AliyunOSSTool'

  s.license      = 'Apache License, Version 2.0'

  s.author             = { "ct5621" => "ct5621@163.com" }
  
  s.ios.deployment_target = '8.0'
  s.requires_arc = true 

  s.source       = { :git => "https://git.oschina.net/ct5621/AliyunOSSTool.git", :tag => s.version }
  

  s.subspec 'AliyunOSSTool' do |aliyunOSSTool|
     aliyunOSSTool.source_files = 'AliyunOSSTool/*'
     aliyunOSSTool.public_header_files = 'AliyunOSSTool/*.h'
     
  # 主模块(必须)
     aliyunOSSHander.dependency 'AliyunOSSiOS'
  end

end
