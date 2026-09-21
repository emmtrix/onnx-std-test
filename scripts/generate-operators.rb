#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate the operator clauses of Part 2 from the vendored upstream
# documentation.
#
#   scripts/generate-operators.rb [--check]
#
# The operator definitions are generated upstream from the operator schemas,
# and are far too many to restate by hand; this script restates them in the
# form Clause 4 of Part 2 requires. The generated files carry a header saying
# so and must never be edited directly.
#
# `--check` regenerates into memory and fails if the files on disk differ,
# which is what CI runs: a hand edit, or a refresh of upstream/onnx/ without a
# regeneration, then shows up as a failing check rather than as drift.
#
# What the upstream source cannot supply is reported rather than papered over.
# Clause 4 of Part 2 makes shape inference, determinism and error conditions
# mandatory elements of an operator definition; the source states none of them.
# Each generated operator records that explicitly, and the run prints a
# coverage summary.

require "kramdoc"
require "optparse"

ROOT = File.expand_path("..", __dir__)

SOURCES = [
  { file: "upstream/onnx/docs/Operators.md",    domain: "ai.onnx (default)" },
  { file: "upstream/onnx/docs/Operators-ml.md", domain: "ai.onnx.ml" },
].freeze

# Domain -> the section file that carries it. Domains found in the source but
# absent here are skipped and reported; see the note on preview domains below.
TARGETS = {
  "ai.onnx (default)" => "sources/part2/sections/05-default-domain.adoc",
  "ai.onnx.ml"        => "sources/part2/sections/06-ml-domain.adoc",
}.freeze

CLAUSE_TITLE = {
  "ai.onnx (default)" => "The default domain",
  "ai.onnx.ml"        => "The ai.onnx.ml domain",
}.freeze

# Mandatory elements of an operator specification, per Clause 4 of Part 2.
# `source:` says whether the upstream documentation supplies the element.
ELEMENTS = [
  { key: :name,        label: "Name and domain",  source: true  },
  { key: :since,       label: "Since version",    source: true  },
  { key: :inputs,      label: "Inputs",           source: true  },
  { key: :outputs,     label: "Outputs",          source: true  },
  { key: :attributes,  label: "Attributes",       source: true  },
  { key: :constraints, label: "Type constraints", source: true  },
  { key: :inference,   label: "Shape inference",  source: false },
  { key: :semantics,   label: "Semantics",        source: true  },
  { key: :determinism, label: "Determinism",      source: false },
  { key: :errors,      label: "Errors",           source: false },
  { key: :vectors,     label: "Test vectors",     source: true  },
].freeze

# ---------------------------------------------------------------- conversion

# The prose carries a little raw inline HTML. Metanorma's schema rejects most
# of it, so translate the tags upstream actually uses into AsciiDoc. This runs
# BEFORE the type-notation guard below, which would otherwise mistake <br> for
# a type parameter.
HTML_INLINE = /\A(?:br|i|em|b|strong|sub|sup|tt|code|a)\z/i.freeze

def normalise_inline_html(md)
  md
    .gsub(%r{<br\s*/?>}i, "\n")
    .gsub(%r{<a\b[^>]*>(.*?)</a>}im) { Regexp.last_match(1) }
    .gsub(%r{<(?:i|em)>(.*?)</(?:i|em)>}im) { "_#{Regexp.last_match(1)}_" }
    .gsub(%r{<(?:b|strong)>(.*?)</(?:b|strong)>}im) { "*#{Regexp.last_match(1)}*" }
    .gsub(%r{<(?:tt|code)>(.*?)</(?:tt|code)>}im) { "`#{Regexp.last_match(1)}`" }
    .gsub(%r{<sub>(.*?)</sub>}im) { "~#{Regexp.last_match(1)}~" }
    .gsub(%r{<sup>(.*?)</sup>}im) { "^#{Regexp.last_match(1)}^" }
end

