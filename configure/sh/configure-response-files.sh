#!/bin/ksh
##########################################
#                                        #
#   auteur : Francois Colombo            #
#                                        #
##########################################

#==========================================================================
# FONCTIONS                                                               =
#==========================================================================

#--- Response file pour WebSphere Application Server ----------------------
function doCreateWASResponseFile
{
}

#--- Response file pour IBM HTTP Server -----------------------------------
function doCreateIHSResponseFile
{
}

#--- Response file pour WebSphere Customization Toolkit -------------------
function doCreateWCTResponseFile
{
}

#--- Response file pour le Plugin WebSphere -------------------------------
function doCreatePLGResponseFile
{
}



  ROOT_URL=$( getAttribute "//packaging/packages/@rootUrl" )
  IIM_PACKAGE=$( getAttribute "//packaging/iim/@path" )

  logVar "ROOT_URL" ${ROOT_URL}
  logVar "IIM_PACKAGE" ${IIM_PACKAGE}

  # commencer par installer IIM si necessaire (obligatoire pour WAS >= 7.0 !)
  if [[ ! -x ${ROOT_PRODUCTS}/IIM/installer/eclipse/IBMIM ]]; then
    logInfo "- telechargement du package d'installation de IIM..."
    cp ${ROOT_URL}/${IIM_PACKAGE} /tmp/iim.zip
    mkdir -p /tmp/IIM
    cd /tmp/IIM
    unzip /tmp/iim.zip
    cd -
    rm /tmp/iim.zip
    IIM_PATH="/tmp/IIM"

    logInfo "- IBMIM n'est pas present, installation necessaire au prealable..."
    if [[ ! -x ${IIM_PATH}/userinstc ]]; then
      logError 30 "installation du package 'IBM Installation Manager' impossible! userinstc doit etre executable pour une installation en mode silencieux..."
    fi
    if [[ ! -w ${IIM_PATH}/install.xml ]]; then
      logError 31 "installation du package 'IBM Installation Manager' impossible! install.xml doit etre writable pour une installation en mode silencieux..."
    fi
    T=`egrep -c "com.ibm.cic.agent.+version='" ${IIM_PATH}/install.xml`
    if [[ $T -eq 0 ]]; then
      logError 32 "installation du package 'IBM Installation Manager' impossible! install.xml ne contient pas le code produit 'com.ibm.cic.agent'..."
    fi
    V=`egrep "com.ibm.cic.agent.+version='" ${IIM_PATH}/install.xml | awk 'sub(/.*version=./,"")' | cut -d\' -f1`
    cat > ${IIM_PATH}/install.xml <<ENDL
<?xml version="1.0" encoding="UTF-8"?>
<agent-input clean='true' temporary='true'>

 <profile kind='self' installLocation='${ROOT_PRODUCTS}/IIM/installer' id='IBM Installation Manager'>
  <data key='eclipseLocation' value='${ROOT_PRODUCTS}/IIM/installer'/>
 </profile>

 <server>
  <repository location='${IIM_PATH}'/>
 </server>

 <install>
  <offering profile='IBM Installation Manager' features='agent_core,agent_jre' id='com.ibm.cic.agent' version='${V}'/>
 </install>

</agent-input>
ENDL
    ${IIM_PATH}/userinst --launcher.ini ${IIM_PATH}/user-silent-install.ini -dataLocation ${ROOT_PRODUCTS}/IIM/data -showProgress -acceptLicense
    logInfo "- test de l'installation de IBMIM..."
    if [[ -x ${ROOT_PRODUCTS}/IIM/installer/eclipse/IBMIM ]]; then
      echo "adddisableOSPrereqChecking=true" >> ${ROOT_PRODUCTS}/IIM/installer/eclipse/configuration/config.ini
      ${ROOT_PRODUCTS}/IIM/installer/eclipse/IBMIM -version -silent -nosplash
    else
      logError 33 "installation du package 'IBM Installation Manager' impossible! il y a eu un probleme sur l'installation de IBMIM dans le repertoire ${ROOT_PRODUCTS}/IIM..."
    fi
    logInfo "- nettoyage des fichiers temporaires"
    rm -fr /tmp/IIM
  fi
}

#--- Ceci permet d'utiliser IIM pour realiser une install -----------------
function doInstallWithIIM
{

  RSPPATH="${1}"
  TSTPATH="${2}"
  VERSION="${3}"

  logInfo "- installation du produit '' depuis le chemin ''"
  ${ROOT_PRODUCTS}/IIM/installer/eclipse/IBMIM -input ${RSPPATH} -silent -showProgress -nosplash -acceptLicense

  logInfo "- controle de l'installation"
  if [[ -s ${TSTPATH} ]]; then
    logInfo "=== le produit est bien installe."
  else
    logError 34 "il y a eu un probleme sur l'installation du produit ! arret de la procedure..."
  fi

  logInfo "- voici la version du produit installee :"
  ${VERSION}

}





















