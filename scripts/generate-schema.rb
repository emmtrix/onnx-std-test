#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate Annex B of Part 1 from the vendored Protocol Buffers schema.
#
#   scripts/generate-schema.rb [--check]
#
# Annex B owes a table of fields per message, giving wire tag, type and
# obligation. The schema source cannot state an obligation -- every proto2
# field is syntactically optional -- so the obligation is read from the
# comment convention the upstream versioning document defines: a field whose
# leading comment says it MUST be present for this version of the IR is
# mandatory, and every other field is optional. A repeated field is neither;
# its obligation is its cardinality.
#
# `--check` regenerates into memory and fails if the file on disk differs,
# which is what CI runs.
#
# What this script deliberately does not carry across is the prose of the
# schema comments. A field table states structure; where a comment carries a
# normative statement it belongs in a clause, and the clauses of this part are
# where those statements now are. The schema source stays vendored as the
# informative aid Annex B points at.

require "optparse"

ROOT = File.expand_path("..", __dir__)

# The ONNX-ML schema is the superset: it defines the map and sequence types
# and the ai.onnx.ml operator set that Part 2 specifies alongside the default
# domain. The plain onnx.proto is the same file with those omitted.
SOURCES = [
  { file: "upstream/onnx/proto/onnx-ml.proto",
    title: "Model, graph and tensor messages" },
  { file: "upstream/onnx/proto/onnx-operators-ml.proto",
    title: "Operator set messages" },
  { file: "upstream/onnx/proto/onnx-data.proto",
    title: "Map and sequence messages" },
].freeze

TARGET = "sources/part1/sections/annex-b-protobuf-schema.adoc"

MANDATORY = /MUST be present (?:in|for) this version of the IR/i.freeze

Field = Struct.new(:label, :type, :name, :tag, :mandatory, :oneof, :deprecated)
Enum  = Struct.new(:name, :values)
Msg   = Struct.new(:name, :fields, :enums, :reserved)

# --------------------------------------------------------------------- parse

