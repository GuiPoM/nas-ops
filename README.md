# nas-ops

Maintenance and update scripts for NAS running Debian / OpenMediaVault 8.

Handles system updates (`apt`) and Docker updates (`docker compose`), with two modes:
- **Interactive terminal**: colored output, confirmations
- **Non-interactive** (Home Assistant, cron): JSON output

## Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GuiPoM/nas-ops/main/install.sh)
```

To install a published branch for testing, set `NAS_OPS_BRANCH` and fetch the installer from the same branch:

```bash
NAS_OPS_BRANCH=feat/compatibility-and-docker-dedup bash <(curl -fsSL https://raw.githubusercontent.com/GuiPoM/nas-ops/feat/compatibility-and-docker-dedup/install.sh)
```

After installation, verify the branch on the NAS with the normal Home Assistant-compatible commands:

```bash
sudo nas-system-update
sudo nas-docker-pull
sudo nas-docker-up
sudo nas-docker-prune
```

For a complete interactive run, use:

```bash
nas-update
```

`nas-docker-pull` must return valid JSON when called without a terminal. Before applying updates, check that the reported containers and Compose directories are the expected ones. On a stack with several updated containers, `nas-docker-up` should run `docker compose up -d` only once for that stack while still reporting the number of updated containers.

Scripts are installed in `/usr/local/bin/` and available directly from the command line. The installer checks for `curl`, `docker`, `apt-get` and `python3`.

## Sudo configuration (required for Home Assistant)

When calling scripts via SSH from Home Assistant, sudo requires passwordless access. Add the following rule on the NAS:

```bash
echo "<user> ALL=(ALL) NOPASSWD: /usr/local/bin/nas-system-update, /usr/local/bin/nas-system-upgrade, /usr/local/bin/nas-docker-pull, /usr/local/bin/nas-docker-up, /usr/local/bin/nas-docker-prune" > /etc/sudoers.d/nas-ops
chmod 440 /etc/sudoers.d/nas-ops
```

Replace `<user>` with the SSH user used in your Home Assistant config (e.g. the user in `/config/.ssh/config`).

## Scripts

### `nas-update`

Interactive root script. Orchestrates all steps in order:

1. System analysis (apt)
2. Docker pull and update detection
3. System upgrade (with confirmation)
4. Docker upgrade (all at once or container by container)
5. Orphaned image cleanup

If Debian/OMV reports that a reboot is required, `nas-update` asks for confirmation at the end. It never reboots automatically in a non-interactive Home Assistant call.

```bash
nas-update
```

---

### `nas-system-update`

Checks available system updates via apt. Does not modify anything.

- Terminal mode: colored output of upgradable packages
- Non-interactive mode (HA): JSON output

```bash
nas-system-update
```

```json
{"count":2,"reboot_required":false,"packages":[{"name":"curl","current":"7.88.0","available":"7.88.1"}]}
```

---

### `nas-system-upgrade`

Applies system updates (`apt full-upgrade`).

- Terminal mode: shows summary + confirmation before applying
- Non-interactive mode (HA): applies directly

```bash
nas-system-upgrade
```

---

### `nas-docker-pull`

Pulls all Docker images for active containers and detects available updates. **Does not recreate containers.**

Idempotent: as long as `nas-docker-up` has not recreated the containers, the check always detects the gap.

- Terminal mode: colored output
- Non-interactive mode (HA): JSON output

```bash
nas-docker-pull
```

```json
{"count":1,"containers":[{"name":"jellyfin","image":"jellyfin/jellyfin:latest","compose_dir":"/opt/stacks/jellyfin","current":"10.9.0","available":"available","source":"https://github.com/example/jellyfin"}],"sources":[{"name":"jellyfin","releases":"https://github.com/example/jellyfin/releases"}]}
```

---

### `nas-docker-up`

Recreates containers on the new image via `docker compose up -d --remove-orphans`.

- No argument: offers to update all containers with a newer image
- With argument: targets a specific stack
- Terminal mode: confirmation per stack or all at once
- Non-interactive mode (HA): applies directly

When several updated containers belong to the same Compose directory, the stack is applied only once. The reported counters still count containers.

```bash
nas-docker-up              # all stacks
nas-docker-up jellyfin     # specific stack
```

---

### `nas-docker-prune`

Removes orphaned (dangling) Docker images. Call after `nas-docker-up`.

```bash
nas-docker-prune
```

---

## Home Assistant Integration

Two ready-to-use files are provided:

**`ha-shell-command.yaml`** — include in `configuration.yaml` as:
```yaml
shell_command: !include ha-shell-command.yaml
```

**`ha-command-line.yaml`** — include in `configuration.yaml` as:
```yaml
command_line: !include ha-command-line.yaml
```

The `command_line` sensors expose:
- `sensor.omv_system_updates` → number of upgradable apt packages
- `sensor.omv_docker_updates` → number of Docker containers to update
- `reboot_required` and `packages` as attributes on the system sensor
- `containers` as attribute on the Docker sensor

The sensors refresh according to their configured `scan_interval`. After running an update manually, refresh them immediately from an automation or script with:

```yaml
action:
  - action: homeassistant.update_entity
    target:
      entity_id:
        - sensor.omv_system_updates
        - sensor.omv_docker_updates
```

## Typical workflow from HA

```
nas_docker_pull    →  detect available updates (idempotent)
nas_docker_up      →  apply updates
nas_docker_prune   →  clean up old images
```
