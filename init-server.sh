#!/bin/bash
set -e
# ==========================
# Script de configuration du serveur VPS
# Installe Docker, configure le firewall, durcit SSH
# et prepare l'environnement de deploiement pour Zero-to-Deploy
#
# NOTE SONARQUBE : l'analyse de code se fait via SonarCloud (SaaS externe),
# aucune installation serveur necessaire ici. Cote pipeline GitHub Actions,
# ajouter le secret SONAR_TOKEN (genere sur sonarcloud.io) et le plugin
# sonar-scanner dans le job de build.
#
# NOTE .ENV : les fichiers .env.test/.env.preprod/.env.prod ne sont PAS
# crees par ce script. Ils sont generes par la pipeline CD a partir des
# Environments/Secrets GitHub, puis deposes ici via SCP a chaque deploiement.
# ==========================

# --- Configuration ---
APP_USER="cicd"
APP_NAME="zero-to-deploy"
APP_BASE_DIR="/home/$APP_USER/$APP_NAME"
SSH_PORT=22
ENVIRONMENTS=("test" "preprod" "prod")
APP_PORTS=(3000 3001 3002)

echo ""
echo "=== Configuration du serveur VPS pour $APP_NAME ==="
echo ""

# --- Mise a jour du systeme ---
echo "[1/7] Mise a jour du systeme..."
apt-get update -y && apt-get upgrade -y

# --- Installation de Docker ---
echo "[2/7] Installation de Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    echo "Docker installe."
else
    echo "Docker deja installe."
fi

# --- Creation de l'utilisateur cicd ---
echo "[3/7] Creation de l'utilisateur $APP_USER..."
if ! id "$APP_USER" &>/dev/null; then
    adduser --disabled-password --gecos "" "$APP_USER"
    echo "Utilisateur $APP_USER cree."
else
    echo "Utilisateur $APP_USER existe deja."
fi
usermod -aG docker "$APP_USER"

# --- Generation des cles SSH pour cicd ---
echo "[4/7] Configuration SSH pour $APP_USER..."
SSH_DIR="/home/$APP_USER/.ssh"
if [ ! -f "$SSH_DIR/id_ed25519" ]; then
    mkdir -p "$SSH_DIR"
    ssh-keygen -t ed25519 -C "cicd-deploy-$APP_NAME" -f "$SSH_DIR/id_ed25519" -N ""
    cat "$SSH_DIR/id_ed25519.pub" >> "$SSH_DIR/authorized_keys"
    chmod 700 "$SSH_DIR"
    chmod 600 "$SSH_DIR/authorized_keys" "$SSH_DIR/id_ed25519"
    chown -R "$APP_USER:$APP_USER" "$SSH_DIR"
    echo "Cles SSH generees."
    echo ""
    echo ">>> CLE PRIVEE (a copier dans le secret GitHub VPS_SSH_KEY) :"
    echo ">>> ATTENTION : copiez-la maintenant, elle ne sera plus affichee."
    echo ""
    cat "$SSH_DIR/id_ed25519"
    echo ""
else
    echo "Cles SSH deja configurees."
fi

# --- Configuration du firewall (UFW) ---
echo "[5/7] Configuration du firewall..."
if ! command -v ufw &>/dev/null; then
    apt-get install ufw -y
fi
ufw allow "$SSH_PORT/tcp"
for PORT in "${APP_PORTS[@]}"; do
    ufw allow "$PORT/tcp"
done
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
echo "Firewall configure (SSH:$SSH_PORT, ports app: ${APP_PORTS[*]})."

# --- Durcissement SSH ---
echo "[6/7] Durcissement SSH..."
configure_ssh() {
    KEY="$1"; VALUE="$2"
    if grep -q "^$KEY" /etc/ssh/sshd_config; then
        sed -i "s|^$KEY.*|$KEY $VALUE|" /etc/ssh/sshd_config
    else
        echo "$KEY $VALUE" >> /etc/ssh/sshd_config
    fi
}
configure_ssh "PermitRootLogin" "no"
configure_ssh "MaxAuthTries" "3"
configure_ssh "ClientAliveInterval" "300"
configure_ssh "ClientAliveCountMax" "2"
systemctl restart ssh
echo "SSH durci."

# --- Preparation des repertoires de deploiement (un par environnement) ---
echo ""
echo "[7/7] Preparation des repertoires de deploiement..."
for ENV in "${ENVIRONMENTS[@]}"; do
    DEPLOY_DIR="$APP_BASE_DIR/$ENV"
    su - "$APP_USER" -c "mkdir -p $DEPLOY_DIR"
    echo "  -> $DEPLOY_DIR cree."
done

echo ""
echo "=== Configuration terminee ==="
echo ""
echo "Prochaines etapes :"
echo "  1. Ajouter la cle privee ci-dessus dans le secret GitHub VPS_SSH_KEY"
echo "  2. Creer le secret GitHub SONAR_TOKEN (depuis sonarcloud.io)"
echo "  3. Configurer les GitHub Environments (test/preprod/prod) avec les variables :"
echo "       IMAGE_NAME, IMAGE_TAG, ENVIRONMENT, HOST_PORT, CONTAINER_NAME"
echo "  4. La pipeline CD deposera docker-compose.yml + .env dans :"
for ENV in "${ENVIRONMENTS[@]}"; do
    echo "       $APP_BASE_DIR/$ENV"
done
echo "  5. La pipeline lancera : docker compose --env-file .env up -d --build"
echo ""