# Build the (unofficial) ONNX Standard with Metanorma.
#
#   make            build semantic XML + HTML
#   make doc        build HTML and Word (.doc)
#   make pdf        build HTML, Word and PDF
#   make site       build the browsable site under _site/ and verify it
#   make lint       fail if the last build reported errors above the
#                   configured severity threshold (builds first if needed)
#   make operators  regenerate the operator clauses of Part 2 from upstream
#   make check-stylesheet
#                   verify the PDF stylesheet (well-formed, no foreign branding)
#   make clean      remove build output

SHELL      := /bin/bash
# ONNX 1 is a multi-part standard; each part is its own Metanorma document.
PARTS      := 1 2 3
DOCUMENTS  := $(foreach p,$(PARTS),sources/part$(p)/onnx-std-$(p).adoc)
SOURCES    := $(DOCUMENTS) sources/onnx.yml \
              $(wildcard sources/part*/sections/*.adoc)
ERRFILES   := $(foreach p,$(PARTS),sources/part$(p)/onnx-std-$(p).err.html)
PDFFILES   := $(foreach p,$(PARTS),sources/part$(p)/onnx-std-$(p).pdf)
STYLESHEET := sources/onnx.standard.xsl
FLAVOUR    := generic
METANORMA  ?= metanorma
RUBY       ?= ruby

# Fail `make lint` on errors of this severity or worse.
# 0 = fatal, 1 = error, 2 = warning, 3 = informational.
SEVERITY   ?= 1

.PHONY: all html doc pdf site lint clean deps check-stylesheet \
        operators check-operators

all: html

deps:
	bundle install

# Declaring `fonts_manifest` in sources/onnx.yml makes Metanorma install fonts
# on every render, not only the ones that need them. Only PDF does, so the
# HTML and DOC targets opt out: otherwise a font download failure breaks builds
# that never touch a font.
NOFONTS    := --no-install-fonts

# Metanorma writes its diagnostics to an err.html per part on every render, so
# `lint` depends on those files rather than on a phony build target: running
# `make doc` and then `make lint` must not compile the documents again.
$(ERRFILES) html: $(SOURCES)
	@for d in $(DOCUMENTS); do \
	  echo "==> $$d"; \
	  $(METANORMA) compile -t $(FLAVOUR) $(NOFONTS) \
	    -x xml,presentation,html "$$d" || exit 1; \
	done

doc: $(SOURCES)
	@for d in $(DOCUMENTS); do \
	  echo "==> $$d"; \
	  $(METANORMA) compile -t $(FLAVOUR) $(NOFONTS) \
	    -x xml,presentation,html,doc "$$d" || exit 1; \
	done

# The operator clauses of Part 2 are generated from the vendored upstream
# documentation; there are 222 of them and they are not written by hand.
operators:
	@$(RUBY) scripts/generate-operators.rb

# Fails if the committed clauses are not what the generator produces — a hand
# edit, or a refresh of upstream/onnx/ without regenerating, shows up here
# rather than as silent drift.
check-operators:
	@$(RUBY) scripts/generate-operators.rb --check

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
	@for d in $(DOCUMENTS); do \
	  echo "==> $$d"; \
	  $(METANORMA) compile -t $(FLAVOUR) --agree-to-terms \
	    -x xml,presentation,html,doc,pdf "$$d" || exit 1; \
	done
	@missing=0; \
	for f in $(PDFFILES); do \
	  if [ ! -s "$$f" ]; then \
	    echo "pdf: $$f was not produced — see the mn2pdf output above" >&2; \
	    missing=1; \
	  fi; \
	done; \
	if [ $$missing -ne 0 ]; then exit 1; fi; \
	echo "pdf: all parts written"

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
# `metanorma site generate` mirrors the source layout, so each part lands under
# documents/part<N>/ rather than flat in documents/.
SITE_FILES := index.html \
              $(foreach p,$(PARTS),documents/part$(p)/onnx-std-$(p).html) \
              $(foreach p,$(PARTS),documents/part$(p)/onnx-std-$(p).doc) \
              $(foreach p,$(PARTS),documents/part$(p)/onnx-std-$(p).pdf) \
              $(foreach p,$(PARTS),documents/part$(p)/onnx-std-$(p).xml)

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

lint: $(ERRFILES)
	@rc=0; \
	for f in $(ERRFILES); do \
	  $(RUBY) scripts/check-errors.rb "$$f" $(SEVERITY) || rc=1; \
	done; \
	exit $$rc

clean:
	rm -rf _site published
	rm -rf sources/part*/*_files
	rm -f sources/part*/onnx-std-*.xml \
	      sources/part*/onnx-std-*.presentation.xml \
	      sources/part*/onnx-std-*.html sources/part*/onnx-std-*.pdf \
	      sources/part*/onnx-std-*.doc sources/part*/onnx-std-*.rxl \
	      sources/part*/onnx-std-*.err.html \
	      sources/part*/onnx-std-*.asciidoc.log.txt
	rm -f sources/part*/*.xml_tmp sources/part*/*.pdf_fonts_config.xml.out
