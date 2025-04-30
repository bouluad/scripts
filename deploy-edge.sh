#!/bin/bash

# Configuration variables
ARTIFACTORY_VERSION="7.77.5"
MASTER_KEY="your_master_key_here"
JOIN_KEY="your_join_key_here"
S3_BUCKET="artifactory-reefy-edge-prod"
AWS_REGION="eu-west-3"
DB_URL="jdbc:postgresql://your-rds-endpoint:5432/artifactory?ssl=true&sslmode=require"
DB_USER="artifactory"
DB_PASSWORD="your_strong_password"
NGINX_RPM_URL="https://nginx.org/packages/centos/7/x86_64/RPMS/nginx-1.24.0-1.el7.ngx.x86_64.rpm"
NGINX_CONFIG_PATH="/etc/nginx/conf.d/default.conf"
ARTIFACTORY_DIR="/opt/jfrog/artifactory/var/etc/security"
ARTIFACTORY_HOME="/opt/jfrog/artifactory"

# Function to install dependencies
install_dependencies() {
  echo "Installing required packages..."
  yum install -y wget openjdk-17-jdk ca-certificates
}

# Function to install NGINX
install_nginx() {
  echo "Installing NGINX..."
  wget -O /tmp/nginx.rpm "$NGINX_RPM_URL"
  yum localinstall -y /tmp/nginx.rpm
}

# Function to download and install Artifactory
install_artifactory() {
  echo "Downloading and installing Artifactory..."
  wget "https://releases.jfrog.io/artifactory/artifactory-edge/${ARTIFACTORY_VERSION}/jfrog-artifactory-edge-${ARTIFACTORY_VERSION}-linux.tar.gz" -O /tmp/artifactory.tar.gz
  tar -xvf /tmp/artifactory.tar.gz -C /opt/
}

# Function to configure Artifactory
configure_artifactory() {
  echo "Configuring Artifactory..."

  # Create the necessary directories
  mkdir -p $ARTIFACTORY_DIR

  # Create system.yaml
  cat <<EOF > /opt/jfrog/artifactory/var/etc/system.yaml
shared:
  node:
    id: $(hostname)
  database:
    type: postgresql
    driver: org.postgresql.Driver
    url: "$DB_URL"
    username: "$DB_USER"
    password: "$DB_PASSWORD"

artifactory:
  join:
    key: "$JOIN_KEY"

router:
  entrypoints:
    externalPort: 8082
EOF

  # Create binarystore.xml
  cat <<EOF > /opt/jfrog/artifactory/var/etc/artifactory/binarystore.xml
<config version="v1">
  <chain template="s3-storage-v3"/>
  <provider id="s3-storage-v3" type="s3">
    <bucketName>${S3_BUCKET}</bucketName>
    <region>${AWS_REGION}</region>
    <endpoint>s3.${AWS_REGION}.amazonaws.com</endpoint>
    <useInstanceCredentials>true</useInstanceCredentials>
  </provider>
</config>
EOF
}

# Function to set the master.key and join.key
set_keys() {
  echo "Setting master.key and join.key..."

  # Save keys to the appropriate directory
  echo "$MASTER_KEY" > "$ARTIFACTORY_DIR/master.key"
  echo "$JOIN_KEY" > "$ARTIFACTORY_DIR/join.key"
}

# Function to install Artifactory as a service
install_artifactory_service() {
  echo "Installing Artifactory service..."

  # Run the JFrog install service script
  /opt/jfrog/artifactory/app/bin/installService.sh
}

# Function to start the Artifactory service
start_artifactory() {
  echo "Starting Artifactory service..."

  systemctl enable artifactory
  systemctl start artifactory
}

# Function to install root CA certificates (for AWS S3 TLS trust)
install_aws_certificates() {
  echo "Installing AWS CA certificates..."
  wget https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem -O /usr/local/share/ca-certificates/aws-bundle.crt
  update-ca-certificates
}

# Run all functions
install_dependencies
install_nginx
install_artifactory
configure_artifactory
set_keys
install_artifactory_service
install_aws_certificates
start_artifactory

echo "Artifactory HA setup completed successfully!"
