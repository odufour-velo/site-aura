
# --- VARIABLES SYSTÈME ---
# On récupère dynamiquement ton ID utilisateur et groupe Linux
LOCAL_UID := $(shell id -u)
LOCAL_GID := $(shell id -g)

# --- VARIABLES À MODIFIER ---
REMOTE_SSH=u72168624@home453993627.1and1-data.host
REMOTE_PATH=/kunden/homepages/41/d453993627/htdocs/ranew
LOCAL_URL=http://localhost:8080
REMOTE_URL=https://www.auvergnerhonealpescyclisme.com
DOCKER_WP_CONTAINER=wordpress  # souvent 'wordpress' dans docker-compose

DB_USER=user
DB_PASSWORD=password
DB_NAME=wordpress

# --- AIDE ---

help:
	@echo "Utilisateur Linux détecté : UID=$(LOCAL_UID), GID=$(LOCAL_GID)"
	@echo "---------------------------------------------------------"
	@echo "Usage:"
	@echo "  make pull-db    : Distant -> Local (Import + Search-Replace)"
	@echo "  make push-db    : Local -> Distant (Export + Search-Replace)"
	@echo "  make pull-files : Distant -> Local (wp-content)"
	@echo "  make push-files : Local -> Distant (wp-content)"
	@echo "  make fix-rights : Réinitialise les permissions sur wp-content"

# --- PERMISSIONS ---

fix-rights:
	@echo "🔧 Correction des permissions pour l'utilisateur $(LOCAL_UID)..."
	sudo chown -R $(LOCAL_UID):$(LOCAL_GID) .
	chmod -R 755 .

# --- DATABASE ---

pull-db:
	@echo "📥 Exportation de la base distante via SSH..."
	ssh $(REMOTE_SSH) "cd $(REMOTE_PATH) && wp db export - --prohibit-password-caps | gzip" > dump_remote.sql.gz
	@echo "💾 Importation dans Docker..."
	gunzip -f dump_remote.sql.gz
	# On injecte le SQL directement dans le conteneur DB
	docker compose exec -u $(LOCAL_UID):$(LOCAL_GID) -T db mysql -u$(DB_USER) -p$(DB_PASSWORD) $(DB_NAME) < dump_remote.sql
	@echo "🔄 Remplacement des URLs ($(REMOTE_URL) -> $(LOCAL_URL))..."
	docker compose exec -u $(LOCAL_UID):$(LOCAL_GID) -T $(DOCKER_WP_CONTAINER) wp search-replace $(REMOTE_URL) $(LOCAL_URL) --all-tables
	rm dump_remote.sql
	@echo "✅ Terminé ! Base de données locale à jour."

push-db:
	@echo "📤 Exportation de la base locale..."
	docker compose exec -u $(LOCAL_UID):$(LOCAL_GID) -T $(DOCKER_WP_CONTAINER) wp db export - | gzip > dump_local.sql.gz
	@echo "🚀 Transfert et importation sur le serveur distant..."
	scp dump_local.sql.gz $(REMOTE_SSH):$(REMOTE_PATH)/
	ssh $(REMOTE_SSH) "cd $(REMOTE_PATH) && gunzip -f dump_local.sql.gz && wp db import dump_local.sql && wp search-replace $(LOCAL_URL) $(REMOTE_URL) --all-tables && rm dump_local.sql"
	rm dump_local.sql.gz
	@echo "✅ Terminé ! Site en ligne mis à jour."

# --- FILES ---

pull-files:
	@echo "📥 Synchronisation des fichiers (distant -> local)..."
	# Le slash à la fin de wp-content/ est crucial pour rsync
	rsync -avz --progress --exclude='cache/' $(REMOTE_SSH):$(REMOTE_PATH)/wp-content/ ./wp-content/
	@echo "✅ wp-content local à jour."

push-files:
	@echo "📤 Synchronisation des fichiers (local -> distant)..."
	rsync -avz --progress --exclude='cache/' ./wp-content/ $(REMOTE_SSH):$(REMOTE_PATH)/wp-content/
	@echo "✅ wp-content distant à jour."

start:
	@echo "🚀 Lancement avec UID=$(LOCAL_UID) et GID=$(LOCAL_GID)"
	# L'export est crucial ici
	export UID=$(LOCAL_UID); \
	export GID=$(LOCAL_GID); \
	docker compose up -d
	@echo "✅ Accès : http://localhost:8080"

stop:
	@echo "🛑 Arrêt des conteneurs..."
	docker compose down

restart: stop start
	@echo "🔄 Conteneurs redémarrés."

logs:
	@echo "📜 Affichage des logs..."
	docker compose logs -f
