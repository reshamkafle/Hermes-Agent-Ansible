# Hermes Agent Ansible

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) on Linux or macOS — locally or over SSH. Installs LM Studio (llmster), configures Hermes (Firecrawl + Telegram), and schedules stock, news, and daily digest skills.

## Quick start

1. **Configure secrets**

```bash
cp vars.example..yml vars.yml
# Edit: lmstudio_model, hermes_model_api_key, Telegram IDs, firecrawl_api_key, tracked_stocks
```

2. **Remote only** — add your server to inventory:

```bash
cp inventory.example.ini inventory.ini
```

3. **Deploy**

```bash
# This machine
chmod +x deploy_local.sh && ./deploy_local.sh

# Remote host (requires inventory.ini — not localhost)
chmod +x deploy_all.sh && ./deploy_all.sh
```

4. **Smoke tests** (optional — see [Smoke tests](#smoke-tests) below):

```bash
chmod +x test_telegram.sh && ./test_telegram.sh                    # before deploy
chmod +x test_lmstudio_gateway.sh && ./test_lmstudio_gateway.sh      # after deploy
chmod +x test_hermes_daily_digest.sh && ./test_hermes_daily_digest.sh
```

The gateway starts automatically after deploy (controlled by `hermes_start_agents` in `vars.yml`, default `true`).

On macOS, check the gateway process and LaunchAgent:

```bash
pgrep -fl "hermes.*gateway run"
launchctl print "gui/$(id -u)/com.hermes.gateway"   # or user/$(id -u) on some macOS versions
```

To skip the gateway during deploy: set `hermes_start_agents: false` in `vars.yml`, or `START_HERMES_AGENTS=0 ./deploy_local.sh`

## Start gateway only

If you already deployed and only need the gateway (or it stopped and you want to restart it):

```bash
chmod +x start_gateway.sh scripts/diagnose_gateway.sh scripts/macos_launchd_gateway.sh
./start_gateway.sh
```

`start_gateway.sh` runs Ansible to redeploy the LaunchAgent plist (macOS), restart the gateway, and print a **diagnostics report** automatically. You may also get a Telegram message *"Gateway shutting down — Your current task will be interrupted"* during the restart — that is expected (the old process stops before the new one starts).

On macOS, `tasks/start_hermes_gateway.yml` calls `scripts/macos_launchd_gateway.sh`, which:

1. Resolves the correct launchd domain (`gui/<uid>` or `user/<uid>`)
2. Bootstraps the plist and kickstarts `com.hermes.gateway`
3. Retries when launchd reports the job is unloaded
4. Falls back to a detached `nohup hermes gateway run --replace` if launchd cannot manage the domain (seen on some macOS 26+ hosts)

Health is verified by **gateway process running** (`pgrep`), not only by LaunchAgent loaded state — so a detached fallback still counts as success.

Then check it:

```bash
# macOS — process + LaunchAgent (auto-restarts on failure when launchd supervises)
pgrep -fl "hermes.*gateway run"
launchctl print "gui/$(id -u)/com.hermes.gateway" 2>/dev/null || launchctl print "user/$(id -u)/com.hermes.gateway"
tail -f ~/.hermes/logs/gateway.stderr.log

# Linux / WSL2 — check the systemd service
systemctl status hermes-workspace
```

Remote host:

```bash
INVENTORY=inventory.ini ./start_gateway.sh
# then SSH in and run: bash scripts/diagnose_gateway.sh vars.yml
```

## Diagnose gateway

When the gateway fails to start or you want a quick health check, run:

```bash
chmod +x scripts/diagnose_gateway.sh
bash scripts/diagnose_gateway.sh vars.yml
```

This prints a report like:

```
=== Hermes gateway diagnostics ===
LM Studio: OK at http://127.0.0.1:1234/v1
macOS GUI session (Aqua): OK — LaunchAgent can load in this session.
Gateway process: running (`hermes gateway run`).
...
Recent gateway stderr (last 25 lines):
...
=== End diagnostics ===
```

**What it checks**

| Check | macOS | Linux |
|-------|-------|-------|
| LM Studio reachable at `lmstudio_base_url` | yes | yes |
| Gateway process / service running | `pgrep` for `hermes gateway run` | `systemctl is-active hermes-workspace` |
| GUI session (Aqua) for LaunchAgent | yes | — |
| LaunchAgent loaded | `com.hermes.gateway` in `gui/<uid>` or `user/<uid>` | — |
| Recent logs | `~/.hermes/logs/gateway.stderr.log` (falls back to `gateway.stdout.log`) | `journalctl -u hermes-workspace` |

Exit code `0` = healthy; `1` = at least one check failed (with fix hints in the output).

`./start_gateway.sh` runs this script automatically after Ansible on localhost. Ansible also writes the same report to `~/.hermes/logs/gateway-diagnostics.txt` during `start_gateway.yml`.

For the same checks plus verification that your configured LM Studio model is listed, use the [LM Studio and gateway smoke test](#lm-studio-and-gateway).

**Common causes when diagnostics fail**

- **LM Studio not running** — config points at `lmstudio_base_url` (default `http://127.0.0.1:1234/v1`). Run `lms daemon up`, `lms server start`, then `lms get <model>`.
- **LaunchAgent not loaded** — run `./start_gateway.sh` to redeploy the plist and bootstrap launchd. An outdated plist (missing `LimitLoadToSessionType`, no `--replace`) is replaced on each start.
- **Gateway crash on startup** — read the stderr tail in the report or `~/.hermes/logs/gateway.stderr.log`.
- **Missing stderr log** — launchd creates log files on first start; if the agent never loaded, run `./start_gateway.sh` first, then re-run diagnostics.
- **Not logged into the Mac GUI** — `com.hermes.gateway` prefers an Aqua session; SSH-only hosts may use the detached fallback instead of LaunchAgent supervision.
- **Process running but LaunchAgent not loaded** — detached fallback is active (launchd unavailable). Gateway works until reboot/crash; re-run `./start_gateway.sh` to retry LaunchAgent supervision.


## Playbooks

Run in this order (`deploy_local.sh` / `deploy_all.sh` do this automatically):

| Playbook | Purpose |
|----------|---------|
| `deploy_hermes.yml` | Core: LM Studio, Hermes CLI, config, `.env` |
| `deploy_investment.yml` | Midnight stock watchlist |
| `deploy_news.yml` | 5 AM IT/AI news digest |
| `deploy_digest.yml` | 6 AM combined HTML briefing via Telegram |

Run `deploy_hermes.yml` first — skill playbooks expect `~/.hermes/` to exist.

## Prerequisites

| | Local (`deploy_local.sh`) | Remote (`deploy_all.sh`) |
|--|---------------------------|--------------------------|
| Required | `ansible-playbook`, `vars.yml` | + SSH, `inventory.ini` |
| macOS | [Homebrew](https://brew.sh/) (git, node) | Same |
| Linux | `libatomic1` (installed by playbook) | Same |
| API keys | Telegram + Firecrawl | Same |

## macOS vs Linux

| | Linux / WSL2 | macOS (local) |
|--|--------------|---------------|
| User / home | `hermes` → `/home/hermes` | Your login user → `~/` |
| Config & skills | `/home/hermes/.hermes/` | `~/.hermes/` |
| LLM model | GGUF via `lmstudio_model_linux` | GGUF via `lmstudio_model` |
| LLM service | systemd (`llmster`) | `lms daemon up` + `lms server start` |
| Scheduler | cron | LaunchAgents in `~/Library/LaunchAgents/` |
| Gateway | systemd (`hermes-workspace`) | LaunchAgent (`com.hermes.gateway`) via `scripts/macos_launchd_gateway.sh` |
| Gateway command | `hermes-run.sh gateway run --replace` | same |

The macOS LaunchAgent plist sets `HERMES_HOME`, runs `gateway run --replace` (avoids stale PID conflicts), and loads in Aqua or Background sessions. Playbooks auto-find the Hermes CLI (`~/.local/bin/hermes`, Homebrew paths, or PATH). Only `deploy_hermes.yml` installs Hermes if missing.

## Scheduled jobs

| Skill | Time | macOS plist |
|-------|------|-------------|
| Stock tracker | Midnight | `com.hermes.investment.plist` |
| Tech news | 5 AM | `com.hermes.technews.plist` |
| Daily digest | 6 AM | `com.hermes.dailydigest.plist` |

Logs: `~/.hermes/logs/` · macOS gateway: `pgrep -fl "hermes.*gateway run"` and `launchctl print gui/$(id -u)/com.hermes.gateway` (or `user/$(id -u)`) · Linux gateway: `systemctl status hermes-workspace`

## Smoke tests

Optional checks you can run on localhost before or after deploy. None of these install Hermes or touch remote hosts.

### Telegram

Confirms bot token and chat IDs. Can run **before** deploy.

```bash
chmod +x test_telegram.sh && ./test_telegram.sh
```

Playbook: `smoke_test_telegram.yml`

### LM Studio and gateway

Confirms LM Studio is up, your configured model is available, and the Hermes gateway is running. Run **after** `./deploy_local.sh`.

```bash
chmod +x test_lmstudio_gateway.sh && ./test_lmstudio_gateway.sh
```

Playbook: `smoke_test_lmstudio_gateway.yml`

**Prerequisites**

- `vars.yml` with `lmstudio_base_url`, `lmstudio_model` (macOS), or `lmstudio_model_linux` (Linux)
- `./deploy_local.sh` already run (`~/.hermes` exists and gateway is installed)
- LM Studio running with the model from `vars.yml` loaded:

```bash
lms daemon up
lms server start
lms get <lmstudio_model-from-vars.yml>
lms load <model-from-vars.yml>
```

**What it checks**

| Check | macOS | Linux |
|-------|-------|-------|
| LM Studio API at `lmstudio_base_url` | yes | yes |
| Model from `vars.yml` in `/v1/models` | yes | yes |
| Gateway process / service running | `pgrep` for `hermes gateway run` | `systemctl is-active hermes-workspace` |
| LaunchAgent loaded | `com.hermes.gateway` in `gui/<uid>` or `user/<uid>` | — |
| GUI session (Aqua) for LaunchAgent | yes | — |

Exit code `0` = all checks passed; `1` = at least one failed. On failure, the playbook prints the full gateway diagnostic report and writes `~/.hermes/logs/gateway-diagnostics.txt`.

**If it fails**

- **LM Studio not reachable** — start the server and load the model (commands above). Confirm with `curl http://127.0.0.1:1234/v1/models` (or your `lmstudio_base_url`).
- **Model not listed** — run `lms get` and `lms load` for the model in `vars.yml`.
- **Gateway not running** — run `./start_gateway.sh` or `bash scripts/diagnose_gateway.sh vars.yml`.
- **macOS LaunchAgent missing** — run `./start_gateway.sh` to redeploy and bootstrap. If the process is running but LaunchAgent is not loaded, the detached fallback may be in use (see [Start gateway only](#start-gateway-only)).

### Daily digest

Runs the full `daily-morning-digest` skill (news + investment → HTML + Telegram). Run **after** deploy. May take several minutes.

```bash
chmod +x test_hermes_daily_digest.sh && ./test_hermes_daily_digest.sh
```

Playbook: `smoke_test_hermes_daily_digest.yml`

Needs LM Studio running, `firecrawl_api_key`, and Telegram configured. Override timeout (default 1800 seconds):

```bash
SMOKE_TEST_TIMEOUT=3600 ./test_hermes_daily_digest.sh
```

## Run one playbook

```bash
# Local
ansible-playbook -i 'localhost,' -c local -e ansible_become=false deploy_hermes.yml

# Remote
ansible-playbook -i inventory.ini deploy_hermes.yml
```

Custom inventory: `INVENTORY=hosts.ini ./deploy_all.sh`

## Key `vars.yml` settings

| Variable | Purpose |
|----------|---------|
| `hermes_start_agents` | Start gateway after deploy (default `true`; set `false` or `START_HERMES_AGENTS=0` to skip) |
| `lmstudio_model` | GGUF model for macOS — default `google/gemma-4-12b@q4_k_m` (from `lmstudio-community/gemma-4-12B-it-GGUF`; use lowercase quant tag as shown by `lms ls`) |
| `lmstudio_model_linux` | GGUF model for Linux/WSL2 — default `google/gemma-4-12b@q4_k_m` |
| `lmstudio_base_url` | LM Studio OpenAI-compatible API URL (default `http://127.0.0.1:1234/v1`) |
| `lmstudio_server_port` | Port for `lms server start` (default `1234`) |
| `lmstudio_download_model` | Run `lms get --yes` during deploy (default `true`; skips if model already on disk) |
| `lmstudio_wait_retries` / `lmstudio_wait_delay` | After download, poll `lms ls` until model appears (default 36 × 10s = 6 min) |
| `lmstudio_load_model` | Run `lms load --yes` during deploy (default `true`; skips if model already in memory) |
| `lmstudio_load_async_seconds` | Max time to wait for `lms load` to finish (default 3600s) |
| `lmstudio_load_poll_interval` | Ansible poll interval while `lms load` runs (default 30s) |
| `lmstudio_model_download_url` | Hugging Face repo for `lms get --gguf` (default in example: `https://huggingface.co/lmstudio-community/gemma-4-12B-it-GGUF`) |
| `hermes_model_provider` | Hermes provider for LM Studio (default `custom`) |
| `hermes_model_api_key` | LM Studio API token when auth is on; use `lm-studio` when auth is off |
| `hermes_model_context_length` | Context window for Hermes and `lms load --context-length` (default `65536`; Hermes minimum is `64000`) |
| `tracked_stocks` | Tickers for investment skill |
| `firecrawl_init_all` / `firecrawl_verify_install` | Firecrawl setup in `~/.hermes/workspace` |

Secrets stay in `vars.yml` (gitignored). Templates generate `~/.hermes/config.yaml` and `~/.hermes/.env`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Gateway not running (macOS) | Run `bash scripts/diagnose_gateway.sh vars.yml` · restart: `./start_gateway.sh` · check process: `pgrep -fl "hermes.*gateway run"` · LaunchAgent: `launchctl print gui/$(id -u)/com.hermes.gateway` or `user/$(id -u)/com.hermes.gateway` · logs: `~/.hermes/logs/gateway.stderr.log` |
| LaunchAgent not loaded (macOS) | Run `./start_gateway.sh` (redeploys plist + bootstrap). Manual: `scripts/macos_launchd_gateway.sh start ~` |
| Gateway process up, LaunchAgent down | Detached fallback — gateway works but won't auto-restart. Re-run `./start_gateway.sh` or accept manual restarts |
| `gateway.stderr.log` missing | LaunchAgent never started the job. Run `./start_gateway.sh`, then check logs again |
| Hermes CLI not found | Run `deploy_hermes.yml` first; check `~/.local/bin/hermes` |
| Skill playbook fails | Core deploy must run first — use `deploy_local.sh` / `deploy_all.sh` |
| `invalid choice: 'workspace'` | Pull latest playbooks (CLI commands changed) |
| LM Studio 401 / auth errors | Enable token in LM Studio Developer → Require Authentication → Manage Tokens; set matching value in `hermes_model_api_key` |
| `lms get` garbled output / deploy fails at model download | Playbooks download via Hugging Face URL: `lms get https://huggingface.co/lmstudio-community/gemma-4-12B-it-GGUF --gguf --yes`. Log: `~/.hermes/logs/lms-get.log` |
| Deploy stuck on `lms load` | Playbooks wait for `lms load --yes` to exit (poll every 30s) and match loaded models via `path`, `modelKey`, `identifier`, and `indexedModelIdentifier`. Log: `~/.hermes/logs/lms-load.log`. First load of a 12B GGUF model can take 5–15 min |
| `Model not found` / `lms load` fails | Re-run `./deploy_local.sh`. Playbooks run `lms get --gguf --yes`, poll disk with `lms ls --json --llm` (falls back to `--variants`), extract exact `path` values for `lms load`, and accept download hints from `~/.hermes/logs/lms-get.log`. Logs: `lms-get.log`, `lms-load.log` |
| `lms: command not found` in your shell | Deploy installs `~/.hermes/bin/lms` on PATH for playbooks; for interactive use run `source ~/.hermes/bin/lmstudio-path.sh` (or `export PATH="$HOME/.hermes/bin:$HOME/.cache/lm-studio/bin:$PATH"`) |
| `Failed to resolve artifact lmstudio-community/gemma-4-e2b-...` | LM Studio's artifact resolver mis-picked a staff model. Set `lmstudio_model_download_url` to the full Hugging Face repo (e.g. `https://huggingface.co/lmstudio-community/gemma-4-12B-it-GGUF`). Re-run `./deploy_local.sh` |
| Gemma 4 load fails | Update LM Studio to latest. See [lmstudio.ai/models/gemma-4](https://lmstudio.ai/models/gemma-4) |
| Digest smoke test fails | Ensure LM Studio is running (`lms server status` or `curl http://127.0.0.1:1234/v1/models`). Re-run `./deploy_local.sh` so `~/.hermes/config.yaml` has `model.provider: custom`, `model.base_url` for LM Studio, and `model.context_length` ≥ 64000. Sync stops the Hermes gateway first so a running gateway cannot revert config. If the model was loaded with a 4K default context, run `lms unload` then `lms load <model> --context-length 65536 --yes`. Check logs in `~/.hermes/logs/` |
| `Context length exceeded (N tokens). Cannot compress further.` with small N (~6K) | LM Studio context alone does not fix this — Hermes uses `~/.hermes/config.yaml`. If that file still points at Ollama (`11434`) or has no `context_length`, re-run `./deploy_local.sh` or the digest smoke test to sync from `vars.yml`. Set `hermes_model_context_length` to match `lms load --context-length`, then `lms unload && lms load <model> --context-length <same> --yes` |
| `Model not found` on manual `lms load` | LM Studio model keys are case-sensitive. Your unload output shows the exact key (e.g. `google/gemma-4-12b@q4_k_m`, not `@Q4_K_M`). Run `lms ls` or `lms load` without `--yes` to pick interactively. `./deploy_local.sh` tries all disk paths/keys automatically |
| `context window ... below the minimum 64,000` | LM Studio loaded the model with a 4K default. Set `hermes_model_context_length: 65536` in `vars.yml`, re-run deploy or the smoke test (syncs `~/.hermes/config.yaml` with `model.context_length`), then reload: `lms unload && lms load <model> --context-length 65536 --yes` |
| LM Studio / gateway smoke test fails | Run `./test_lmstudio_gateway.sh` — see [LM Studio and gateway](#lm-studio-and-gateway). Start LM Studio, load the model from `vars.yml`, then `./start_gateway.sh` if the gateway is down |
| `no API keys or providers found` | Hermes needs `~/.hermes/config.yaml` (not just `.env`). Re-deploy or run the smoke test playbook — it syncs config from `vars.yml`. For LM Studio, `model.provider` must be `custom` with `base_url: http://127.0.0.1:1234/v1` and a non-empty `api_key` |
| macOS job not firing | `launchctl list \| grep hermes` · reload plist after re-deploy |

**Hugging Face token:** Only needed if you download gated models from Hugging Face. Public LM Studio staff picks (e.g. in `vars.example..yml`) do not require a token.

## Project layout

```
deploy_hermes.yml          deploy_investment.yml    deploy_news.yml    deploy_digest.yml
deploy_local.sh            deploy_all.sh            start_gateway.sh   start_gateway.yml
test_telegram.sh           test_lmstudio_gateway.sh test_hermes_daily_digest.sh
smoke_test_telegram.yml    smoke_test_lmstudio_gateway.yml smoke_test_hermes_daily_digest.yml
scripts/diagnose_gateway.sh    scripts/macos_launchd_gateway.sh    scripts/read_hermes_start_agents.sh
tasks/resolve_hermes_cmd.yml    tasks/sync_hermes_config.yml    tasks/start_hermes_gateway.yml    tasks/diagnose_hermes_gateway.yml    tasks/bootstrap_lmstudio.yml    tasks/lmstudio_cli_environment.yml    tasks/parse_lmstudio_disk_listing.yml    tasks/ensure_lmstudio_server.yml    tasks/ensure_lmstudio_model.yml    tasks/ensure_lmstudio_load.yml    tasks/verify_lmstudio_model_on_disk.yml    tasks/read_lmstudio_get_log_tail.yml    templates/*.j2    vars.yml (from vars.example..yml)
```
