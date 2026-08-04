---
title: stern
description: Tail logs from multiple Kubernetes pods and containers at once, colour-coded per pod, with live pod discovery
keywords: stern,kubernetes,k8s,logs,tail,kubectl,containers,pods,observability,cli,go
---

# stern

[stern](https://github.com/stern/stern) tails logs from many Kubernetes pods
and containers at the same time. Where `kubectl logs` binds you to one pod and
one container, stern takes a regular expression — or a `<resource>/<name>`
reference such as `deployment/api` — and follows every pod that matches it,
colour-coding each pod and container so interleaved output stays readable.

Pod discovery is live: a pod created after stern starts is picked up and
tailed automatically, and a deleted one drops out. That makes it usable
straight through a rollout, where the pod names you would have had to type do
not exist yet.

## What's included

- **stern** — the binary. `stern <pod-query>` tails everything matching, and
  the query is a regex, so `stern .` follows the whole namespace.
  `-n`/`--all-namespaces` scope it, `-c`/`--container` narrows to a container,
  `-i`/`--include` and `-e`/`--exclude` filter the log lines themselves,
  `--since` and `--tail` bound the history, and `--no-follow` makes it exit
  once the existing logs are shown. `-o json` and `--template` reshape the
  output for a downstream consumer; `--stdin` runs those same filters and
  renderers over a local stream with no cluster involved.

The archive also ships upstream's `LICENSE` alongside the binary.

## Configuration

stern reads the same kubeconfig `kubectl` does, honouring `KUBECONFIG`,
`--kubeconfig` and `--context`, and it respects RBAC — you can tail exactly
what you are allowed to read. Defaults for the flags can be kept in a config
file:

```sh
# defaults live here; override the location with --config
cat ~/.config/stern/config.yaml
tail: 50
timestamps: short
```

## Links

- [stern on GitHub](https://github.com/stern/stern)
- [Usage and flags](https://github.com/stern/stern#usage)
- [Changelog](https://github.com/stern/stern/blob/master/CHANGELOG.md)
