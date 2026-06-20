# Hermes Agent Ansible

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) on Linux or macOS — locally or over SSH.

* **Automated**: Ansible playbooks install LM Studio, Hermes CLI, config, and scheduled skills
* **Local LLM**: downloads and loads your GGUF model via LM Studio (llmster)
* **Telegram**: stock watchlist, tech news, gold trend, and morning digest
* **Gateway**: LaunchAgent on macOS, systemd on Linux — auto-starts after deploy

---

## Install

```bash
cp vars.example..yml vars.yml          # edit secrets (Telegram, Firecrawl, model)
cp inventory.example.ini inventory.ini   # remote deploy only
chmod +x deploy_local.sh deploy_all.sh
./deploy_local.sh                        # this machine
# ./deploy_all.sh                        # remote host (needs inventory.ini)
```

Gateway starts when `hermes_start_agents: true` in `vars.yml` (default). Skip with `hermes_start_agents: false` or `START_HERMES_AGENTS=0 ./deploy_local.sh`.

## Restart gateway

```bash
chmod +x start_gateway.sh
./start_gateway.sh
```

## Smoke tests (optional)

```bash
./test_telegram.sh                 # before deploy
./test_lmstudio_gateway.sh         # after deploy
./test_hermes_daily_digest.sh      # full digest (slow on local LLM)
```

---

## Documentation

| Topic | |
|-------|---|
| [Gateway & diagnostics](docs/gateway.md) | start, diagnose, macOS launchd |
| [Smoke tests](docs/smoke-tests.md) | Telegram, LM Studio, daily digest |
| [Configuration](docs/configuration.md) | playbooks, vars, schedules, platform |
| [Troubleshooting](docs/troubleshooting.md) | common errors and fixes |
