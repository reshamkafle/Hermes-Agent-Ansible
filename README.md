# Hermes Agent Ansible

Ansible playbooks to deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) on Linux or macOS — either on a **remote host** over SSH or on **this machine** (localhost). The setup installs Ollama, configures Hermes with Firecrawl and Telegram, and schedules automated skills for stock tracking, tech news, and a daily HTML digest.

## What it deploys

| Playbook | Purpose |
|----------|---------|
| `deploy_hermes.yml` | Core install: Ollama, Hermes CLI, home dirs, config, and `.env` |
| `deploy_investment.yml` | Midnight stock watchlist reports |
| `deploy_news.yml` | 5 AM IT/AI news digest |
| `deploy_digest.yml` | 6 AM combined Bootstrap HTML briefing via Telegram |

Playbooks run in that order when you use `deploy_local.sh` or `deploy_all.sh`. Run `deploy_hermes.yml` first — the skill playbooks expect `~/.hermes/` to already exist.

## Project layout

```
.
├── deploy_hermes.yml          # Core Hermes + Ollama install
├── deploy_investment.yml      # Investment skill + scheduler
├── deploy_news.yml            # Tech news skill + scheduler
├── deploy_digest.yml          # Daily digest skill + scheduler
├── deploy_local.sh            # Run all playbooks on this machine
├── deploy_all.sh              # Run all playbooks on remote hosts
├── test_telegram.sh           # Telegram smoke test (no Hermes install)
├── tasks/
│   └── resolve_hermes_cmd.yml # Shared Hermes CLI path resolver
├── templates/
│   ├── hermes.config.yaml.j2
│   ├── hermes.env.j2
│   ├── com.hermes.investment.plist.j2   # macOS midnight job
│   ├── com.hermes.technews.plist.j2     # macOS 5 AM job
│   └── com.hermes.dailydigest.plist.j2  # macOS 6 AM job
└── vars.yml                   # Your secrets (copy from vars.example..yml)
```

## Prerequisites

- `ansible-playbook` installed
- `vars.yml` configured (copy from `vars.example..yml`)
- API keys for Telegram and Firecrawl

**Remote deploy** (`deploy_all.sh`):

- SSH access to a remote host
- `inventory.ini` listing that host (copy from `inventory.example.ini`)

**Local deploy** (`deploy_local.sh`):

