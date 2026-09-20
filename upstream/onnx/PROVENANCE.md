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

For the record, `main` was at `7671b22f21c96d5938a5c3f0825f3e16323a67c5`
(VERSION_NUMBER 1.24.0) when this copy was taken, two days after v1.23.0. The
difference between the two is the upstream change the next refresh will show.

## What is here

| Path | Content |
|---|---|
| `docs/` | The upstream `docs/` tree, minus `docsgen/` |
| `proto/` | The Protocol Buffers schema from the upstream `onnx/` directory |
| `LICENSE` | The upstream Apache-2.0 licence |
| `VERSION_NUMBER` | The upstream version string |
| `SOURCE.txt` | Machine-readable provenance, written by the refresh script |

`docs/docsgen/` is excluded. It is the Sphinx website generator — `conf.py`,
tutorials, images and a minified JavaScript library — not specification text.
Nothing else is filtered; the 44 Markdown documents (34 at the top level, 10
under `docs/proposals/`) and 8 `.proto` files are copied as they stand,
including the ones with no bearing on the standard
(release administration, CI pipelines, backend test coverage), so that the
copy is plainly a copy rather than a selection someone has to second-guess.

The `.proto` files are vendored with the prose because they, not the prose, are
the normative serialization definition that Clause 9 restates.

## What the draft draws on

The correspondence is approximate and is given as a reading aid, not as a
claim of completeness:

| Upstream document | Clause of the draft |
|---|---|
| `docs/IR.md` | 6 Model structure, 7 Graph semantics |
| `docs/ONNXTypes.md`, `docs/TypeDenotation.md`, `docs/DimensionDenotation.md` | 5 Type system |
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
scripts/vendor-onnx-docs.sh v1.24.0    # or whichever release
```

The script rewrites this directory in place and regenerates `SOURCE.txt`, so
the resulting commit diff is exactly the upstream change. Update the version
statements in this file when the ref changes, and re-read Annex B: an upstream
release may have closed a gap recorded there, or opened a new one.
