#!/usr/bin/env ruby
# frozen_string_literal: true

# Verify the ONNX PDF stylesheet before it reaches mn2pdf.
#
#   scripts/check-stylesheet.rb [path]
#
# Two properties, both of which have failed silently before:
#
#   1. The file is well-formed XML. mn2pdf parses the stylesheet itself, and a
#      malformed one fails there with "Content is not allowed in prolog" —
#      after which Metanorma still exits 0 and simply produces no PDF. Checking
#      here fails the build early, and needs no fonts, so it works in
#      environments where a full PDF render cannot run.
#
#   2. No publisher name from the upstream stylesheet survives in its body.
#      Publishing a document that carries another organization's name or
#      copyright would misrepresent it. The file's own header names its source
#      deliberately, so the header is skipped.

require "nokogiri"

path = ARGV[0] || "sources/onnx.standard.xsl"
abort "#{path}: not found" unless File.exist?(path)

source = File.read(path, encoding: "UTF-8")
failures = []

begin
  doc = Nokogiri::XML(source, &:strict)
  puts "#{path}: well-formed XML (root <#{doc.root&.name}>)"
rescue Nokogiri::XML::SyntaxError => e
  failures << "not well-formed XML: #{e.message}"
end

# Skip the leading provenance comment: everything up to the end of the first
# comment that starts the file.
body = source.sub(/\A\s*(<\?xml[^>]*\?>)?\s*<!--.*?-->/m, "")

BRANDING = /calconnect|calendaring and scheduling|consortium, inc/i
offenders = body.each_line.with_index(1).select { |line, _| line.match?(BRANDING) }
unless offenders.empty?
  failures << "upstream publisher name left in the body of the stylesheet:\n" +
              offenders.map { |line, n| "    line #{n}: #{line.strip[0, 100]}" }.join("\n")
end
puts "#{path}: no upstream publisher name in body" if offenders.empty?

unless failures.empty?
  warn "\n#{path}: FAILED"
  failures.each { |f| warn "  - #{f}" }
  exit 1
end
