# nas-scripts

Scripts de gestion des mises à jour pour NAS sous OpenMediaVault 8.

## Installation

```bash
cp nas-update-system nas-upgrade-system nas-docker-pull nas-docker-up nas-docker-prune nas-update /usr/local/bin/
chmod +x /usr/local/bin/nas-update-system /usr/local/bin/nas-upgrade-system \
         /usr/local/bin/nas-docker-pull /usr/local/bin/nas-docker-up \
         /usr/local/bin/nas-docker-prune /usr/local/bin/nas-update
```

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

### `nas-update-system`

Vérifie les mises à jour système disponibles via apt. Ne modifie rien.

- Mode terminal : affichage coloré des paquets upgradables
- Mode non-interactif (HA) : output JSON

```bash
nas-update-system
```

```json
{"count":2,"reboot_required":false,"packages":[{"name":"curl","current":"7.88.0","available":"7.88.1"}]}
```

---

### `nas-upgrade-system`

Applique les mises à jour système (`apt full-upgrade`).

- Mode terminal : affiche le bilan + confirmation avant d'appliquer
- Mode non-interactif (HA) : applique directement

```bash
nas-upgrade-system
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

Voir `nas-ha-config.yaml` pour la configuration complète.

```yaml
shell_command:
  nas_update_system: "ssh -F /config/.ssh/config omv 'sudo nas-update-system'"
  nas_upgrade_system: "ssh -F /config/.ssh/config omv 'sudo nas-upgrade-system'"
  nas_docker_pull: "ssh -F /config/.ssh/config omv 'sudo nas-docker-pull'"
  nas_docker_up: "ssh -F /config/.ssh/config omv 'sudo nas-docker-up'"
  nas_docker_up_stack: "ssh -F /config/.ssh/config omv 'sudo nas-docker-up {{ stack }}'"
  nas_docker_prune: "ssh -F /config/.ssh/config omv 'sudo nas-docker-prune'"
```

## Flux typique depuis HA

```
nas_docker_pull    →  détecte les mises à jour dispo (idempotent)
nas_docker_up      →  applique les mises à jour
nas_docker_prune   →  nettoie les anciennes images
```
