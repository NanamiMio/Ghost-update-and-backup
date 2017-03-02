#!/bin/bash
# shower
# update Ghost

# !!!
# You should set the following variables

GHOST_PATH="" #Ghost path, such as "/var/www/ghost"
GHOST_RESTART="" #Ghost restart command, such as "pm2 restart Ghost"
BACKUP_ON="" # Backup switch, "TRUE" or "FALSE"

# Backup setting.

BACKUP_PATH="" # such as "/home/backup"
GHOST_BASE_URL="" #Ghost blog's url, such as "https://yourblog.com"
GHOST_ADMIN_USER="" #Ghost admin user's e-mail
GHOST_ADMIN_PASS="" #Ghost admin password

# When you need you can change the following variables

UPDATE_TMP="/tmp" # Temporary folder used when upgrading
NPM="npm" # You can use "cnpm" instead of it

GHOST_SIGNIN_URL=""${GHOST_BASE_URL}"/ghost/signin/"
GHOST_AUTH_URL=""${GHOST_BASE_URL}"/ghost/api/v0.1/authentication/token/"
GHOST_EXPORT_URL=""${GHOST_BASE_URL}"/ghost/api/v0.1/db/"

## ------ Check remote version ------

LOCAL_VERSION=$(cat $GHOST_PATH/package.json | grep 'version' | sed 's/.*"version": "\(.*\)".*/\1/g')
REMOTE_VERSION=$(curl -s https://api.github.com/repos/TryGhost/Ghost/releases/latest | grep 'tag_name' | sed 's/.*"tag_name": "\(.*\)".*/\1/g')
if [ "${LOCAL_VERSION}" == "${REMOTE_VERSION}" ]
then
DATE=$(date "+%y/%m/%d %T")
echo ""${DATE}" The local and remote versions are the same. Nothing needs to be done."
exit 0
fi

## ------ Backup ------

if [ "${BACKUP_ON}" == "TRUE" ]
then

GHOST_CLIENTID=$(curl -s "${GHOST_SIGNIN_URL}" | grep 'clientId' | sed 's/.*content="\(.*\)".*".*".*/\1/g')
GHOST_CLIENTSECERT=$(curl -s "${GHOST_SIGNIN_URL}" | grep 'clientSecret' | sed 's/.*content="\(\w*\)".*/\1/g')
GHOST_TOCKEN=$(curl -s -d \
               "grant_type=password&username="${GHOST_ADMIN_USER}"&password="${GHOST_ADMIN_PASS}"&client_id="${GHOST_CLIENTID}"&client_secret="${GHOST_CLIENTSECERT}"" \
               "${GHOST_AUTH_URL}" | sed 's/.*"access_token":"\(\w*\)".*/\1/g')

DATE=$(date +%y-%m-%d)
BACKUP_NAME="ghost-backup-"${DATE}""

cd "${UPDATE_TMP}"
mkdir "${BACKUP_NAME}"
curl -s "${GHOST_EXPORT_URL}"?access_token="${GHOST_TOCKEN}" -o /tmp/ghost-backup-"${DATE}"/data.json

cp "${GHOST_PATH}"/config.js "${BACKUP_NAME}"/config.js
cp -r "${GHOST_PATH}"/content "${BACKUP_NAME}"/content
tar -zcf "${BACKUP_PATH}"/"${BACKUP_NAME}".tar.gz "${BACKUP_NAME}"
DATE=$(date "+%y/%m/%d %T")
echo ""${DATE}" Created backup named "${BACKUP_NAME}".tar.gz at "${BACKUP_PATH}""

rm -r "${BACKUP_NAME}"

fi

# ------ Update ------

# Fetching the latest Ghost version
curl -LOs https://github.com/TryGhost/Ghost/releases/download/"${REMOTE_VERSION}"/Ghost-"${REMOTE_VERSION}".zip

# Unzip to a temporary location
unzip -o Ghost-"${REMOTE_VERSION}".zip -d ghost-temp > /dev/null
rm Ghost-"${REMOTE_VERSION}".zip
 
rm -rf "${GHOST_PATH}"/core # Remove the core directory completely


#Copy over the new files
cd ghost-temp
cp -R core "${GHOST_PATH}"
cp index.js *.json "${GHOST_PATH}"

rm -rf ../ghost-temp

cd "${GHOST_PATH}"

chown -R ghost:ghost * #Update permissions

"${NPM}" install --production &> /dev/null # Upgrade dependencies

${GHOST_RESTART} > /dev/null # Restart Ghost

DATE=$(date "+%y/%m/%d %T")
echo "${DATE} Update successed. From "${LOCAL_VERSION}" to "${REMOTE_VERSION}"."

exit 0