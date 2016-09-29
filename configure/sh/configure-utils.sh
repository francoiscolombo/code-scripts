#!/bin/ksh
##########################################
#                                        #
#   auteur : Francois Colombo            #
#                                        #
##########################################

#==========================================================================
# PUBLIC PROPERTIES                                                       =
#==========================================================================

#### Constantes fixes (non dependantes de l'environnement) #################
ROOT_PRODUCTS="/s2ipgm/tst"
#ROOT_LOGS="/logs"
LIB_VERSION="1.1"

#### Parametres obligatoires ###############################################
PROJECT="$1"
ACTION="$2"
############################################################################

### les parametres sont forces en minuscules ###############################
PROJECT=`echo "$PROJECT" | tr "[:upper:]" "[:lower:]"`
ACTION=`echo "$ACTION" | tr "[:upper:]" "[:lower:]"`
############################################################################

#### Traitement du fichier de configuration ################################
CONF_FILE=`echo "${PROJECT}" | tr "[:upper:]" "[:lower:]"`
CONF_FILE=${ROOT_PRODUCTS}/scripts/configure/conf/${CONF_FILE}-cell.xml
#### Pas de fichier de configuration : traitement impossible ###############
if [[ ! -s ${CONF_FILE} ]]; then
  echo "le fichier de configuration '${CONF_FILE}' n'existe pas, vous devez le creer au prealable de l'execution de ce script... operation annulee."
  exit -1
fi
############################################################################

#### Fichier de configuration invalide : traitement impossible #############
#cat > /tmp/xmlvalid.pl <<ENDL
#use XML::LibXML;
#my \$parser = XML::LibXML->new;
#\$parser->validation(1);
#\$parser->parse_file("${CONF_FILE}");
#ENDL
#perl /tmp/xmlvalid.pl
#if [ $? -ne 0 ]; then
#  echo "des erreurs sont presentes dans le fichier XML de configuration localise ici : ${CONF_FILE}, vous devez imperativement les corriger au prealable de l'execution de ce script... operation annulee."
#  exit -2
#fi
#rm /tmp/xmlvalid.pl
############################################################################

#### Variables globales ####################################################
HOSTNAME=`hostname`
HOSTNAME=`echo "$HOSTNAME" | tr "[:upper:]" "[:lower:]"`
SHORT_HOSTNAME=`hostname -s`
SHORT_HOSTNAME=`echo "$SHORT_HOSTNAME" | tr "[:upper:]" "[:lower:]"`
############################################################################

#==========================================================================
# PUBLIC FUNCTIONS                                                        =
#==========================================================================

#--- afficher la valeur d'une variable ------------------------------------
function logVar
{
  T=`date +"%d.%m.%Y %H:%M:%S"`
  echo "[${T}] ${1}='${2}'"
}

#--- afficher un message de trace -----------------------------------------
function logTrace
{
  T=`date +"%d.%m.%Y %H:%M:%S"`
  echo "[${T}] # ${1}"
}

#--- logguer un composant demarre -----------------------------------------
function logStarted
{
  T=`date +"%d.%m.%Y %H:%M:%S"`
  echo "[${T}] <INFO> ${1} [STARTED]"
}

#--- logguer un composant qui n'a pas reussi a demarrer -------------------
function logNotStarted
{
  T=`date +"%d.%m.%Y %H:%M:%S"`
  echo "[${T}] <INFO> ${1} [NOT STARTED]"
}

#--- logguer un composant arrete ------------------------------------------
function logStopped
{
  T=`date +"%d.%m.%Y %H:%M:%S"`
  echo "[${T}] <INFO> ${1} [STOPPED]"
}

#--- logguer un composant qui n'a pas reussi a s'arreter ------------------
function logNotStopped
{
  T=`date +"%d.%m.%Y %H:%M:%S"`
  echo "[${T}] <INFO> ${1} [NOT STOPPED]"
}

#--- afficher un message --------------------------------------------------
function logInfo
{
  T=`date +"%d.%m.%Y %H:%M:%S"`
  echo "[${T}] <INFO> ${1}"
}

