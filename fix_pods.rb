# fix_pods.rb
def fix_boring_ssl_flags(project_path)
  require 'xcodeproj'
  
  if File.exist?(project_path)
    project = Xcodeproj::Project.open(project_path)
    
    project.targets.each do |target|
      if target.name.include?('BoringSSL-GRPC')
        target.build_configurations.each do |config|
          # Fix compiler flags
          if config.build_settings['OTHER_CFLAGS']
            config.build_settings['OTHER_CFLAGS'] = config.build_settings['OTHER_CFLAGS'].gsub('-GCC_WARN_INHIBIT_ALL_WARNINGS', '-w')
          end
          
          # Fix any COMPILER_FLAGS
          if config.build_settings['COMPILER_FLAGS']
            config.build_settings['COMPILER_FLAGS'] = config.build_settings['COMPILER_FLAGS'].gsub('-GCC_WARN_INHIBIT_ALL_WARNINGS', '-w')
          end
        end
      end
    end
    
    project.save
    puts "Fixed BoringSSL flags for #{project_path}!"
  else
    puts "Skipping #{project_path} - doesn't exist"
  end
end

# Fix both iOS and macOS if they exist
fix_boring_ssl_flags('ios/Pods/Pods.xcodeproj')
fix_boring_ssl_flags('macos/Pods/Pods.xcodeproj')