# A hand-rolled reader for the subset of proto2 these files use: messages,
# nested messages, enums, oneofs, reserved ranges and scalar fields. It is not
# a proto parser and is not meant to be one; it fails loudly on anything it
# does not recognise inside a message body rather than skipping it, so that a
# schema change upstream shows up as a failed run rather than a missing row.
def parse(path)
  messages = []
  stack = []          # enclosing message names
  comment = []        # comment lines gathered since the last statement
  enum = nil
  oneof = nil
  depth_of_oneof = nil

  # The message currently being read, by its full path. `messages.last` is not
  # it: once a nested message closes, the fields that follow belong to the
  # enclosing message again, and appending them to the last entry created
  # silently moved them onto the nested one.
  current = lambda do
    path_now = stack.join(".")
    messages.reverse.find { |m| m.name == path_now }
  end

  File.readlines(path, encoding: "UTF-8").each_with_index do |raw, i|
    line = raw.strip
    lineno = i + 1

    if line.start_with?("//")
      comment << line.sub(%r{\A//\s?}, "")
      next
    end
    if line.empty?
      comment.clear if stack.empty? && enum.nil?
      next
    end

    case line
    when /\A(?:syntax|package|option|import)\b/
      comment.clear
    when /\Amessage\s+(\w+)\s*\{/
      stack << Regexp.last_match(1)
      messages << Msg.new(stack.join("."), [], [], [])
      comment.clear
    when /\Aenum\s+(\w+)\s*\{/
      enum = Enum.new([*stack, Regexp.last_match(1)].join("."), [])
      # A top-level enum has no message to hang on; give it one of its own so
      # that it is emitted in source order rather than dropped.
      messages << Msg.new(enum.name, [], [], []) if stack.empty?
      comment.clear
    when /\Aoneof\s+(\w+)\s*\{/
      oneof = Regexp.last_match(1)
      depth_of_oneof = stack.length
      comment.clear
    when /\Areserved\s+(.+);/
      owner = current.call or raise "#{path}:#{lineno}: reserved outside a message"
      owner.reserved << Regexp.last_match(1).strip
      comment.clear
    when /\A\}\s*;?\z/
      if enum
        # Nested enums belong to the message being read; a top-level enum
        # belongs to the entry opened for it above, which is the last one.
        owner = stack.empty? ? messages.last : current.call
        owner or raise "#{path}:#{lineno}: enum has no owner"
        owner.enums << enum
        enum = nil
      elsif oneof && depth_of_oneof == stack.length
        oneof = nil
      else
        stack.pop or raise "#{path}:#{lineno}: unbalanced brace"
      end
      comment.clear
    when /\A(\w+)\s*=\s*(0[xX][0-9a-fA-F]+|\d+)\s*;/ # enum member
      enum or raise "#{path}:#{lineno}: enum member outside an enum: #{line}"
      enum.values << [Regexp.last_match(1), Integer(Regexp.last_match(2))]
      comment.clear
    when /\A(optional|repeated|required)?\s*([\w.<>, ]+?)\s+(\w+)\s*=\s*(\d+)\s*(\[[^\]]*\])?\s*;/
      label = Regexp.last_match(1) || (oneof ? "oneof" : "optional")
      type  = Regexp.last_match(2).strip
      name  = Regexp.last_match(3)
      tag   = Regexp.last_match(4).to_i
      text  = comment.join(" ")
      owner = current.call or raise "#{path}:#{lineno}: field outside a message"
      owner.fields << Field.new(
        label, type, name, tag,
        text.match?(MANDATORY), oneof,
        text.match?(/\bdeprecated\b/i)
      )
      comment.clear
    else
      raise "#{path}:#{lineno}: unrecognised: #{line}"
    end
  end

  stack.empty? or raise "#{path}: unterminated message #{stack.inspect}"
  messages.reject { |m| m.fields.empty? && m.enums.empty? }
end

# --------------------------------------------------------------------- emit

def obligation(field)
  return "deprecated" if field.deprecated
  return "repeated" if field.label == "repeated"
  return "one of the group" if field.label == "oneof"

  field.mandatory ? "mandatory" : "optional"
end

def adoc_type(type)
  "`#{type}`"
end

def anchor(name)
  "schema-#{name.downcase.tr('.', '-')}"
end

def render_message(msg)
  out = []
  out << "[[#{anchor(msg.name)}]]"
  out << "==== #{msg.name}"
  out << ""

  unless msg.fields.empty?
    out << "[[tbl-#{anchor(msg.name)}]]"
    out << ".Fields of `#{msg.name}`"
    out << '[cols="3,1,3,2"]'
    out << "|==="
    out << "| Field | Tag | Type | Obligation"
    out << ""
    msg.fields.each do |f|
      out << "| `#{f.name}` | #{f.tag} | #{adoc_type(f.type)} | #{obligation(f)}"
    end
    out << "|==="
    out << ""
  end

  groups = msg.fields.map(&:oneof).compact.uniq
  groups.each do |g|
    members = msg.fields.select { |f| f.oneof == g }.map { |f| "`#{f.name}`" }
    out << "Exactly one of #{members.join(', ')} SHALL be present, being the " \
           "group `#{g}`."
    out << ""
  end

  unless msg.reserved.empty?
    out << "Tags and names reserved in `#{msg.name}`, which SHALL NOT be used: " \
           "#{msg.reserved.map { |r| "`#{r}`" }.join('; ')}."
    out << ""
  end

  msg.enums.each do |e|
    out << "[[tbl-#{anchor(e.name)}]]"
    out << ".Values of `#{e.name}`"
    out << '[cols="3,1"]'
    out << "|==="
    out << "| Name | Value"
    out << ""
    e.values.each { |(n, v)| out << "| `#{n}` | #{v}" }
    out << "|==="
    out << ""
  end

  out.join("\n")
end

def render(groups)
  counts = groups.sum { |g| g[:messages].length }
  fields = groups.sum { |g| g[:messages].sum { |m| m.fields.length } }
  mandatory = groups.sum do |g|
    g[:messages].sum { |m| m.fields.count(&:mandatory) }
  end

  out = []
  out << "// Generated by scripts/generate-schema.rb from upstream/onnx/proto/"
  out << "// at the release recorded in upstream/onnx/SOURCE.txt."
  out << "// Do not edit: run the script instead."
  out << "// See CONTRIBUTING.md, \"The generated schema annex\"."
  out << ""
  out << "[[annex-schema]]"
  out << "[appendix,obligation=normative]"
  out << "== Protocol Buffers schema"
  out << ""
  out << "=== General"
  out << ""
  out << "This annex states the message definitions of the serialized form: " \
         "#{counts} messages and #{fields} fields."
  out << ""
  out << "The tag of a field is normative; it identifies the field on the " \
         "wire and SHALL NOT be reused. A field marked mandatory SHALL be " \
         "present. A field marked optional MAY be absent, and a " \
         "<<consumer,consumer>> SHALL accept a message in which it is. A field marked " \
         "repeated holds zero or more values. A field marked deprecated " \
         "SHALL NOT be written by a <<producer,producer>>, and a consumer that reads " \
         "one SHALL ignore it."
  out << ""
  out << "The obligations are those in force at the IR version stated in " \
         "<<ir-version-specified>>."
  out << ""
  out << "NOTE: #{mandatory} of the #{fields} fields are mandatory. Protocol " \
         "Buffers cannot express the distinction: in the syntax this schema " \
         "uses every field is optional, and the obligation is carried in the " \
         "comments. Stating it in a table is the reason this annex exists."
  out << ""
  out << "[[tbl-schema-sources]]"
  out << ".Subclauses of this annex and the schema file each restates"
  out << '[cols="3,4,1"]'
  out << "|==="
  out << "| Subclause | Source | Messages"
  out << ""
  groups.each_with_index do |g, i|
    out << "| B.#{i + 2} #{g[:title]} | `#{g[:file]}` | #{g[:messages].length}"
  end
  out << "|==="
  out << ""

  groups.each do |g|
    out << "=== #{g[:title]}"
    out << ""
    g[:messages].each { |m| out << render_message(m) }
  end

  out << "=== Schema source"
  out << ""
  out << "The schema source is vendored in the repository at " \
         "`upstream/onnx/proto/`, at the release recorded in " \
         "`upstream/onnx/SOURCE.txt`. It is an informative aid: where a " \
         "comment in it carries a normative statement, that statement is in " \
         "the clause it belongs to and not in this annex."
  out << ""

  out.join("\n").gsub(/\n{3,}/, "\n\n")
end

# ---------------------------------------------------------------------- main

check = false
OptionParser.new do |o|
  o.banner = "usage: generate-schema.rb [--check]"
  o.on("--check", "fail if the generated file differs from the one on disk") do
    check = true
  end
end.parse!

groups = SOURCES.map do |src|
  path = File.join(ROOT, src[:file])
  File.exist?(path) or abort "missing: #{src[:file]}"
  { title: src[:title], file: src[:file], messages: parse(path) }
end

text = render(groups)
target = File.join(ROOT, TARGET)

if check
  on_disk = File.exist?(target) ? File.read(target, encoding: "UTF-8") : nil
  if on_disk == text
    puts "check: Annex B is up to date"
  else
    warn "check: #{TARGET} differs from the generated output."
    warn "       Run `make schema` and commit the result."
    exit 1
  end
else
  File.write(target, text)
  total_m = groups.sum { |g| g[:messages].length }
  total_f = groups.sum { |g| g[:messages].sum { |m| m.fields.length } }
  mand = groups.sum { |g| g[:messages].sum { |m| m.fields.count(&:mandatory) } }
  enums = groups.sum { |g| g[:messages].sum { |m| m.enums.length } }
  groups.each do |g|
    puts format("  %-40s %3d messages", g[:file], g[:messages].length)
  end
  puts
  puts format("  %d messages, %d fields (%d mandatory), %d enumerations -> %s",
              total_m, total_f, mand, enums, TARGET)
end