#--- Ceci permet de realiser l'installation du moteur websphere -----------
function doInstallWAS
{

  WASVERSION=$( getAttribute "//websphere/@version" )
  WASMODE=$( getAttribute "//websphere/@mode" )
  ROOT_URL=$( getAttribute "//websphere/packages/@rootUrl" )
  IIM_PACKAGE=$( getAttribute "//websphere/packages/package[@name='iim-path']/@path" )
  WAS_PACKAGE=$( getAttribute "//websphere/packages/package[@name='was-path']/@path" )
  WAS_OFF_ID=$( getAttribute "//websphere/productKeys/productKey[@id='appsrv']/@key" )
  WAS_LOCATION=$( getWasLocation )

  logVar "WASVERSION" ${WASVERSION}
  logVar "WASMODE" ${WASMODE}
  logVar "ROOT_URL" ${ROOT_URL}
  logVar "WAS_PACKAGE" ${WAS_PACKAGE}
  logVar "IIM_PACKAGE" ${IIM_PACKAGE}
  logVar "WAS_OFF_ID" ${WAS_OFF_ID}
  logVar "WAS_LOCATION" ${WAS_LOCATION}

  logInfo "- installation du was core (binaires)"

  # commencer par installer IIM si necessaire (obligatoire pour WAS >= 7.0 !)
  if [[ ! -x ${ROOT_PRODUCTS}/IIM/installer/eclipse/IBMIM ]]; then
    logInfo "- telechargement du package d'installation de IIM..."
    cp ${ROOT_URL}/${IIM_PACKAGE} /tmp/iim.zip
    mkdir -p /tmp/IIM
    cd /tmp/IIM
    unzip /tmp/iim.zip
    cd -
    rm /tmp/iim.zip
    IIM_PATH="/tmp/IIM"

    logInfo "- IBMIM n'est pas present, installation necessaire au prealable..."
    if [[ ! -x ${IIM_PATH}/userinstc ]]; then
      logError 30 "installation du package 'IBM Installation Manager' impossible! userinstc doit etre executable pour une installation en mode silencieux..."
    fi
    if [[ ! -w ${IIM_PATH}/install.xml ]]; then
      logError 31 "installation du package 'IBM Installation Manager' impossible! install.xml doit etre writable pour une installation en mode silencieux..."
    fi
    T=`egrep -c "com.ibm.cic.agent.+version='" ${IIM_PATH}/install.xml`
    if [[ $T -eq 0 ]]; then
      logError 32 "installation du package 'IBM Installation Manager' impossible! install.xml ne contient pas le code produit 'com.ibm.cic.agent'..."
    fi
    V=`egrep "com.ibm.cic.agent.+version='" ${IIM_PATH}/install.xml | awk 'sub(/.*version=./,"")' | cut -d\' -f1`
    cat > ${IIM_PATH}/install.xml <<ENDL
<?xml version="1.0" encoding="UTF-8"?>
<agent-input clean='true' temporary='true'>

 <profile kind='self' installLocation='${ROOT_PRODUCTS}/IIM/installer' id='IBM Installation Manager'>
  <data key='eclipseLocation' value='${ROOT_PRODUCTS}/IIM/installer'/>
 </profile>

 <server>
  <repository location='${IIM_PATH}'/>
 </server>

 <install>
  <offering profile='IBM Installation Manager' features='agent_core,agent_jre' id='com.ibm.cic.agent' version='${V}'/>
 </install>

</agent-input>
ENDL
    ${IIM_PATH}/userinst --launcher.ini ${IIM_PATH}/user-silent-install.ini -dataLocation ${ROOT_PRODUCTS}/IIM/data -showProgress -acceptLicense
    logInfo "- test de l'installation de IBMIM..."
    if [[ -x ${ROOT_PRODUCTS}/IIM/installer/eclipse/IBMIM ]]; then
      echo "adddisableOSPrereqChecking=true" >> ${ROOT_PRODUCTS}/IIM/installer/eclipse/configuration/config.ini
      ${ROOT_PRODUCTS}/IIM/installer/eclipse/IBMIM -version -silent -nosplash
    else
      logError 33 "installation du package 'IBM Installation Manager' impossible! il y a eu un probleme sur l'installation de IBMIM dans le repertoire ${ROOT_PRODUCTS}/IIM..."
    fi
    logInfo "- nettoyage des fichiers temporaires"
    rm -fr /tmp/IIM
  fi

  logInfo "- creation du responsefile"
  cat > /tmp/was-response.xml <<ENDL
<?xml version="1.0" encoding="UTF-8"?>
<agent-input clean='true' temporary='true'>

<server>
  <repository location='${ROOT_URL}/${WAS_PACKAGE}'/>
</server>

<install>
  <offering id='${WAS_OFF_ID}'
            profile='IBM WebSphere Application Server ${WASVERSION} ${WASMODE}bit'
            features='core.feature,ejbdeploy,thinclient,embeddablecontainer,com.ibm.sdk.6_${WASMODE}bit'
            installFixes='none'/>
</install>

<profile id='IBM WebSphere Application Server ${WASVERSION} ${WASMODE}bit'
         installLocation='${WAS_LOCATION}'>
  <data key='eclipseLocation' value='${WAS_LOCATION}'/>
  <data key='user.import.profile' value='false'/>
  <data key='cic.selector.os' value='aix'/>
  <data key='cic.selector.arch' value='ppc'/>
  <data key='cic.selector.ws' value='motif'/>
  <data key='cic.selector.nl' value='en'/>
</profile>

<preference name='com.ibm.cic.common.core.preferences.eclipseCache' value='${ROOT_PRODUCTS}/IIM/shared'/>
<preference name='com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts' value='false'/>

<preference name='com.ibm.cic.common.core.preferences.connectTimeout' value='30'/>
<preference name='com.ibm.cic.common.core.preferences.readTimeout' value='45'/>
<preference name='com.ibm.cic.common.core.preferences.downloadAutoRetryCount' value='0'/>
<preference name='offering.service.repositories.areUsed' value='true'/>
<preference name='com.ibm.cic.common.core.preferences.ssl.nonsecureMode' value='false'/>
<preference name='com.ibm.cic.common.core.preferences.http.disablePreemptiveAuthentication' value='false'/>
<preference name='http.ntlm.auth.kind' value='NTLM'/>
<preference name='http.ntlm.auth.enableIntegrated.win32' value='true'/>
<preference name='com.ibm.cic.common.core.preferences.keepFetchedFiles' value='false'/>
<preference name='PassportAdvantageIsEnabled' value='false'/>
<preference name='com.ibm.cic.common.core.preferences.searchForUpdates' value='false'/>
<preference name='com.ibm.cic.agent.ui.displayInternalVersion' value='false'/>

<preference name='com.ibm.cic.common.sharedUI.showErrorLog' value='true'/>
<preference name='com.ibm.cic.common.sharedUI.showWarningLog' value='true'/>
<preference name='com.ibm.cic.common.sharedUI.showNoteLog' value='true'/>

</agent-input>
ENDL

  logInfo "- installation du core WebSphere"
  ${ROOT_PRODUCTS}/IIM/installer/eclipse/IBMIM -input /tmp/was-response.xml -silent -showProgress -nosplash -acceptLicense

  logInfo "- controle de l'installation"
  if [[ -s ${WAS_LOCATION}/bin/startServer.sh ]]; then
    logInfo "=== le moteur est bien installe."
  else
    logError 34 "il y a eu un probleme sur l'installation du moteur dans le repertoire ${WAS_LOCATION} ! arret de la procedure..."
  fi

  logInfo "- voici la version de WebSphere Application Server installee :"
  ${WAS_LOCATION}/bin/versionInfo.sh
}

