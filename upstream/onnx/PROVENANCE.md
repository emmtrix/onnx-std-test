# Vendored ONNX documentation

This directory is a verbatim copy of the upstream ONNX documentation and
Protocol Buffers schema. It is **not** part of the standard and is never built
or published. It exists to fix, and to make auditable, the baseline that the
draft in `sources/` restates.

Exact version, commit and retrieval time are in [`SOURCE.txt`](SOURCE.txt).

## Why a release, not `main`

The copy is taken from the release tag **v1.23.0**, not from `main`.

A normative document has to say what it is a restatement *of*. A branch moves
under that claim: a reader of Annex B who wants to check "the reference
implementation's test suite uses relative tolerance 1e-3" needs the tree that
sentence was written against, not whatever `main` holds when they read it.

For the record, `main` was at `7671b22f21c96d5938a5c3f0825f3e16323a67c5` when
this copy was taken, two days after v1.23.0. Its `VERSION_NUMBER` read `1.24.0`,
which is the *development* version of the next release, not a released one:
at the time of writing, v1.23.0 is the newest tag in the repository and no
1.24 tag exists. The difference between the tag and that commit is the
upstream change the next refresh will show.

## What is here

| Path | Content |
|---|---|
| `docs/` | The upstream `docs/` tree, minus `proposals/` — 67 Markdown/reStructuredText documents |
| `proto/` | The Protocol Buffers schema from the upstream `onnx/` directory |
| `LICENSE` | The upstream Apache-2.0 licence |
| `VERSION_NUMBER` | The upstream version string |
| `SOURCE.txt` | Machine-readable provenance, written by the refresh script |

`docs/proposals/` is left out by decision: it holds RFC-style proposals for
changes that may never land, and this copy is meant to fix what ONNX *is*, not
what has been suggested for it. Note the consequence — two documents that are
kept, `IR.md` and `ShapeInference.md`, link into that directory (to the
multi-device and symbolic-shape-inference proposals), and those two links are
therefore dead in this copy. They resolve upstream.

Nothing else is filtered. The rest of `docs/` is copied whole, including
material with no bearing on the standard (release administration, CI pipelines,
backend test coverage, the Sphinx `conf.py` and site assets).

An earlier version of this copy also excluded `docs/docsgen/`. That tree holds
`docsgen/source/intro/concepts.md` — the conceptual
introduction published as
<https://onnx.ai/onnx/intro/concepts.html> — and
`docsgen/source/technical/{float4,float6,float8,int2,int4,kv_cache}.md`, the
reduced-precision type specifications. Those are among the documents Clause 5
and Annex B lean on most. Deciding what counts as "specification text" is
exactly the judgement a provenance copy should not be making, so it no longer
makes it.

The `.proto` files are vendored with the prose because they, not the prose, are
the normative serialization definition that Clause 9 restates.

## What the draft draws on

The correspondence is approximate and is given as a reading aid, not as a
claim of completeness:

| Upstream document | Clause of the draft |
|---|---|
| `docs/docsgen/source/intro/concepts.md` | 3 Terms and definitions, 6 Model structure (the conceptual overview) |
| `docs/IR.md` | 6 Model structure, 7 Graph semantics |
| `docs/ONNXTypes.md`, `docs/TypeDenotation.md`, `docs/DimensionDenotation.md` | 5 Type system |
| `docs/docsgen/source/technical/float4.md`, `float6.md`, `float8.md`, `int2.md`, `int4.md` | 5.2 Element types, and the tolerance gap in Annex B |
| `docs/ShapeInference.md`, `docs/ShapeAnnotationSemantics.md` | 5.6 Type inference |
| `docs/Broadcasting.md` | 5 Type system, 8 Operator specification |
| `docs/Operators.md`, `docs/Operators-ml.md`, `docs/OpConventions.md` | 8 Operator specification |
| `docs/Changelog.md`, `docs/Changelog-ml.md` | 8, 10 Versioning |
| `docs/Versioning.md`, `docs/VersionConverter.md` | 10 Versioning and compatibility |
| `docs/ExternalData.md`, `docs/ExternalDataSecurity.md` | 9.3 External data |
| `docs/MetadataProps.md` | 6.7 Metadata |
| `proto/onnx.proto`, `proto/onnx-ml.proto` | 9 Serialization |
| `docs/TestCoverage.md` | 4.4 Numerical tolerances (the gap recorded in Annex B) |

## Licence

The contents of this directory are licensed under Apache-2.0 by the ONNX
contributors; see [`LICENSE`](LICENSE). They are reproduced here unmodified.
The standard drafted in `sources/` is a separate work.

## Refreshing

```sh
scripts/vendor-onnx-docs.sh v1.23.0    # the current baseline
scripts/vendor-onnx-docs.sh <tag>      # a newer release, once one is tagged
```

Pass a release tag, not `main`. `VERSION_NUMBER` on `main` names the *next*
release and is not a tag you can check out; `git ls-remote --tags
https://github.com/onnx/onnx.git` shows what actually exists.

The script rewrites this directory in place and regenerates `SOURCE.txt`, so
the resulting commit diff is the upstream change plus the new provenance
header. Re-running it on the same ref is otherwise a no-op: only the
`retrieved:` timestamp moves. Update the version
statements in this file when the ref changes, and re-read Annex B: an upstream
release may have closed a gap recorded there, or opened a new one.