#--- afficher une erreur --------------------------------------------------
function logError
{
  typeset -RZ3 ERC
  T=`date +"%d.%m.%Y %H:%M:%S"`
  ERC=${1}
  echo "[${T}] [ERROR] <$ERC> ${2}..."
  exit -${1}
}

#--- recuperer un attribut ------------------------------------------------
function getAttribute
{
  A=`echo "${1}" | tr "'" '"'`
  cat > /tmp/getattr.pl <<ENDL
use 5.010;
use strict;
use warnings;
use XML::LibXML;

my \$dom = XML::LibXML->new->parse_file("${CONF_FILE}");
for my \$node (\$dom->findnodes('${A}')) {
    say \$node->textContent;
}
ENDL
  perl /tmp/getattr.pl
  rm /tmp/getattr.pl
}

#--- recuperer un attribut ------------------------------------------------
function getNodeList
{
  A=`echo "${1}" | tr "'" '"'`
  cat > /tmp/getnodelist.pl <<ENDL
use 5.010;
use strict;
use warnings;
use XML::LibXML;
my \$i = 0;
my \$dom=XML::LibXML->new->parse_file("${CONF_FILE}");
for my \$node (\$dom->findnodes('${A}')) {
  \$i++;
  say "[" . \$i . "] " . \$node->textContent;
}
ENDL
  perl /tmp/getnodelist.pl
  rm /tmp/getnodelist.pl
}

#--- dumper la liste des ports pour un profile nomme ----------------------
function getProfilePorts
{
  cat > /tmp/getprfports.pl <<ENDL
use 5.010;
use strict;
use warnings;
use XML::LibXML;
my \$dom=XML::LibXML->new->parse_file("${CONF_FILE}");
my \$offset=${2};
for my \$node (\$dom->findnodes('//profiles/profile[@name=\'${1}\']/ports/port')) {
  my \$name = "";
  my \$value = "";
  for my \$attr (\$node->attributes()) {
    if (\$attr->nodeName eq 'name') {
      \$name = \$attr->getValue;
    }
    elsif (\$attr->nodeName eq 'value') {
      \$value = \$attr->getValue + \$offset;
    }
  }
  say \$name . "=" . \$value;
}
ENDL
  perl /tmp/getprfports.pl > ${3}
  rm /tmp/getprfports.pl
}

#--- est-ce que le process tourne ? ---------------------------------------
function isRunning
{
  V=`ps -ef | grep "${1}" | grep -v "grep" | wc -l`
  echo "${V}"
}

