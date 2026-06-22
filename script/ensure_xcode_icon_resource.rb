#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"

root = File.expand_path(ARGV[0] || File.expand_path("..", __dir__))
project_path = File.join(root, "PaperBanana.xcodeproj")
icon_path = File.join("PaperBanana", "Resources", "AppIcon.icon")

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |candidate| candidate.name == "PaperBanana" }
abort("PaperBanana target not found") unless target

main_group = project.main_group
paper_group = main_group.find_subpath("PaperBanana", true)
paper_group.set_path("PaperBanana")
resources_group = paper_group.find_subpath("Resources", true)
resources_group.set_path("Resources")

icon_ref = resources_group.files.find { |file| file.path == "AppIcon.icon" }
icon_ref ||= resources_group.new_file("AppIcon.icon")
icon_ref.last_known_file_type = "wrapper.icon"
icon_ref.source_tree = "<group>"

unless target.resources_build_phase.files_references.include?(icon_ref)
  target.resources_build_phase.add_file_reference(icon_ref)
end

target.build_configurations.each do |config|
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
end

project.predictabilize_uuids
project.save
