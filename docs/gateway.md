# Gateway

## Start gateway only

If you already deployed and only need the gateway (or it stopped):

```bash
chmod +x start_gateway.sh scripts/diagnose_gateway.sh scripts/macos_launchd_gateway.sh
./start_gateway.sh
```

`start_gateway.sh` redeploys the LaunchAgent plist (macOS), restarts the gateway, and prints a diagnostics report. A Telegram *"Gateway shutting down"* message during restart is expected.

On macOS, `scripts/macos_launchd_gateway.sh`:

1. Resolves launchd domain (`gui/<uid>` or `user/<uid>`)
2. Bootstraps `com.hermes.gateway` and kickstarts the job
3. Retries when launchd reports unloaded
4. Falls back to detached `nohup hermes gateway run --replace` if launchd cannot manage the domain (some macOS 26+ hosts)

Health is verified by **gateway process running** (`pgrep`), not only LaunchAgent loaded state.

Remote host:

```bash
INVENTORY=inventory.ini ./start_gateway.sh
# then SSH in: bash scripts/diagnose_gateway.sh vars.yml
```

## Check status

```bash
# macOS
pgrep -fl "hermes.*gateway run"
launchctl print "gui/$(id -u)/com.hermes.gateway" 2>/dev/null || launchctl print "user/$(id -u)/com.hermes.gateway"
tail -f ~/.hermes/logs/gateway.stderr.log

# Linux / WSL2
systemctl status hermes-workspace
```

## Diagnose

```bash
bash scripts/diagnose_gateway.sh vars.yml
```

| Check | macOS | Linux |
|-------|-------|-------|
| LM Studio at `lmstudio_base_url` | yes | yes |
| Gateway process / service | `pgrep` | `systemctl is-active hermes-workspace` |
| GUI session (Aqua) | yes | — |
| LaunchAgent loaded | yes | — |
| Recent logs | `~/.hermes/logs/gateway.stderr.log` | `journalctl -u hermes-workspace` |

Exit `0` = healthy; `1` = failed (fix hints in output). Report also written to `~/.hermes/logs/gateway-diagnostics.txt`.

**Common failures**

- **LM Studio not running** — `lms daemon up`, `lms server start`, `lms get <model>`
- **LaunchAgent not loaded** — run `./start_gateway.sh`
- **Gateway crash** — read stderr tail in report or `~/.hermes/logs/gateway.stderr.log`
- **SSH-only Mac** — detached fallback may be used instead of LaunchAgent supervision
- **Process up, LaunchAgent down** — detached fallback active; re-run `./start_gateway.sh` to retry supervision
