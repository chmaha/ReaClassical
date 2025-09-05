front_matter="docs/core/src/01_front_matter/front_matter.adoc"
index="docs/core/src/index.adoc"
current_date=$(TZ=UTC date "+%Y-%m-%d %H:%M:%S")
sed -i "s/\`Updated:.*/\`Updated: $current_date UTC\`/" "$front_matter" \
&& sed -i "s/^Generated.*/Generated $current_date UTC/" "$index" \
&& asciidoctor -o docs/core/index.html docs/core/src/index.adoc \
&& asciidoctor-pdf -a imagesdir=assets docs/core/src/index.adoc -o PDF-Manual/ReaClassical-Core-Manual.pdf
