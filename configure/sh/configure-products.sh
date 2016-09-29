#!/bin/ksh
##########################################
#                                        #
#   auteur : Francois Colombo            #
#                                        #
##########################################

#==========================================================================
#=== FONCTIONS UTILITAIRES                                              ===
#==========================================================================

#--- Ceci permet de realiser l'installation de IIM si necessaire ----------
function doInstallIIM
{

  # commencer par installer IIM si necessaire (obligatoire pour WAS >= 7.0 !)
  if [[ ! -x ${ROOT_PRODUCTS}/install/setup/eclipse/IBMIM ]]; then

    ROOT_URL=$( getAttribute "//packaging/packages/@rootUrl" )
    IIM_PACKAGE=$( getAttribute "//packaging/iim/@path" )

    logVar "ROOT_URL" ${ROOT_URL}
    logVar "IIM_PACKAGE" ${IIM_PACKAGE}

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

 <profile kind='self' installLocation='${ROOT_PRODUCTS}/install/setup' id='IBM Installation Manager'>
  <data key='eclipseLocation' value='${ROOT_PRODUCTS}/install/setup'/>
 </profile>

 <server>
  <repository location='${IIM_PATH}'/>
 </server>

 <install>
  <offering profile='IBM Installation Manager' features='agent_core,agent_jre' id='com.ibm.cic.agent' version='${V}'/>
 </install>

</agent-input>
ENDL
    ${IIM_PATH}/userinst --launcher.ini ${IIM_PATH}/user-silent-install.ini -dataLocation ${ROOT_PRODUCTS}/install/data -showProgress -acceptLicense
    logInfo "- test de l'installation de IBMIM..."
    if [[ -x ${ROOT_PRODUCTS}/install/setup/eclipse/IBMIM ]]; then
      echo "adddisableOSPrereqChecking=true" >> ${ROOT_PRODUCTS}/install/setup/eclipse/configuration/config.ini
      ${ROOT_PRODUCTS}/install/setup/eclipse/IBMIM -version -silent -nosplash
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
  TGTDIR="${2}"
  TSTCMD="${3}"

  doInstallIIM

  logInfo "- installation du produit dans le repertoire '${TGTDIR}'"
  ${ROOT_PRODUCTS}/install/setup/eclipse/IBMIM -input ${RSPPATH} -silent -showProgress -nosplash -acceptLicense

  logInfo "- controle de l'installation"
  if [[ -s ${TGTDIR}/bin/${TSTCMD} ]]; then
    logInfo "=== le produit est bien installe."
  else
    logError 34 "il y a eu un probleme sur l'installation du produit dans le repertoire ${TGTDIR} ! arret de la procedure..."
  fi

  logInfo "- voici la version du produit installee :"
  ${TGTDIR}/bin/versionInfo.sh

}

#--- Ceci permet d'utiliser IIM pour realiser une update ------------------
function doUpdateWithIIM
{

  PKEY=`echo "${1}" | tr '[:upper:]' '[:lower:]'`
  TGTDIR="${2}"

  ROOT_URL=$( getAttribute "//packaging/packages/@rootUrl" )
  PACKAGE_PATH=$( getAttribute "//packaging/packages/package[@name='${PKEY}']/@updatepath" )
  OFF_ID=$( getAttribute "//packaging/packages/package[@name='${PKEY}']/@key" )

  logVar "ROOT_URL" ${ROOT_URL}
  logVar "PACKAGE_PATH" ${PACKAGE_PATH}
  logVar "OFF_ID" ${OFF_ID}

  doInstallIIM

  logInfo "- mise a jour du produit ${PKEY} (par application de fixpack)"

  TST=`${ROOT_PRODUCTS}/install/setup/eclipse/tools/imcl listAvailablePackages -repositories ${ROOT_URL}/${PACKAGE_PATH} | grep -c "${OFF_ID}"`
  if [[ ${TST} -ne 1 ]]; then
    logError 35 "le package ${OFF_ID} n'existe pas dans le repository ${ROOT_URL}/${PACKAGE_PATH} !"
  fi

  logInfo "- upgrade du produit ${OFF_ID}..."
  ${ROOT_PRODUCTS}/install/setup/eclipse/tools/imcl install ${OFF_ID} -repositories ${ROOT_URL}/${PACKAGE_PATH} -installationDirectory ${TGTDIR}/ -installFixes all -acceptLicense -sP -preferences com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=false,com.ibm.cic.common.core.preferences.searchForUpdates=false,com.ibm.cic.common.core.preferences.keepFetchedFiles=false
  if [[ $? -eq 0 ]]; then
    logInfo "- upgrade du produit ${OFF_ID} acheve avec succes."
  else
    logError 36 "l'upgrade du produit ${OFF_ID} n'a pas fonctionne correctement. voir logs precedents."
  fi

  logInfo "- voici la version du produit apres mise a jour :"
  ${TGTDIR}/bin/versionInfo.sh

}

