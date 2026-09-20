# Contributing

## Drafting conventions

This document follows ISO/IEC Directives, Part 2, because it is intended to
travel towards an ISO deliverable. The conventions below are the ones that
matter most in review.

**Normative vs. informative.** Every sentence is one or the other, and it must
be obvious which. Requirements use the verbal forms of Clause 4 of this
document (currently RFC 2119 keywords; see the migration note in Clause 4).
Explanation goes in a `NOTE`, an `[example]`, or an annex marked
`obligation=informative`.

**Requirements are testable.** A requirement that cannot be checked against an
implementation is not a requirement. "SHALL be efficient" is not admissible;
"SHALL complete within the tolerance of 4.4" is. If a requirement cannot yet be
made testable, say so in an editorial note and record it in Annex B rather than
writing an untestable one.

**No forward-looking text.** The document describes ONNX as it is. Proposals
for change belong in an issue.

**Terms are defined once.** Clause 3 is the only place a term is defined. Use
`<<term>>` to refer to it; do not restate the definition.

**Editorial notes.** Open questions appear *in the document*, at the clause
where the gap is, as:

```adoc
[IMPORTANT]
.Editorial note
====
What is missing, and what the options are.
====
```

They are not source comments. A reader of the PDF must see that a thin clause
is a known, tracked gap rather than a finished requirement; a `// TODO:`
comment renders to nothing and tells them nothing.

Each note is also covered by a row in Annex C of Part 1. A clause with a note
and no row is incomplete: the annex is the consolidated view the Steering
Committee reads, across all three parts.
Both the notes and Annex B are draft apparatus and come out before publication.

Three placement constraints, each learned from a failed build:

- Do not put a note inside an `[example]` block. Its `====` delimiter closes
  the example early and empties it. Put the note after the example.
- Admonitions admit only paragraphs, no lists. Write options as separate
  paragraphs.
- A `[bibliography]` clause admits no admonition at all, only `NOTE:`. Clause 2
  uses a note for that reason.

## Structure

One clause per file under `sources/part<N>/sections/`, named `NN-slug.adoc` in
document order. Add the file to the include list in the part's master document,
`sources/part<N>/onnx-std-<N>.adoc`.

Put content in the part it belongs to. Part 1 must name no individual operator
— that is what keeps it still while the operator sets move. A rule about
operators in general belongs in Part 1; a rule about `Relu` belongs in Part 2.

Clause numbering is generated. Never hard-code a clause number in prose — use a
cross-reference, so that inserting a clause does not silently invalidate
references elsewhere.

## Before opening a pull request

```sh
make lint
```

This builds the document and fails if Metanorma reports any diagnostic of
severity 1 (error) or worse. Relaton bibliography lookups are severity 2-3 and
do not fail the build, since they depend on network access, but check
each part's `onnx-std-<N>.err.html` for new ones.

Commit only sources. Build output is ignored by `.gitignore`; rendered
documents are published as CI artifacts.

`Gemfile.lock` *is* committed. A standards document must render identically
from the same sources years apart, so the toolchain is pinned rather than
resolved afresh on each build. Update it deliberately, in its own commit.

## The PDF stylesheet

`sources/onnx.standard.xsl` is the ONNX house style for PDF. It is a vendored,
de-branded derivative of CalConnect's stylesheet, because Metanorma's `generic`
flavour ships none. Its file header records where it came from and the four
changes made to it; all four read the publisher identity from the document's
bibdata, so changing `sources/onnx.yml` is still enough and this file needs no
edit.

If you update it from upstream, re-apply exactly those four changes and run:

```sh
make check-stylesheet
```

That verifies the file is well-formed XML and that no upstream publisher name
survives in its body. Both have failed silently before: mn2pdf parses the
stylesheet itself, and Metanorma exits 0 when that parse fails, so a broken
stylesheet produces no PDF while the build still looks green. Publishing a
document carrying another organization's name or copyright would misrepresent
it.

## The vendored upstream copy

`upstream/onnx/` is a verbatim copy of the ONNX documentation the draft
restates. Never edit it by hand — it is upstream's text, and a local edit would
silently break the claim that it is a faithful baseline. To move to a newer
upstream release:

```sh
scripts/vendor-onnx-docs.sh <release-tag>
```

Pass a tag that exists — `git ls-remote --tags https://github.com/onnx/onnx.git`
lists them. The `VERSION_NUMBER` file on `main` names the next, unreleased
version and is not a checkout-able ref.

That rewrites the directory and regenerates `SOURCE.txt`, so the commit diff is
the upstream change plus the new provenance header. Then update the version statements in
`upstream/onnx/PROVENANCE.md` and re-read Annex B: a new release may have
closed a gap recorded there, or opened one.

## Changing the publisher flavour

The publisher identity lives in `sources/onnx.yml` and in the
`:mn-document-class:` attribute of each part's master document. Moving to a Linux
Foundation or ISO house style should touch those two places and nothing else.
If a flavour change requires editing the document body, that is a defect in how
the body is written — report it.
