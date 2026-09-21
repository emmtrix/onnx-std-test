# Proposed structure of the ONNX standard

**Status: implemented.** `sources/part1/`, `sources/part2/` and
`sources/part3/` follow this structure. This file remains the rationale for it:
what it takes from where, and what it deliberately does not take.

It merges two inputs: the structure of the current draft, and a rough outline
proposed in an earlier discussion. Where they disagree, the reasoning is given.

## The central decision: three parts, not one document

The requirement that shapes everything else is that **the core and the operator
sets move at different speeds**:

| | Changes when | Observed cadence |
|---|---|---|
| The information model, semantics, encoding | The IR version changes | Roughly once a year |
| The operator sets | Every ONNX release | Two to three times a year, hundreds of entries |
| The conformance test vectors | With the operator sets | Tracks the operator sets |

Putting all three in one document means the stable part carries a new edition
every time an operator is added. That is the wrong economics for a standard:
implementers re-read, committees re-ballot, and citations go stale for changes
that do not touch the core.

So the proposal is a multi-part standard:

- **Part 1 — Core.** Information model, type system, semantics, inference,
  validation, numerical behaviour, encoding, versioning, security,
  conformance. Names no individual operator.
- **Part 2 — Operator sets.** The operator registry, per domain and per opset
  version.
- **Part 3 — Conformance test package.** Test vectors, which track Part 2.

The seam that makes this work: Part 1 specifies the *form* an operator
definition must take and the rules operator sets must obey — it never names
`Relu`. Part 2 supplies the definitions in that form. An operator added
upstream is then a Part 2 amendment and leaves Part 1 untouched.

This is what the editorial note in the current Clause 8.4 proposes, made
concrete.

## Part 1 — Core

```
1  Scope
2  Normative references
3  Terms and definitions
4  Conformance
   4.1  Requirement terminology
   4.2  Conformance classes
   4.3  Conformance profiles
   4.4  Operator set coverage
   4.5  Conformance statement
   4.6  Relationship to Parts 2 and 3
5  Information model
   5.1  General
   5.2  Entities and their relationships
   5.3  Model
   5.4  Names and scoping
   5.5  Metadata
   5.6  Domains as the extension point
6  Type system
   6.1  General
   6.2  Element types
   6.3  Reduced-precision element types
   6.4  String elements and character encoding
   6.5  Shapes and dimensions
   6.6  Dimension denotation
   6.7  Composite types
   6.8  Type equality and assignability
7  Graph structure
   7.1  Graph, inputs and outputs
   7.2  Initializers
   7.3  Nodes
   7.4  Attributes
   7.5  Topological constraints
   7.6  Subgraphs and scoping
8  Graph semantics
   8.1  Evaluation model
   8.2  Evaluation order and concurrency
   8.3  Control flow
   8.4  Functions
   8.5  Determinism
   8.6  Error semantics
9  Shape and type inference
   9.1  General
   9.2  Obligations on operator definitions
   9.3  Symbolic dimensions
   9.4  Strictness and failure
   9.5  Relationship to validation
10 Model validation
   10.1  General
   10.2  Structural checks
   10.3  Type and shape checks
   10.4  Operator set checks
   10.5  Severity and reporting
11 Numerical behaviour
   11.1  General
   11.2  Floating-point arithmetic
   11.3  Special values
   11.4  Accumulation and reassociation
   11.5  Tolerances
   11.6  Non-deterministic operators
12 Serialization
   12.1  General
   12.2  Encoding
   12.3  Message definitions
   12.4  Canonical form
13 External data
   13.1  General
   13.2  Reference resolution
   13.3  Integrity
14 Versioning and compatibility
   14.1  Version axes
   14.2  IR version evolution
   14.3  Operator set evolution
   14.4  Compatibility obligations
   14.5  Deprecation and removal
15 Security and resource limits
   15.1  General
   15.2  Threat model
   15.3  External data and path resolution
   15.4  Resource bounds
   15.5  Handling untrusted models
16 Maintenance and extension
   16.1  Custom domains
   16.2  Experimental operators
   16.3  Adding an operator
   16.4  Amending this document

Annex A (normative)    Conformance statement
Annex B (normative)    Protocol Buffers schema
Annex C (informative)  Known gaps and divergences
Annex D (informative)  Correspondence with the ONNX reference implementation
```

## Part 2 — Operator sets

```
1  Scope
2  Normative references
3  Terms and definitions          (by reference to Part 1)
4  Required form of an operator specification
5  The default domain
6  The ai.onnx.ml domain

Annex A (normative)    Operator registry, by domain and opset version
Annex B (informative)  Changelog
```

## Part 3 — Conformance test package

```
1  Scope
2  Test vector format
3  Test selection by profile
4  Application of tolerances
5  Reporting

Annex A (normative)    Test vectors
```

## What this takes from the earlier outline, and why

