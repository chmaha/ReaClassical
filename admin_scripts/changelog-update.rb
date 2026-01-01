#!/usr/bin/env ruby
code_path = "code/chmaha/ReaClassical"
html_file_path = File.join(Dir.home, code_path, "admin_scripts/rc_changelog.html")
lua_file_path = File.join(Dir.home, code_path, "ReaClassical", "ReaClassical.lua")

begin
    # Extract version from @version line in ReaClassical.lua
    version_line = File.foreach(lua_file_path).find { |line| line =~ /^@\s*version\s+([^\s]+)/i }
    if version_line
        highest_version_reaclassical = version_line[/@version\s+([^\s]+)/i, 1]
    else
        puts "No @version tag found in #{lua_file_path}"
        highest_version_reaclassical = nil
    end

    # Read the HTML file and update the version input field
    html_content = File.read(html_file_path)
    if highest_version_reaclassical
        html_content.gsub!(
            /(<input type="text" id="version" name="version" value=")([^"]*)(")/,
            "\\1#{highest_version_reaclassical}\\3"
        )
    end

    # Read ReaClassical.lua and extract changelog
    changelog_lines = []
    in_changelog_section = false
    in_metapackage_section = false

    File.readlines(lua_file_path).each do |line|
        if line =~ /^@\s*changelog/i
            in_changelog_section = true
            next
        elsif line =~ /^@\s*metapackage/i
            in_metapackage_section = true
            break
        elsif in_changelog_section
            changelog_lines << line.strip unless line.strip.empty?
        end
    end

    # Prepare changelog content for the textarea
    changelog_textarea_content = changelog_lines.join("\n")

    # Update the textarea in the HTML
    html_content.gsub!(
        /(<textarea id="changelog" name="changelog">)(.*?)(<\/textarea>)/m,
        "\\1#{changelog_textarea_content}\\3"
    )

    # Write the updated content back to the HTML file
    File.write(html_file_path, html_content)

    puts "Updated version to #{highest_version_reaclassical} and added changelog to textarea in #{html_file_path}"

    system("xdg-open #{html_file_path}") # Linux only

rescue => e
    puts "Failed to update: #{e.message}"
end