#--- Decoder un mot de passe present dans le XML --------------------------
function decodePwd
{
  P="${1}"
  # encoder manuellement : echo "test" | openssl base64 -e 
  # puis ajouter "{dcu}" devant le résultat
  echo ${P#\{dcu\}} | openssl base64 -d
}

#--- recuperer extension d'un nom de fichier ------------------------------
function getFileExt
{
  T=`basename ${1}`
  TX=""
  while [[ $T = ?*.* && ( ${T##*.} = [A-Za-z]* ) ]]; do
    TX=${T##*.}.$TX
    T=${T%.*}
  done
  TX=${TX%.}
  echo "${TX}"
}

#--- recuperer nom de fichier sans extension ------------------------------
function getFileNameWithoutExt
{
  T=`basename ${1}`
  while [[ $T = ?*.* && ( ${T##*.} = [A-Za-z]* ) ]]; do
    T=${T%.*}
  done
  echo "${T}"
}

#--- Retourner le repertoire root de l'install WAS ------------------------
function getWasLocation
{
  WASVERSION=$( getAttribute "//websphere/@version" )
  WASMODE=$( getAttribute "//websphere/@mode" )
  ENVIRONMENT=$( getAttribute "//cellule/@environment" )
  ENVIRONMENT=`echo "$ENVIRONMENT" | tr "[:upper:]" "[:lower:]"`
  WAS_LOCATION=${ROOT_PRODUCTS}/was/${WASVERSION}
  if [[ ${WASMODE} == "32" ]]; then
    WAS_LOCATION="${WAS_LOCATION}_32"
  fi
  echo "${WAS_LOCATION}/${ENVIRONMENT}/${PROJECT}"
}

#--- Retourner l'alias du CA ----------------------------------------------
function getWasCAAlias
{
  WASCAALIAS=$( getAttribute "//certificates/rootca/@alias" )
  echo "${WASCAALIAS}"
}

#--- Retourner le path du P12 du CA ---------------------------------------
function getWasCAPath
{
  WASCAPATH=$( getAttribute "//certificates/rootca/@path" )
  echo "${WASCAPATH}"
}

#--- Retourner le mot de passe du P12 du CA -------------------------------
function getWasCAPassword
{
  WASCAEPWD=$( getAttribute "//certificates/rootca/@password" )
  WASCAPWD=$( decodePwd "${WASCAEPWD}" )
  echo "${WASCAPWD}"
}

#--- Retourner l'alias du certificat du serveur ---------------------------
function getWasPKAlias
{
  SRV="${1}"
  WASPKALIAS=$( getAttribute "//certificates/personals/personal[@server='${SRV}']/@alias" )
  echo "${WASPKALIAS}"
}

#--- Retourner le path du P12 du certificat -------------------------------
function getWasPKPath
{
  SRV="${1}"
  WASPKPATH=$( getAttribute "//certificates/personals/personal[@server='${SRV}']/@path" )
  echo "${WASPKPATH}"
}

#--- Retourner le mot de passe du P12 du certificat -----------------------
function getWasPKPassword
{
  SRV="${1}"
  WASPKEPWD=$( getAttribute "//certificates/personals/personal[@server='${SRV}']/@password" )
  WASPKPWD=$( decodePwd "${WASPKEPWD}" )
  echo "${WASPKPWD}"
}

#--- Controler existance d'un fichier -------------------------------------
function doCheckFile
{
  if [[ ! -s $1 ]]; then
    logError 1 "le fichier $1 n'existe pas... operation annulee."
  fi
}

#--- Controler existance d'un repertoire ----------------------------------
function doCheckDirectory
{
  if [[ ! -d $1 ]]; then
    logError 2 "le repertoire $1 n'existe pas... operation annulee."
  fi
}

#--- Effectuer les controles de base --------------------------------------
function doSanityChecks
{

  if [[ ! -d ${ROOT_PRODUCTS} ]]; then
    logError 3 "le repertoire ${ROOT_PRODUCTS} n'existe pas, vous devez le creer en tant que point de montage au prealable de l'execution de ce script... operation annulee."
  fi

  TST_RP=`df | grep "${ROOT_PRODUCTS}" | wc -l`
  if [[ TST_RP -eq 0 ]]; then
    RP=`dirname ${ROOT_PRODUCTS}`
    TST_BINARIES_SIZE=`df | grep "${RP}" | awk '{print $4}'`
  else
    TST_BINARIES_SIZE=`df | grep "${ROOT_PRODUCTS}" | awk '{print $4}'`
  fi

  TST_BINARIES_SIZE=`echo ${TST_BINARIES_SIZE%\%}`
  if [[ TST_BINARIES_SIZE -gt 80 ]]; then
    logError 4 "le repertoire ${ROOT_PRODUCTS} est plein a plus de 80%... operation annulee."
  fi

#  if [[ ! -d ${ROOT_LOGS} ]]; then
#    logError 5 "le repertoire ${ROOT_LOGS} n'existe pas, vous devez le creer en tant que point de montage au prealable de l'execution de ce script... operation annulee."
#  fi

#  TST_LOGS_SIZE=`df | grep "${ROOT_LOGS}" | awk '{print $4}'`
#  TST_LOGS_SIZE=`echo ${TST_LOGS_SIZE%\%}`
#  if [[ TST_LOGS_SIZE -gt 80 ]]; then
#    logError 6 "le repertoire ${ROOT_LOGS} est plein a plus de 80%... operation annulee."
#  fi
}

#==========================================================================
# PROPERTIES                                                              =
#==========================================================================
logVar "PROJECT" ${PROJECT}
logVar "ACTION" ${ACTION}
logVar "HOSTNAME" ${HOSTNAME}
logVar "SHORT_HOSTNAME" ${SHORT_HOSTNAME}
logVar "CONF_FILE" ${CONF_FILE}
############################################################################

logTrace "Chargement de configure-utils.sh (version ${LIB_VERSION}) effectue."
