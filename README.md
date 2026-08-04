# mirror-stern

OCX mirror for [stern](https://github.com/stern/stern), a multi-pod, multi-container
log tailer for Kubernetes. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [stern](https://github.com/stern/stern) | [`stern/mirror.yml`](stern/mirror.yml) | `ghcr.io/ocx-contrib/stern/stern` | [`ocx.sh/stern/stern`](https://index.ocx.sh/stern/stern) | `Apache-2.0` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`stern` is the project's own GitHub org and its own brand, so the org is the
namespace: the package is `stern/stern`. Provenance lives in the index claim's
`upstream` block, not in the namespace.

## Layout

```
stern/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

There is **no `mirror-base.yml`** and no `extends:` chain: every key this
single package needs is package-owned. That is deliberate — `extends:` is a
shallow merge of top-level keys, and a spec that restates `platforms:` to
change one runner drops every `containers:` entry with it while nothing reds.
With one spec there is nothing to merge and the trap does not exist. A second
package here would move the genuinely repo-wide keys into a base; that is a
content move, not a rename, and changes no generated workflow filename.

## Platforms

`stern` publishes six platform entries: both Linux arches, both macOS arches
and both Windows arches. All six are shipped by upstream on every in-range
release.

Upstream builds are **static Go binaries**. Measured with `file` / `readelf` on
both declared Linux arches at all three points of the mirrored range — 1.33.0,
1.33.1 and 1.34.0 — all six show no `PT_INTERP`, no `DT_NEEDED` and no
versioned GLIBC symbol references at all, and `readelf -h` reports real section
headers at offset 400 with zero `UPX` strings (i.e. not a packer stub faking a
static verdict). `os.features` states what an artifact requires *of the host*,
so both Linux keys are **bare**: `+libc.glibc` would hide the package from every
musl host and `+libc.musl` from every glibc host, and neither is true. The
`alpine:3.20` container leg on both arches is what turns that claim into
evidence; the measurement transcript is recorded above the `assets:` block in
`stern/mirror.yml`.

No `containers[].setup` line is needed on any leg. That was measured, not
assumed: 1.34.0's linux/amd64 binary ran `--version`, the `--stdin` filter, the
JSON renderer and both negative controls identically in stock `ubuntu:24.04`,
`alpine:3.20` and `fedora:40`. stern speaks HTTP to a Kubernetes apiserver and
parses kubeconfig itself — unlike the git-shelling tools on this fleet, it
execs nothing.

Upstream also publishes 32-bit `linux_arm` archives on every release, and a
`windows_arm` archive at 1.33.0 only. ocx expresses exactly `amd64` and
`arm64`, so neither is a declarable platform — the anchored `^…$` asset regexes
are what keep them out.

Two naming traps make those anchors load-bearing, and both are defused by
end-anchoring on `\.tar\.gz$`:

1. **Windows gained a `.zip` sibling mid-range.** 1.33.0 ships only
   `stern_1.33.0_windows_amd64.tar.gz`; from 1.33.1 upstream ships both the
   `.tar.gz` and a `.zip`. A loosely anchored pattern therefore
   double-matches on 1.33.1+ (a hard ambiguous error), while a `.zip`-anchored
   one matches **zero** on 1.33.0 — silently skipped, yielding a green run with
   a missing platform. `.tar.gz` is the only format present across the entire
   range, so **Windows is a tarball platform here**, not the usual zip, and
   needs no per-platform `asset_type` override.
2. `stern_<V>_linux_arm.tar.gz` sits beside `stern_<V>_linux_arm64.tar.gz` in
   every release, so an unanchored `_linux_arm` fragment matches both.

Resolution was verified **both ways on every in-range release**: 6 platforms ×
3 releases = 18 checks, each matching exactly one asset. A pattern matching
zero would be silently skipped rather than reported, so this check is not
optional.

Asset names **are** version-suffixed and each agrees with its own tag, so a
release re-shipping its predecessor's binaries would be visible in the
filename. It was checked a second way regardless, because the 1.33.0 and 1.33.1
archives hold byte-identically *sized* binaries on all six platforms (a
version-string-only bump preserves the byte count): all 18 extracted binaries
hash to 18 distinct SHA-256 digests, and each self-reports its own version via
`stern --version`.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `stern/mirror.yml` | hand | yes — see below |
| `stern/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `stern/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec stern/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`stern/metadata.json` declares `binaries: ["stern"]` by hand, and
`stern/mirror.yml` sets `bin_scan: "off"` — forced, not preferred. The scan only
inspects an interface-visible `${installPath}/<dir>` PATH entry, and stern's
archives are **flat**: `stern` (`stern.exe` on Windows) and `LICENSE` sit at the
archive root with no subdirectory to point one at. With nothing to inspect the
scan would pass green whatever the archive contained, so `auto` and `verify`
both fail spec load at exit 65 rather than offer a hollow check. The
hand-written list is what the error message itself directs, and it is short and
stable — the binary is the only mode-0755 entry; `LICENSE` is 0644 data.

## The smoke test

stern's headline behaviour is tailing logs out of a live Kubernetes cluster,
and CI has no cluster. Rather than settle for a liveness probe, the smoke test
drives the one code path that does real work with no apiserver at all:
`--stdin`, documented upstream as *"Parse logs from stdin. All Kubernetes
related flags are ignored when it is set."* In that mode stern is its own log
pipeline, so the assertions are on **computed results**, never on exit 0:

- `stern --version` — liveness on the composed PATH plus the version *shape*
  (`\d+\.\d+\.\d+`), never the labels around it.
- `--include alpha` over four records must leave **exactly two**, and
  `--exclude alpha` exactly the complementary two. Asserted as token counts,
  because an empty result set also exits 0 — and a passthrough that echoed its
  stdin could not drop a record.
- `-o json` must emit **four** `"message":` records, structure a passthrough
  cannot fabricate.
- `--template "[{{.Message}}]"` must render four bracketed records with the
  field reference resolved, proving the Go template engine evaluated.
- The same filter re-run with `--color always` must produce **different bytes**
  than with `--color never` — which is what proves `never` is honoured rather
  than ignored, and keeps the plain-substring assertions above safe.

Two **negative controls**, because everything above runs in `--stdin` mode and
would otherwise say nothing about the half of stern that talks to a cluster:

- `KUBECONFIG` pointed at a deliberately malformed YAML file written into the
  test scratch sandbox must exit **non-zero**. It exercises the kubeconfig
  loader and fails in the YAML parser before any network call, so no leg can
  hang on an unreachable apiserver — and a binary that exited 0 on everything
  fails here.
- `--include '['` — an unterminated character class — must exit **non-zero**. A
  substring matcher would accept it and quietly return zero records; stern has
  to fail to compile it. That is what makes the filter counts evidence of regex
  filtering rather than of incidental string matching.

**Ceiling, stated honestly:** nothing here tails a real pod. The cluster-facing
path is covered only to the point of "kubeconfig is parsed and bad input is
rejected"; a regression in log streaming against a live apiserver would not be
caught by this mirror's CI.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md). The logo is an
original mark authored for this mirror — stern ships none — see `NOTICE.md`.
