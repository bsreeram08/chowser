require 'xcodeproj'

project_path = "Chowser.xcodeproj"
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == "Chowser" }

if project.targets.any? { |t| t.name == "ChowserUITests" }
  puts "Target already exists."
  exit 0
end

target = project.new_target(:ui_test_bundle, "ChowserUITests", :macos, app_target.deployment_target)

# Add group
group = project.main_group.find_subpath("ChowserUITests", true)
group.set_source_tree('<group>')
group.set_path('ChowserUITests')

# Add swift file
file_ref = group.new_file("ChowserUITests.swift")
target.source_build_phase.add_file_reference(file_ref)

# Configure build settings
target.build_configurations.each do |config|
  config.build_settings['TEST_TARGET_NAME'] = "Chowser"
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "in.sreerams.ChowserUITests"
  config.build_settings['GENERATE_INFOPLIST_FILE'] = "YES"
  config.build_settings['SWIFT_VERSION'] = "5.0"
  config.build_settings['CODE_SIGN_STYLE'] = "Automatic"
  config.build_settings['DEVELOPMENT_TEAM'] = app_target.build_settings("Release")['DEVELOPMENT_TEAM']
end

app_target.add_dependency(target)

project.save
puts "Added ChowserUITests target via xcodeproj."
