#!/usr/bin/env ruby

require 'nokogiri'
require 'rubygems'

index_file_path = File.expand_path('index.xml', __dir__ + '/../')

begin
    xml_doc = Nokogiri::XML(File.read(index_file_path))

    def keep_last_versions(xml_doc, category_name)
        versions = xml_doc.xpath("//category[@name='#{category_name}']/reapack/version/@name").map(&:value)

        if versions.any?
            sorted_versions = versions.map { |v| Gem::Version.new(v) rescue nil }.compact.sort
            versions_to_keep = sorted_versions.last(3).map(&:to_s)

            xml_doc.xpath("//category[@name='#{category_name}']/reapack/version").each do |node|
                version = node.attribute('name').value
                node.remove unless versions_to_keep.include?(version)
            end

            puts "Kept last three versions for #{category_name}: #{versions_to_keep.join(', ')}"
        else
            puts "No versions found for #{category_name}"
        end
    end

    keep_last_versions(xml_doc, 'ReaClassical')
    keep_last_versions(xml_doc, 'RCPlugs')
    keep_last_versions(xml_doc, 'ReaClassicalCore')

    cleaned_xml = xml_doc.to_xml.lines.reject { |line| line.strip.empty? }.join
    File.write(index_file_path, cleaned_xml)

rescue => e
    warn "Failed to prune index.xml: #{e.message}"
    exit 1
end
