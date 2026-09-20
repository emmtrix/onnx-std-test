# Build the (unofficial) ONNX Standard with Metanorma.
#
#   make            build semantic XML + HTML
#   make doc        build HTML and Word (.doc)
#   make site       build the browsable site under _site/ and verify it
#   make lint       fail if the last build reported errors above the
#                   configured severity threshold (builds first if needed)
#   make clean      remove build output

SHELL      := /bin/bash
DOCUMENT   := sources/onnx-std.adoc
SOURCES    := $(DOCUMENT) sources/onnx.yml $(wildcard sources/sections/*.adoc)
ERRFILE    := sources/onnx-std.err.html
FLAVOUR    := generic
METANORMA  ?= metanorma

# Fail `make lint` on errors of this severity or worse.
# 0 = fatal, 1 = error, 2 = warning, 3 = informational.
SEVERITY   ?= 1

.PHONY: all html doc site lint clean deps

all: html

deps:
	bundle install

# Metanorma writes its diagnostics to $(ERRFILE) on every render, so `lint`
# depends on that file rather than on a phony build target: running `make doc`
# and then `make lint` must not compile the document a second time.
$(ERRFILE) html: $(SOURCES)
	$(METANORMA) compile -t $(FLAVOUR) -x xml,presentation,html $(DOCUMENT)

# The `generic` flavour ships no PDF converter (its output formats are
# html, doc, xml, presentation and rxl). PDF becomes available on the move to a
# publisher flavour that carries PDF stylesheets; until then, `doc` is the
# review-friendly format.
doc: $(SOURCES)
	$(METANORMA) compile -t $(FLAVOUR) -x xml,presentation,html,doc $(DOCUMENT)

# Output formats are passed explicitly rather than left to the manifest:
#   - the `generic` flavour has no PDF converter, and the default format set
#     includes PDF, which aborts the build;
#   - `presentation` must be listed, because it is the intermediate that the
#     HTML and DOC converters read. Omitted, Metanorma writes it under a
#     truncated filename, both converters fail with ENOENT on
#     `onnx-std.presentation.xml`, and the site build still exits 0 — leaving a
#     site whose document links all 404.
SITE_EXT   := xml,presentation,html,doc,rxl
SITE_DIR   := _site

# Files the published site must contain. `metanorma site generate` exits 0 even
# when a converter failed and wrote nothing, so the build is verified rather
# than trusted: without this check a broken site deploys silently.
SITE_FILES := index.html \
              documents/onnx-std.html \
              documents/onnx-std.doc \
              documents/onnx-std.xml

site:
	$(METANORMA) site generate --agree-to-terms --continue-without-fonts \
	  -x $(SITE_EXT)
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
