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

**Editorial notes.** Open questions are marked in the source with a
`// TODO:` comment explaining what is missing and what the options are, and are
mirrored as a row in Annex B. A `TODO` without an Annex B row is incomplete:
the annex is what the Steering Committee reads.

## Structure

One clause per file under `sources/sections/`, named `NN-slug.adoc` in document
order. Add the file to the include list in `sources/onnx-std.adoc`.

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
`sources/onnx-std.err.html` for new ones.

Commit only sources. Build output is ignored by `.gitignore`; rendered
documents are published as CI artifacts.

`Gemfile.lock` *is* committed. A standards document must render identically
from the same sources years apart, so the toolchain is pinned rather than
resolved afresh on each build. Update it deliberately, in its own commit.

## Changing the publisher flavour

The publisher identity lives in `sources/onnx.yml` and in the
`:mn-document-class:` attribute of `sources/onnx-std.adoc`. Moving to a Linux
Foundation or ISO house style should touch those two places and nothing else.
If a flavour change requires editing the document body, that is a defect in how
the body is written — report it.
