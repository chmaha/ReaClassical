RC_install_manual_html="$HOME/Desktop/ReaClassical_26/Scripts/chmaha Scripts/ReaClassical/ReaClassical-Manual.html"
RC_package_manual_html="$HOME/code/chmaha/ReaClassical/ReaClassical/ReaClassical-Manual.html"
RC_install_terminal_html="$HOME/Desktop/ReaClassical_26/Scripts/chmaha Scripts/ReaClassical/ReaClassical-Terminal-Guide.html"
RC_package_terminal_html="$HOME/code/chmaha/ReaClassical/ReaClassical/ReaClassical-Terminal-Guide.html"
front_matter="docs/manual/src/front_matter/front_matter.adoc"
index="docs/manual/src/index.adoc"
terminal_guide="docs/terminal_guide.md"
terminal_html="docs/rcterminal.html"
current_date=$(TZ=UTC date "+%Y-%m-%d %H:%M:%S")
sed -i "s/\`Updated:.*/\`Updated: $current_date UTC\`/" "$front_matter" \
&& sed -i "s/^Generated.*/Generated $current_date UTC/" "$index" \
&& asciidoctor -o docs/manual/index.html docs/manual/src/index.adoc \
&& asciidoctor-pdf -a imagesdir=assets docs/manual/src/index.adoc -o PDF-Manual/ReaClassical-Manual.pdf \
&& pandoc "$terminal_guide" -o "$terminal_html" \
    --standalone \
    --metadata pagetitle="ReaClassical Terminal — Complete Command Guide" \
    --metadata lang=en \
    --metadata document-css=false \
    --css=css/rcterminal.css \
&& asciidoctor -a data-uri -a webfonts\! -a imagesdir=assets \
    -o "$RC_package_manual_html" docs/manual/src/index.adoc \
&& cp "$RC_package_manual_html" "$RC_install_manual_html" \
&& pandoc "$terminal_guide" -o "$RC_package_terminal_html" \
    --standalone \
    --embed-resources \
    --metadata pagetitle="ReaClassical Terminal — Complete Command Guide" \
    --metadata lang=en \
    --metadata document-css=false \
    --css=docs/css/rcterminal.css \
&& cp "$RC_package_terminal_html" "$RC_install_terminal_html"

