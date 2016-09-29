#--------------------------------------------------------------------
# Logger
#--------------------------------------------------------------------
# author : F. Colombo
#--------------------------------------------------------------------

import string

from java.util import Date
from java.text import SimpleDateFormat

#--------------------------------------------------------------------
# this is class intents to give custom logging services
# it's used by all the others classes...
#--------------------------------------------------------------------
class Logger:

	#==================================================================
	# private members
	#==================================================================
	# current date
	__currentDate=SimpleDateFormat('dd.MM.yyyy').format(Date())
	__currentDateTime=SimpleDateFormat("dd.MM.yyyy HH:mm:ss").format(Date())
	# default log level
	__logLevel = 'INFO'

	#==================================================================
	# setters
	#==================================================================
	def setLogLevel(self,v_logLevel):
		self.__logLevel = string.upper(v_logLevel)

	#==================================================================
	# getters
	#==================================================================
	def getLogLevel(self):
		return self.__logLevel

	def getCurrentDate(self):
		return self.__currentDate

	def getCurrentDateTime(self):
		return self.__currentDateTime

	#=================================================================
	# display a log
	#=================================================================
	def __log(self, level, message):
		level = string.upper(level)
		print '[%s %s] <%s> %s' % (self.__currentDate,SimpleDateFormat('HH:mm:ss').format(Date()),level,message)

	def debug(self, message):
		if self.__logLevel == 'DEBUG':
			self.__log('DEBUG',message)

	def info(self, message):
		if self.__logLevel in ['DEBUG','INFO']:
			self.__log('INFO',message)

	def warning(self, message):
		if self.__logLevel in ['DEBUG','INFO','WARNING']:
			self.__log('WARNING',message)

	def error(self, message):
		if self.__logLevel in ['DEBUG','INFO','WARNING','ERROR']:
			self.__log('ERROR',message)

	def fatal(self, message):
		if self.__logLevel in ['DEBUG','INFO','WARNING','ERROR','FATAL']:
			self.__log('FATAL',message)

	def isLogLevel(self,level):
		if (level is not None) and (level != ''):
			if string.upper(level) in ['DEBUG','INFO','WARNING','ERROR','FATAL']:
				return 1
		return 0
