Pod::Spec.new do |s|
  s.name         = 'YUSCNSceneCIRenderExtension'
  s.version      = '0.1'
  s.author       = { 'YuAo' => 'me@imyuao.com' }
  s.homepage     = 'https://github.com/YuAo/YUSCNSceneCIRenderExtension'
  s.summary      = 'Render a SCNScene to CIImages.'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.source       = {:git => 'https://github.com/YuAo/YUSCNSceneCIRenderExtension.git', :tag => '0.1'}
  s.requires_arc = true
  s.ios.deployment_target = '8.0'
  s.source_files = 'Sources/**/*.{h,m}'
end
