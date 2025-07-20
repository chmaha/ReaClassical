front_matter="docs/manual/src/01_front_matter/front_matter.adoc"
index="docs/manual/src/index.adoc"
current_date=$(TZ=UTC date "+%Y-%m-%d %H:%M:%S")
sed -i "s/\`Updated:.*/\`Updated: $current_date UTC\`/" "$front_matter" \
&& sed -i "s/^Generated.*/Generated $current_date UTC/" "$index" \
&& asciidoctor -o docs/manual/index.html docs/manual/src/index.adoc \
&& asciidoctor-pdf -a imagesdir=assets docs/manual/src/index.adoc -o PDF-Manual/ReaClassical-Manual.pdf
