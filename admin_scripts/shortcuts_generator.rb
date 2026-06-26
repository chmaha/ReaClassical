#!/usr/bin/env ruby
# REAPER KeyMap -> HTML Index Generator
# Reads ReaClassical/ReaClassical-kb.ini and writes a searchable shortcuts
# page to docs/rcshortcuts.html for inclusion in build-docs.sh.

require 'cgi'

ROOT_DIR = File.expand_path('..', __dir__)
DEFAULT_KB_PATH = File.join(ROOT_DIR, 'ReaClassical', 'ReaClassical-kb.ini')
DEFAULT_OUT_PATH = File.join(ROOT_DIR, 'docs', 'rcshortcuts.html')

# Comprehensive VK -> char map
VK = {
  8 => 'Backspace',
  9 => 'Tab',
  13 => 'Enter',
  32 => 'Space',
  44 => ',',
  46 => '.',
  59 => ';',
  96 => 'Numpad 0',
  48 => '0', 49 => '1', 50 => '2', 51 => '3', 52 => '4',
  53 => '5', 54 => '6', 55 => '7', 56 => '8', 57 => '9',
  65 => 'A', 66 => 'B', 67 => 'C', 68 => 'D', 69 => 'E',
  70 => 'F', 71 => 'G', 72 => 'H', 73 => 'I', 74 => 'J',
  75 => 'K', 76 => 'L', 77 => 'M', 78 => 'N', 79 => 'O',
  80 => 'P', 81 => 'Q', 82 => 'R', 83 => 'S', 84 => 'T',
  85 => 'U', 86 => 'V', 87 => 'W', 88 => 'X', 89 => 'Y', 90 => 'Z',
  112 => 'F1', 113 => 'F2', 114 => 'F3', 115 => 'F4', 116 => 'F5',
  117 => 'F6', 118 => 'F7', 119 => 'F8', 120 => 'F9', 121 => 'F10',
  122 => 'F11', 123 => 'F12',
  # REAPER special virtual key mappings
  32805 => 'Left',
  32806 => 'Up',
  32807 => 'Right',
  32808 => 'Down',
  32814 => 'Delete'
}.freeze

def decode_key(keycode)
  VK[keycode.to_i] || "VK#{keycode}"
end

def decode_mod(mod)
  mod = mod.to_i
  return 'None' if mod == 0 || mod == 1

  parts = []
  parts << 'Shift' if mod & 4 != 0
  parts << 'Ctrl' if mod & 8 != 0
  parts << 'Alt' if mod & 16 != 0
  parts << 'Win' if mod & 32 != 0

  parts.empty? ? 'None' : parts.join('+')
end