#--- Application des fixpacks sur le core WAS -----------------------------
function doUpdateWas
{

  WASVERSION=$( getAttribute "//websphere/@version" )
  WASMODE=$( getAttribute "//websphere/@mode" )
  ROOT_URL=$( getAttribute "//websphere/packages/@rootUrl" )
  WAS_PACKAGE=$( getAttribute "//websphere/packages/package[@name='wasupdate-path']/@path" )
  WAS_OFF_ID=$( getAttribute "//websphere/productKeys/productKey[@id='appsrv']/@key" )
  WAS_LOCATION=$( getWasLocation )

  logVar "WASVERSION" ${WASVERSION}
  logVar "WASMODE" ${WASMODE}
  logVar "ROOT_URL" ${ROOT_URL}
  logVar "WAS_PACKAGE" ${WAS_PACKAGE}
  logVar "WAS_OFF_ID" ${WAS_OFF_ID}
  logVar "WAS_LOCATION" ${WAS_LOCATION}

  logInfo "- mise a jour du was core (par application de fixpack)"

  TST=`${ROOT_PRODUCTS}/IIM/installer/eclipse/tools/imcl listAvailablePackages -repositories ${ROOT_URL}/${WAS_PACKAGE} | grep -c "${WAS_OFF_ID}"`
  if [[ ${TST} -ne 1 ]]; then
    logError 35 "le package ${WAS_OFF_ID} n'existe pas dans le repository ${ROOT_URL}/${WAS_PACKAGE} !"
  fi

  logInfo "- upgrade du core WebSphere..."
  ${ROOT_PRODUCTS}/IIM/installer/eclipse/tools/imcl install ${WAS_OFF_ID} -repositories ${ROOT_URL}/${WAS_PACKAGE} -installationDirectory ${WAS_LOCATION}/ -installFixes all -acceptLicense -sP -preferences com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=false,com.ibm.cic.common.core.preferences.searchForUpdates=false,com.ibm.cic.common.core.preferences.keepFetchedFiles=false
  if [[ $? -eq 0 ]]; then
    logInfo "- upgrade du core WebSphere acheve avec succes."
  else
    logError 36 "l'upgrade du core websphere n'a pas fonctionne correctement. voir logs precedents."
  fi

  ${WAS_LOCATION}/bin/versionInfo.sh

}

