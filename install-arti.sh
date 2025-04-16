#!/bin/bash

set -e

# === CONFIG VARIABLES ===
ARTIFACTORY_VERSION="7.x.y"
ARTIFACTORY_ZIP_URL="https://releases.jfrog.io/artifactory/artifactory-rpms/org/artifactory/artifactory-oss/${ARTIFACTORY_VERSION}/artifactory-oss-${ARTIFACTORY_VERSION}.zip"
ARTIFACTORY_USER="artifactory"
ARTIFACTORY_HOME="/opt/jfrog/artifactory"

# Replace with your actual values
RDS_ENDPOINT="your-rds-hostname.amazonaws.com"
RDS_PORT="5432"
RDS_DB_NAME="artifactory"
RDS_DB_USER="artifactory_user"
RDS_DB_PASSWORD="your_secure_password"

S3_BUCKET_NAME="your-artifactory-s3-bucket"
S3_REGION="eu-west-3"  # Paris for example
AWS_ACCESS_KEY="YOUR_ACCESS_KEY"
AWS_SECRET_KEY="YOUR_SECRET_KEY"
ARTIFACTORY_JOIN_KEY="your-artifactory-cluster-join-key"
NODE_ID=$(hostname)

NGINX_RPM_URL="http://nginx.org/packages/rhel/7/x86_64/RPMS/nginx-1.24.0-1.el7.ngx.x86_64.rpm"

# === CREATE ARTIFACTORY USER ===
if ! id "$ARTIFACTORY_USER" &>/dev/null; then
    echo "[+] Creating user: $ARTIFACTORY_USER"
    useradd -m -s /bin/bash "$ARTIFACTORY_USER"
fi

# === DOWNLOAD & INSTALL ARTIFACTORY ===
mkdir -p /opt/jfrog
cd /opt/jfrog

echo "[+] Downloading Artifactory..."
curl -LO "$ARTIFACTORY_ZIP_URL"
unzip -q artifactory-oss-*.zip
rm -f artifactory-oss-*.zip
chown -R $ARTIFACTORY_USER:$ARTIFACTORY_USER artifactory

# === CONFIGURE system.yaml ===
echo "[+] Creating system.yaml config..."
mkdir -p $ARTIFACTORY_HOME/var/etc
cat <<EOF > $ARTIFACTORY_HOME/var/etc/system.yaml
shared:
  node:
    id: $NODE_ID
  joinKey: "$ARTIFACTORY_JOIN_KEY"

configVersion: 1

database:
  type: postgresql
  driver: org.postgresql.Driver
  url: jdbc:postgresql://$RDS_ENDPOINT:$RDS_PORT/$RDS_DB_NAME
  username: $RDS_DB_USER
  password: $RDS_DB_PASSWORD

filestore:
  type: s3
  s3:
    bucketName: $S3_BUCKET_NAME
    region: $S3_REGION
    identity: $AWS_ACCESS_KEY
    credential: $AWS_SECRET_KEY
EOF

chown -R $ARTIFACTORY_USER:$ARTIFACTORY_USER $ARTIFACTORY_HOME

# === CREATE SYSTEMD SERVICE ===
echo "[+] Creating systemd service for Artifactory..."

cat <<EOF > /etc/systemd/system/artifactory.service
[Unit]
Description=JFrog Artifactory
After=network.target

[Service]
Type=simple
User=$ARTIFACTORY_USER
ExecStart=$ARTIFACTORY_HOME/app/bin/artifactory.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable artifactory
systemctl start artifactory

# === INSTALL NGINX ===
echo "[+] Installing Nginx..."
curl -LO "$NGINX_RPM_URL"
yum localinstall -y nginx-*.rpm
rm -f nginx-*.rpm

echo "[+] Configuring Nginx as reverse proxy..."
cat <<EOF > /etc/nginx/conf.d/artifactory.conf
server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass          http://127.0.0.1:8081/;
        proxy_set_header    Host \$host;
        proxy_set_header    X-Real-IP \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto \$scheme;
    }
}
EOF

systemctl enable nginx
systemctl start nginx

echo "[✔] Artifactory HA node setup complete on $(hostname)"
echo "[→] Access it via http://<instance-ip>/"
