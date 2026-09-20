# Build the (unofficial) ONNX Standard with Metanorma.
#
#   make            build semantic XML + HTML
#   make doc        build HTML and Word (.doc)
#   make pdf        build HTML, Word and PDF
#   make site       build the browsable site under _site/ and verify it
#   make lint       fail if the last build reported errors above the
#                   configured severity threshold (builds first if needed)
#   make check-stylesheet
#                   verify the PDF stylesheet (well-formed, no foreign branding)
#   make clean      remove build output

SHELL      := /bin/bash
DOCUMENT   := sources/onnx-std.adoc
SOURCES    := $(DOCUMENT) sources/onnx.yml $(wildcard sources/sections/*.adoc)
ERRFILE    := sources/onnx-std.err.html
PDFFILE    := sources/onnx-std.pdf
STYLESHEET := sources/onnx.standard.xsl
FLAVOUR    := generic
METANORMA  ?= metanorma
RUBY       ?= ruby

# Fail `make lint` on errors of this severity or worse.
# 0 = fatal, 1 = error, 2 = warning, 3 = informational.
SEVERITY   ?= 1

.PHONY: all html doc pdf site lint clean deps check-stylesheet

all: html

deps:
	bundle install

# Declaring `fonts_manifest` in sources/onnx.yml makes Metanorma install fonts
# on every render, not only the ones that need them. Only PDF does, so the
# HTML and DOC targets opt out: otherwise a font download failure breaks builds
# that never touch a font.
NOFONTS    := --no-install-fonts

# Metanorma writes its diagnostics to $(ERRFILE) on every render, so `lint`
# depends on that file rather than on a phony build target: running `make doc`
# and then `make lint` must not compile the document a second time.
$(ERRFILE) html: $(SOURCES)
	$(METANORMA) compile -t $(FLAVOUR) $(NOFONTS) \
	  -x xml,presentation,html $(DOCUMENT)

doc: $(SOURCES)
	$(METANORMA) compile -t $(FLAVOUR) $(NOFONTS) \
	  -x xml,presentation,html,doc $(DOCUMENT)

# mn2pdf parses the stylesheet itself, and Metanorma exits 0 when that parse
# fails — producing no PDF while the build looks successful. Check it first;
# the check needs no fonts, so it also runs where a full PDF render cannot.
check-stylesheet:
	@$(RUBY) scripts/check-stylesheet.rb $(STYLESHEET)

# PDF is rendered by mn2pdf through the ONNX XSL-FO stylesheet configured in
# sources/onnx.yml. `--agree-to-terms` accepts the licences of the fonts named
# in that file, which fontist downloads on first use.
#
# The PDF is then verified to exist, for the same reason: a failed render does
# not fail the command.
pdf: check-stylesheet $(SOURCES)
	$(METANORMA) compile -t $(FLAVOUR) --agree-to-terms \
	  -x xml,presentation,html,doc,pdf $(DOCUMENT)
	@if [ ! -s "$(PDFFILE)" ]; then \
	  echo "pdf: $(PDFFILE) was not produced — see the mn2pdf output above" >&2; \
	  exit 1; \
	fi; \
	echo "pdf: $(PDFFILE) written"

# Output formats are passed explicitly rather than left to the manifest:
#   - `rxl` is not in the flavour's own format list, so it has to be named;
#   - `presentation` must be listed, because it is the intermediate that the
#     HTML and DOC converters read. Omitted, Metanorma writes it under a
#     truncated filename, both converters fail with ENOENT on
#     `onnx-std.presentation.xml`, and the site build still exits 0 — leaving a
#     site whose document links all 404.
SITE_EXT   := xml,presentation,html,doc,pdf,rxl
SITE_DIR   := _site

# Files the published site must contain. `metanorma site generate` exits 0 even
# when a converter failed and wrote nothing, so the build is verified rather
# than trusted: without this check a broken site deploys silently.
SITE_FILES := index.html \
              documents/onnx-std.html \
              documents/onnx-std.doc \
              documents/onnx-std.pdf \
              documents/onnx-std.xml

site: check-stylesheet
	$(METANORMA) site generate --agree-to-terms -x $(SITE_EXT)
	@missing=0; \
	for f in $(SITE_FILES); do \
	  if [ ! -s "$(SITE_DIR)/$$f" ]; then \
	    echo "site: missing or empty: $(SITE_DIR)/$$f" >&2; missing=1; \
	  fi; \
	done; \
	if [ $$missing -ne 0 ]; then \
	  echo "site: incomplete build — see above" >&2; exit 1; \
	fi; \
	echo "site: all expected documents present in $(SITE_DIR)"

lint: $(ERRFILE)
	@scripts/check-errors.rb $(ERRFILE) $(SEVERITY)

clean:
	rm -rf _site published
	rm -rf sources/*_files
	rm -f sources/onnx-std.xml sources/onnx-std.presentation.xml \
	      sources/onnx-std.html sources/onnx-std.pdf sources/onnx-std.doc \
	      sources/onnx-std.rxl sources/onnx-std.err.html \
	      sources/onnx-std.asciidoc.log.txt
	rm -f sources/*.xml_tmp sources/*.pdf_fonts_config.xml.out