#--- Ceci permet de realiser l'installation du JDK 7 ----------------------
function doInstallJDK7
{

  ROOT_URL=$( getAttribute "//websphere/packages/@rootUrl" )
  JDK_PACKAGE=$( getAttribute "//websphere/packages/package[@name='sdk7-path']/@path" )
  JDK_OFF_ID=$( getAttribute "//websphere/productKeys/productKey[@id='ibmsdk']/@key" )
  WASMODE=$( getAttribute "//websphere/@mode" )
  WAS_LOCATION=$( getWasLocation )

  logVar "ROOT_URL" ${ROOT_URL}
  logVar "JDK_PACKAGE" ${JDK_PACKAGE}
  logVar "JDK_OFF_ID" ${JDK_OFF_ID}
  logVar "WAS_LOCATION" ${WAS_LOCATION}
  logVar "WASMODE" ${WASMODE}

  logInfo "- installation du jdk 7 (binaires)"
  ${ROOT_PRODUCTS}/IIM/installer/eclipse/tools/imcl install ${JDK_OFF_ID} -repositories ${ROOT_URL}/${JDK_PACKAGE} -installationDirectory ${WAS_LOCATION}

  logInfo "- controle de l'installation"
  if [[ -x ${WAS_LOCATION}/java_1.7_${WASMODE}/bin/java ]]; then
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

  WASVERSION=$( getAttribute "//websphere/@version" )
  WASMODE=$( getAttribute "//websphere/@mode" )
  ROOT_URL=$( getAttribute "//websphere/packages/@rootUrl" )
  WAS_PACKAGE=$( getAttribute "//websphere/packages/package[@name='sdk7-path']/@path" )
  SDK_OFF_ID=$( getAttribute "//websphere/productKeys/productKey[@id='ibmsdk']/@key" )
  WAS_LOCATION=$( getWasLocation )

  logVar "WASVERSION" ${WASVERSION}
  logVar "WASMODE" ${WASMODE}
  logVar "ROOT_URL" ${ROOT_URL}
  logVar "WAS_PACKAGE" ${WAS_PACKAGE}
  logVar "SDK_OFF_ID" ${SDK_OFF_ID}
  logVar "WAS_LOCATION" ${WAS_LOCATION}

  logInfo "- forcer WAS a utiliser le JDK 7 pour s'executer"

  logInfo "- upgrade du JDK de WebSphere de la version 1.6 vers la version 1.7..."
  ${ROOT_PRODUCTS}/IIM/installer/eclipse/tools/imcl install ${SDK_OFF_ID} -repositories ${ROOT_URL}/${WAS_PACKAGE}/ -installationDirectory ${WAS_LOCATION}/ -installFixes none -acceptLicense -sP -preferences com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=false,com.ibm.cic.common.core.preferences.searchForUpdates=false,com.ibm.cic.common.core.preferences.keepFetchedFiles=false
  if [[ $? -eq 0 ]]; then
    logInfo "- upgrade du JDK WebSphere acheve avec succes."
    ${WAS_LOCATION}/bin/managesdk.sh -listAvailable

    logInfo "- forcer les profiles a utiliser un jdk 1.7 au lieu du 1.6..."
    ${WAS_LOCATION}/bin/managesdk.sh -setCommandDefault -sdkName 1.7_${WASMODE}
    ${WAS_LOCATION}/bin/managesdk.sh -setNewProfileDefault -sdkName 1.7_${WASMODE}
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

#--- Installation ou mise a jour des jars des drivers JDBC ----------------
function doUpdateLibraries
{

  ROOT_URL=$( getAttribute "//websphere/packages/@rootUrl" )
  PACKAGEPATH=$( getAttribute "//websphere/libraries/library[@name='jdbc-drivers']/@path" )
  TARGETDIR=$( getAttribute "//websphere/libraries/library[@name='jdbc-drivers']/@targetDirectory" )

  logVar "ROOT_URL" ${ROOT_URL}
  logVar "PACKAGEPATH" ${PACKAGEPATH}
  logVar "TARGETDIR" ${TARGETDIR}

  logInfo "- installation dans le repertoire cible ${TARGETDIR}"
  mkdir -p ${TARGETDIR}
  cd ${TARGETDIR}
  unzip ${ROOT_URL}/${PACKAGEPATH}
  tar xvf `ls -1 *.tar`
  if [[ $? -gt 127 ]]; then
    logError 39 "l'installation des .jar ne s'est pas correctement deroulee... arret de la procedure."
  fi
  rm `ls -1 *.tar`
  cd -

}

#--- Installation ou mise a jour des jars des sharedlibs ------------------
function doUpdateSharedLibs
{

  SHARELIB_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`
  ROOT_URL=$( getAttribute "//websphere/packages/@rootUrl" )
  PACKAGEPATH=$( getAttribute "//websphere/libraries/library[@name='${SHARELIB_NAME}']/@path" )
  TARGETDIR=$( getAttribute "//websphere/libraries/library[@name='${SHARELIB_NAME}']/@targetDirectory" )

  logVar "SHARELIB_NAME" ${SHARELIB_NAME}
  logVar "ROOT_URL" ${ROOT_URL}
  logVar "PACKAGEPATH" ${PACKAGEPATH}
  logVar "TARGETDIR" ${TARGETDIR}

  logInfo "- installation des .jar de la sharedlib ${SHARELIB_NAME} vers ${TARGETDIR}"
  mkdir -p ${TARGETDIR}
  cd ${TARGETDIR}
  unzip ${ROOT_URL}/${PACKAGEPATH}
  tar xvf `ls -1 *.tar`
  if [[ $? -gt 127 ]]; then
    logError 40 "l'installation des .jar de la sharedlib ${SHARELIB_NAME} ne s'est pas correctement deroulee... arret de la procedure."
  fi
  rm `ls -1 *.tar`
  cd -

}

#--- Creation d'un profile standalone -------------------------------------
function doCreateProfile
{

  SRV_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`

  WASVERSION=$( getAttribute "//websphere/@version" )
  SOAP_PORT=$( getAttribute "//servers/server[@name='${SRV_NAME}']/@soapPort" )
  NODE_NAME=`echo "${SHORT_HOSTNAME}_${SRV_NAME}" | tr '[:upper:]' '[:lower:]'`
  CELL_NAME=$( getAttribute "//environment/@cell" )
  IS_SECURE=$( getAttribute "//environment/@secure" )
  WAS_LOCATION=$( getWasLocation )

  WAS_CA_ALIAS=$( getWasCAAlias )
  WAS_CA_PATH=$( getWasCAPath )
  WAS_CA_PWD=$( getWasCAPassword )

  WAS_PKEY_ALIAS=$( getWasPKAlias "${SRV_NAME}" )
  WAS_PKEY_PATH=$( getWasPKPath "${SRV_NAME}" )
  WAS_PKEY_PWD=$( getWasPKPassword "${SRV_NAME}" )

  # juste utilise pour l'appel initial a manageprofiles -create,
  # surcharge ensuite lors de l'appel de l'option "secure"
  ADM_USR_NAME="admin"
  ADM_USR_PSWD="SA3j39AP"

  logVar "WASVERSION" ${WASVERSION}
  logVar "WAS_LOCATION" ${WAS_LOCATION}
  logVar "SRV_NAME" ${SRV_NAME}
  logVar "CELL_NAME" ${CELL_NAME}
  logVar "IS_SECURE" ${IS_SECURE}
  logVar "SOAP_PORT" ${SOAP_PORT}
  logVar "ADM_USR_NAME" ${ADM_USR_NAME}
  #logVar "ADM_USR_PSWD" ${ADM_USR_PSWD}

  P01=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='BOOTSTRAP_ADDRESS']/@value" )
  P02=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='CELL_DISCOVERY_ADDRESS']/@value" )
  P03=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS']/@value" )
  P04=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='DataPowerMgr_inbound_secure']/@value" )
  P05=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='DCS_UNICAST_ADDRESS']/@value" )
  P06=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='IPC_CONNECTOR_ADDRESS']/@value" )
  P07=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='ORB_LISTENER_ADDRESS']/@value" )
  P08=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='OVERLAY_TCP_LISTENER_ADDRESS']/@value" )
  P09=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='OVERLAY_UDP_LISTENER_ADDRESS']/@value" )
  P10=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='SAS_SSL_SERVERAUTH_LISTENER_ADDRESS']/@value" )
  P11=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='SIB_ENDPOINT_ADDRESS']/@value" )
  P12=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='SIB_ENDPOINT_SECURE_ADDRESS']/@value" )
  P13=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='SIB_MQ_ENDPOINT_ADDRESS']/@value" )
  P14=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='SIB_MQ_ENDPOINT_SECURE_ADDRESS']/@value" )
  P15=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='SIP_DEFAULTHOST_SECURE']/@value" )
  P16=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='SIP_DEFAULTHOST']/@value" )
  P17=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='SOAP_CONNECTOR_ADDRESS']/@value" )
  P18=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='STATUS_LISTENER_ADDRESS']/@value" )
  P19=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='WC_adminhost_secure']/@value" )
  P20=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='WC_adminhost']/@value" )
  P21=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='WC_defaulthost_secure']/@value" )
  P22=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='WC_defaulthost']/@value" )
  P23=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='XDAGENT_PORT']/@value" )
  P24=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_BOOTSTRAP_ADDRESS']/@value" )
  P25=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS']/@value" )
  P26=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS']/@value" )
  P27=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_DCS_UNICAST_ADDRESS']/@value" )
  P28=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_DISCOVERY_ADDRESS']/@value" )
  P29=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_IPC_CONNECTOR_ADDRESS']/@value" )
  P30=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_IPV6_MULTICAST_DISCOVERY_ADDRESS']/@value" )
  P31=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_MULTICAST_DISCOVERY_ADDRESS']/@value" )
  P32=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_ORB_LISTENER_ADDRESS']/@value" )
  P33=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_OVERLAY_TCP_LISTENER_ADDRESS']/@value" )
  P34=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_OVERLAY_UDP_LISTENER_ADDRESS']/@value" )
  P35=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_SAS_SSL_SERVERAUTH_LISTENER_ADDRESS']/@value" )
  P36=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_SOAP_CONNECTOR_ADDRESS']/@value" )
  P37=$( getAttribute "//servers/server[@name='${SRV_NAME}']/ports/port[@name='NODE_XDAGENT_PORT']/@value" )

  logInfo "- nettoyage des profiles..."
  ${WAS_LOCATION}/bin/manageprofiles.sh -validateAndUpdateRegistry

  logInfo "- creation property file pour les ports du profile"
  cat > /tmp/ports.properties <<ENDL
