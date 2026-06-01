# nas-ops

Scripts de maintenance et de mise à jour pour NAS sous Debian / OpenMediaVault 8.

Gère les mises à jour système (`apt`) et Docker (`docker compose`), avec deux modes :
- **Terminal interactif** : affichage coloré, confirmations
- **Non-interactif** (Home Assistant, cron) : output JSON

## Installation

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GuiPoM/nas-ops/main/install.sh)
```

Les scripts sont installés dans `/usr/local/bin/` et disponibles directement en ligne de commande.

## Configuration sudo (requis pour Home Assistant)

Lors des appels SSH depuis Home Assistant, sudo demande un mot de passe. Il faut autoriser ces commandes sans mot de passe sur le NAS :

```bash
echo "<user> ALL=(ALL) NOPASSWD: /usr/local/bin/nas-system-update, /usr/local/bin/nas-system-upgrade, /usr/local/bin/nas-docker-pull, /usr/local/bin/nas-docker-up, /usr/local/bin/nas-docker-prune" > /etc/sudoers.d/nas-ops
chmod 440 /etc/sudoers.d/nas-ops
```

Remplace `<user>` par l'utilisateur SSH utilisé dans ta config Home Assistant (celui défini dans `/config/.ssh/config`).

## Scripts

### `nas-update`

Script racine interactif. Orchestre toutes les étapes dans l'ordre :

1. Analyse système (apt)
2. Pull et détection des mises à jour Docker
3. Upgrade système (confirmation)
4. Upgrade Docker (tout ou conteneur par conteneur)
5. Nettoyage des images orphelines

```bash
nas-update
```

---

### `nas-system-update`

Vérifie les mises à jour système disponibles via apt. Ne modifie rien.

- Mode terminal : affichage coloré des paquets upgradables
- Mode non-interactif (HA) : output JSON

```bash
nas-system-update
```

```json
{"count":2,"reboot_required":false,"packages":[{"name":"curl","current":"7.88.0","available":"7.88.1"}]}
```

---

### `nas-system-upgrade`

Applique les mises à jour système (`apt full-upgrade`).

- Mode terminal : affiche le bilan + confirmation avant d'appliquer
- Mode non-interactif (HA) : applique directement

```bash
nas-system-upgrade
```

---

### `nas-docker-pull`

Pull toutes les images Docker des conteneurs actifs et détecte les mises à jour disponibles. **Ne recrée pas les conteneurs.**

Idempotent : tant que `nas-docker-up` n'a pas recréé les conteneurs, le check détecte toujours l'écart.

- Mode terminal : affichage coloré
- Mode non-interactif (HA) : output JSON

```bash
nas-docker-pull
```

```json
{"count":1,"containers":[{"name":"jellyfin","image":"jellyfin/jellyfin:latest","compose_dir":"/opt/stacks/jellyfin","current":"10.9.0","available":"disponible"}]}
```

---

### `nas-docker-up`

Recrée les conteneurs sur la nouvelle image via `docker compose up -d --remove-orphans`.

- Sans argument : propose la mise à jour de tous les conteneurs ayant une image plus récente
- Avec argument : cible une stack spécifique
- Mode terminal : confirmation par stack ou tout d'un coup
- Mode non-interactif (HA) : applique directement

```bash
nas-docker-up              # toutes les stacks
nas-docker-up jellyfin     # stack spécifique
```

---

### `nas-docker-prune`

Nettoie les images Docker orphelines (dangling). À appeler après `nas-docker-up`.

```bash
nas-docker-prune
```

---

## Intégration Home Assistant

Deux fichiers prêts à l'emploi sont fournis :

**`ha-shell-command.yaml`** — à inclure dans `configuration.yaml` :
```yaml
shell_command: !include ha-shell-command.yaml
```

**`ha-command-line.yaml`** — à inclure dans `configuration.yaml` :
```yaml
command_line: !include ha-command-line.yaml
```

Les sensors `command_line` exposent :
- `sensor.omv_system_updates` → nombre de paquets apt upgradables
- `sensor.omv_docker_updates` → nombre de conteneurs Docker à mettre à jour
- `reboot_required` et `packages` comme attributs du sensor système
- `containers` comme attribut du sensor Docker

## Flux typique depuis HA

```
nas_docker_pull    →  détecte les mises à jour dispo (idempotent)
nas_docker_up      →  applique les mises à jour
nas_docker_prune   →  nettoie les anciennes images
```
