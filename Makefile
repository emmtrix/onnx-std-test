# Build the (unofficial) ONNX Standard with Metanorma.
#
#   make            build semantic XML + HTML
#   make doc        build HTML and Word (.doc)
#   make site       build the browsable site under _site/
#   make lint       build and fail if Metanorma reports errors above the
#                   configured severity threshold
#   make clean      remove build output

SHELL      := /bin/bash
DOCUMENT   := sources/onnx-std.adoc
FLAVOUR    := generic
METANORMA  ?= metanorma

# Fail `make lint` on errors of this severity or worse.
# 0 = fatal, 1 = error, 2 = warning, 3 = informational.
SEVERITY   ?= 1

.PHONY: all html doc site lint clean deps

all: html

deps:
	bundle install

html:
	$(METANORMA) compile -t $(FLAVOUR) -x xml,presentation,html $(DOCUMENT)

# The `generic` flavour ships no PDF converter (its output formats are
# html, doc, xml, presentation and rxl). PDF becomes available on the move to a
# publisher flavour that carries PDF stylesheets; until then, `doc` is the
# review-friendly format.
doc:
	$(METANORMA) compile -t $(FLAVOUR) -x xml,presentation,html,doc $(DOCUMENT)

site:
	$(METANORMA) site generate --agree-to-terms

lint: html
	@scripts/check-errors.rb sources/onnx-std.err.html $(SEVERITY)

clean:
	rm -rf _site published
	rm -rf sources/*_files
	rm -f sources/onnx-std.xml sources/onnx-std.presentation.xml \
	      sources/onnx-std.html sources/onnx-std.pdf sources/onnx-std.doc \
	      sources/onnx-std.rxl sources/onnx-std.err.html \
	      sources/onnx-std.asciidoc.log.txt