BOOTSTRAP_ADDRESS=${P01}
CELL_DISCOVERY_ADDRESS=${P02}
CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=${P03}
DataPowerMgr_inbound_secure=${P04}
DCS_UNICAST_ADDRESS=${P05}
IPC_CONNECTOR_ADDRESS=${P06}
ORB_LISTENER_ADDRESS=${P07}
OVERLAY_TCP_LISTENER_ADDRESS=${P08}
OVERLAY_UDP_LISTENER_ADDRESS=${P09}
SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=${P10}
SIB_ENDPOINT_ADDRESS=${P11}
SIB_ENDPOINT_SECURE_ADDRESS=${P12}
SIB_MQ_ENDPOINT_ADDRESS=${P13}
SIB_MQ_ENDPOINT_SECURE_ADDRESS=${P14}
SIP_DEFAULTHOST_SECURE=${P15}
SIP_DEFAULTHOST=${P16}
SOAP_CONNECTOR_ADDRESS=${P17}
STATUS_LISTENER_ADDRESS=${P18}
WC_adminhost_secure=${P19}
WC_adminhost=${P20}
WC_defaulthost_secure=${P21}
WC_defaulthost=${P22}
XDAGENT_PORT=${P23}
NODE_BOOTSTRAP_ADDRESS=${P24}
NODE_CSIV2_SSL_MUTUALAUTH_LISTENER_ADDRESS=${P25}
NODE_CSIV2_SSL_SERVERAUTH_LISTENER_ADDRESS=${P26}
NODE_DCS_UNICAST_ADDRESS=${P27}
NODE_DISCOVERY_ADDRESS=${P28}
NODE_IPC_CONNECTOR_ADDRESS=${P29}
NODE_IPV6_MULTICAST_DISCOVERY_ADDRESS=${P30}
NODE_MULTICAST_DISCOVERY_ADDRESS=${P31}
NODE_ORB_LISTENER_ADDRESS=${P32}
NODE_OVERLAY_TCP_LISTENER_ADDRESS=${P33}
NODE_OVERLAY_UDP_LISTENER_ADDRESS=${P34}
NODE_SAS_SSL_SERVERAUTH_LISTENER_ADDRESS=${P35}
NODE_SOAP_CONNECTOR_ADDRESS=${P36}
NODE_XDAGENT_PORT=${P37}
ENDL

  logInfo "- creation du profile ${SRV_NAME} pour le serveur ${HOSTNAME}"
  mkdir -p ${WAS_LOCATION}/profiles
  if [[ ${SRV_NAME} == 'jobmanager' ]]; then
    ${WAS_LOCATION}/bin/manageprofiles.sh -create -templatePath ${WAS_LOCATION}/profileTemplates/management -serverType JOB_MANAGER -profileName ${SRV_NAME} -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} -cellName ${CELL_NAME} -nodeName ${NODE_NAME} -hostName ${HOSTNAME} -adminUserName ${ADM_USR_NAME} -adminPassword ${ADM_USR_PSWD} -enableAdminSecurity true -importSigningCertKSAlias ${WAS_CA_ALIAS} -importSigningCertKS ${WAS_CA_PATH} -importSigningCertKSPassword ${WAS_CA_PWD} -importSigningCertKSType PKCS12 -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} -importPersonalCertKS ${WAS_PKEY_PATH} -importPersonalCertKSPassword ${WAS_PKEY_PWD} -importPersonalCertKSType PKCS12 -keyStorePassword ${WAS_PKEY_PWD} -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
  elif [[ ${SRV_NAME} == 'adminagent' ]]; then
    ${WAS_LOCATION}/bin/manageprofiles.sh -create -templatePath ${WAS_LOCATION}/profileTemplates/management -serverType ADMIN_AGENT -profileName ${HOSTNAME}_${SRV_NAME} -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} -cellName ${CELL_NAME} -nodeName ${NODE_NAME} -hostName ${HOSTNAME} -adminUserName ${ADM_USR_NAME} -adminPassword ${ADM_USR_PSWD} -enableAdminSecurity true -importSigningCertKSAlias ${WAS_CA_ALIAS} -importSigningCertKS ${WAS_CA_PATH} -importSigningCertKSPassword ${WAS_CA_PWD} -importSigningCertKSType PKCS12 -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} -importPersonalCertKS ${WAS_PKEY_PATH} -importPersonalCertKSPassword ${WAS_PKEY_PWD} -importPersonalCertKSType PKCS12 -keyStorePassword ${WAS_PKEY_PWD} -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
  elif [[ ${SRV_NAME} == 'dmgr' ]]; then
    ${WAS_LOCATION}/bin/manageprofiles.sh -create -templatePath ${WAS_LOCATION}/profileTemplates/management -serverType DEPLOYMENT_MANAGER -profileName ${SRV_NAME} -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} -cellName ${CELL_NAME} -nodeName ${NODE_NAME} -hostName ${HOSTNAME} -adminUserName ${ADM_USR_NAME} -adminPassword ${ADM_USR_PSWD} -enableAdminSecurity true -importSigningCertKSAlias ${WAS_CA_ALIAS} -importSigningCertKS ${WAS_CA_PATH} -importSigningCertKSPassword ${WAS_CA_PWD} -importSigningCertKSType PKCS12 -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} -importPersonalCertKS ${WAS_PKEY_PATH} -importPersonalCertKSPassword ${WAS_PKEY_PWD} -importPersonalCertKSType PKCS12 -keyStorePassword ${WAS_PKEY_PWD} -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
  elif [[ ${SRV_NAME} == 'nodeagent' ]]; then
    ${WAS_LOCATION}/bin/manageprofiles.sh -create -templatePath ${WAS_LOCATION}/profileTemplates/managed -profileName ${HOSTNAME}_${SRV_NAME} -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} -cellName ${CELL_NAME} -nodeName ${NODE_NAME} -hostName ${HOSTNAME} -adminUserName ${ADM_USR_NAME} -adminPassword ${ADM_USR_PSWD} -enableAdminSecurity true -importSigningCertKSAlias ${WAS_CA_ALIAS} -importSigningCertKS ${WAS_CA_PATH} -importSigningCertKSPassword ${WAS_CA_PWD} -importSigningCertKSType PKCS12 -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} -importPersonalCertKS ${WAS_PKEY_PATH} -importPersonalCertKSPassword ${WAS_PKEY_PWD} -importPersonalCertKSType PKCS12 -keyStorePassword ${WAS_PKEY_PWD} -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
  else
    # seuls les profiles "standalone" peuvent etre cree en "non secure"
    # en "non secure", on applique le tunning des performances "std" et non pas celui de prod.
    if [[ ${IS_SECURE} == 'true' ]]; then
      ${WAS_LOCATION}/bin/manageprofiles.sh -create -templatePath ${WAS_LOCATION}/profileTemplates/default -profileName ${SRV_NAME} -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} -cellName ${CELL_NAME} -nodeName ${NODE_NAME} -hostName ${HOSTNAME} -adminUserName ${ADM_USR_NAME} -adminPassword ${ADM_USR_PSWD} -enableAdminSecurity true -importSigningCertKSAlias ${WAS_CA_ALIAS} -importSigningCertKS ${WAS_CA_PATH} -importSigningCertKSPassword ${WAS_CA_PWD} -importSigningCertKSType PKCS12 -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} -importPersonalCertKS ${WAS_PKEY_PATH} -importPersonalCertKSPassword ${WAS_PKEY_PWD} -importPersonalCertKSType PKCS12 -keyStorePassword ${WAS_PKEY_PWD} -applyPerfTuningSetting production -omitAction defaultAppDeployAndConfig deployIVTApplication -serverName ${SRV_NAME} -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
    else
      ${WAS_LOCATION}/bin/manageprofiles.sh -create -templatePath ${WAS_LOCATION}/profileTemplates/default -profileName ${SRV_NAME} -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} -cellName ${CELL_NAME} -nodeName ${NODE_NAME} -hostName ${HOSTNAME} -enableAdminSecurity false -importSigningCertKSAlias ${WAS_CA_ALIAS} -importSigningCertKS ${WAS_CA_PATH} -importSigningCertKSPassword ${WAS_CA_PWD} -importSigningCertKSType PKCS12 -importPersonalCertKSAlias ${WAS_PKEY_ALIAS} -importPersonalCertKS ${WAS_PKEY_PATH} -importPersonalCertKSPassword ${WAS_PKEY_PWD} -importPersonalCertKSType PKCS12 -keyStorePassword ${WAS_PKEY_PWD} -applyPerfTuningSetting standard -omitAction defaultAppDeployAndConfig deployIVTApplication -serverName ${SRV_NAME} -portsFile /tmp/ports.properties 1>/tmp/install-out.log 2>/tmp/install-err.log
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

  if [[ ${IS_SECURE} == 'true' ]]; then
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
  fi

  logInfo "- demarrage de ${SRV_NAME} sur ${HOSTNAME}"
  ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/startServer.sh ${SRV_NAME}
  if [[ $? -gt 127 ]]; then
    logError 44 "${SRV_NAME} n'a pas reussi a demarrer... arret de la procedure."
  fi

  logInfo "${SRV_NAME} est demarre."

}

