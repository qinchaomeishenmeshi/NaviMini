require 'xcodeproj'

project_path = File.expand_path('NaviMini.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group['NaviMini']
unless group
  group = project.main_group.new_group('NaviMini')
end

file_ref = group.new_file('Assets.xcassets')
target.add_resources([file_ref])
# Ensure build setting is there
target.build_configurations.each do |config|
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end

project.save
puts "Successfully added AppIcon to Xcode project"
