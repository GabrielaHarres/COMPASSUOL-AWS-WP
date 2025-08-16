#!/bin/bash
set -xe

# ================== VARIÁVEIS (EDITE AQUI) ==================
EFS_ID="fs-xxxxxxxx"                             # ID do seu EFS 
DB_ENDPOINT="seu-rds.us-east-1.rds.amazonaws.com" # Endpoint do RDS (sem porta)
DB_NAME="wordpressdb"                            # Nome do banco no RDS
DB_USER="wpuser"                                 # Usuário do banco
DB_PASSWORD="TroqueEssaSenha123!"                # Senha do banco

# Porta HTTP do WordPress no host (mantenha 80 para usar atrás do ALB)
HTTP_PORT="80"

# ================== PACOTES E DOCKER ==================
# Amazon Linux usa yum/dnf (yum costuma funcionar como alias)
yum update -y
yum install -y aws-cli docker amazon-efs-utils git

systemctl enable --now docker
usermod -a -G docker ec2-user

# Docker Compose (binário simples)
curl -sSL https://github.com/docker/compose/releases/download/v2.34.0/docker-compose-linux-x86_64 \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# ================== MONTAGEM DO EFS ==================
# usaremos um subdiretório específico para 'wp-content'
mkdir -p /mnt/efs/wp-content

# monta com helper do EFS (+TLS). Se sua VPC não resolve DNS do EFS use ${EFS_ID}.efs.<regiao>.amazonaws.com
mount -t efs -o tls ${EFS_ID}:/ /mnt/efs || mount -t efs ${EFS_ID}:/ /mnt/efs

# garante que o subdiretório exista no EFS
mkdir -p /mnt/efs/wp-content

# permissões: www-data no WordPress é 33:33 nos contêineres oficiais
chown -R 33:33 /mnt/efs/wp-content
chmod -R 775 /mnt/efs/wp-content

# Fstab para remontar no boot
if ! grep -q "${EFS_ID}:/ /mnt/efs efs" /etc/fstab; then
  echo "${EFS_ID}:/ /mnt/efs efs _netdev,tls 0 0" >> /etc/fstab
fi

# ================== PROJETO DOCKER ==================
mkdir -p /opt/wordpress
cd /opt/wordpress

# .env com variáveis usadas pelo compose
cat > .env <<EOF
WORDPRESS_DB_HOST=${DB_ENDPOINT}
WORDPRESS_DB_NAME=${DB_NAME}
WORDPRESS_DB_USER=${DB_USER}
WORDPRESS_DB_PASSWORD=${DB_PASSWORD}
HOST_HTTP_PORT=${HTTP_PORT}
EOF

# docker-compose.yml
# OBSERVAÇÃO: montamos SOMENTE /var/www/html/wp-content no EFS
cat > docker-compose.yml <<'EOF'
version: "3.8"

services:
  wordpress:
    image: wordpress:6.8.2-php8.1-apache
    restart: unless-stopped
    ports:
      - "${HOST_HTTP_PORT}:80"
    env_file: .env
    environment:
      WORDPRESS_DB_HOST: "${WORDPRESS_DB_HOST}"
      WORDPRESS_DB_NAME: "${WORDPRESS_DB_NAME}"
      WORDPRESS_DB_USER: "${WORDPRESS_DB_USER}"
      WORDPRESS_DB_PASSWORD: "${WORDPRESS_DB_PASSWORD}"
    volumes:
      - /mnt/efs/wp-content:/var/www/html/wp-content
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/wp-login.php"]  # bom pra ALB health check
      interval: 30s
      timeout: 5s
      retries: 5

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    restart: unless-stopped
    depends_on:
      - wordpress
    ports:
      - "8081:80"
    env_file: .env
    environment:
      PMA_HOST: "${WORDPRESS_DB_HOST}"
      PMA_USER: "${WORDPRESS_DB_USER}"
      PMA_PASSWORD: "${WORDPRESS_DB_PASSWORD}"
EOF

# sobe serviços
docker-compose up -d

# ================== QUALQUER AJUSTE ÚTIL ==================
# Opcional: abre firewall local (normalmente o SG/ALB cuidam disso)
# firewall-cmd --permanent --add-service=http || true
# firewall-cmd --reload || true