def parse_keymap(text)
  text = text.gsub("\r\n", "\n")
  path_db = {}
  name_db = {}
  shortcut_list = []

  # First pass: build databases from SCR lines
  text.each_line do |line|
    m = line.match(/SCR\s+\d+\s+\d+\s+(\S+)\s+"(.*?)"\s+"(.*?)"/)
    next unless m

    guid, name, path = m.captures
    name = name.sub(/^custom:\s*/i, '')
    name_db[guid] = name
    path_db[guid] = path
  end

  # Second pass: process KEY entries
  text.each_line do |line|
    m = line.match(/KEY\s+(\d+)\s+(\d+)\s+(\S+).*?#\s*(.*)$/)
    next unless m

    mod, key, raw_guid, comment = m.captures
    guid = raw_guid.sub(/^_*/, '').strip

    fallback_name = 'Unknown Action'
    if comment
      clean_comment = (comment.match(/.*:\s*(.*)$/) || [nil, comment])[1]
      fallback_name = clean_comment.sub(/^Script:\s*/, '').sub(/^OVERRIDE DEFAULT\s*:\s*/, '')
    end

    final_name = name_db[guid] || fallback_name
    final_path = path_db[guid] || 'Internal / Extension Action'

    next if final_name.include?('DISABLED DEFAULT') || raw_guid == '0'

    # REAPER's own comment is "<context> : <key combo> : <action>", so the
    # key combo -- always the second " : "-delimited field -- is authoritative
    # and covers far more keys than our own VK-code table could (mousewheel,
    # numpad, page up/down, etc.). Only fall back to decoding mod/key
    # ourselves if the comment doesn't have that shape.
    comment_parts = comment.split(' : ', 3)
    combination = if comment_parts.length >= 2
                    comment_parts[1]
                  else
                    mod_str = decode_mod(mod)
                    key_str = decode_key(key)
                    mod_str == 'None' ? key_str : "#{mod_str}+#{key_str}"
                  end

    is_xfm        = final_path.include?('ReaClassical_XFM')
    is_reaclassical = !is_xfm && final_path.include?('ReaClassical')
    type = if is_xfm then 'ReaClassical XFade Mode'
           elsif is_reaclassical then 'ReaClassical'
           else 'Internal / Extension'
           end
    display_name = if is_xfm
                     final_name.sub(/^ReaClassical_XFM /, '').sub(/\.lua$/i, '')
                   elsif is_reaclassical
                     final_name.sub(/^ReaClassical_/, '').sub(/\.lua$/i, '')
                   else
                     final_name
                   end

    shortcut_list << { name: display_name, type: type, shortcut: combination }
  end

  shortcut_list.sort_by { |s| s[:name] }
end

def generate_html(shortcuts)
  rows = shortcuts.map do |s|
    "<tr>" \
      "<td><strong>#{CGI.escapeHTML(s[:name])}</strong></td>" \
      "<td><code>#{CGI.escapeHTML(s[:type])}</code></td>" \
      "<td>#{CGI.escapeHTML(s[:shortcut])}</td>" \
      "</tr>"
  end

  <<~HTML
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <title>ReaClassical Keyboard Shortcuts</title>
    <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 30px; background-color: #f8f9fa; color: #333; }
    h2 { margin: 0 0 5px 0; color: #111; }
    small { color: #666; display: block; margin-bottom: 20px; font-style: italic; }
    input { width: 100%; padding: 12px; margin-bottom: 20px; border: 1px solid #ccc; border-radius: 6px; box-sizing: border-box; font-size: 16px; }
    table { width: 100%; border-collapse: collapse; background: white; border-radius: 6px; overflow: hidden; box-shadow: 0 2px 5px rgba(0,0,0,0.05); }
    th, td { border: 1px solid #eee; padding: 10px 14px; text-align: left; }
    th { background-color: #f1f3f5; font-weight: 600; color: #495057; }
    code { background: #f1f3f5; padding: 2px 6px; border-radius: 4px; font-size: 13px; }
    tr.hidden { display: none; }
    tr:hover { background-color: #fdfdfd; }
    </style>
    </head>
    <body>
    <h2>ReaClassical Keyboard Shortcuts</h2>
    <small>Source: ReaClassical-kb.ini</small>
    <input id="search" placeholder="Type to filter hotkeys...">
    <table id="tbl">
    <tr>
    <th width="45%">Action Name</th>
    <th width="35%">Type</th>
    <th width="20%">Shortcut</th>
    </tr>
    #{rows.join("\n")}
    </table>
    <script>
    const input = document.getElementById("search");
    input.addEventListener("input", function() {
        const q = this.value.toLowerCase();
        document.querySelectorAll("#tbl tr").forEach((row, i) => {
            if (i === 0) return;
            row.classList.toggle("hidden", !row.innerText.toLowerCase().includes(q));
        });
    });
    </script>
    </body>
    </html>
  HTML
end

# MAIN EXECUTION
kb_path = ARGV[0] || DEFAULT_KB_PATH
out_path = ARGV[1] || DEFAULT_OUT_PATH

unless File.exist?(kb_path)
  warn "Error: cannot read file #{kb_path}"
  exit 1
end

text = File.read(kb_path)
shortcuts = parse_keymap(text)
html = generate_html(shortcuts)

File.write(out_path, html)