# Type notation such as Tensor<T> or map(K,V)<...> is not HTML, but a Markdown
# converter reads it as a tag and mangles the paragraph. Wrap it in a code span
# first; it is monospace in the output anyway.
def protect_type_notation(md)
  md.gsub(/(?<!`)\b([A-Za-z_][\w.]*)<([^<>`\n]{1,60})>(?!`)/) do
    name = Regexp.last_match(2)
    # Leave anything that is actually an HTML tag to normalise_inline_html.
    name.match?(HTML_INLINE) ? Regexp.last_match(0) : "`#{Regexp.last_match(1)}<#{name}>`"
  end
end

# Operator prose links to other upstream documents, e.g. "[the doc](IR.md)".
# Converted naively those become cross-references to targets this standard does
# not contain, and Metanorma rejects them. The link text is kept and the target
# dropped; the clause-level editorial note records that the standard does not
# yet restate the documents concerned. Links inside fenced code are left alone.
def dereference_upstream_links(md)
  fence = false
  md.split("\n", -1).map do |line|
    if line.start_with?("```")
      fence = !fence
      line
    elsif fence
      line
    else
      line.gsub(/\[([^\]\n]+)\]\((?!https?:|mailto:)[^)\n]*\)/) { Regexp.last_match(1) }
    end
  end.join("\n")
end

def markdown_to_adoc(md)
  text = md.to_s.strip
  return "" if text.empty?

  Kramdoc.convert(
    protect_type_notation(normalise_inline_html(dereference_upstream_links(text)))
  ).strip
end

# Inline conversion for a phrase: same treatment, but collapsed to one line so
# it can sit in a description list item.
# Metanorma wants every table titled. The upstream prose has untitled tables;
# rather than invent a caption, state what the table is.
def title_tables(adoc, operator)
  out = []
  adoc.split("\n", -1).each_with_index do |line, i|
    if line.start_with?("|===") && !out.last.to_s.start_with?(".") &&
       !out[-2].to_s.start_with?(".")
      # opening delimiter of a table that has no title yet
      opened = out.count { |l| l.start_with?("|===") }.odd?
      out << ".Table from the upstream description of `#{operator}`" unless opened
    end
    out << line
  end
  out.join("\n")
end

def inline(md)
  markdown_to_adoc(md).gsub(/\n+/, " ").strip
end

def strip_tags(html)
  html.gsub(%r{</?[^>]+>}, "").strip
end

def anchor(domain, name)
  "op-#{domain.gsub(/[^\w]+/, '-')}-#{name}".gsub(/-+/, "-").downcase
end

# ------------------------------------------------------------------- parsing

# The source is generated Markdown with embedded HTML definition lists. Fenced
# code blocks contain Python whose comments start with '#', so heading
# detection has to be fence-aware or it finds 1300 spurious headings.
def parse(path)
  ops = []
  domain = nil
  op = nil
  section = nil
  fence = false

  File.readlines(path, encoding: "UTF-8").each do |raw|
    line = raw.chomp

    if line.start_with?("```")
      fence = !fence
      op[:sections][section] << line if op && section
      next
    end

    if fence
      op[:sections][section] << line if op && section
      next
    end

    case line
    when /\A## (.+)\z/
      domain = Regexp.last_match(1).strip
      op = nil
    when /\A### .*\*\*(.+?)\*\*(.*)\z/
      next unless domain

      op = { name: Regexp.last_match(1).strip, domain: domain,
             deprecated: Regexp.last_match(2).include?("(deprecated)"),
             prose: [], sections: Hash.new { |h, k| h[k] = [] } }
      section = nil
      ops << op
    when /\A#### (.+)\z/
      next unless op

      section = Regexp.last_match(1).strip
      op[:sections][section] # touch
    else
      next unless op

      if section
        op[:sections][section] << line
      else
        op[:prose] << line
      end
    end
  end

  ops
end

# <dl><dt><tt>name</tt> (flags) : type</dt><dd>description</dd></dl>
def parse_definition_list(lines)
  text = lines.join("\n")
  entries = []
  text.scan(%r{<dt>(.*?)</dt>\s*<dd>(.*?)</dd>}m) do |dt, dd|
    term = strip_tags(dt).gsub(/\s+/, " ").strip
    entries << { term: term, desc: strip_tags(dd).gsub(/\s+/, " ").strip }
  end
  entries
