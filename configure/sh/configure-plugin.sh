#!/bin/ksh
##########################################
#                                        #
#   auteur : Francois Colombo            #
#                                        #
##########################################

#==========================================================================
# FONCTIONS                                                               =
#==========================================================================

#--- Ceci permet de realiser la configuration du plugin WAS ---------------
function doConfigurePlugin
{

  SRV_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`
  WEB_NAME=`echo "${2}" | tr '[:upper:]' '[:lower:]'`

  read ADM_USR_NAME?'> web admin user ? '
  read ADM_USR_PSWD?'> web admin password ? '

  WASVERSION=$( getAttribute "//packaging/websphere/@version" )
  IHS_HTTP_PORT=$( getAttribute "//webservers/webserver[@name='${WEB_NAME}']/@port" )
  IHS_ADMIN_PORT=$( getAttribute "//webservers/webserver[@name='${WEB_NAME}']/@adminPort" )
  ADMIN_USER_ID=$( getAttribute "//webservers/webserver[@name='${WEB_NAME}']/@userId" )
  ADMIN_GROUP_ID=$( getAttribute "//webservers/webserver[@name='${WEB_NAME}']/@groupId" )

  logVar "WASVERSION" ${WASVERSION}
  logVar "SRV_NAME" ${SRV_NAME}
  logVar "WEB_NAME" ${WEB_NAME}
  logVar "IHS_HTTP_PORT" ${IHS_HTTP_PORT}
  logVar "IHS_ADMIN_PORT" ${IHS_ADMIN_PORT}
  logVar "ADMIN_USER_ID" ${ADMIN_USER_ID}
  logVar "ADMIN_GROUP_ID" ${ADMIN_GROUP_ID}

  logInfo "- association du webserver ${WEB_NAME} avec le profile ${SRV_NAME}"

  logInfo "- arret admin de ${WEB_NAME}"
  ${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME}/bin/adminctl stop

  logInfo "- creation du responsefile"
  cat > /tmp/plugin-response.txt <<ENDL
configType=local_standalone
enableAdminServerSupport=true
enableUserAndPass=true
enableWinService=false
ihsAdminCreateUserAndGroup=false
ihsAdminUserID=${ADM_USR_NAME}
ihsAdminPassword=${ADM_USR_PSWD}
ihsAdminPort=${IHS_ADMIN_PORT}
ihsAdminUnixUserGroup=${ADMIN_GROUP_ID}
ihsAdminUnixUserID=${ADMIN_USER_ID}
mapWebServerToApplications=true
profileName=${SRV_NAME}
wasExistingLocation=${ROOT_PRODUCTS}/was/${WASVERSION}
webServerConfigFile1=${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME}/conf/httpd.conf
webServerDefinition=${WEB_NAME}
webServerHostName=${HOSTNAME}
webServerInstallArch=64
webServerPortNumber=${IHS_HTTP_PORT}
webServerSelected=ihs
webServerType=IHS
ENDL

  TST=`${ROOT_PRODUCTS}/wct/${WASVERSION}/WCT/wctcmd.sh -tool pct -listDefinitionLocations | grep "${ROOT_PRODUCTS}/wasplugins/${WASVERSION}" | wc -l`
  if [[ ${TST} -eq 1 ]]
  then
    logInfo "- suppression des anciennes definitions (sans cela, pas possible de creer la nouvelle...)"
    ${ROOT_PRODUCTS}/wct/${WASVERSION}/WCT/wctcmd.sh -tool pct -removeDefinitionLocation -defLocPathname ${ROOT_PRODUCTS}/wasplugins/${WASVERSION}
  fi

  logInfo "- creation du plugin..."
  ${ROOT_PRODUCTS}/wct/${WASVERSION}/WCT/wctcmd.sh -tool pct -defLocPathname ${ROOT_PRODUCTS}/wasplugins/${WASVERSION} -defLocName ${WEB_NAME} -response /tmp/plugin-response.txt
  if [[ $? -gt 127 ]]
  then
    logError 13 "la creation du plugin ${WEB_NAME} ne s'est pas correctement deroulee... arret de la procedure."
  fi

  logInfo "- le plugin ${WEB_NAME} est cree... on va maintenant l'associer avec WAS."
  cp ${ROOT_PRODUCTS}/wasplugins/${WASVERSION}/bin/configure${WEB_NAME}.sh ${ROOT_PRODUCTS}/was/${WASVERSION}/profiles/${SRV_NAME}/bin/
  ${ROOT_PRODUCTS}/was/${WASVERSION}/profiles/${SRV_NAME}/bin/configure${WEB_NAME}.sh

  logInfo "- demarrage admin de ${WEB_NAME}"
  ${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME}/bin/adminctl start
  if [[ $? -gt 127 ]]
  then
    logError 14 "le demarrage d'IHS ne s'est pas correctement deroule... veuillez controler les logs."
  else
    logInfo "- operation terminee avec succes."
  fi
}

#==========================================================================
# FIN DE DEFINITION DES FONCTIONS                                         =
#==========================================================================
logTrace "Chargement de configure-plugin.sh (version ${LIB_VERSION}) effectue."
