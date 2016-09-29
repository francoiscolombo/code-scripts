#--------------------------------------------------------------------
# some usefull utilities...
#--------------------------------------------------------------------
# author : F. Colombo
#--------------------------------------------------------------------

from Logger import Logger


#--------------------------------------------------------------------
# this class contains some usefull utilities for managing WAS
# objects
#--------------------------------------------------------------------
class Utilities:

	#==================================================================
	# private members
	#==================================================================
	__log = Logger()

	#==================================================================
	# constructor
	#==================================================================
	def __init__(self,wasAdmConfig,wasAdmControl,wasAdmTask):
		global AdminConfig, AdminControl, AdminTask, AdminApp
		AdminConfig = wasAdmConfig
		AdminControl = wasAdmControl
		AdminTask = wasAdmTask

	#==================================================================
	# getters
	#==================================================================
	def getCellId(self):
		return AdminConfig.getid('/Cell:'+AdminControl.getCell())

	def getCellName(self):
		return AdminControl.getCell()

	def getNodeName(self,srvName):
		nodeName = 'none'
		for nodeId in self.splitlines(AdminConfig.list('Node',AdminConfig.getid('/Cell:'+AdminControl.getCell()))):
			for srvId in self.splitlines(AdminConfig.list('Server',nodeId)):
				sname = AdminConfig.showAttribute(srvId,'name')
				if sname == srvName:
					nodeName = AdminConfig.showAttribute(nodeId,'name')
		if nodeName == 'none':
			self.__log.warning('impossible de retrouver le nom du noeud pour le serveur %s... verifiez le nom du serveur, SVP.' % srvName)
		return nodeName

	def getNodeId(self,srvName):
		nodeName = self.getNodeName(srvName)
		if nodeName == 'none':
			return AdminConfig.getid('/Node:'+AdminControl.getNode())
		return AdminConfig.getid('/Node:'+nodeName)

	def getServerId(self,srvName):
		return AdminConfig.getid('/Server:'+srvName)

	def getLogRoot(self):
		return "${LOG_ROOT}"

	def getFileStorePath(self):
		return self.getLogRoot()+'/stores/'

	def getStartingPort(self):
		for np in self.splitlines(AdminConfig.list('NamedEndPoint',AdminConfig.getid('/Cell:'+AdminControl.getCell()))):
			if AdminConfig.showAttribute(np,'endPointName') == 'WC_defaulthost':
				ep = AdminConfig.showAttribute(np,'endPoint')
				return AdminConfig.showAttribute(ep,'port')
		return 0

	def getHostName(self):
		scope=AdminConfig.getid('/Node:'+AdminControl.getNode())
		return AdminConfig.showAttribute(scope,'hostName')

	#==================================================================
	# convert string to array with linefeed
	#==================================================================
	def splitlines(self,s):
		rv = [s]
		if '\r' in s:
			rv = s.split('\r\n')
		elif '\n' in s:
			rv = s.split('\n')
		if rv[-1] == '':
			rv = rv[:-1]
		return rv

	#==================================================================
	# convert string array in real array
	#==================================================================
	def splitstrarray(self,s):
		if (s[0] == '[') and (s[len(s)-1] == ']'):
			s = s[1:len(s)-1]
		rv = [s]
		if ' ' in s:
			rv=s.split(' ')
		if rv[-1] == '':
			rv = rv[:-1]
		return rv

	#==================================================================
	# get path of a keystore
	#==================================================================
	def getKeyStorePath(self,keyStoreName):
		t=AdminTask.getKeyStoreInfo(['-keyStoreName',keyStoreName])
		t=t[t.find('[location '):]
		t=t[:t.find('] ')]
		return t[10:]

	#==================================================================
	# Sync configuration changes with nodes
	#==================================================================
	def synchronizeNodes(self):
		# Obtain deployment manager MBean
		dm = AdminControl.queryNames("type=DeploymentManager,*")
		# "syncActiveNodes" can only be run on the deployment manager's
		# MBean, it will fail in standalone environment
		if dm:
			self.__log.info('Synchronizing configuration repository with nodes. Please wait...')
			# Force sync with all currently active nodes
			nodes = AdminControl.invoke(dm, "syncActiveNodes", "true")
			self.__log.info('The following nodes have been synchronized:\n'+str(nodes))
		else:
			self.__log.info('Standalone server, no nodes to sync')
