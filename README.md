# old-mc

Archived legacy `mc` fish function for managing local Minecraft servers on
`laptoo`. Superseded by the compiled Go binary (see `mc-go`).

> **yep this is vibecoded asw it was just some manual aliases then evolved into a function"

## Contents

| File | Purpose |
|---|---|
| `mc.fish` | Main `mc` command (start/stop/restart/console/logs/backup/restore/status/check/rmworld/list/whitelist/bot) |
| `_mc_format_duration.fish` | Format seconds → human readable |
| `_mc_kick_bots.fish` | Kick bots bound to a server port before stop |
| `_mc_list_servers.fish` | List server dirs containing a jar |
| `_mc_notify.fish` | Desktop notify-send + paplay sound + ntfy push |
| `mc.fish.bak` | Older backup of the function |

## Why it was replaced

The fish function was slow (interpreted), fish-dependent, and grew to 437
lines across 5 files. `mc-go` is a single static Go binary with a real CLI,
no runtime deps beyond `tmux`, and better stop-timeout handling (retry +
force-kill prompt + leftover listing).
