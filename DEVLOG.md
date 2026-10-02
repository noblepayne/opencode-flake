# Devlog

Running notes. Short, dated, and written down **because something surprised me** —
the failure modes here are all cases where a check went green while doing nothing
useful, which is the hardest kind to notice.

---

## 2026-10-02 — server unit hardening; the exit-0 trap

**What happened.** A `nixos-rebuild switch` produced **56 silent restarts** of
`opencode2-server` over 5 minutes. The journal contained *nothing* — no exit
code, no error, no `opencode2` output at all. The unit eventually won the port
and has been healthy since.

**Why.** Two things stacked:

1. A client-spawned server already held `4096`. `serve --service` checks for an
   incumbent first and, finding one, **returns before binding and exits 0**.
2. `Restart = "always"` + `RestartSec = 5` turned that into a hot loop.

**The trap — do not "fix" this with `Restart=on-failure`.**

It is the obvious change and it is strictly worse. Because the losing exit is
`0`, `on-failure` never fires. The unit would sit `inactive` while the incumbent
served; when the incumbent later died, nothing would pull the unit back in,
because `wantedBy = [ "default.target" ]` only fires at boot/login. You trade a
loud loop for a **permanent silent death**. `Restart=always` is load-bearing.

**Why the loop could never stop on its own.** systemd's start-limit defaults are
`10s / burst 5`. With a flat 5s restart you only fit 2 starts in that window, so
the breaker is mathematically unreachable — the exact opposite of a safety net.
Now `startLimitIntervalSec = 900` / `startLimitBurst = 12`: trips after ~8 min
of continuous failure, lands in `failed` **with a journal line naming it**, and
`nixos-rebuild` prints a warning listing failed user units during activation.

**Also pinned** `--hostname 0.0.0.0 --port 4096` onto `ExecStart`. `serve`
otherwise reads `~/.config/opencode/service.json`; with that file missing the
fallback is **port 49374**, so NetBird reachability would vanish with no error.

---

## Things about OpenCode v2 worth knowing

- **Clients connect; they don't always spawn.** A client resolves an
  "incumbent" from `~/.local/state/opencode/service.json` and connects to it if
  one is live. This is why TUIs usually do *not* start their own server. The
  race only opens in the window where the incumbent is stale — e.g. right after
  a switch stops the unit.
- **`--server http://127.0.0.1:4096` forces connect-only.** There is no env var
  for it, so it would need a shell alias — which would then break the
  `opencode2 service` / `serve` subcommands. Left alone deliberately: the
  incumbent mechanism already gives the right behaviour in practice.
- **There is no health endpoint to poll.** `/global/health` does not exist —
  every non-`/api/*` path returns the SPA catch-all with HTTP 200. The real one
  is `/api/info` (200 ready / 503 starting / 500 failed), but it is Basic-auth
  gated, so it has no business in a unit file. For a manual check:
  `opencode2 service status`.
- **No `sd_notify`.** The binary has zero support for `NOTIFY_SOCKET`,
  `READY=1` or `WATCHDOG=1`. `WatchdogSec` and `Type=notify` are therefore not
  available — that is the ceiling, not an oversight.

---

## The recurring shape of these bugs

Three separate incidents this month, one pattern: **CI or the service reported
success while doing nothing.**

1. Frozen v1 auto-updates aborted the v2 updater → v2 stale for two days.
2. The weekly flake-update workflow committed on the base branch, so
   `create-pull-request` saw an empty rebase, reset the branch to `main`, and
   **deleted it** — exit 0, zero PRs ever, `flake.lock` pinned ~6 months.
3. The server unit crash-looping with an empty journal.

The general lesson, and the reason this file exists: *a check that passes is a
claim, not a fact.* The expensive failures here are the ones where something
looked fine and wasn't. When a step is load-bearing, make it fail **loudly** —
assert the rewrite happened, refuse a no-op commit, let a restart loop trip a
circuit breaker instead of spinning forever.