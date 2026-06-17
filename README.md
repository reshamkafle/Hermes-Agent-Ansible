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

On macOS, check the gateway: `launchctl print gui/$(id -u)/com.hermes.gateway`

To skip the gateway during deploy: set `hermes_start_agents: false` in `vars.yml`, or `START_HERMES_AGENTS=0 ./deploy_local.sh`

## Start gateway only

If you already deployed and only need the gateway (or it stopped and you want to restart it):

```bash
chmod +x start_gateway.sh scripts/diagnose_gateway.sh && ./start_gateway.sh
```

`start_gateway.sh` runs Ansible to restart the gateway, then prints a **diagnostics report** automatically. You may also get a Telegram message *"Gateway shutting down — Your current task will be interrupted"* during the restart — that is expected (the old process stops before the new one starts).

Then check it:

```bash
# macOS — LaunchAgent (auto-restarts on failure)
launchctl print gui/$(id -u)/com.hermes.gateway
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
| Recent logs | `~/.hermes/logs/gateway.stderr.log` | `journalctl -u hermes-workspace` |

Exit code `0` = healthy; `1` = at least one check failed (with fix hints in the output).

`./start_gateway.sh` runs this script automatically after Ansible on localhost. Ansible also writes the same report to `~/.hermes/logs/gateway-diagnostics.txt` during `start_gateway.yml`.

For the same checks plus verification that your configured LM Studio model is listed, use the [LM Studio and gateway smoke test](#lm-studio-and-gateway).

**Common causes when diagnostics fail**

- **LM Studio not running** — config points at `lmstudio_base_url` (default `http://127.0.0.1:1234/v1`). Run `lms daemon up`, `lms server start`, then `lms get <model>`.
- **Gateway crash on startup** — read the stderr tail in the report or `~/.hermes/logs/gateway.stderr.log`.
- **Not logged into the Mac GUI** — `com.hermes.gateway` uses `LimitLoadToSessionType Aqua`; SSH-only sessions cannot load the LaunchAgent.


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
| LLM model | GGUF via `lmstudio_model_linux` | MLX via `lmstudio_model` |
| LLM service | systemd (`llmster`) | `lms daemon up` + `lms server start` |
| Scheduler | cron | LaunchAgents in `~/Library/LaunchAgents/` |
| Gateway | systemd (`hermes-workspace`) | LaunchAgent (`com.hermes.gateway`) |

Playbooks auto-find the Hermes CLI (`~/.local/bin/hermes`, Homebrew paths, or PATH). Only `deploy_hermes.yml` installs Hermes if missing.

## Scheduled jobs

| Skill | Time | macOS plist |
|-------|------|-------------|
| Stock tracker | Midnight | `com.hermes.investment.plist` |
| Tech news | 5 AM | `com.hermes.technews.plist` |
| Daily digest | 6 AM | `com.hermes.dailydigest.plist` |

Logs: `~/.hermes/logs/` · macOS gateway: `launchctl print gui/$(id -u)/com.hermes.gateway` · Linux gateway: `systemctl status hermes-workspace`

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
| LaunchAgent loaded | `com.hermes.gateway` | — |
| GUI session (Aqua) for LaunchAgent | yes | — |

Exit code `0` = all checks passed; `1` = at least one failed. On failure, the playbook prints the full gateway diagnostic report and writes `~/.hermes/logs/gateway-diagnostics.txt`.

**If it fails**

- **LM Studio not reachable** — start the server and load the model (commands above). Confirm with `curl http://127.0.0.1:1234/v1/models` (or your `lmstudio_base_url`).
- **Model not listed** — run `lms get` and `lms load` for the model in `vars.yml`.
- **Gateway not running** — run `./start_gateway.sh` or `bash scripts/diagnose_gateway.sh vars.yml`.
- **macOS LaunchAgent missing** — log in to the Mac desktop (not SSH-only); `com.hermes.gateway` requires an Aqua GUI session.

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
| `lmstudio_model` | MLX model for macOS — use a full repo path (e.g. `lmstudio-community/gemma-4-12B-it-MLX-4bit`); short aliases like `google/gemma-4-12b` can mis-resolve via `lms get --mlx` |
| `lmstudio_model_linux` | GGUF model for Linux/WSL2 — set in `vars.yml` |
| `lmstudio_base_url` | LM Studio OpenAI-compatible API URL (default `http://127.0.0.1:1234/v1`) |
| `lmstudio_server_port` | Port for `lms server start` (default `1234`) |
| `lmstudio_download_model` | Run `lms get --yes` during deploy (default `true`; skips if model already on disk) |
| `lmstudio_model_download_url` | Optional override; defaults to `https://huggingface.co/<lmstudio_model>` for org/repo IDs |
| `hermes_model_provider` | Hermes provider for LM Studio (default `custom`) |
| `hermes_model_api_key` | LM Studio API token when auth is on; use `lm-studio` when auth is off |
| `tracked_stocks` | Tickers for investment skill |
| `firecrawl_init_all` / `firecrawl_verify_install` | Firecrawl setup in `~/.hermes/workspace` |

Secrets stay in `vars.yml` (gitignored). Templates generate `~/.hermes/config.yaml` and `~/.hermes/.env`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Gateway not running (macOS) | Run `bash scripts/diagnose_gateway.sh vars.yml` · ensure `~/.hermes/logs/` exists · check `launchctl print gui/$(id -u)/com.hermes.gateway` · logs: `~/.hermes/logs/gateway.stderr.log` · restart: `./start_gateway.sh` |
| Hermes CLI not found | Run `deploy_hermes.yml` first; check `~/.local/bin/hermes` |
| Skill playbook fails | Core deploy must run first — use `deploy_local.sh` / `deploy_all.sh` |
| `invalid choice: 'workspace'` | Pull latest playbooks (CLI commands changed) |
| LM Studio 401 / auth errors | Enable token in LM Studio Developer → Require Authentication → Manage Tokens; set matching value in `hermes_model_api_key` |
| `lms get` garbled output / deploy fails at model download | Playbooks download via Hugging Face URL: `lms get https://huggingface.co/<org>/<repo> --yes`. Log: `~/.hermes/logs/lms-get.log` |
| `Failed to resolve artifact lmstudio-community/gemma-4-e2b-...` | LM Studio's artifact resolver mis-picked a staff model. Playbooks now download via `https://huggingface.co/<org>/<repo>`. Re-run `./deploy_local.sh` or run `lms get https://huggingface.co/lmstudio-community/gemma-4-12B-it-MLX-4bit --yes` manually |
| Gemma 4 MLX load fails | Update LM Studio to latest; Gemma 4 needs recent mlx-engine. See [lmstudio.ai/models/gemma-4](https://lmstudio.ai/models/gemma-4) |
| Digest smoke test fails | Ensure LM Studio is running (`lms server status` or `curl http://127.0.0.1:1234/v1/models`). Re-run `./deploy_local.sh` so `~/.hermes/config.yaml` has `model.provider: custom` and `model.base_url` for LM Studio. Check logs in `~/.hermes/logs/` |
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
scripts/diagnose_gateway.sh    scripts/read_hermes_start_agents.sh
tasks/resolve_hermes_cmd.yml    tasks/sync_hermes_config.yml    tasks/start_hermes_gateway.yml    tasks/diagnose_hermes_gateway.yml    tasks/ensure_lmstudio_model.yml    templates/*.j2    vars.yml (from vars.example..yml)
```
