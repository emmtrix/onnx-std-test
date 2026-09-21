# frozen_string_literal: true

source "https://rubygems.org"

# Metanorma toolchain. The `generic` flavour is pulled in by metanorma-cli and
# is configured for ONNX in sources/onnx.yml.
gem "metanorma-cli", "~> 1.12"

# Pinned explicitly so that CI and local builds agree on the flavour used to
# render this document.
gem "metanorma-generic"

# isodoc requires sassc-embedded at runtime to compile the house-style SCSS
# into the rendered HTML, but does not declare it as a dependency. Without it
# every HTML/DOC render fails with `cannot load such file -- sassc-embedded`.
gem "sassc-embedded"

# Used by scripts/generate-operators.rb to convert the upstream operator prose
# from Markdown to AsciiDoc. Hand-rolling that conversion is not worth it: the
# prose carries tables, lists, code fences and inline HTML.
gem "kramdown-asciidoc"
