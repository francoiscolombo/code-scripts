#!/bin/ksh
##########################################
#                                        #
#   auteur : Francois Colombo            #
#                                        #
##########################################

#==========================================================================
# FONCTIONS                                                               =
#==========================================================================

#--- Ceci permet de realiser l'installation du JDK 7 ----------------------
function doInstallJDK7
{

  ROOT_URL=$( getAttribute "//packaging/packages/@rootUrl" )
  JDK_PACKAGE=$( getAttribute "//packaging/packages/package[@name='ibmsdk']/@sourcepath" )
  JDK_OFF_ID=$( getAttribute "//packaging/packages/package[@name='ibmsdk']/@key" )
  WASMODE=$( getAttribute "//packaging/websphere/@mode" )
  WAS_LOCATION=$( getWasLocation )

  logVar "ROOT_URL" ${ROOT_URL}
  logVar "JDK_PACKAGE" ${JDK_PACKAGE}
  logVar "JDK_OFF_ID" ${JDK_OFF_ID}
  logVar "WAS_LOCATION" ${WAS_LOCATION}
  logVar "WASMODE" ${WASMODE}

  logInfo "- installation du jdk 7 (binaires)"
  ${ROOT_PRODUCTS}/install/setup/eclipse/tools/imcl install ${JDK_OFF_ID} -repositories ${ROOT_URL}/${JDK_PACKAGE}/ -installationDirectory ${WAS_LOCATION}/ -installFixes none -acceptLicense -sP -preferences com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=false,com.ibm.cic.common.core.preferences.searchForUpdates=false,com.ibm.cic.common.core.preferences.keepFetchedFiles=false

  logInfo "- controle de l'installation"
  if [[ -x ${WAS_LOCATION}/java_1.7.1_${WASMODE}/bin/java ]]; then
    logInfo "=== le JDK est bien installe."
  else
    logError 34 "il y a eu un probleme sur l'installation du JDK dans le repertoire ${WAS_LOCATION} ! arret de la procedure..."
  fi

  logInfo "- a present vous disposez des JDK suivants :"
  ${WAS_LOCATION}/bin/managesdk.sh -listAvailable

}

#--- Permet de changer le JDK par defaut de WAS pour le SDK 7 -------------
function doForceJDK7
{

  ROOT_URL=$( getAttribute "//packaging/packages/@rootUrl" )
  JDK_PACKAGE=$( getAttribute "//packaging/packages/package[@name='ibmsdk']/@sourcepath" )
  JDK_OFF_ID=$( getAttribute "//packaging/packages/package[@name='ibmsdk']/@key" )
  WASVERSION=$( getAttribute "//packaging/websphere/@version" )
  WASMODE=$( getAttribute "//packaging/websphere/@mode" )
  WAS_LOCATION=$( getWasLocation )

  logVar "WASVERSION" ${WASVERSION}
  logVar "WASMODE" ${WASMODE}
  logVar "ROOT_URL" ${ROOT_URL}
  logVar "JDK_PACKAGE" ${JDK_PACKAGE}
  logVar "JDK_OFF_ID" ${JDK_OFF_ID}
  logVar "WAS_LOCATION" ${WAS_LOCATION}

  logInfo "- forcer WAS a utiliser le JDK 7 pour s'executer"

  logInfo "- upgrade du JDK de WebSphere de la version 1.6 vers la version 1.7..."
  ${ROOT_PRODUCTS}/install/setup/eclipse/tools/imcl install ${JDK_OFF_ID} -repositories ${ROOT_URL}/${JDK_PACKAGE}/ -installationDirectory ${WAS_LOCATION}/ -installFixes none -acceptLicense -sP -preferences com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=false,com.ibm.cic.common.core.preferences.searchForUpdates=false,com.ibm.cic.common.core.preferences.keepFetchedFiles=false
  if [[ $? -eq 0 ]]; then
    logInfo "- upgrade du JDK WebSphere acheve avec succes."
    ${WAS_LOCATION}/bin/managesdk.sh -listAvailable

    logInfo "- forcer les profiles a utiliser un jdk 1.7 au lieu du 1.6..."
    ${WAS_LOCATION}/bin/managesdk.sh -setCommandDefault -sdkName 1.7.1_${WASMODE}
    ${WAS_LOCATION}/bin/managesdk.sh -setNewProfileDefault -sdkName 1.7.1_${WASMODE}
    if [[ $? -eq 0 ]]; then
      logInfo "- upgrade du JDK pour les profiles acheve avec succes."
      ${WAS_LOCATION}/bin/managesdk.sh -getNewProfileDefault -verbose
      ${WAS_LOCATION}/bin/managesdk.sh -getCommandDefault -verbose
    else
      logError 37 "l'upgrade du JDK websphere n'a pas fonctionne correctement..."
    fi
  else
    logError 38 "l'upgrade du JDK websphere n'a pas fonctionne correctement..."
  fi

}

