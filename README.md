# openshell-stuffs

My OpenShell profiles and scripts - network-proxy profiles for AI/inference endpoints, plus helpers to import, create providers for, and clean them up from OpenShell.

## What's inside

| Directory | Contents |
|-----------|----------|
| `profiles/` | OpenShell profile YAML files (one per inference provider / gateway). See [Included profiles](#included-profiles). |
| `scripts/` | Bash helpers to generate and run `openshell` commands. See [Scripts](#scripts). |
| `config/gateway.toml.example` | Example OpenShell gateway config. |

## Quick start

1. **Install OpenShell** (if you haven't already) and make sure the `openshell` CLI is on your PATH.

2. **Configure the gateway** (example):

   ```bash
   cp config/gateway.toml.example ~/.config/openshell/gateway.toml
   # edit ~/.config/openshell/gateway.toml to match your setup
   ```

3. **Import the profiles** into OpenShell:

   ```bash
   ./scripts/import_profiles.sh
   # or run them directly:
   ./scripts/import_profiles.sh --execute
   ```

4. **Create providers** for the profiles whose API keys are set in your environment:

   ```bash
   export OPENAI_API_KEY=sk-...
   export ANTHROPIC_API_KEY=sk-ant-...
   ./scripts/create_providers.sh --execute
   ```

   Commands whose credential env var isn't set are skipped (shown commented-out in dry-run mode).

5. **Use OpenShell** - route `curl`, `opencode`, etc. through the configured gateway/providers.

6. **Clean up** when you're done (dry-run first, then execute):

   ```bash
   ./scripts/cleanup.sh               # dry-run: show delete commands
   ./scripts/cleanup.sh --execute     # delete providers first, then profiles
   ```

## Scripts

All scripts live in `scripts/` and default to reading profiles from `profiles/` (overridable with `$PROFILE_DIR`).

### `import_profiles.sh`

Generates `openshell profile import --file <profile.yaml>` commands for every `profile-*.yaml` file.

```bash
# Dry-run: print the import commands (nothing is changed)
./scripts/import_profiles.sh

# Save to a file for review
./scripts/import_profiles.sh > import_profiles.txt

# Execute: print and run the imports
./scripts/import_profiles.sh --execute
```

### `create_providers.sh`

Generates `openshell provider create --name <provider> --type <type> [--credential <env>]` commands, one per profile.

The credential flag is only added when the profile declares an env var, and the command is **skipped** if that env var isn't set in your environment:

- **Dry-run (default):** the command is printed commented out, with an inline skip reason (`# skipped: environment variable ... is not set`).
- **`--execute` mode:** a warning is shown and execution continues to the next command - one missing env var never aborts the whole run.

In short: **if the related system environment variable is not found, the provider is not created.** Set the key first, then re-run.

```bash
# Dry-run: print commands (missing env vars are commented out with a skip reason)
./scripts/create_providers.sh

# Set keys first, then execute only the ones whose keys are present
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
./scripts/create_providers.sh --execute
```

### `cleanup.sh`

Removes OpenShell providers and profiles (not the local YAML files). Providers are deleted before profiles (dependency order). Dry-run by default.

```bash
# Dry-run: show provider delete + profile delete commands
./scripts/cleanup.sh

# Platform-scoped dry-run
./scripts/cleanup.sh --global

# Execute: delete providers first, then profiles
./scripts/cleanup.sh --execute

# Execute platform-scoped
./scripts/cleanup.sh --global --execute
```

## Configuration

### `config/gateway.toml.example`

An example OpenShell gateway config using the podman compute driver:

```toml
[openshell]
version = 2

[openshell.gateway]
compute_driver = "podman"

[openshell.drivers.podman]
network_name = "openshell"
allow_driver_config = true
```

Copy it to your OpenShell config location (e.g. `~/.config/openshell/gateway.toml`) and adjust `network_name` / driver settings for your environment.

## Included profiles

These profiles grant OpenShell access to inference endpoints. Each `profile-<host>.yaml` declares the endpoint host/port, required credentials (API key env vars), allowed binaries, and enforcement rules.

### Provider profiles

| Profile file | Endpoint | Credential env var | Notes |
|--------------|----------|--------------------|-------|
| `profile-api.anthropic.com.yaml` | api.anthropic.com:443 | `ANTHROPIC_API_KEY` | Anthropic |
| `profile-api.cerebras.ai.yaml` | api.cerebras.ai:443 | (varies) | Cerebras |
| `profile-api.cohere.ai.yaml` | api.cohere.ai:443 | (varies) | Cohere |
| `profile-api.deepinfra.com.yaml` | api.deepinfra.com:443 | (varies) | DeepInfra |
| `profile-api.deepseek.com.yaml` | api.deepseek.com:443 | (varies) | DeepSeek |
| `profile-api.fireworks.ai.yaml` | api.fireworks.ai:443 | (varies) | Fireworks |
| `profile-api.groq.com.yaml` | api.groq.com:443 | (varies) | Groq |
| `profile-api.jina.ai.yaml` | api.jina.ai:443 | (varies) | Jina AI |
| `profile-api.mistral.ai.yaml` | api.mistral.ai:443 | (varies) | Mistral |
| `profile-api.novita.ai.yaml` | api.novita.ai:443 | (varies) | Novita |
| `profile-api.openai.com.yaml` | api.openai.com:443 | `OPENAI_API_KEY` | OpenAI |
| `profile-api.perplexity.ai.yaml` | api.perplexity.ai:443 | (varies) | Perplexity |
| `profile-api.siliconflow.cn.yaml` | api.siliconflow.cn:443 | (varies) | SiliconFlow |
| `profile-api.together.xyz.yaml` | api.together.xyz:443 | (varies) | Together |
| `profile-api.typesafe.ai.yaml` | api.typesafe.ai:443 | (varies) | Typesafe |
| `profile-api.x.ai.yaml` | api.x.ai:443 | (varies) | xAI |
| `profile-generativelanguage.googleapis.com.yaml` | generativelanguage.googleapis.com:443 | `GEMINI_API_KEY` / `GOOGLE_API_KEY` | Google Gemini |
| `profile-integrate.api.nvidia.com.yaml` | integrate.api.nvidia.com:443 | (varies) | NVIDIA |
| `profile-openrouter.ai.yaml` | openrouter.ai:443 | `OPENROUTER_API_KEY` | OpenRouter |

### Gateway profiles

| Profile file | Endpoint | Notes |
|--------------|----------|-------|
| `profile-host.docker.internal.yaml` | host.docker.internal:20128 | Local gateway via Docker host |
| `profile-host.openshell.internal.yaml` | host.openshell.internal:20128 | Local gateway via OpenShell internal DNS |

### Agent sandbox profile

| Profile file | Endpoint | Credential env var | Notes |
|--------------|----------|--------------------|-------|
| `omniroute-agent.yaml` | host.openshell.internal:20128 | `OMNIROUTE_API_KEY` | Agent sandbox (opencode, curl, node, claude) that reaches **only** the OmniRoute gateway. Upstream provider keys never enter this sandbox. |

## Use examples

### Example 1: Call OpenAI through OpenShell with curl

Import the OpenAI profile and create a provider (requires `OPENAI_API_KEY`):

```bash
export OPENAI_API_KEY=sk-...
./scripts/import_profiles.sh --execute
./scripts/create_providers.sh --execute | grep openai
```

Then route a request through the OpenShell gateway:

```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Hello"}]}'
```

OpenShell enforces the profile: only the `api.openai.com` endpoint is reachable, and only the listed binaries (`omniroute`, `node`, `curl`) may use it.

### Example 2: Restrict an agent sandbox to the OmniRoute gateway only

The `omniroute-agent.yaml` profile lets an agent sandbox (e.g. OpenCode) call the OmniRoute gateway via `OMNIROUTE_API_KEY`, but blocks every provider endpoint:

```bash
export OMNIROUTE_API_KEY=omni-...
./scripts/import_profiles.sh --execute  # imports omniroute-agent.yaml too
./scripts/create_providers.sh --execute # skipped unless OMNIROUTE_API_KEY is set
```

Allowed binaries (`opencode`, `node`, `claude`, `curl`) can reach `host.openshell.internal:20128/v1/**` only. Any request to a provider endpoint (OpenAI, Anthropic, etc.) is blocked by `enforcement: enforce`.

### Example 3: Onboard a new provider

1. Add a new `profile-api.<host>.yaml` to `profiles/` following the existing pattern (see `profile-api.openai.com.yaml`).
2. Import it:

   ```bash
   ./scripts/import_profiles.sh --execute
   ```

3. Set its API key in your environment, then create the provider:

   ```bash
   export NEWPROVIDER_API_KEY=...
   ./scripts/create_providers.sh --execute
   ```

   The command for the new provider is generated automatically; it runs only if the corresponding env var is set.

### Example 4: Tear everything down

Dry-run first to review, then execute:

```bash
./scripts/cleanup.sh               # review provider + profile delete commands
./scripts/cleanup.sh --execute     # delete providers, then profiles
```

Use `--global` to target platform-scoped providers/profiles instead of user-scoped ones.

## Profile file anatomy

Each profile YAML declares:

- `id` / `display_name` / `description` - identifying metadata.
- `category` / `inference_capable` - profile type (typically `inference: true`).
- `credentials` - name, description, `env_vars`, `required`, `auth_style`, `header_name`.
- `endpoints` - host, port, path, protocol, access, enforcement, and which credentials apply.
- `binaries` - which binaries are allowed to use this profile.

See any file in `profiles/` for a concrete example.

## License

MIT - see `LICENSE`.
