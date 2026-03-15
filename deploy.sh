#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Configuration file handling
CONFIG_FILE=${1:-deploy.config}

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "\033[0;31mError: Configuration file '$CONFIG_FILE' not found.\033[0m"
    echo "Usage: $0 [config_file]"
    echo "Example: Create a file named 'deploy.config' from 'deploy.config.sample'."
    exit 1
fi

# Load variables from the specified config file
source "$CONFIG_FILE"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to handle errors
error_handler() {
    echo -e "${RED}Error: $1 failed!${NC}"
    exit 1
}

build_project() {
    echo -e "${GREEN} Building project: Re-generating local dependencies...${NC}"
    composer install --no-dev --optimize-autoloader || error_handler "build_project"

    echo -e "${GREEN} Generating web/sites/default/settings.php from template...${NC}"
    
    # Export variables so envsubst can see them
    export DB_NAME DB_USER DB_PASS DB_HOST DB_PORT DB_PREFIX HASH_SALT
    
    # Use envsubst to replace database and security variables in the template.
    # We use single quotes for the variable list to prevent the shell from expanding them here.
    # envsubst only replaces the variables listed.
    envsubst '$DB_NAME$DB_USER$DB_PASS$DB_HOST$DB_PORT$DB_PREFIX$HASH_SALT' \
        < settings.php.template > web/sites/default/settings.php || error_handler "Generating settings.php"
}

upload_files() {
    echo -e "${GREEN} Uploading files to $REMOTE_HOST (port ${SSH_PORT:-22})...${NC}"
    rsync -avz --delete \
        -e "ssh -p ${SSH_PORT:-22}" \
        --exclude='.git' \
        --exclude='web/sites/default/files' \
        --exclude='web/sites/default/settings.local.php' \
        --exclude="$CONFIG_FILE" \
        --exclude='deploy.config.sample' \
        --exclude='deploy.sh' \
        --exclude='settings.php.template' \
        --exclude='.env' \
        ./ $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH || error_handler "upload_files"
}

remote_commands() {
    echo -e "${GREEN}Executing remote operations (port ${SSH_PORT:-22})...${NC}"
    
    # Use PHP_BIN from config or pick a default
    LOCAL_PHP_BIN=${PHP_BIN:-/usr/local/bin/php-8.4}

    # Use set -e inside the SSH block to ensure remote failures are caught.
    ssh -p "${SSH_PORT:-22}" $REMOTE_USER@$REMOTE_HOST << EOF || error_handler "remote_commands"
        set -e
        cd $REMOTE_PATH

        # Check if Drupal is installed
        if ! $LOCAL_PHP_BIN ./vendor/bin/drush status --format=json | grep -q '"bootstrap": "Successful"'; then
            echo "Drupal is not installed. Installing..."
            $LOCAL_PHP_BIN ./vendor/bin/drush site:install ${DRUPAL_PROFILE:-standard} \
                --site-name="${SITE_NAME:-My Drupal Site}" \
                --account-name=admin \
                --account-pass=admin_password \
                --db-url=mysql://user:pass@mysql.host.com/db_name \
                -y
        else
            echo "Drupal is installed. Running updates..."
            $LOCAL_PHP_BIN ./vendor/bin/drush deploy -y
        fi

        echo "Clearing cache..."
        $LOCAL_PHP_BIN ./vendor/bin/drush cr
EOF
}

# Main Execution
echo -e "${GREEN}Starting Deployment using $CONFIG_FILE...${NC}"

build_project
upload_files
remote_commands

echo -e "${GREEN}Deployment Complete!${NC}"