#--- Response file pour WebSphere Application Server ----------------------
function doCreateWASResponseFile
{

  WASVERSION=$( getAttribute "//packaging/websphere/@version" )
  WASMODE=$( getAttribute "//packaging/websphere/@mode" )
  ROOT_URL=$( getAttribute "//packaging/packages/@rootUrl" )
  WAS_PACKAGE=$( getAttribute "//packaging/packages/package[@name='appsrv']/@sourcepath" )
  WAS_OFF_ID=$( getAttribute "//packaging/packages/package[@name='appsrv']/@key" )
  WAS_LOCATION=$( getWasLocation )

  logVar "WASVERSION" ${WASVERSION}
  logVar "WASMODE" ${WASMODE}
  logVar "ROOT_URL" ${ROOT_URL}
  logVar "WAS_PACKAGE" ${WAS_PACKAGE}
  logVar "WAS_OFF_ID" ${WAS_OFF_ID}
  logVar "WAS_LOCATION" ${WAS_LOCATION}

  if [[ ! -d ${WAS_LOCATION} ]]
  then
    logInfo "- creation du repertoire ${WAS_LOCATION}"
    mkdir -p ${WAS_LOCATION}
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

<preference name='com.ibm.cic.common.core.preferences.eclipseCache' value='${ROOT_PRODUCTS}/install/shared'/>
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

}

