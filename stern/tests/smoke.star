# stern/tests/smoke.star — stable across upstream stern releases.
# Asserts the contract (exit codes, version shape, a real computed result),
# never help/version prose. See ocx.mirror testing-practices.md.
#
# stern's headline behaviour is tailing logs out of a live Kubernetes cluster,
# and CI has no cluster. Rather than settle for a liveness probe, this file
# drives the one code path that does REAL work with no apiserver at all:
#
#   --stdin   "Parse logs from stdin. All Kubernetes related flags are ignored
#              when it is set."
#
# In that mode stern is its own log pipeline — the include/exclude regex
# filters, the `-o` renderers and the Go `--template` engine all run over
# whatever is fed in. So the assertions below are on COMPUTED RESULTS (how many
# records survived a filter, how many JSON records came out, what the template
# rendered), not on the fact that the process exited 0. Verified identical on
# 1.33.0, 1.33.1 and 1.34.0, and under ubuntu:24.04 / alpine:3.20 / fedora:40.
#
# `--color never` is passed to every functional invocation on purpose: stern's
# default is `auto`, and a leg whose stdout happened to be a tty would wrap
# every token in SGR escapes and break a plain-substring assertion. One check
# below deliberately re-runs with `--color always` and asserts the bytes DIFFER,
# which is what proves `never` is doing something rather than being ignored.

STERN = "stern.exe" if ocx.target_platform.os == ocx.os.Windows else "stern"

# Four records, two of which match /alpha/. The counts are the contract.
LOG = "alpha one\nbeta two\nalpha three\ngamma four\n"

# ── Tier 1 + 2: liveness on the composed PATH + version SHAPE ───────────────
# `--version` prints `version: <semver>`, a commit and a build date. The digits
# are the contract; the labels around them are not.
r_version = ocx.run(STERN, "--version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Tier 3a: the filter must DROP records ──────────────────────────────────
# A passthrough — a binary that merely echoed its stdin — would satisfy `-o raw`
# and exit 0. It cannot satisfy this: two of the four input records have to
# disappear. Asserted as a COUNT of surviving tokens rather than as exit 0,
# because an empty result set also exits 0.
r_inc = ocx.run(STERN, "--stdin", "--color", "never", "--include", "alpha", "-o", "raw", stdin=LOG)
expect.ok(r_inc)
expect.eq(r_inc.stdout.count("alpha"), 2)
expect.eq(r_inc.stdout.count("beta"), 0)
expect.eq(r_inc.stdout.count("gamma"), 0)

# The complementary direction, so a filter stuck at "match nothing" or "match
# everything" fails one of the two.
r_exc = ocx.run(STERN, "--stdin", "--color", "never", "--exclude", "alpha", "-o", "raw", stdin=LOG)
expect.ok(r_exc)
expect.eq(r_exc.stdout.count("alpha"), 0)
expect.eq(r_exc.stdout.count("beta"), 1)
expect.eq(r_exc.stdout.count("gamma"), 1)

# ── Tier 3b: the JSON renderer must STRUCTURE the records ──────────────────
# Each input line comes back as one JSON object carrying a `message` field —
# output a passthrough cannot fabricate. Counted, so a renderer that emitted a
# single merged blob or dropped records reds here.
r_json = ocx.run(STERN, "--stdin", "--color", "never", "-o", "json", stdin=LOG)
expect.ok(r_json)
expect.eq(r_json.stdout.count("\"message\":"), 4)
expect.contains(r_json.stdout, "\"message\":\"alpha three\"")

# ── Tier 3c: the Go template engine must EVALUATE ──────────────────────────
# `[{{.Message}}]` renders to `[alpha one][beta two][alpha three][gamma four]`
# with no separators of its own, so the bracket count is the record count and
# the bracketed text is proof the field reference resolved. Safe as a plain
# multi-word substring only because `--color never` is explicit above.
r_tpl = ocx.run(STERN, "--stdin", "--color", "never", "--template", "[{{.Message}}]", stdin=LOG)
expect.ok(r_tpl)
expect.eq(r_tpl.stdout.count("["), 4)
expect.contains(r_tpl.stdout, "[alpha three]")

# ── The colorizer is wired, and `never` is honoured ────────────────────────
# Compare bytes rather than asserting on either rendering: `always` emits SGR
# escapes per token, `never` emits none, so equality here would mean one of the
# two modes is being ignored.
r_color = ocx.run(STERN, "--stdin", "--color", "always", "--include", "alpha", "-o", "raw", stdin=LOG)
expect.ok(r_color)
expect.ne(r_color.stdout, r_inc.stdout)

# ── NEGATIVE CONTROL 1: stern really reads kubeconfig, and rejects garbage ──
# Everything above runs in `--stdin` mode, which bypasses Kubernetes entirely —
# so on its own it says nothing about the half of stern that talks to a cluster.
# Pointing KUBECONFIG at a deliberately malformed YAML file exercises the
# kubeconfig loader and must fail there. It is offline and immediate: the error
# comes out of the YAML parser, before any network call, so no leg can hang on
# an unreachable apiserver. A binary that exited 0 on everything fails here.
BADKUBE = "ocx-bad-kubeconfig.yaml"
ocx.write_file(BADKUBE, "this is: [not\n  a: valid ]kubeconfig\n")
r_kube = ocx.run(
    STERN, "--no-follow", "--color", "never", ".*",
    env={"KUBECONFIG": ocx.scratch_root + "/" + BADKUBE},
)
expect.ne(r_kube.exit_code, 0)

# ── NEGATIVE CONTROL 2: the include filter is a real regex engine ───────────
# `[` is an unterminated character class. A substring matcher would accept it
# and quietly return zero records (exit 0); stern must fail to compile it. This
# is what makes the Tier 3a counts evidence of regex filtering rather than of
# incidental string matching.
r_badrx = ocx.run(STERN, "--stdin", "--color", "never", "--include", "[", stdin=LOG)
expect.ne(r_badrx.exit_code, 0)
