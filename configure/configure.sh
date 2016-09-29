#!/bin/ksh
##########################################
#                                        #
#   auteur : Francois Colombo            #
#                                        #
##########################################

############################################################################
#### Code du script par lui-meme : aucune modif permise a partir d'ici #####
############################################################################

#==========================================================================
# PRIVATE FUNCTIONS                                                       =
#==========================================================================

#--- Erreur dans le passage des parametres --------------------------------
function doShowParamError
{
  echo " "
  echo "vous devez specifier le projet, ainsi que l'action a realiser"
  echo "parmi les options suivantes :"
  echo " "
  echo "1) installation des binaires"
  echo "   -------------------------"
  echo "   install was      (installation du core websphere)"
  echo " "
  echo "2) application des fixpacks"
  echo "   ------------------------"
  echo "   update was       (application fixpack sur core WAS)"
  echo " "
  echo "3) gestion du JDK"
  echo "   --------------"
  echo "   install jdk7   (installer les binaires du JDK 7)"
  echo "   force jdk7     (forcer l'usage du JDK7 pour les nouveaux profiles)"
  echo "   force jdk6     (forcer l'usage du JDK6 pour les nouveaux profiles)"
  echo " "
  echo "4) gestion des libraries"
  echo "   ---------------------"
  echo "   install racf          (installer la librairies RACF)"
  echo "   update library <name> (installer ou mettre a jour un package qui"
  echo "                          contient plusieurs jar. cela peut etre un"
  echo "                          driver jdbc, une sharedlib, etc.)"
  echo " "
  echo "5) gestion des webserver IHS"
  echo "   -------------------------"
  echo "   install webserver <name>   (creer & installer un profile IHS)"
  echo "   update webserver <name>    (appliquer un fixpack sur un profile"
  echo "                               installe au prealable)"
  echo " "
  echo "6) gestion des plugins"
  echo "   -------------------"
  echo "   install plugin   (installation du plugin WAS)"
  echo "   update plugin    (application fixpack sur plugin WAS)"
  echo " "
  echo "7) gestion des profiles WAS"
  echo "   ------------------------"
  echo "   create dmgr profile         (creer le profile 'dmgr')"
  echo "   create <name> nodeprofile   (creer le profile du noeud nomme)"
  echo "   create jobmanager profile   (creer le profile 'jobmanager')"
  echo "   create adminagent profile   (creer le profile 'adminagent')"
  echo "   create <name> profile       (creer un profile, a enregistrer ensuite)"
  echo "   register <name> with admin  (associer le profile avec l'adminagent)"
  echo " "
  echo "8) operations de mise a jour de la configuration"
  echo "   ---------------------------------------------"
  echo "   secure <name>      (securiser un profile cree au prealable)"
  echo "   configure cell     (configurer les serveurs manages et profiles administratif"
  echo "                       d'une cellule, mais ne configure pas les ressources)"
  echo "   configure <name>   (configurer ou reconfigurer une cellule ou un profile)"
  echo " "
  echo "execution annulee."
  echo " "
  echo "ex: configure ged install was"
  echo " "
  exit -59
}

#==========================================================================
# MAIN FUNCTION                                                           =
#==========================================================================