#--- Permet de changer le JDK par defaut de WAS pour le SDK 7 -------------
function doForceJDK6
{

  WASMODE=$( getAttribute "//packaging/websphere/@mode" )
  WAS_LOCATION=$( getWasLocation )

  logVar "WAS_LOCATION" ${WAS_LOCATION}
  logVar "WASMODE" ${WASMODE}

  logInfo "- forcer WAS a utiliser le JDK 6 pour s'executer"

  logInfo "- forcer les profiles a utiliser un jdk 1.6..."
  ${WAS_LOCATION}/bin/managesdk.sh -setCommandDefault -sdkName 1.6_${WASMODE}
  ${WAS_LOCATION}/bin/managesdk.sh -setNewProfileDefault -sdkName 1.6_${WASMODE}
  if [[ $? -eq 0 ]]; then
    logInfo "- downgrade du JDK pour les profiles acheve avec succes."
    ${WAS_LOCATION}/bin/managesdk.sh -getNewProfileDefault -verbose
    ${WAS_LOCATION}/bin/managesdk.sh -getCommandDefault -verbose
  else
    logError 37 "le downgrade du JDK websphere n'a pas fonctionne correctement..."
  fi

}

#--- Creation d'un profile (non node agent) -------------------------------
function doCreateProfile
{

  SRV_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`

  WASVERSION=$( getAttribute "//packaging/websphere/@version" )
  CELL_NAME=$( getAttribute "//cellule/@name" )
  IS_SECURE=$( getAttribute "//composition/servers/server[@name='${SRV_NAME}']/@secure" )
  SRV_PROFILE=$( getAttribute "//composition/servers/server[@name='${SRV_NAME}']/@profile" )
  SRV_OFFSET=$( getAttribute "//composition/servers/server[@name='${SRV_NAME}']/@offsetPorts" )
  NODE_NAME=$( getAttribute "//composition/servers/server[@name='${SRV_NAME}']/@nodeName" )

  # quel est le nom du noeud associe ?
  if [[ $SRV_NAME = "dmgr" ]]; then
    NODE_NAME=`echo "${CELL_NAME}_node" | tr '[:upper:]' '[:lower:]'`
  elif [[ $SRV_NAME = "jobmgr" ]]; then
    NODE_NAME=`echo "${CELL_NAME}_jobmgr_node" | tr '[:upper:]' '[:lower:]'`
  elif [[ $SRV_NAME = "adminagent" ]]; then
    NODE_NAME=`echo "${SHORT_HOSTNAME}_admin_node" | tr '[:upper:]' '[:lower:]'`
  else
    if [[ $NODE_NAME = "" ]]; then
      NODE_NAME=$( getAttribute "//composition/nodes/node[@hostName='${HOSTNAME}']/@name" )
	fi
  fi

  WAS_LOCATION=$( getWasLocation )

  WAS_CA_ALIAS=$( getWasCAAlias )
  WAS_CA_PATH=$( getWasCAPath )
  WAS_CA_PWD=$( getWasCAPassword )

  IS_DMGR_PROFILE=0
  # cas particulier des profiles administratif
  if [[ $SRV_NAME = "adminagent" ]] || [[ $SRV_NAME = "jobmgr" ]] || [[ $SRV_NAME = "dmgr" ]]; then
    IS_SECURE="true"
    SRV_PROFILE="${SRV_NAME}"
    SRV_OFFSET=0
  fi

  WAS_PKEY_ALIAS=$( getWasPKAlias "${SRV_NAME}" )
  WAS_PKEY_PATH=$( getWasPKPath "${SRV_NAME}" )
  WAS_PKEY_PWD=$( getWasPKPassword "${SRV_NAME}" )

  # juste utilise pour l'appel initial a manageprofiles -create,
  # surcharge ensuite lors de l'appel de l'option "secure"
  ADM_USR_NAME="admin"
  ADM_USR_PSWD="SA3j39AP"

  # calcul du port SOAP en fonction du template de profile et de l'offset...
  SOAP_PORT=$( getAttribute "//profiles/profile[@name='${SRV_PROFILE}']/ports/port[@name='SOAP_CONNECTOR_ADDRESS']/@value" )
  let SOAP_PORT=SOAP_PORT+SRV_OFFSET

  # rechercher le host du DMGR et son port SOAP
  DMGR_HOSTNAME=$( getAttribute "//composition/dmgr/@hostName" )
  DMGR_SOAP_PORT=$( getAttribute "//composition/dmgr/@soapPort" )

  # cas particulier pour les adminagent/nodeagent : certificat depend du nom du noeud et pas du serveur...
  if [[ $SRV_NAME = "adminagent" ]] || [[ $SRV_NAME = "nodeagent" ]] || [[ $SRV_NAME = "odrnode" ]]; then
    WAS_PKEY_ALIAS=$( getWasPKAlias "${NODE_NAME}" )
    WAS_PKEY_PATH=$( getWasPKPath "${NODE_NAME}" )
    WAS_PKEY_PWD=$( getWasPKPassword "${NODE_NAME}" )
  fi

  # afficher les constantes
  logVar "WASVERSION" ${WASVERSION}
  logVar "WAS_LOCATION" ${WAS_LOCATION}
  logVar "CELL_NAME" ${CELL_NAME}
  logVar "NODE_NAME" ${NODE_NAME}
  logVar "SRV_NAME" ${SRV_NAME}
  logVar "IS_SECURE" ${IS_SECURE}
  logVar "SRV_PROFILE" ${SRV_PROFILE}
  logVar "SRV_OFFSET" ${SRV_OFFSET}
  logVar "SOAP_PORT" ${SOAP_PORT}
  logVar "DMGR_HOSTNAME" ${DMGR_HOSTNAME}
  logVar "DMGR_SOAP_PORT" ${DMGR_SOAP_PORT}
  logVar "DMGR_NAME" ${DMGR_NAME}
  logVar "ADM_USR_NAME" ${ADM_USR_NAME}
  logVar "WAS_PKEY_ALIAS" ${WAS_PKEY_ALIAS}
  logVar "WAS_PKEY_PATH" ${WAS_PKEY_PATH}
  logVar "WAS_PKEY_PWD" ${WAS_PKEY_PWD}
  #logVar "ADM_USR_PSWD" ${ADM_USR_PSWD}

  logInfo "- nettoyage des profiles..."
  ${WAS_LOCATION}/bin/manageprofiles.sh -validateAndUpdateRegistry

  logInfo "- creation property file pour les ports du profile"
  getProfilePorts "${SRV_PROFILE}" "${SRV_OFFSET}" "/tmp/ports.properties"

  logInfo "- creation du profile ${SRV_NAME} pour le serveur ${HOSTNAME}"
  mkdir -p ${WAS_LOCATION}/profiles
  if [[ ${SRV_NAME} == 'jobmgr' ]]; then
    ${WAS_LOCATION}/bin/manageprofiles.sh -create \
                                          -templatePath ${WAS_LOCATION}/profileTemplates/management \
                                          -serverType JOB_MANAGER \
                                          -profileName ${SRV_NAME} \
                                          -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} \
                                          -cellName ${CELL_NAME} \
                                          -nodeName ${NODE_NAME} \
                                          -hostName ${HOSTNAME} \
                                          -adminUserName ${ADM_USR_NAME} \
                                          -adminPassword ${ADM_USR_PSWD} \
                                          -enableAdminSecurity true \
                                          -importSigningCertKSAlias ${WAS_CA_ALIAS} \
                                          -importSigningCertKS ${WAS_CA_PATH} \
                                          -importSigningCertKSPassword ${WAS_CA_PWD} \
                                          -importSigningCertKSType PKCS12 \
                                          -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} \
                                          -importPersonalCertKS ${WAS_PKEY_PATH} \
                                          -importPersonalCertKSPassword ${WAS_PKEY_PWD} \
                                          -importPersonalCertKSType PKCS12 \
                                          -keyStorePassword ${WAS_PKEY_PWD} \
                                          -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
  elif [[ ${SRV_NAME} == 'adminagent' ]]; then
    ${WAS_LOCATION}/bin/manageprofiles.sh -create \
                                          -templatePath ${WAS_LOCATION}/profileTemplates/management \
                                          -serverType ADMIN_AGENT \
                                          -profileName ${HOSTNAME}_${SRV_NAME} \
                                          -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} \
                                          -cellName ${CELL_NAME} \
                                          -nodeName ${NODE_NAME} \
                                          -hostName ${HOSTNAME} \
                                          -adminUserName ${ADM_USR_NAME} \
                                          -adminPassword ${ADM_USR_PSWD} \
                                          -enableAdminSecurity true \
                                          -importSigningCertKSAlias ${WAS_CA_ALIAS} \
                                          -importSigningCertKS ${WAS_CA_PATH} \
                                          -importSigningCertKSPassword ${WAS_CA_PWD} \
                                          -importSigningCertKSType PKCS12 \
                                          -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} \
                                          -importPersonalCertKS ${WAS_PKEY_PATH} \
                                          -importPersonalCertKSPassword ${WAS_PKEY_PWD} \
                                          -importPersonalCertKSType PKCS12 \
                                          -keyStorePassword ${WAS_PKEY_PWD} \
                                          -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
  elif [[ ${SRV_NAME} == 'dmgr' ]]; then
    ${WAS_LOCATION}/bin/manageprofiles.sh -create \
                                          -templatePath ${WAS_LOCATION}/profileTemplates/management \
                                          -serverType DEPLOYMENT_MANAGER \
                                          -profileName ${SRV_NAME} \
                                          -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} \
                                          -cellName ${CELL_NAME} \
                                          -nodeName ${NODE_NAME} \
                                          -hostName ${HOSTNAME} \
                                          -adminUserName ${ADM_USR_NAME} \
                                          -adminPassword ${ADM_USR_PSWD} \
                                          -enableAdminSecurity true \
                                          -importSigningCertKSAlias ${WAS_CA_ALIAS} \
                                          -importSigningCertKS ${WAS_CA_PATH} \
                                          -importSigningCertKSPassword ${WAS_CA_PWD} \
                                          -importSigningCertKSType PKCS12 \
                                          -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} \
                                          -importPersonalCertKS ${WAS_PKEY_PATH} \
                                          -importPersonalCertKSPassword ${WAS_PKEY_PWD} \
                                          -importPersonalCertKSType PKCS12 \
                                          -keyStorePassword ${WAS_PKEY_PWD} \
                                          -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
  else
    # attention : on doit determiner si le profile a creer est une profile standalone ou pas...
    # car si ce n'est pas une profile standalone, il sera cree par script jython lors de l'appel
    # a "ConfigureCell.py"... et pas maintenant.
    TST=`${WAS_LOCATION}/bin/wsadmin.sh -host ${DMGR_HOSTNAME} -port ${DMGR_SOAP_PORT} -conntype SOAP -lang jython -c "'${NODE_NAME}' in map(lambda x: AdminConfig.showAttribute(x,'name'), AdminConfig.list('Node').split(lineSeparator))" | tail -1`
    if [[ $TST -gt 0 ]]; then
      logError 44 "${SRV_NAME} est associe au node ${NODE_NAME} qui est un noeud manage. le profile n'est donc pas un profile standalone. le serveur sera cree lors de l'appel a 'configure <project> configure cell'. operation annulee."
    fi
    # seuls les profiles purement "standalone" peuvent etre cree en "non secure"
    # en "non secure", on applique le tunning des performances "std" et non pas celui de prod.
    if [[ ${IS_SECURE} == 'true' ]]; then
      ${WAS_LOCATION}/bin/manageprofiles.sh -create \
                                            -templatePath ${WAS_LOCATION}/profileTemplates/default \
                                            -profileName ${SRV_NAME} \
                                            -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} \
                                            -cellName ${CELL_NAME} \
                                            -nodeName ${NODE_NAME} \
                                            -serverName ${SRV_NAME} \
                                            -hostName ${HOSTNAME} \
                                            -adminUserName ${ADM_USR_NAME} \
                                            -adminPassword ${ADM_USR_PSWD} \
                                            -enableAdminSecurity true \
                                            -importSigningCertKSAlias ${WAS_CA_ALIAS} \
                                            -importSigningCertKS ${WAS_CA_PATH} \
                                            -importSigningCertKSPassword ${WAS_CA_PWD} \
                                            -importSigningCertKSType PKCS12 \
                                            -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} \
                                            -importPersonalCertKS ${WAS_PKEY_PATH} \
                                            -importPersonalCertKSPassword ${WAS_PKEY_PWD} \
                                            -importPersonalCertKSType PKCS12 \
                                            -keyStorePassword ${WAS_PKEY_PWD} \
                                            -applyPerfTuningSetting peak \
                                            -omitAction defaultAppDeployAndConfig deployIVTApplication \
                                            -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
    else
      ${WAS_LOCATION}/bin/manageprofiles.sh -create \
                                            -templatePath ${WAS_LOCATION}/profileTemplates/default \
                                            -profileName ${SRV_NAME} \
                                            -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} \
                                            -cellName ${CELL_NAME} \
                                            -nodeName ${NODE_NAME} \
                                            -serverName ${SRV_NAME} \
                                            -hostName ${HOSTNAME} \
                                            -enableAdminSecurity false \
                                            -importSigningCertKSAlias ${WAS_CA_ALIAS} \
                                            -importSigningCertKS ${WAS_CA_PATH} \
                                            -importSigningCertKSPassword ${WAS_CA_PWD} \
                                            -importSigningCertKSType PKCS12 \
                                            -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} \
                                            -importPersonalCertKS ${WAS_PKEY_PATH} \
                                            -importPersonalCertKSPassword ${WAS_PKEY_PWD} \
                                            -importPersonalCertKSType PKCS12 \
                                            -keyStorePassword ${WAS_PKEY_PWD} \
                                            -applyPerfTuningSetting standard \
                                            -omitAction defaultAppDeployAndConfig deployIVTApplication \
                                            -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
    fi
  fi
  CHK_TST=`grep -c "INSTCONFSUCCESS" /tmp/install-out.log`
  if [[ ${CHK_TST} -eq 0 ]]; then
    cat /tmp/install-out.log
    cat /tmp/install-err.log
    logError 42 "il y a eu un probleme sur l'installation du profile ${SRV_NAME} ! arret de la procedure..."
  fi

  #rm /tmp/ports.properties

  logInfo "- replacer securite sur les fichiers non executables"
  for p in `ls -1 ${WAS_LOCATION}/profiles/${SRV_NAME} | grep -v "bin"`; do
    find ${WAS_LOCATION}/profiles/${SRV_NAME}/${p} -type f -exec chmod 640 {} \;
  done

  logInfo "- generation du fichier soap file pour ${SRV_NAME}"
  cat > ${WAS_LOCATION}/profiles/${SRV_NAME}/properties/soap.client.props <<ENDL
com.ibm.SOAP.securityEnabled=false
com.ibm.SOAP.loginUserid=${ADM_USR_NAME}
com.ibm.SOAP.loginPassword=${ADM_USR_PSWD}
com.ibm.SOAP.loginSource=prompt
com.ibm.SOAP.requestTimeout=180
com.ibm.ssl.alias=DefaultSSLSettings
ENDL
  chmod 600 ${WAS_LOCATION}/profiles/${SRV_NAME}/properties/soap.client.props
  ${WAS_LOCATION}/bin/PropFilePasswordEncoder.sh ${WAS_LOCATION}/profiles/${SRV_NAME}/properties/soap.client.props com.ibm.SOAP.loginPassword

  logInfo "- demarrage de ${SRV_NAME} sur ${HOSTNAME}"
  ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/startServer.sh ${SRV_NAME}
  if [[ $? -ne 0 ]]; then
    logError 44 "${SRV_NAME} n'a pas reussi a demarrer... arret de la procedure."
  fi
  logInfo "${SRV_NAME} est demarre."

  logInfo "operation completed successfully."
}

#--- Creation d'un profile node agent -------------------------------------
function doCreateNodeProfile
{

  NODE_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`

  WASVERSION=$( getAttribute "//packaging/websphere/@version" )
  CELL_NAME=$( getAttribute "//cellule/@name" )
  SRV_NAME="nodeagent"
  SRV_PROFILE="nodeagent"
  SRV_OFFSET=$( getAttribute "//composition/nodes/node[@name='${NODE_NAME}']/@offsetPorts" )

  WAS_LOCATION=$( getWasLocation )

  WAS_CA_ALIAS=$( getWasCAAlias )
  WAS_CA_PATH=$( getWasCAPath )
  WAS_CA_PWD=$( getWasCAPassword )

  WAS_PKEY_ALIAS=$( getWasPKAlias "${NODE_NAME}" )
  WAS_PKEY_PATH=$( getWasPKPath "${NODE_NAME}" )
  WAS_PKEY_PWD=$( getWasPKPassword "${NODE_NAME}" )

  # juste utilise pour l'appel initial a manageprofiles -create,
  # surcharge ensuite lors de l'appel de l'option "secure"
  ADM_USR_NAME="admin"
  ADM_USR_PSWD="SA3j39AP"

  # calcul du port SOAP en fonction du template de profile et de l'offset...
  SOAP_PORT=$( getAttribute "//profiles/profile[@name='${SRV_PROFILE}']/ports/port[@name='SOAP_CONNECTOR_ADDRESS']/@value" )
  let SOAP_PORT=SOAP_PORT+SRV_OFFSET

  # rechercher le host du DMGR et son port SOAP
  DMGR_HOSTNAME=$( getAttribute "//composition/dmgr/@hostName" )
  DMGR_SOAP_PORT=$( getAttribute "//composition/dmgr/@soapPort" )

  # afficher les constantes
  logVar "WASVERSION" ${WASVERSION}
  logVar "WAS_LOCATION" ${WAS_LOCATION}
  logVar "CELL_NAME" ${CELL_NAME}
  logVar "NODE_NAME" ${NODE_NAME}
  logVar "SRV_NAME" ${SRV_NAME}
  logVar "SRV_PROFILE" ${SRV_PROFILE}
  logVar "SRV_OFFSET" ${SRV_OFFSET}
  logVar "SOAP_PORT" ${SOAP_PORT}
  logVar "DMGR_HOSTNAME" ${DMGR_HOSTNAME}
  logVar "DMGR_SOAP_PORT" ${DMGR_SOAP_PORT}
  logVar "DMGR_NAME" ${DMGR_NAME}
  logVar "ADM_USR_NAME" ${ADM_USR_NAME}
  logVar "WAS_PKEY_ALIAS" ${WAS_PKEY_ALIAS}
  logVar "WAS_PKEY_PATH" ${WAS_PKEY_PATH}
  logVar "WAS_PKEY_PWD" ${WAS_PKEY_PWD}
  #logVar "ADM_USR_PSWD" ${ADM_USR_PSWD}

  logInfo "- nettoyage des profiles..."
  ${WAS_LOCATION}/bin/manageprofiles.sh -validateAndUpdateRegistry

  logInfo "- creation property file pour les ports du profile"
  getProfilePorts "${SRV_PROFILE}" "${SRV_OFFSET}" "/tmp/ports.properties"

  logInfo "- creation du profile ${NODE_NAME} pour le serveur ${HOSTNAME}"
  mkdir -p ${WAS_LOCATION}/profiles
  echo ">>> Vous devez a present entrer les credentials vous permettant de vous connecter sur le DMGR..."
  read DMGR_ADM_USR_NAME?'> admin user ? '
  stty -echo
  printf "> admin password ? "
  read DMGR_ADM_USR_PSWD
  stty echo
  printf "\n"
  logInfo "- creation du profile ${NODE_NAME} pour le serveur ${HOSTNAME} en cours..."
  ${WAS_LOCATION}/bin/manageprofiles.sh -create \
                                        -templatePath ${WAS_LOCATION}/profileTemplates/managed \
                                        -profileName ${NODE_NAME} \
                                        -profilePath ${WAS_LOCATION}/profiles/${NODE_NAME} \
                                        -cellName tmp_${CELL_NAME} \
                                        -nodeName ${NODE_NAME} \
                                        -hostName ${HOSTNAME} \
                                        -adminUserName ${ADM_USR_NAME} \
                                        -adminPassword ${ADM_USR_PSWD} \
                                        -enableAdminSecurity true \
                                        -importSigningCertKSAlias ${WAS_CA_ALIAS} \
                                        -importSigningCertKS ${WAS_CA_PATH} \
                                        -importSigningCertKSPassword ${WAS_CA_PWD} \
                                        -importSigningCertKSType PKCS12 \
                                        -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} \
                                        -importPersonalCertKS ${WAS_PKEY_PATH} \
                                        -importPersonalCertKSPassword ${WAS_PKEY_PWD} \
                                        -importPersonalCertKSType PKCS12 \
                                        -keyStorePassword ${WAS_PKEY_PWD} \
                                        -dmgrHost ${DMGR_HOSTNAME} \
                                        -dmgrPort ${DMGR_SOAP_PORT} \
                                        -dmgrAdminUserName ${DMGR_ADM_USR_NAME} \
                                        -dmgrAdminPassword ${DMGR_ADM_USR_PSWD} \
                                        -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
  CHK_TST=`grep -c "INSTCONFSUCCESS" /tmp/install-out.log`
  if [[ ${CHK_TST} -eq 0 ]]; then
    cat /tmp/install-out.log
    cat /tmp/install-err.log
    logError 42 "il y a eu un probleme sur l'installation du profile ${NODE_NAME} ! arret de la procedure..."
  fi

  #rm /tmp/ports.properties

  ${WAS_LOCATION}/profiles/${NODE_NAME}/bin/stopNode.sh

  logInfo "- replacer securite sur les fichiers non executables"
  for p in `ls -1 ${WAS_LOCATION}/profiles/${NODE_NAME} | grep -v "bin"`; do
    find ${WAS_LOCATION}/profiles/${NODE_NAME}/${p} -type f -exec chmod 640 {} \;
  done

  logInfo "- generation du fichier soap file pour ${SRV_NAME}"
  cat > ${WAS_LOCATION}/profiles/${NODE_NAME}/properties/soap.client.props <<ENDL
