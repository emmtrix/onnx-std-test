# ONNX Standard (unofficial Metanorma draft)

> **This is not an ONNX project deliverable.** It has no standing within the
> ONNX project, the Linux Foundation, IEC, ISO or any other standards
> development organization, and it must not be cited as a normative reference.

This repository restates the ONNX format as a *normative specification*,
authored in [Metanorma](https://www.metanorma.org). It exists to make a
concrete proposal discussable: rather than arguing in the abstract about
whether ONNX should become a standard, it shows what the standard would
actually look like, what it would require, and what is currently missing.

The intended audience is the ONNX Steering Committee.

## Why

The present ONNX specification is a set of Markdown documents maintained
alongside the reference implementation. That serves rapid evolution well, but
it does not give ONNX the properties adopters increasingly ask for:

- a stable document identifier and edition;
- an unambiguous separation of normative requirements from explanation;
- conformance requirements that can be tested, and conformance claims that
  mean something specific;
- a controlled change process with a defined IPR regime.

## Intended path

1. **Now** — this draft, authored in Metanorma's `generic` flavour, as a
   demonstration and discussion document.
2. **Next** — publication as a specification of a Linux Foundation
   [Joint Development Foundation](https://www.jointdevelopment.org) (JDF)
   project, which supplies a specification process and an explicit IPR regime.
3. **Later** — submission of that specification towards an ISO or ISO/IEC
   deliverable, e.g. via the JTC 1 Publicly Available Specification (PAS)
   route.

The document is drafted to ISO/IEC Directives Part 2 conventions from the
start, so that each step is a change of publisher and house style rather than a
rewrite. Metanorma makes that concrete: the flavour is selected in one
attribute and one configuration file, and the document body is unchanged.

## Repository layout

```
metanorma.yml              Metanorma manifest (site build)
Gemfile                    Toolchain
Makefile                   Build entry points
sources/
  onnx-std.adoc            Master document: metadata + includes
  onnx.yml                 Publisher identity for the `generic` flavour
  sections/                One file per clause
scripts/check-errors.rb    Gates the build on Metanorma diagnostic severity
scripts/vendor-onnx-docs.sh  Refreshes the vendored upstream copy
upstream/onnx/             Verbatim upstream ONNX docs (complete) + .proto
.github/workflows/         CI: build HTML + PDF, publish as artifacts
```

## Published site

Every push to `main` builds the document and publishes it to GitHub Pages:

**https://emmtrix.github.io/onnx-std-test/**

The page links the standard as HTML (for reading), PDF (for circulation),
Word (for review and comments), Metanorma semantic XML and the Relaton
bibliographic record.

Nothing is published if the render is incomplete or the document has errors of
severity 1 or worse — see `.github/workflows/pages.yml`.

> **One-time setup:** this requires GitHub Pages to be enabled for the
> repository with **Settings → Pages → Build and deployment → Source =
> "GitHub Actions"**. Until that is set, the `deploy` job fails; the build
> itself still runs.

## Building

```sh
bundle install
make          # semantic XML + HTML
make doc      # also Word (.doc)
make pdf      # also PDF
make site     # the full site under _site/, as published to Pages
make lint     # fail on Metanorma errors of severity <= 1
make clean
```

Output lands next to the sources as `sources/onnx-std.{xml,html,doc,pdf}`.
`sources/onnx-std.err.html` is Metanorma's diagnostic report — read it after
every build.

PDF is rendered through `sources/onnx.standard.xsl`, the ONNX house style. The
`generic` flavour ships no XSL-FO stylesheet, so this one is derived from
CalConnect's and de-branded; its header records the provenance and the exact
changes. The first PDF build downloads the fonts named in `sources/onnx.yml`.
`sources/onnx-std.err.html` is Metanorma's diagnostic report — read it after
every build.

## State of the draft

The framework — scope, terms, conformance classes, versioning rules, the
required form of an operator specification — is drafted. The technical clauses
are deliberately partial. Every gap is flagged by an editorial note in the
document itself, at the clause where it occurs, and summarised in **Annex B,
"Known gaps and divergences"**. A reader of the published PDF sees which
clauses are unfinished without having to consult the source.

Annex B is the interesting part of this repository. It records the places where
ONNX as it exists today does not yet supply what a normative standard needs —
unspecified numerical tolerances, an uncitable serialization format, two
readings of the initializer rules, unstated determinism guarantees. These are
questions for the Steering Committee, not editorial oversights, and none of
them can be resolved by the editor alone.

## What the draft is based on

`upstream/onnx/` holds a verbatim copy of the ONNX documentation and Protocol
Buffers schema that this draft restates — release **v1.23.0**, commit
`ee3ccbd`. It is vendored rather than linked so that the baseline is fixed and
auditable: a reader checking a statement in Annex B needs the tree that
statement was written against, not whatever `main` holds today.

See [`upstream/onnx/PROVENANCE.md`](upstream/onnx/PROVENANCE.md) for the exact
version, what was and was not copied, the mapping from upstream documents to
clauses of the draft, and how to refresh it.

The copy is never built or published; it is reference material.

## Where this is going structurally

[`STRUCTURE.md`](STRUCTURE.md) proposes the structure the document should move
to: a multi-part standard that separates a stable **Core** from the
faster-moving **operator sets** and **conformance test vectors**, so that
adding an operator does not force a new edition of the core.

It is a proposal for discussion, not yet implemented; the document in
`sources/` still has the ten-clause structure of the initial draft.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for drafting conventions.
