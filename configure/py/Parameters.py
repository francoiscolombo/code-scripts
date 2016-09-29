#--------------------------------------------------------------------
# parameter's management
#--------------------------------------------------------------------
# author : F. Colombo
#--------------------------------------------------------------------

import sys
import string

from Logger import Logger


#--------------------------------------------------------------------
# only use for parameter's management
#--------------------------------------------------------------------
class Parameters:

	#==================================================================
	# private members
	#==================================================================
	__parameters = {}
	__log = Logger()

	#==================================================================
	# setters
	#==================================================================
	def setParameter(self,v_key,v_name,v_desc,v_sample,v_default):
		self.__parameters[v_key] = {}
		self.__parameters[v_key]['name'] = v_name
		self.__parameters[v_key]['desc'] = v_desc
		self.__parameters[v_key]['sample'] = v_sample
		self.__parameters[v_key]['value'] = v_default
		self.__parameters[v_key]['allowed'] = None

	def setParameterValuesAllowed(self,v_key,v_allowed):
		self.__parameters[v_key]['allowed'] = v_allowed

	#==================================================================
	# getter
	#==================================================================
	def getParameterValue(self,key):
		return self.__parameters[key]['value']

	#=================================================================
	# get script name
	#=================================================================
	def getScriptName(self):
		return self.__scriptName

	#=================================================================
	# parse command line
	#=================================================================
	def parseCmdLine(self,args):
		for i in range(0,len(args),2):
			key = string.lower(args[i]).replace('-','')
			found = 0
			for k in self.__parameters.keys():
				if key == k:
					va = self.__parameters[key]['allowed']
					if va is not None:
						if va.find(args[i+1]) < 0:
							self.__log.error('Valeur "%s" non reconnue pour le parametre "%s", les valeurs autorisees sont : "%s"...' % (args[i+1],key,va))
							self.doShowParams()
							sys.exit(-91)
					self.__parameters[key]['value'] = args[i+1]
					self.__log.debug('"%s" = "%s"' % (k,args[i+1]))
					found = 1
			if found == 0:
				self.__log.error('Parametre "%s" non reconnu...' % key)
				self.doShowParams()
				sys.exit(-92)
		for k in self.__parameters.keys():
			if self.__parameters[k]['value'] is None:
				self.__log.error('Le parametre "%s" est pas renseigne : execution du script impossible.' % k)
				self.doShowParams()
				sys.exit(-93)

	#=================================================================
	# display help
	#=================================================================
	def doShowParams(self):
		print ''
		print 'ce script necessite comme parametres :'
		sample = ''
		for k in self.__parameters.keys():
			sample += '--%s %s ' % (k,self.__parameters[k]['sample'])
			va = self.__parameters[k]['allowed']
			if va is None:
				print '--%s (%s) : %s' % (k,self.__parameters[k]['name'],self.__parameters[k]['desc'])
			else:
				print '--%s (%s) : %s. les valeurs autorisees pour ce parametre sont "%s".' % (k,self.__parameters[k]['name'],self.__parameters[k]['desc'],va)
		print 'e.g.:		 %s %s' % (self.getScriptName(),sample)
		print ''