#--- Securiser un profile -------------------------------------------------
function doSecureProfile
{

  SRV_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`

  WASVERSION=$( getAttribute "//websphere/@version" )
  SOAP_PORT=$( getAttribute "//servers/server[@name='${SRV_NAME}']/@soapPort" )
  NODE_NAME=`echo "${SHORT_HOSTNAME}_${SRV_NAME}" | tr '[:upper:]' '[:lower:]'`
  CELL_NAME=$( getAttribute "//environment/@cell" )
  IS_SECURE=$( getAttribute "//environment/@secure" )
  WAS_LOCATION=$( getWasLocation )

  logVar "WASVERSION" ${WASVERSION}
  logVar "WAS_LOCATION" ${WAS_LOCATION}
  logVar "SRV_NAME" ${SRV_NAME}
  logVar "CELL_NAME" ${CELL_NAME}
  logVar "IS_SECURE" ${IS_SECURE}
  logVar "SOAP_PORT" ${SOAP_PORT}

  if [[ ${IS_SECURE} == 'true' ]]; then
    logInfo "- configuration de la securite pour le serveur ${SRV_NAME} de l'environnement ${ENVIRONMENT}"
    ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/wsadmin.sh -host ${HOSTNAME} -port ${SOAP_PORT} -conntype SOAP -lang jython -f ${ROOT_PRODUCTS}/was/scripts/configure/as/WasConfigure.py --environment ${ENVIRONMENT} --project ${PROJECT} --server ${SRV_NAME} --security true
    if [[ $? -gt 127 ]]; then
      logError 45 "configuration de ${SRV_NAME} terminee en erreur : voir les logs precedents... arret de la procedure."
    fi

    logInfo "- redemarrage de ${SRV_NAME} sur ${HOSTNAME} pour activer le LDAP administratif"
    ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/stopServer.sh ${SRV_NAME}
    if [[ $? -gt 127 ]]; then
      logError 46 "${SRV_NAME} ne parvient pas a s'arreter... verifiez les logs. arret de la procedure."
    fi

    echo ">>> Vous devez a present entrer un administrateur existant sur le LDAP. Attention : celui-ci doit etre present dans la liste des administrateurs du fichier de configuration..."
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
    if [[ $? -gt 127 ]]; then
      logError 47 "${SRV_NAME} n'a pas reussi a demarrer... arret de la procedure."
    else
      logInfo "la configuration de securite de base de ${SRV_NAME} est realisee, et il est correctement demarre."
    fi
  fi
}

#--- Application de la configuration websphere sur un serveur -------------
function doConfigure
{

  SRV_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`

  TST_SRV=`egrep -c "server.*name=.${SRV_NAME}. " ${CONF_FILE}`
  if [[ ${TST_SRV} -eq 0 ]]; then
    logError 49 "le nom de serveur ${SRV_NAME} n'existe pas dans le fichier de configuration, operation impossible..."
  fi

  DMGR_HOST_PORT=$( getAttribute "//servers/server[@name='dmgr']/@hostName" )
  DMGR_SOAP_PORT=$( getAttribute "//servers/server[@name='dmgr']/@soapPort" )
  SOAP_PORT=$( getAttribute "//servers/server[@name='${SRV_NAME}']/@soapPort" )
  WAS_LOCATION=$( getWasLocation )

  logVar "DMGR_HOST_PORT" ${DMGR_HOST_PORT}
  logVar "DMGR_SOAP_PORT" ${DMGR_SOAP_PORT}
  logVar "SRV_NAME" ${SRV_NAME}
  logVar "SOAP_PORT" ${SOAP_PORT}
  logVar "WAS_LOCATION" ${WAS_LOCATION}

  logInfo "- configuration du serveur ${SRV_NAME} pour l'environnement ${ENVIRONMENT}"
  ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/wsadmin.sh -host ${HOSTNAME} -port ${SOAP_PORT} -conntype SOAP -lang jython -f ${ROOT_PRODUCTS}/was/scripts/configure/as/WasConfigure.py --environment ${ENVIRONMENT} --project ${PROJECT} --server ${SRV_NAME}
  if [[ $? -gt 127 ]]; then
    logError 50 "configuration de ${SRV_NAME} terminee en erreur : voir les logs precedents... arret de la procedure."
  fi

  logInfo "- arret de ${SRV_NAME} sur ${HOSTNAME}"
  ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/stopServer.sh ${SRV_NAME}
  if [[ $? -gt 127 ]]; then
    logError 51 "${SRV_NAME} ne parvient pas a s'arreter... verifiez les logs. arret de la procedure."
  fi

  sleep 5

  logInfo "- demarrage de ${SRV_NAME} sur ${HOSTNAME}"
  ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/startServer.sh ${SRV_NAME}
  if [[ $? -gt 127 ]]; then
    logError 52 "${SRV_NAME} n'a pas reussi a demarrer... arret de la procedure."
  fi

  if [[ ${DMGR_HOST_PORT} != "" ]] && [[ ${DMGR_SOAP_PORT} != "" ]]; then
    logInfo "- synchronisation du serveur ${SRV_NAME} pour l'environnement ${ENVIRONMENT}"
    ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/syncNode.sh ${DMGR_HOST_PORT} ${DMGR_SOAP_PORT} -conntype SOAP 
  fi
}

