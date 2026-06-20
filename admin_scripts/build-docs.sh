RC_install="$HOME/Desktop/ReaClassical_26/Scripts/chmaha Scripts/ReaClassical/ReaClassical-Manual.pdf"
RC_package="$HOME/code/chmaha/ReaClassical/ReaClassical/ReaClassical-Manual.pdf"
front_matter="docs/manual/src/front_matter/front_matter.adoc"
index="docs/manual/src/index.adoc"
terminal_guide="docs/terminal_guide.md"
terminal_html="docs/rcterminal.html"
current_date=$(TZ=UTC date "+%Y-%m-%d %H:%M:%S")
sed -i "s/\`Updated:.*/\`Updated: $current_date UTC\`/" "$front_matter" \
&& sed -i "s/^Generated.*/Generated $current_date UTC/" "$index" \
&& asciidoctor -o docs/manual/index.html docs/manual/src/index.adoc \
&& asciidoctor-pdf -a imagesdir=assets docs/manual/src/index.adoc -o PDF-Manual/ReaClassical-Manual.pdf \
&& cp PDF-Manual/ReaClassical-Manual.pdf "$RC_install" \
&& cp PDF-Manual/ReaClassical-Manual.pdf "$RC_package" \
&& pandoc "$terminal_guide" -o "$terminal_html" \
    --standalone \
    --metadata pagetitle="ReaClassical Terminal — Complete Command Guide" \
    --metadata lang=en \
    --metadata document-css=false \
    --css=css/rcterminal.css