end

def section_named(op, prefix)
  key = op[:sections].keys.find { |k| k == prefix || k.start_with?("#{prefix} (") }
  return [nil, nil] unless key

  arity = key[/\((.+)\)/, 1]
  [op[:sections][key], arity&.gsub("&#8734;", "unbounded")]
end

def since_version(op)
  lines = op[:sections]["Version"] or return nil

  body = lines.join(" ")
  body[/available since version (\d+)/, 1] || body[/deprecated since version (\d+)/, 1]
end

def other_versions(op)
  lines = op[:sections]["Version"] or return []

  body = lines.join(" ")
  return [] unless body.include?("Other versions")

  body.split("Other versions").last.scan(/>(\d+)</).flatten.uniq
end

# Test vector names are the `name="test_..."` arguments in the example code.
def test_vectors(op)
  op[:sections]["Examples"].join("\n").scan(/name="(test_[\w.]+)"/).flatten.uniq
end

# ----------------------------------------------------------------- rendering

def render_entries(entries)
  entries.map do |e|
    term = e[:term]
    desc = inline(e[:desc])
    desc.empty? ? "`#{term}`" : "`#{term}` -- #{desc}"
  end
end

def render_operator(op)
  out = []
  out << "[[#{anchor(op[:domain], op[:name])}]]"
  out << "=== #{op[:name]}"
  out << ""

  prose = title_tables(
    markdown_to_adoc(op[:prose].map { |l| l.sub(/\A {1,2}/, "") }.join("\n")),
    op[:name]
  )
  unless prose.empty?
    out << prose
    out << ""
  end

  since = since_version(op)
  others = other_versions(op)

  out << "Domain::"
  out << "`#{op[:domain].sub(/ \(default\)\z/, '')}`"
  out << ""
  out << "Since version::"
  out << (since ? since : "Not stated by the source.")
  out << ""
  if op[:deprecated]
    out << "Status::"
    out << "Deprecated. Clause 14.5 of <<onnx-part-1>> applies: a deprecated " \
           "operator is not removed, and a consumer continues to evaluate it."
    out << ""
  end
  unless others.empty?
    out << "Earlier versions::"
    out << others.join(", ")
    out << ""
  end

  # "None." and "not documented" are different claims, and only one of them
  # may be asserted. Upstream omits the Attributes section when an operator has
  # no attributes, so an absent section there means none. For inputs, outputs
  # and type constraints it omits the section only for deprecated operators,
  # where it means the signature is no longer documented at all.
  [["Inputs", "Inputs", :undocumented],
   ["Outputs", "Outputs", :undocumented],
   ["Attributes", "Attributes", :none],
   ["Type constraints", "Type Constraints", :undocumented]].each do |label, prefix, absent|
    lines, arity = section_named(op, prefix)
    out << "#{label}#{arity ? " (#{arity})" : ''}::"
    entries = lines ? render_entries(parse_definition_list(lines)) : []
    out << if !entries.empty?
             entries.join(" +\n")
           elsif lines || absent == :none
             "None."
           else
             "Not stated by the source."
           end
    out << ""
  end

  vectors = test_vectors(op)
  out << "Test vectors::"
  out << (vectors.empty? ? "None published for this operator." : vectors.map { |v| "`#{v}`" }.join(", "))
  out << ""

  missing = ELEMENTS.reject { |e| e[:source] }.map { |e| e[:label].downcase }
  out << "Not supplied by the upstream source::"
  out << "#{missing.join(', ').capitalize}. See the editorial note at the head of this clause."
  out << ""

  out.join("\n")
end

def render_clause(domain, ops, provenance)
  title = CLAUSE_TITLE.fetch(domain)
  short = domain.sub(/ \(default\)\z/, "")

  <<~ADOC
    // Generated by scripts/generate-operators.rb from #{provenance[:file]}
    // at #{provenance[:version]}. Do not edit: run the script instead.
    // See CONTRIBUTING.md, "The generated operator clauses".

    == #{title}

    === General

    This clause specifies the operators of the `#{short}` domain, in the form
    required by <<required-form>>.

    [IMPORTANT]
    .Editorial note
    ====
    This clause is generated from the upstream operator documentation, which
    does not supply three of the elements <<required-form>> makes mandatory:
    shape inference, determinism and error conditions. Every operator below
    records their absence rather than omitting the elements, so that the
    incompleteness is visible where it matters instead of only in Annex C of
    <<onnx-part-1>>.

    Supplying them is the substance of the work this part represents. They
    cannot be generated, because the upstream source does not contain them;
    they have to be written, per operator, and agreed.

    Operator prose below also refers to upstream documents that
    <<onnx-part-1>> does not yet restate, broadcasting among them. Those
    references appear as plain text, because a normative cross-reference to a
    clause that does not exist would be worse than none. Annex C of
    <<onnx-part-1>> records the omission.
    ====

    NOTE: Examples and sample implementations are not reproduced. They are
    informative under <<required-form>>, and the reference implementation is
    not restated here; see Annex D of <<onnx-part-1>>. The test vector names
    extracted from the examples are retained, because <<onnx-part-3>> needs
    them.

    #{ops.map { |op| render_operator(op) }.join("\n")}
  ADOC
end

# --------------------------------------------------------------------- driver

options = { check: false }
OptionParser.new do |o|
  o.banner = "usage: scripts/generate-operators.rb [--check]"
  o.on("--check", "fail if the files on disk are not what this script generates") do
    options[:check] = true
  end
end.parse!

provenance_file = File.join(ROOT, "upstream/onnx/SOURCE.txt")
version = if File.exist?(provenance_file)
            File.read(provenance_file)[/^ref:\s*(\S+)/, 1] || "unknown"
          else
            "unknown"
          end

by_domain = Hash.new { |h, k| h[k] = [] }
SOURCES.each do |src|
  path = File.join(ROOT, src[:file])
  unless File.exist?(path)
    warn "#{src[:file]}: not found; run scripts/vendor-onnx-docs.sh first"
    exit 1
  end
  parse(path).each { |op| by_domain[op[:domain]] << [op, src[:file]] }
end

stale = []
by_domain.keys.sort.each do |domain|
  ops = by_domain[domain].map(&:first)
  target = TARGETS[domain]
  unless target
    puts format("  %-26s %4d operators   SKIPPED (no clause; see Clause 16 of Part 1)",
                domain, ops.size)
    next
  end

  file = by_domain[domain].first.last
  content = render_clause(domain, ops, file: file, version: version)
  path = File.join(ROOT, target)

  if options[:check]
    current = File.exist?(path) ? File.read(path, encoding: "UTF-8") : nil
    stale << target if current != content
  else
    File.write(path, content)
  end
  puts format("  %-26s %4d operators   -> %s", domain, ops.size, target)
end

# Coverage of the required form, counted over what was emitted.
emitted = by_domain.select { |d, _| TARGETS.key?(d) }.values.flatten(1).map(&:first)
puts
puts "Required form coverage over #{emitted.size} emitted operators:"
ELEMENTS.each do |el|
  n = case el[:key]
      when :name        then emitted.size
      when :since       then emitted.count { |op| since_version(op) }
      when :inputs      then emitted.count { |op| section_named(op, "Inputs").first }
      when :outputs     then emitted.count { |op| section_named(op, "Outputs").first }
      when :attributes  then emitted.count { |op| section_named(op, "Attributes").first }
      when :constraints then emitted.count { |op| section_named(op, "Type Constraints").first }
      when :semantics   then emitted.count { |op| !op[:prose].join.strip.empty? }
      when :vectors     then emitted.count { |op| !test_vectors(op).empty? }
      else 0
      end
  mark = el[:source] ? " " : "!"
  puts format("  %s %-18s %4d / %d", mark, el[:label], n, emitted.size)
end
puts
puts "  ! = not supplied by the upstream source at all; must be written."

if options[:check]
  unless stale.empty?
    warn "\nThese generated files differ from what the script produces:"
    stale.each { |f| warn "  #{f}" }
    warn "Run scripts/generate-operators.rb and commit the result."
    exit 1
  end
  puts "\ncheck: generated clauses are up to date"
end