com.ibm.SOAP.securityEnabled=false
com.ibm.SOAP.loginUserid=${ADM_USR_NAME}
com.ibm.SOAP.loginPassword=${ADM_USR_PSWD}
com.ibm.SOAP.loginSource=prompt
com.ibm.SOAP.requestTimeout=180
com.ibm.ssl.alias=DefaultSSLSettings
ENDL
  chmod 600 ${WAS_LOCATION}/profiles/${NODE_NAME}/properties/soap.client.props
  ${WAS_LOCATION}/bin/PropFilePasswordEncoder.sh ${WAS_LOCATION}/profiles/${NODE_NAME}/properties/soap.client.props com.ibm.SOAP.loginPassword

  logInfo "- demarrage du ${SRV_NAME} de ${NODE_NAME} sur ${HOSTNAME}"
  ${WAS_LOCATION}/profiles/${NODE_NAME}/bin/startNode.sh
  if [[ $? -ne 0 ]]; then
    logError 44 "${NODE_NAME} n'a pas reussi a demarrer... arret de la procedure."
  fi
  logInfo "${NODE_NAME} est demarre."

  logInfo "operation completed successfully."
}

#--- Federer un profile encore en standalone ------------------------------
function doRegisterProfile
{

  SRV_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`
  NODE_NAME=`echo "${2}" | tr '[:upper:]' '[:lower:]'`

  WAS_LOCATION=$( getWasLocation )
  DMGR_HOSTNAME=$( getAttribute "//composition/dmgr/@hostName" )
  DMGR_SOAP_PORT=$( getAttribute "//composition/dmgr/@soapPort" )

  logVar "WAS_LOCATION" ${WAS_LOCATION}
  logVar "SRV_NAME" ${SRV_NAME}
  logVar "NODE_NAME" ${NODE_NAME}
  logVar "DMGR_HOSTNAME" ${DMGR_HOSTNAME}
  logVar "DMGR_SOAP_PORT" ${DMGR_SOAP_PORT}

  echo ">>> pour enregistrer un profile vous devez entrez votre identifiant d'administration..."
  read ADM_USR_NAME?'> votre admin user ? '
  stty -echo
  printf "> votre admin password ? "
  read ADM_USR_PSWD
  stty echo
  printf "\n"

  logInfo "- enregistrement de ${SRV_NAME} avec ${NODE_NAME}"
  if [[ -x ${WAS_LOCATION}/profiles/${NODE_NAME}/bin/registerNode.sh ]]; then
    ${WAS_LOCATION}/profiles/${NODE_NAME}/bin/registerNode.sh -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} -username ${ADM_USR_NAME} -password ${ADM_USR_PSWD}
    if [[ $? -ne 0 ]]; then
      logError 51 "(RC:$?) ${SRV_NAME} non enregistre avec ${NODE_NAME}. Merci de consulter les logs precedent pour plus d'information... arret de la procedure."
    else
      logInfo "${SRV_NAME} correctement enregistre avec ${NODE_NAME}"
      logInfo "${SRV_NAME} doit a present etre redemarre..."
      ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/startServer.sh ${SRV_NAME}
      if [[ $? -ne 0 ]]; then
        logError 52 "(RC:$?) ${SRV_NAME} n'a pas reussi a demarrer... arret de la procedure."
      else
        logInfo "${SRV_NAME} est correctement demarre."
      fi
    fi
  else
    logError 50 "(RC:$?) aucun agent administratif n'est encore defini. vous devez en definir un au prealable. arret de la procedure."
  fi

}

#--- Securiser un profile -------------------------------------------------
function doSecureProfile
{

  SRV_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`

  WASVERSION=$( getAttribute "//packaging/websphere/@version" )
  SRV_PROFILE=$( getAttribute "//composition/servers/server[@name='${SRV_NAME}']/@profile" )
  SRV_OFFSET=$( getAttribute "//composition/servers/server[@name='${SRV_NAME}']/@offsetPorts" )

  WAS_LOCATION=$( getWasLocation )

  # pour les profiles administratifs
  if [[ $SRV_PROFILE = "" ]]; then
    SRV_PROFILE="$SRV_NAME"
  fi
  if [[ $SRV_OFFSET = "" ]]; then
    SRV_OFFSET=0
  fi

  # calcul du port SOAP en fonction du template de profile et de l'offset
  SOAP_PORT=$( getAttribute "//profiles/profile[@name='${SRV_PROFILE}']/ports/port[@name='SOAP_CONNECTOR_ADDRESS']/@value" )
  let SOAP_PORT=SOAP_PORT+SRV_OFFSET

  logVar "WASVERSION" ${WASVERSION}
  logVar "WAS_LOCATION" ${WAS_LOCATION}
  logVar "SRV_NAME" ${SRV_NAME}
  logVar "SOAP_PORT" ${SOAP_PORT}

  logInfo "- configuration de la securite pour le serveur ${SRV_NAME}"
  cd ${ROOT_PRODUCTS}/scripts/configure/py/
  ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/wsadmin.sh -host ${HOSTNAME} -port ${SOAP_PORT} -conntype SOAP -lang jython -f Secure.py --project ${PROJECT}
  if [[ $? -ne 0 ]]; then
    logError 45 "(RC:$?) securisation de ${SRV_NAME} terminee en erreur : voir les logs precedents... arret de la procedure."
  fi
  cd - > /dev/null

  logInfo "- redemarrage de ${SRV_NAME} sur ${HOSTNAME} pour activer le LDAP administratif"
  ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/stopServer.sh ${SRV_NAME}
  if [[ $? -ne 0 ]]; then
    logError 46 "(RC:$?) ${SRV_NAME} ne parvient pas a s'arreter... verifiez les logs. arret de la procedure."
  fi

  echo ">>> Vous devez a present entrer un administrateur existant sur le LDAP et disposant des droits d'admin WAS. habituellement, cet utilisateur est admwsh..."
  read ADM_USR_NAME?'> admin user ? '
  stty -echo
  printf "> admin password ? "
  read ADM_USR_PSWD
  stty echo
  printf "\n"

  cat > ${WAS_LOCATION}/profiles/${SRV_NAME}/properties/soap.client.props <<ENDL
com.ibm.SOAP.securityEnabled=false
com.ibm.SOAP.loginUserid=${ADM_USR_NAME}
com.ibm.SOAP.loginPassword=${ADM_USR_PSWD}
com.ibm.SOAP.loginSource=prompt
com.ibm.SOAP.requestTimeout=180
com.ibm.ssl.alias=DefaultSSLSettings
ENDL
  ${WAS_LOCATION}/bin/PropFilePasswordEncoder.sh ${WAS_LOCATION}/profiles/${SRV_NAME}/properties/soap.client.props com.ibm.SOAP.loginPassword

  ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/startServer.sh ${SRV_NAME}
  if [[ $? -ne 0 ]]; then
    logError 47 "(RC:$?) ${SRV_NAME} n'a pas reussi a demarrer... arret de la procedure."
  else
    logInfo "la configuration de securite de base de ${SRV_NAME} est realisee, et il est correctement demarre."
  fi
}