#### Gestion des parametres passes au script ###############################
if [[ $# -lt 2 ]]
then
  doShowParamError
fi

DIRBASENAME=`dirname $0`
. ${DIRBASENAME}/sh/configure-utils.sh

logTrace "======================"
logTrace "=== Configure v${LIB_VERSION} ==="
logTrace "======================"

. ${DIRBASENAME}/sh/configure-products.sh
. ${DIRBASENAME}/sh/configure-was.sh
. ${DIRBASENAME}/sh/configure-plugin.sh
. ${DIRBASENAME}/sh/configure-racf.sh

# commencer par effectuer les controles necessaires
doSanityChecks

# si on a selectionne une action on l'execute
if [[ $ACTION != "" ]]
then
  # et c'est parti !
  logTrace "=== Action a realiser : [ $ACTION ] ==="
  case ${ACTION} in
#   associate)
#     if [[ $3 != "" ]] && [[ $4 != "" ]]
#     then
#       doConfigurePlugin ${3} ${4}
#     else
#       logError "vous devez specifier des parametres avec l'option associate. utilisez l'option <help> pour plus de details."
#     fi
#      ;;
    install)
      if [[ $3 = "was" ]]
      then
        doInstallWAS
      elif [[ $3 = "racf" ]]
      then
        doInstallRacf
      elif [[ $3 = "jdk7" ]]
      then
        doInstallJDK7
      elif [[ $3 = "plugin" ]]
      then
        doInstallPlugin
      elif [[ $3 = "webserver" ]] && [[ $4 != "" ]]
      then
        doInstallWebServer ${4}
      else
        logError "vous devez specifier des parametres avec l'option install. utilisez l'option <help> pour plus de details."
      fi
      ;;
    update)
      if [[ $3 = "was" ]]
      then
        doUpdateWas
      elif [[ $3 = "library" ]] && [[ $4 != "" ]]
      then
        doUpdateLibrary ${4}
      elif [[ $3 = "plugin" ]]
      then
        doUpdatePlugin
      elif [[ $3 = "jdk7" ]]
      then
        doUpdateJdk7
      elif [[ $3 = "webserver" ]] && [[ $4 != "" ]]
      then
        doUpdateWebServer ${4}
      else
        logError "vous devez specifier des parametres avec l'option update. utilisez l'option <help> pour plus de details."
      fi
      ;;
    force)
      if [[ $3 = "jdk7" ]]
      then
        doForceJDK7
      elif [[ $3 = "jdk6" ]]
      then
        doForceJDK6
      else
        logError "vous devez specifier des parametres avec l'option force. utilisez l'option <help> pour plus de details."
      fi
      ;;
    create)
      if [[ $3 = "adminagent" ]] && [[ $4 = "profile" ]]
      then
        doCreateProfile "adminagent"
      elif [[ $3 = "jobmanager" ]] && [[ $4 = "profile" ]]
      then
        doCreateProfile "jobmgr"
      elif [[ $3 = "dmgr" ]] && [[ $4 = "profile" ]]
      then
        doCreateProfile "dmgr"
      elif [[ $3 != "" ]] && [[ $4 = "nodeprofile" ]]
      then
        doCreateNodeProfile ${3}
	  elif [[ $3 != "" ]] && [[ $4 = "profile" ]]
      then
        doCreateProfile ${3}
      else
        logError "vous devez specifier des parametres avec l'option create. utilisez l'option <help> pour plus de details."
      fi
      ;;
    register)
      if [[ $3 != "" ]] && [[ $4 = "with" ]] && [[ $5 = "admin" ]]
      then
        doRegisterProfile ${3} "adminagent"
      else
        logError "vous devez specifier des parametres avec l'option register. utilisez l'option <help> pour plus de details."
      fi
      ;;
    configure)
      if [[ $3 = "cell" ]]
      then
        doConfigureCell
      elif [[ $3 != "" ]]
      then
        doConfigure ${3}
      else
        logError "vous devez specifier des parametres avec l'option configure. utilisez l'option <help> pour plus de details."
      fi
      ;;
    secure)
      if [[ $3 != "" ]]
      then
        doSecureProfile ${3}
      else
        logError "vous devez specifier un parametre avec l'option secure. utilisez l'option <help> pour plus de details."
      fi
      ;;
    help)
      doShowParamError
      ;;
    *)
      logError "Action non reconnue : ${ACTION}. Arret immediat de la procedure. Utilisez l'option <help> pour obtenir de l'aide."
      doShowParamError
      ;;
  esac
else
  doShowParamError
fi

exit 0