| Adopted | Why it matters |
|---|---|
| **Shape and type inference as its own clause** | It is normatively load-bearing — consumers rely on it, producers may omit `value_info` — and 5.6 of a type-system clause is too small a place to specify it. |
| **Model validation as its own clause** | The draft already defines a "checking consumer" conformance class and then never says what it must detect. This closes that hole. |
| **Security and resource limits** | The draft says nothing. Upstream has `ExternalDataSecurity.md`; path traversal, unbounded shapes and allocation limits are real, and a standard silent on them is incomplete. |
| **Normative test vectors** (as Part 3) | This is the most valuable idea in the outline. Annex C records unspecified numerical tolerances as the single largest blocking gap, precisely because conformance is not testable without them. Test vectors are the mechanism that makes it testable. |
| **Conformance profiles** | Named subsets an implementation can claim, distinct from the producer/consumer conformance classes. |
| **Numerical behaviour as its own clause** | It is not a subclause of conformance: it covers tolerances, determinism, special values and accumulation order. |
| **External data as its own clause** | A separate mechanism with its own security surface, currently buried at 9.3. |
| **Maintenance and extension** | Custom domains and experimental operators are how ONNX actually grows; upstream documents the process and the standard should too. |
| **Information model as a framing clause** | Introduce the entities before detailing them, rather than opening with the type system. |
| **Normative Protobuf schema as an annex** | Matches the decision recorded in Clause 9's editorial note. |

## What this does not take, and why

**Conformance stays early, at Clause 4, not at 13–14.** The outline places it
late. Requirement terminology has to be defined before the first `SHALL`, and
in the outline clauses 4 to 12 would use requirement language before the clause
that defines it. Conformance *classes* and *profiles* belong with that
terminology.

**"Graph and model semantics" is split into structure (7) and semantics (8).**
What a well-formed graph *is* and what evaluating it *means* are different
obligations, land on different conformance classes — a producer must satisfy
the first, an evaluating consumer both — and are better not interleaved.

**The Python reference implementation is not an informative annex.** It is a
large, fast-moving codebase; reproducing it in the standard would age badly.
Annex D instead states the correspondence, and `upstream/onnx/` already holds
the copy of the implementation's documentation that the draft is written
against.

**Annex C (known gaps) is kept**, which the outline does not have. It is the
part of this repository the Steering Committee is most likely to read first.

## Open questions

These are for the Steering Committee, not the editor:

1. **Is three parts right, or two?** Test vectors could be an annex of Part 2
   rather than a part of their own. Three is proposed because a test package is
   a deliverable people consume separately, often under a different licence.
2. **Does Part 1 name a default operator set version?** If it does, it
   re-acquires the cadence the split is meant to avoid. The proposal is that it
   does not, and that a conformance statement names the versions instead.
3. **What is the IPR position on Part 3?** Test vectors are the part most
   likely to be embedded in implementations, which may argue for a different
   licence from the prose.

## State of the implementation

The skeleton is complete and builds: three documents, 16 + 6 + 7 clauses and
seven annexes. The prose of the previous ten-clause draft has been carried
across and re-anchored.

What is drafted and what is not follows the same convention as before. Clauses
carry an editorial note where content is owed, and Annex C of Part 1 records
every such clause. The count rose from 16 notes to 44 across the three parts,
which was not a regression: the new clauses — validation, security, inference,
test vectors — are places the previous structure had no room to admit a gap in.

A pass over the vendored upstream documentation has since closed 20 gaps,
taking Part 1 from 34 editorial notes to 25 and the three parts together from
44 to 35. (Twelve notes went; three new ones came, all from reading the source
closely: two in the narrow-type conversion rules, and one on the IR version
this edition specifies, which turns out to be one ONNX has not published.) The clauses concerned are the ones where ONNX does
state a rule and this document simply had not yet said so: the complete
element type enumeration, the narrow types and their packing, broadcasting,
denotation, opaque types, the model and its operator set imports, namespaces and subgraph
visibility, metadata keys, initializers, variadic and unsupplied inputs and
outputs, functions, the model as a stateless function, external data resolution,
the security threat model and path resolution, IR and operator set evolution,
inference strictness, and the status of experimental operators. Annex C now
carries a second table naming, for each, the upstream document it was taken
from, so that the transcription can be checked rather than trusted.

What is left in the first table is what ONNX does not state at all, or states
in a form a standard cannot adopt: tolerances, the Protocol Buffers citation
and wire subset, canonical form, determinism per operator, control-flow
semantics, type equality, and the testable form of the validation checks.

Clauses 5 and 6 of Part 2 are generated from the vendored upstream
documentation by `scripts/generate-operators.rb`: 222 operators, restated in
the form Clause 4 requires. The authored-or-generated question is settled in
favour of generated, and CI checks that the committed files match the
generator.

What remains is what generation cannot reach. The upstream source supplies no
shape inference, no determinism statement and no error conditions — for any of
the 222 operators — and Clause 4 makes all three mandatory. The generator
reports the coverage on every run:

```
    Since version       222 / 222
    Inputs              218 / 222
    Outputs             218 / 222
    Attributes          139 / 222
    Type constraints    218 / 222
  ! Shape inference       0 / 222
    Semantics           222 / 222
  ! Determinism           0 / 222
  ! Errors                0 / 222
    Test vectors        189 / 222
```

The four operators short of a signature are the deprecated ones: upstream stops
documenting inputs, outputs and type constraints once an operator is
deprecated, while Clause 14.5 of Part 1 requires consumers to keep evaluating
it. Annex C records that.
