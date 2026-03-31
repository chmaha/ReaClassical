#!/usr/bin/env ruby
require 'tempfile'

code_path = "code/chmaha/ReaClassical"
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

  # Extract changelog lines
  changelog_lines = []
  in_changelog_section = false
  File.readlines(lua_file_path).each do |line|
    if line =~ /^@\s*changelog/i
      in_changelog_section = true
      next
    elsif line =~ /^@\s*metapackage/i
      break
    elsif in_changelog_section
      changelog_lines << line.strip unless line.strip.empty?
    end
  end

  changelog_textarea_content = changelog_lines.join("\n")

  # Build HTML dynamically
  html_content = <<~HTML
    <!-- Form for auto-generating the output required for ReaClassical new release posts on https://forum.cockos.com/showthread.php?t=265145 -->
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>ReaClassical Changelog Formatter</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            textarea { width: 100%; height: 150px; }
            button { margin-top: 10px; }
            #copy-alert { display: none; color: green; margin-top: 10px; }
            .color-inputs { display: flex; align-items: center; }
            .color-inputs input[type="text"] { margin-left: 10px; width: 80px; }
        </style>
    </head>
    <body>
        <h1>ReaClassical Changelog Formatter</h1>
        <form id="changelog-form">
            <label for="version">Version:</label><br>
            <input type="text" id="version" name="version" value="#{highest_version_reaclassical}"><br><br>

            <label for="changelog">Changelog (one per line):</label><br>
            <textarea id="changelog" name="changelog">#{changelog_textarea_content}</textarea><br><br>

            <label for="description">Description:</label><br>
            <textarea id="description" name="description"></textarea><br><br>

            <label for="color">Color:</label><br>
            <div class="color-inputs">
                <input type="color" id="color" name="color" onchange="updateManualHex()">
                <input type="text" id="manualHex" placeholder="#ffffff" oninput="updateColorPicker()">
            </div><br><br>

            <button type="button" onclick="randomizeColor()">Randomize Color</button><br><br>
            <button type="button" onclick="generateOutput()">Generate</button>
        </form>

        <div id="copy-alert">Formatted text copied to clipboard!</div>

        <script>
            function getRandomHexColor() {
                return '#' + Math.floor(Math.random() * 16777215).toString(16).padStart(6, '0');
            }
            function randomizeColor() {
                const randomColor = getRandomHexColor();
                document.getElementById('color').value = randomColor;
                document.getElementById('manualHex').value = randomColor;
            }
            function generateOutput() {
                const version = document.getElementById('version').value;
                const changelog = document.getElementById('changelog').value;
                const description = document.getElementById('description').value;
                const color = document.getElementById('color').value;
                let output = `[B][COLOR=${color}]NEW: ReaClassical ${version}[/COLOR][/B]\\n[LIST]\\n`;
                changelog.split('\\n').forEach(line => {
                    const trimmedLine = line.trim();
                    if (trimmedLine) { output += `[*][B]${trimmedLine}[/B]\\n`; }
                });
                output += `[/LIST]\\n${description}`;
                copyToClipboard(output);
                document.getElementById('copy-alert').style.display = 'block';
                setTimeout(() => { document.getElementById('copy-alert').style.display = 'none'; }, 3000);
            }
            function copyToClipboard(text) {
                navigator.clipboard.writeText(text).then(() => {
                    console.log('Copied to clipboard');
                }).catch(err => { console.error('Failed to copy: ', err); });
            }
            function updateManualHex() {
                document.getElementById('manualHex').value = document.getElementById('color').value;
            }
            function updateColorPicker() {
                const manualHex = document.getElementById('manualHex').value;
                if (/^#([0-9A-F]{3}|[0-9A-F]{6})$/i.test(manualHex)) {
                    document.getElementById('color').value = manualHex;
                }
            }
            window.onload = function() { randomizeColor(); }
        </script>
    </body>
    </html>
  HTML

  # Write to a temp file and open it
  tmp = Tempfile.new(['rc_changelog', '.html'])
  tmp.write(html_content)
  tmp.flush
  system("xdg-open #{tmp.path}")
  sleep 2  # Give the browser time to load before the file is cleaned up
  tmp.close
  tmp.unlink

  puts "Opened changelog formatter for version #{highest_version_reaclassical}"

rescue => e
  puts "Failed: #{e.message}"
end