#--- Application de la configuration websphere sur une cellule ------------
function doConfigureCell
{
  DMGR_HOST_PORT=$( getAttribute "//servers/server[@name='dmgr']/@hostName" )
  DMGR_SOAP_PORT=$( getAttribute "//servers/server[@name='dmgr']/@soapPort" )
  WASVERSION=$( getAttribute "//websphere/@version" )
  WAS_LOCATION=$( getWasLocation )

  logVar "DMGR_HOST_PORT" ${DMGR_HOST_PORT}
  logVar "DMGR_SOAP_PORT" ${DMGR_SOAP_PORT}
  logVar "WAS_LOCATION" ${WAS_LOCATION}

  logInfo "- configuration de la cellule pour l'environnement ${ENVIRONMENT}"
  ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/wsadmin.sh -host ${DMGR_HOST_PORT} -port ${DMGR_SOAP_PORT} -conntype SOAP -lang jython -f ${ROOT_PRODUCTS}/was/scripts/configure/as/WasConfigureCell.py --environment ${ENVIRONMENT} --project ${PROJECT}
  if [[ $? -gt 127 ]]; then
    logError 50 "configuration de ${SRV_NAME} terminee en erreur : voir les logs precedents... arret de la procedure."
  fi
}

#--- Enregistrer un profile standalone avec un agent administratif --------
function doRegisterProfile
{
  SRV_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`
  NODE_NAME=`echo "${2}" | tr '[:upper:]' '[:lower:]'`

  WASVERSION=$( getAttribute "//websphere/@version" )
  WAS_LOCATION=$( getWasLocation )

  logVar "WASVERSION" ${WASVERSION}
  logVar "WAS_LOCATION" ${WAS_LOCATION}
  logVar "SRV_NAME" ${SRV_NAME}
  logVar "NODE_NAME" ${NODE_NAME}

  echo ">>> pour enregistrer un profile vous devez entrez votre identifiant d'administration..."
  read ADM_USR_NAME?'> votre admin user ? '
  stty -echo
  printf "> votre admin password ? "
  read ADM_USR_PSWD
  stty echo
  printf "\n"

  logInfo "- enregistrement de ${SRV_NAME} avec ${NODE_NAME}"
  if [[ -x ${WAS_LOCATION}/profiles/${NODE_NAME}/bin/registerNode.sh ]]
  then
    ${WAS_LOCATION}/profiles/${NODE_NAME}/bin/registerNode.sh -profilePath ${WAS_LOCATION}/profiles/${SRV_NAME} -username ${ADM_USR_NAME} -password ${ADM_USR_PSWD}
    if [[ $? -gt 127 ]]
    then
      logError 51 "${SRV_NAME} non enregistre avec ${NODE_NAME}. Merci de consulter les logs precedent pour plus d'information... arret de la procedure."
    else
      logInfo "${SRV_NAME} correctement enregistre avec ${NODE_NAME}"
      logInfo "${SRV_NAME} doit a present etre redemarre..."
      ${WAS_LOCATION}/profiles/${SRV_NAME}/bin/startServer.sh ${SRV_NAME}
      if [[ $? -gt 127 ]]
      then
        logError 52 "${SRV_NAME} n'a pas reussi a demarrer... arret de la procedure."
      else
        logInfo "${SRV_NAME} est correctement demarre."
      fi
    fi
  else
    logError 50 "aucun agent administratif ou node agent n'est encore defini. vous devez en definir un au prealable. arret de la procedure."
  fi

}

#==========================================================================
# FIN DE DEFINITION DES FONCTIONS                                         =
#==========================================================================
logTrace "Chargement de configure-was.sh (version ${LIB_VERSION}) effectue."