#--- Response file pour IBM HTTP Server -----------------------------------
function doCreateIHSResponseFile
{

  WEB_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`

  # NOTE : le port d'admin de l'IHS n'est pas configure pour le moment, on
  # ----   laisse IHS le selectionner pour nous.

  WASVERSION=$( getAttribute "//packaging/websphere/@version" )
  ROOT_URL=$( getAttribute "//packaging/packages/@rootUrl" )
  IHS_PACKAGE=$( getAttribute "//packaging/packages/package[@name='ihs']/@sourcepath" )
  IHS_OFF_ID=$( getAttribute "//packaging/packages/package[@name='ihs']/@key" )
  IHS_HTTP_PORT=$( getAttribute "//webservers/webserver[@name='${WEB_NAME}']/@port" )
  #IHS_ADMIN_PORT=$( getAttribute "//webservers/webserver[@name='${WEB_NAME}']/@adminPort" )

  logVar "WASVERSION" ${WASVERSION}
  logVar "WEB_NAME" ${WEB_NAME}
  logVar "ROOT_URL" ${ROOT_URL}
  logVar "IHS_PACKAGE" ${IHS_PACKAGE}
  logVar "IHS_OFF_ID" ${IHS_OFF_ID}
  logVar "IHS_HTTP_PORT" ${IHS_HTTP_PORT}
  #logVar "IHS_ADMIN_PORT" ${IHS_ADMIN_PORT}

  if [[ ! -d ${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME} ]]
  then
    logInfo "- creation du repertoire ${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME}"
    mkdir -p ${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME}
  fi

  logInfo "- creation du responsefile"
  cat > /tmp/ihs-response.xml <<ENDL
<?xml version="1.0" encoding="UTF-8"?>
<agent-input acceptLicense='true'>

    <server>
        <repository location='${ROOT_URL}/${IHS_PACKAGE}'/>
    </server>

    <install modify='false'>
        <offering id='${IHS_OFF_ID}'
                  profile='IBM HTTP Server ${WEB_NAME}'
                  features='core.feature,arch.64bit'
                  installFixes='none'/>
    </install>

    <profile id='IBM HTTP Server ${WEB_NAME}'
             installLocation='${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME}'>
        <data key='eclipseLocation' value='${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME}'/>
        <data key='user.import.profile' value='false'/>
        <data key='cic.selector.os' value='aix'/>
        <data key='cic.selector.ws' value='motif'/>
        <data key='cic.selector.arch' value='ppc'/>

        <data key='user.ihs.http.server.service.name' value='${WEB_NAME}'/>
        <data key='user.ihs.httpPort' value='${IHS_HTTP_PORT}'/>
        <data key='user.ihs.installHttpService' value='false'/>
        <data key='user.ihs.allowNonRootSilentInstall' value='true'/>
<!--
        <data key='user.ihs.adminPort' value='${IHS_ADMIN_PORT}'/>
-->
        <data key='cic.selector.nl' value='en'/>
    </profile>

    <preference name='com.ibm.cic.common.core.preferences.eclipseCache' value='${ROOT_PRODUCTS}/install/shared'/>
    <preference name='com.ibm.cic.common.core.preferences.connectTimeout' value='30'/>
    <preference name='com.ibm.cic.common.core.preferences.readTimeout' value='45'/>
    <preference name='com.ibm.cic.common.core.preferences.downloadAutoRetryCount' value='0'/>
    <preference name='offering.service.repositories.areUsed' value='true'/>
    <preference name='com.ibm.cic.common.core.preferences.ssl.nonsecureMode' value='false'/>
    <preference name='com.ibm.cic.common.core.preferences.http.disablePreemptiveAuthentication' value='false'/>
    <preference name='http.ntlm.auth.kind' value='NTLM'/>
    <preference name='http.ntlm.auth.enableIntegrated.win32' value='true'/>
    <preference name='com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts' value='false'/>
    <preference name='com.ibm.cic.common.core.preferences.keepFetchedFiles' value='false'/>
    <preference name='PassportAdvantageIsEnabled' value='false'/>
    <preference name='com.ibm.cic.common.core.preferences.searchForUpdates' value='false'/>
    <preference name='com.ibm.cic.agent.ui.displayInternalVersion' value='false'/>
    <preference name='com.ibm.cic.common.sharedUI.showErrorLog' value='true'/>
    <preference name='com.ibm.cic.common.sharedUI.showWarningLog' value='true'/>
    <preference name='com.ibm.cic.common.sharedUI.showNoteLog' value='true'/>

</agent-input>
ENDL

}

#--- Response file pour WebSphere Customization Toolkit -------------------
function doCreateWCTResponseFile
{

  WASVERSION=$( getAttribute "//packaging/websphere/@version" )
  ROOT_URL=$( getAttribute "//packaging/packages/@rootUrl" )
  WCT_PACKAGE=$( getAttribute "//packaging/packages/package[@name='wct']/@sourcepath" )
  WCT_OFF_ID=$( getAttribute "//packaging/packages/package[@name='wct']/@key" )

  logVar "WASVERSION" ${WASVERSION}
  logVar "ROOT_URL" ${ROOT_URL}
  logVar "WCT_PACKAGE" ${WCT_PACKAGE}
  logVar "WCT_OFF_ID" ${WCT_OFF_ID}

  if [[ ! -d ${ROOT_PRODUCTS}/wct/${WASVERSION} ]]
  then
    logInfo "- creation du repertoire ${ROOT_PRODUCTS}/wct/${WASVERSION}"
    mkdir -p ${ROOT_PRODUCTS}/wct/${WASVERSION}
  fi

  logInfo "- creation du responsefile"
  cat > /tmp/wct-response.xml <<ENDL
<?xml version="1.0" encoding="UTF-8"?>
<agent-input acceptLicense='true'>

    <server>
        <repository location='${ROOT_URL}/${WCT_PACKAGE}'/>
    </server>

    <install modify='false'>
        <offering id='${WCT_OFF_ID}'
                  profile='WebSphere Customization Toolbox ${WASVERSION}'
                  features='core.feature,pct'
                  installFixes='none'/>
    </install>

    <profile id='WebSphere Customization Toolbox ${WASVERSION}'
             installLocation='${ROOT_PRODUCTS}/wct/${WASVERSION}'>
        <data key='eclipseLocation' value='${ROOT_PRODUCTS}/wct/${WASVERSION}'/>
        <data key='user.import.profile' value='false'/>
        <data key='cic.selector.os' value='aix'/>
        <data key='cic.selector.ws' value='motif'/>
        <data key='cic.selector.arch' value='ppc'/>
        <data key='cic.selector.nl' value='en'/>
    </profile>

    <preference name='com.ibm.cic.common.core.preferences.eclipseCache' value='${ROOT_PRODUCTS}/install/shared'/>
    <preference name='com.ibm.cic.common.core.preferences.connectTimeout' value='30'/>
    <preference name='com.ibm.cic.common.core.preferences.readTimeout' value='45'/>
    <preference name='com.ibm.cic.common.core.preferences.downloadAutoRetryCount' value='0'/>
    <preference name='offering.service.repositories.areUsed' value='true'/>
    <preference name='com.ibm.cic.common.core.preferences.ssl.nonsecureMode' value='false'/>
    <preference name='com.ibm.cic.common.core.preferences.http.disablePreemptiveAuthentication' value='false'/>
    <preference name='http.ntlm.auth.kind' value='NTLM'/>
    <preference name='http.ntlm.auth.enableIntegrated.win32' value='true'/>
    <preference name='com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts' value='false'/>
    <preference name='com.ibm.cic.common.core.preferences.keepFetchedFiles' value='false'/>
    <preference name='PassportAdvantageIsEnabled' value='false'/>
    <preference name='com.ibm.cic.common.core.preferences.searchForUpdates' value='false'/>
    <preference name='com.ibm.cic.agent.ui.displayInternalVersion' value='false'/>
    <preference name='com.ibm.cic.common.sharedUI.showErrorLog' value='true'/>
    <preference name='com.ibm.cic.common.sharedUI.showWarningLog' value='true'/>
    <preference name='com.ibm.cic.common.sharedUI.showNoteLog' value='true'/>

</agent-input>
ENDL

}

#--- Response file pour le Plugin WebSphere -------------------------------
function doCreatePLGResponseFile
{

  WASVERSION=$( getAttribute "//packaging/websphere/@version" )
  ROOT_URL=$( getAttribute "//packaging/packages/@rootUrl" )
  PLG_PACKAGE=$( getAttribute "//packaging/packages/package[@name='plugin']/@sourcepath" )
  PLG_OFF_ID=$( getAttribute "//packaging/packages/package[@name='plugin']/@key" )

  logVar "WASVERSION" ${WASVERSION}
  logVar "ROOT_URL" ${ROOT_URL}
  logVar "PLG_PACKAGE" ${PLG_PACKAGE}
  logVar "PLG_OFF_ID" ${PLG_OFF_ID}

  if [[ ! -d ${ROOT_PRODUCTS}/wasplugins/${WASVERSION} ]]
  then
    logInfo "- creation du repertoire ${ROOT_PRODUCTS}/wasplugins/${WASVERSION}"
    mkdir -p ${ROOT_PRODUCTS}/wasplugins/${WASVERSION}
  fi

  logInfo "- creation du responsefile"
  cat > /tmp/plg-response.xml <<ENDL
<?xml version="1.0" encoding="UTF-8"?>
<agent-input acceptLicense='true'>

    <server>
        <repository location='${ROOT_URL}/${PLG_PACKAGE}'/>
    </server>

    <install modify='false'>
        <offering id='${PLG_OFF_ID}'
                  profile='Web Server Plug-ins for IBM WebSphere Application Server ${WASVERSION}'
                  features='core.feature,com.ibm.jre.6_64bit' installFixes='none'/>
    </install>

    <profile id='Web Server Plug-ins for IBM WebSphere Application Server ${WASVERSION}'
             installLocation='${ROOT_PRODUCTS}/wasplugins/${WASVERSION}'>
        <data key='eclipseLocation' value='${ROOT_PRODUCTS}/wasplugins/${WASVERSION}'/>
        <data key='user.import.profile' value='false'/>
        <data key='cic.selector.os' value='aix'/>
        <data key='cic.selector.ws' value='motif'/>
        <data key='cic.selector.arch' value='ppc'/>
        <data key='cic.selector.nl' value='en'/>
    </profile>

    <preference name='com.ibm.cic.common.core.preferences.eclipseCache' value='${ROOT_PRODUCTS}/install/shared'/>
    <preference name='com.ibm.cic.common.core.preferences.connectTimeout' value='30'/>
    <preference name='com.ibm.cic.common.core.preferences.readTimeout' value='45'/>
    <preference name='com.ibm.cic.common.core.preferences.downloadAutoRetryCount' value='0'/>
    <preference name='offering.service.repositories.areUsed' value='true'/>
    <preference name='com.ibm.cic.common.core.preferences.ssl.nonsecureMode' value='false'/>
    <preference name='com.ibm.cic.common.core.preferences.http.disablePreemptiveAuthentication' value='false'/>
    <preference name='http.ntlm.auth.kind' value='NTLM'/>
    <preference name='http.ntlm.auth.enableIntegrated.win32' value='true'/>
    <preference name='com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts' value='false'/>
    <preference name='com.ibm.cic.common.core.preferences.keepFetchedFiles' value='false'/>
    <preference name='PassportAdvantageIsEnabled' value='false'/>
    <preference name='com.ibm.cic.common.core.preferences.searchForUpdates' value='false'/>
    <preference name='com.ibm.cic.agent.ui.displayInternalVersion' value='false'/>
    <preference name='com.ibm.cic.common.sharedUI.showErrorLog' value='true'/>
    <preference name='com.ibm.cic.common.sharedUI.showWarningLog' value='true'/>
    <preference name='com.ibm.cic.common.sharedUI.showNoteLog' value='true'/>

</agent-input>
ENDL

}

#==========================================================================
#=== ACTIONS                                                            ===
#==========================================================================

#--- Ceci permet de realiser l'installation du moteur websphere -----------
function doInstallWAS
{
  WAS_LOCATION=$( getWasLocation )

  logVar "WAS_LOCATION" ${WAS_LOCATION}

  logInfo "- installation du was core (binaires)"
  doCreateWASResponseFile
  doInstallWithIIM "/tmp/was-response.xml" "${WAS_LOCATION}" "startServer.sh"
  doUpdateWithIIM "appsrv" "${WAS_LOCATION}/"
}

#--- Application des fixpacks sur le core WAS -----------------------------
function doUpdateWas
{
  WAS_LOCATION=$( getWasLocation )

  logVar "WAS_LOCATION" ${WAS_LOCATION}

  logInfo "- mise a jour du was core (binaires)"
  doUpdateWithIIM "appsrv" "${WAS_LOCATION}/"
}

#--- Application des fixpacks sur le jdk ----------------------------------
function doUpdateJdk7
{
  WAS_LOCATION=$( getWasLocation )

  logVar "WAS_LOCATION" ${WAS_LOCATION}

  logInfo "- mise a jour du jdk7 (binaires)"
  doUpdateWithIIM "ibmsdk" "${WAS_LOCATION}/"
}

#--- Ceci permet de realiser l'installation de WCT ------------------------
function doInstallWCT
{
  WASVERSION=$( getAttribute "//packaging/websphere/@version" )

  logVar "WASVERSION" ${WASVERSION}

  logInfo "- installation de websphere customization toolkit"
  doCreateWCTResponseFile
  doInstallWithIIM "/tmp/wct-response.xml" "${ROOT_PRODUCTS}/wct/${WASVERSION}" "setupCmdLine.sh"
  doUpdateWithIIM "wct" "${ROOT_PRODUCTS}/wct/${WASVERSION}/"
}

#--- Application des fixpacks sur WCT -------------------------------------
function doUpdateWCT
{
  WASVERSION=$( getAttribute "//packaging/websphere/@version" )

  logVar "WASVERSION" ${WASVERSION}

  logInfo "- mise a jour du websphere customization toolkit"
  doUpdateWithIIM "wct" "${ROOT_PRODUCTS}/wct/${WASVERSION}/"
}

#--- Ceci permet de realiser l'installation du plugin WAS -----------------
function doInstallPlugin
{
  WASVERSION=$( getAttribute "//packaging/websphere/@version" )

  logVar "WASVERSION" ${WASVERSION}

  logInfo "- installation du plugin websphere"
  doCreatePLGResponseFile
  doInstallWithIIM "/tmp/plg-response.xml" "${ROOT_PRODUCTS}/wasplugins/${WASVERSION}" "ConfigureIHSPlugin.sh"
  doUpdateWithIIM "plugin" "${ROOT_PRODUCTS}/wasplugins/${WASVERSION}/"
}

#--- Application des fixpacks sur le plugin WAS ---------------------------
function doUpdatePlugin
{
  WASVERSION=$( getAttribute "//packaging/websphere/@version" )

  logVar "WASVERSION" ${WASVERSION}

  logInfo "- mise a jour du plugin websphere"
  doUpdateWithIIM "plugin" "${ROOT_PRODUCTS}/wasplugins/${WASVERSION}/"
}

#--- Ceci permet de realiser l'installation de IHS ------------------------
function doInstallWebServer
{
  WEB_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`
  WASVERSION=$( getAttribute "//packaging/websphere/@version" )

  logVar "WASVERSION" ${WASVERSION}
  logVar "WEB_NAME" ${WEB_NAME}

  logInfo "- installation de IBM HTTP Server (${WEB_NAME})"
  doCreateIHSResponseFile ${WEB_NAME}
  doInstallWithIIM "/tmp/ihs-response.xml" "${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME}" "adminctl"
  doUpdateWithIIM "ihs" "${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME}/"
}

