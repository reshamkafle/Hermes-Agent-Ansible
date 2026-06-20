# Configuration

## Prerequisites

| | Local (`deploy_local.sh`) | Remote (`deploy_all.sh`) |
|--|---------------------------|--------------------------|
| Required | `ansible-playbook`, `vars.yml` | + SSH, `inventory.ini` |
| macOS | [Homebrew](https://brew.sh/) (git, node) | Same |
| Linux | `libatomic1` (installed by playbook) | Same |
| API keys | Telegram + Firecrawl | Same |

## Playbooks

Run in order (`deploy_local.sh` / `deploy_all.sh` do this automatically):

| Playbook | Purpose |
|----------|---------|
| `deploy_hermes.yml` | Core: LM Studio, Hermes CLI, config, `.env` |
| `deploy_investment.yml` | Midnight stock watchlist |
| `deploy_news.yml` | 5 AM IT/AI news digest |
| `deploy_gold.yml` | 5:30 AM gold 7-day trend |
| `deploy_digest.yml` | 6 AM combined Telegram briefing |

Run `deploy_hermes.yml` first — skill playbooks expect `~/.hermes/`.

## Run one playbook

```bash
# Local
ansible-playbook -i 'localhost,' -c local -e ansible_become=false deploy_hermes.yml

# Remote
ansible-playbook -i inventory.ini deploy_hermes.yml
```

Custom inventory: `INVENTORY=hosts.ini ./deploy_all.sh`

## macOS vs Linux

| | Linux / WSL2 | macOS |
|--|--------------|-------|
| Home | `/home/hermes` | `~/` |
| Config | `/home/hermes/.hermes/` | `~/.hermes/` |
| Model var | `lmstudio_model_linux` | `lmstudio_model` |
| LLM service | systemd (`llmster`) | `lms daemon up` + `lms server start` |
| Scheduler | cron | LaunchAgents in `~/Library/LaunchAgents/` |
| Gateway | systemd (`hermes-workspace`) | LaunchAgent (`com.hermes.gateway`) |

## Scheduled jobs

| Skill | Time | macOS plist |
|-------|------|-------------|
| Stock tracker | Midnight | `com.hermes.investment.plist` |
| Tech news | 5 AM | `com.hermes.technews.plist` |
| Gold trend | 5:30 AM | `com.hermes.gold.plist` |
| Daily digest | 6 AM | `com.hermes.dailydigest.plist` |

Logs: `~/.hermes/logs/`

## Key `vars.yml` settings

| Variable | Purpose |
|----------|---------|
| `hermes_start_agents` | Start gateway after deploy (default `true`) |
| `lmstudio_model` / `lmstudio_model_linux` | GGUF model key (default `google/gemma-4-12b@q4_k_m`) |
| `lmstudio_base_url` | LM Studio API URL (default `http://127.0.0.1:1234/v1`) |
| `lmstudio_download_model` / `lmstudio_load_model` | Auto get/load during deploy (default `true`) |
| `lmstudio_model_download_url` | Hugging Face repo for `lms get --gguf` |
| `hermes_model_api_key` | LM Studio token; use `lm-studio` when auth is off |
| `hermes_model_context_length` | Context window (default `65536`; Hermes min `64000`) |
| `tracked_stocks` | Tickers for investment skill |
| `tracked_gold_instruments` | Gold ETFs/benchmarks (e.g. GLD, IAU, XAUUSD) |
| `firecrawl_init_all` / `firecrawl_verify_install` | Firecrawl setup in workspace |

Secrets stay in `vars.yml` (gitignored). Templates generate `~/.hermes/config.yaml` and `~/.hermes/.env`.

See `vars.example..yml` for all options.

## Project layout

```
deploy_*.yml          deploy_local.sh / deploy_all.sh    start_gateway.sh
test_*.sh             smoke_test_*.yml
scripts/              tasks/                             templates/
vars.yml              inventory.ini (from examples)
```