- No inventory or SSH required
- macOS: [Homebrew](https://brew.sh/) installed (playbooks install Ollama, git, node, and tmux via brew)

## Setup

1. Copy and edit `vars.yml`:

```bash
cp vars.example..yml vars.yml
```

Fill in your Ollama model, Telegram IDs, Firecrawl key, and stock tickers.

2. For **remote** deploy only, copy and edit the inventory:

```bash
cp inventory.example.ini inventory.ini
```

Replace the example host with your server IP or hostname and SSH user. Do **not** use `localhost` or `127.0.0.1` — `deploy_all.sh` refuses to run without a remote target.

### macOS vs Linux paths

| Setting | Linux / WSL2 | macOS (local deploy) |
|---------|----------------|----------------------|
| `hermes_user` | Used (`hermes` system user) | Ignored — uses your login user |
| `hermes_home` | Used (`/home/hermes`) | Ignored — uses `~/` |
| Hermes config | `/home/hermes/.hermes/` | `~/.hermes/` |
| Skills | `/home/hermes/.hermes/skills/` | `~/.hermes/skills/` |
| Skill data / reports | `/home/hermes/.hermes/workspace/` | `~/.hermes/workspace/` |
| Scheduler | cron | LaunchAgents in `~/Library/LaunchAgents/` |

On macOS, the Hermes installer typically places the CLI at `~/.local/bin/hermes`, which is not always on your shell PATH. All playbooks resolve the binary automatically — you do not need to add it to PATH manually.

## Hermes CLI path resolution

Every playbook uses `tasks/resolve_hermes_cmd.yml` to find the Hermes binary before running any commands. It checks, in order:

1. `~/.local/bin/hermes` (default macOS install location)
2. `/opt/homebrew/bin/hermes` (Apple Silicon Homebrew)
3. `/usr/local/bin/hermes` (Intel Mac / Linux)
4. `command -v hermes` with an expanded PATH

Only `deploy_hermes.yml` installs Hermes if none of those locations have the binary (via `https://hermes-agent.nousresearch.com/install.sh`). The skill playbooks (`deploy_investment.yml`, `deploy_news.yml`, `deploy_digest.yml`) look up the path but do not install — run the core playbook first.

Resolved paths are used for:

- `hermes postinstall` (bootstrap after install)
- `hermes gateway run` (background messaging daemon)
- `hermes chat --skills …` (scheduled skill runs)
- Linux cron jobs
- macOS LaunchAgent plists (`com.hermes.*.plist`)

### Hermes CLI commands used by these playbooks

| Task | Command |
|------|---------|
| Bootstrap home dirs | Ansible creates `~/.hermes/{skills,workspace,logs}` |
| Post-install deps | `hermes postinstall` |
| Start gateway (Linux) | `hermes gateway run` via `hermes-workspace.service` |
| Start gateway (macOS) | `hermes gateway run` in tmux session `hermes_ws` |
| Run a scheduled skill | `hermes chat -Q -q 'Run the … skill according to its instructions.' --skills <name> --yolo` |

## Telegram smoke test

Verify your bot token and chat IDs before deploying. This runs on your control machine only and does **not** install Hermes or SSH to remote hosts.

`test_telegram.sh` reads `vars.yml` and exports the same `TELEGRAM_*` environment variables used by Hermes (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_HOME_CHANNEL`, `TELEGRAM_ALLOWED_USERS`, `TELEGRAM_SEND_USERS`), then runs the smoke test playbook:

```bash
chmod +x test_telegram.sh
./test_telegram.sh
```

Set `telegram_bot_token` and at least one of `telegram_chat_id` or `telegram_allowed_users` in `vars.yml`. You should receive a short confirmation message in Telegram.

## Run

### Local (this machine)

Deploy all playbooks to localhost (gateway stays stopped by default):

```bash
chmod +x deploy_local.sh
./deploy_local.sh
```

To also start the Hermes gateway after deploy:

```bash
START_HERMES_AGENTS=1 ./deploy_local.sh
```

This passes `-e hermes_start_agents=true` to the playbooks (overriding the default in `vars.yml`).

On macOS, the gateway runs in a tmux session named `hermes_ws`. Attach with:

```bash
tmux attach -t hermes_ws
```

### Remote (SSH)

Deploy all playbooks to hosts in `inventory.ini` (gateway stays stopped by default):

```bash
chmod +x deploy_all.sh
./deploy_all.sh
```

Use a custom inventory file:

```bash
INVENTORY=hosts.ini ./deploy_all.sh
```

To also start the Hermes gateway after deploy:

```bash
START_HERMES_AGENTS=1 ./deploy_all.sh
```

### Single playbook

Remote:

```bash
ansible-playbook -i inventory.ini deploy_hermes.yml -e hermes_start_agents=false
```

Local:

```bash
ansible-playbook -i 'localhost,' -c local -e ansible_become=false deploy_hermes.yml -e hermes_start_agents=false
```

| Script | Target |
|--------|--------|
| `deploy_local.sh` | This machine only (`localhost`) |
| `deploy_all.sh` | Remote hosts only (refuses localhost) |

## Configuration

Secrets live in `vars.yml` (gitignored). Shared templates in `templates/` generate `~/.hermes/config.yaml` and `~/.hermes/.env` on the target host.

| Variable | Purpose |
|----------|---------|
| `hermes_start_agents` | Start the Hermes gateway after deploy (default: `false`; set via `START_HERMES_AGENTS=1` in deploy scripts) |
| `firecrawl_init_all` | Install Firecrawl npm package in `~/.hermes/workspace` |
| `firecrawl_verify_install` | Verify Firecrawl after install |
| `ollama_model` | Local LLM model to pull via Ollama |
| `tracked_stocks` | Tickers for the investment skill |

Set `hermes_start_agents: false` in `vars.yml` to deploy config and scheduled jobs without starting the gateway. Use `START_HERMES_AGENTS=1 ./deploy_local.sh` (or `deploy_all.sh`) when you want the gateway started regardless of `vars.yml`.

## Scheduled jobs

| Skill | Schedule | Linux (cron) | macOS (LaunchAgent) |
|-------|----------|--------------|---------------------|
| Investment tracker | Midnight | `hermes chat … --skills stock-investment-tracker` | `com.hermes.investment.plist` |
| Tech news | 5:00 AM | `hermes chat … --skills tech-news-intelligence` | `com.hermes.technews.plist` |
| Daily digest | 6:00 AM | `hermes chat … --skills daily-morning-digest` | `com.hermes.dailydigest.plist` |

macOS logs are written to `~/.hermes/logs/`. On Linux, check gateway status with `systemctl status hermes-workspace`.

## Troubleshooting

### `Hermes CLI not found`

The resolver checked all known install paths and PATH. Try:

1. Run the core playbook first: `./deploy_local.sh` (or `deploy_hermes.yml` alone)
2. Confirm the binary exists: `ls -la ~/.local/bin/hermes`
3. Re-run deploy — `deploy_hermes.yml` will run the official installer if Hermes is missing

### `invalid choice: 'workspace'`

Older versions of these playbooks used removed CLI subcommands (`hermes workspace init`, `sync`, `start`, `run`). Pull the latest playbooks — they now use `hermes postinstall`, `hermes gateway run`, and `hermes chat --skills`.

### Skill playbook fails after core deploy

Skill playbooks do not install Hermes. Always run `deploy_hermes.yml` before `deploy_investment.yml`, `deploy_news.yml`, or `deploy_digest.yml`. Using `deploy_local.sh` or `deploy_all.sh` handles the order automatically.

### macOS LaunchAgent not firing

Check logs:

```bash
cat ~/.hermes/logs/dailydigest.stderr.log
launchctl list | grep hermes
```

Reload a plist after re-deploy:

```bash
launchctl unload ~/Library/LaunchAgents/com.hermes.dailydigest.plist
launchctl load -w ~/Library/LaunchAgents/com.hermes.dailydigest.plist
```