#--- Application de la configuration websphere sur une cellule ------------
function doConfigureCell
{

  DMGR_HOST_PORT=$( getAttribute "//composition/dmgr/@hostName" )
  DMGR_SOAP_PORT=$( getAttribute "//composition/dmgr/@soapPort" )

  WAS_LOCATION=$( getWasLocation )

  logVar "DMGR_HOST_PORT" ${DMGR_HOST_PORT}
  logVar "DMGR_SOAP_PORT" ${DMGR_SOAP_PORT}
  logVar "WAS_LOCATION" ${WAS_LOCATION}

  logInfo "- configuration de la cellule"
  cd ${ROOT_PRODUCTS}/scripts/configure/py/
  ${WAS_LOCATION}/bin/wsadmin.sh -host ${DMGR_HOST_PORT} -port ${DMGR_SOAP_PORT} -conntype SOAP -profileName dmgr -lang jython -f ${ROOT_PRODUCTS}/scripts/configure/py/ConfigureCell.py --project ${PROJECT}
  if [[ $? -ne 0 ]]; then
    logError 50 "configuration de la cellule terminee en erreur : voir les logs precedents... arret de la procedure."
  fi
  cd - > /dev/null

}

#==========================================================================
# FIN DE DEFINITION DES FONCTIONS                                         =
#==========================================================================
logTrace "Chargement de configure-was.sh (version ${LIB_VERSION}) effectue."
