# NOTICE

This repository packages and redistributes upstream software published by the
[stern](https://github.com/stern/stern) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

The logo shipped in `stern/logo.svg` / `stern/logo.png` is an **original mark
authored for this mirror**, not an upstream asset: stern publishes no logo of
its own (the repository contains no image files and the README carries none).
It is used only to identify the mirrored software in OCX clients, and no
endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `stern` | `ghcr.io/ocx-contrib/stern/stern` | `Apache-2.0` |

---

## `stern`

Upstream: <https://github.com/stern/stern>
Published to `ghcr.io/ocx-contrib/stern/stern`.

| Component | SPDX | Holder |
|---|---|---|
| stern (`stern`) | **Apache-2.0** | Copyright © 2016 Wercker Holding BV and the stern authors |

Verified at the redistribution gate:

```
$ gh api repos/stern/stern/license --jq '{spdx: .license.spdx_id, name: .license.name}'
{"name":"Apache License 2.0","spdx":"Apache-2.0"}
```

`stern/stern` is the maintained continuation of the discontinued
[`wercker/stern`](https://github.com/wercker/stern), and upstream's source
files still carry the original `Copyright 2016 Wercker Holding BV` header — the
holder above is taken verbatim from them, since the shipped `LICENSE` is an
unmodified copy of the Apache-2.0 text with the appendix placeholders left
unfilled.

The Apache License 2.0 grants redistribution of the work in source and object
form, on the conditions that recipients receive a copy of the license, that
modified files are marked, and that applicable attribution notices are
retained. Those conditions are met by construction: upstream's `LICENSE` file
ships **inside every mirrored archive**, at the archive root beside the binary,
and is republished unmodified as part of the bundle content.

The published binaries statically link third-party Go modules under permissive
licenses, enumerated in the `go.mod` / `go.sum` of the tagged upstream source
for each mirrored version.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