#--- Application des fixpacks sur le serveur IHS nomme --------------------
function doUpdateWebServer
{
  WEB_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`
  WASVERSION=$( getAttribute "//packaging/websphere/@version" )

  logVar "WASVERSION" ${WASVERSION}
  logVar "WEB_NAME" ${WEB_NAME}

  logInfo "- mise a jour de IBM HTTP Server (${WEB_NAME})"
  doUpdateWithIIM "ihs" "${ROOT_PRODUCTS}/ihs/${WASVERSION}/${WEB_NAME}/"
}

#--- Installation ou mise a jour des jars d'une librairie -----------------
function doUpdateLibrary
{
  LIB_NAME=`echo "${1}" | tr '[:upper:]' '[:lower:]'`

  ROOT_URL=$( getAttribute "//packaging/libraries/@rootUrl" )
  TARGETDIR=$( getAttribute "//packaging/libraries/library[@name='${LIB_NAME}']/@targetpath" )

  logVar "ROOT_URL" ${ROOT_URL}
  logVar "LIB_NAME" ${LIB_NAME}
  logVar "TARGETDIR" ${TARGETDIR}

  logInfo "- installation de ${LIB_NAME} dans le repertoire cible ${TARGETDIR}"
  mkdir -p ${TARGETDIR}
  unzip -o -v ${ROOT_URL}/${LIB_NAME}.zip -d ${TARGETDIR}
  if [[ $? -gt 127 ]]; then
    logError 39 "l'installation des .jar ne s'est pas correctement deroulee... arret de la procedure."
  fi

}


#==========================================================================
# FIN DE DEFINITION DES FONCTIONS                                         =
#==========================================================================
logTrace "Chargement de configure-products.sh (version ${LIB_VERSION}) effectue."
