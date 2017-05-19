Pod::Spec.new do |s|
s.name         = "MMNetworkingKit"
s.version      = "0.0.1"
s.summary      = "MMNetworkingKit is a networking framework for iOS."

s.description  = <<-DESC
MMNetworkingKit provide a networking layer for your App where you could perform all URL requesting operations in ease and clean way.
DESC

s.homepage     = "https://github.com/Meseery/MMNetworkingKit.git"
s.license      = { :type => "MIT", :file => "LICENSE" }
s.author       = { "Meseery" => "eng.m.elmeseery@gmail.com" }

s.platform     = :ios, "9.0"
s.source       = { :git => "https://github.com/Meseery/MMNetworkingKit.git", :tag => s.version }

s.source_files = "MMNetworkTaskQueue/*.{h,m}"
s.public_header_files = "MMNetworkTaskQueue/*.h"
end

