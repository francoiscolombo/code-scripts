#--------------------------------------------------------------------
# composition of admin server for the cellule
#--------------------------------------------------------------------
# author : F. Colombo
#--------------------------------------------------------------------

import sys
import string
import traceback

from Logger import Logger
from XML import XML
from Utilities import Utilities
from Parameters import Parameters

#--------------------------------------------------------------------
# This is the class for managing cellule's composition
#--------------------------------------------------------------------
class ConfigureCell:

	#==================================================================
	# private members
	#==================================================================
	__nodes = map(lambda x: AdminConfig.showAttribute(x,'name'), AdminConfig.list('Node').split(lineSeparator))
	__servers = map(lambda x: AdminConfig.showAttribute(x,'name'), AdminConfig.list('Server').split(lineSeparator))
	__cfg = None
	__log = None
	__utl = None

	#==================================================================
	# constructor
	#==================================================================
	def __init__(self, project):
		self.__cfg = XML(project)
		self.__log = Logger()
		self.__utl = Utilities(AdminConfig,AdminControl,AdminTask)
		self.__nodes = filter(lambda a: (a.find('dmgr') < 0) and (a.find(AdminControl.getCell()) < 0), self.__nodes)
		self.__servers = filter(lambda a: (a.find('dmgr') < 0) and (a.find('nodeagent') < 0), self.__servers)

	#==================================================================
	# configure les jvm des process administratifs (dmgr, nodeagents)
	#==================================================================
	def doConfigureAdminJvm(self):
		# configure dmgr
		self.doConfigureJvm('dmgr')
		# confifure nodeagent
		jvm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='nodeagent']/jvm"))
		jvm = filter(lambda a: a[1] != '', jvm)
		maxHeap = int(filter(lambda a: a[0]=='maximumHeapSize',jvm)[0][1])
		minHeap = int(filter(lambda a: a[0]=='initialHeapSize',jvm)[0][1])
		if maxHeap >= minHeap:
			args = filter(lambda a: a[0]=='genericJvmArguments',jvm)[0][1]
			jvm = filter(lambda a: a[0]!='genericJvmArguments',jvm)
			jvm=map(lambda a: ['-' + a[0],a[1]], jvm)
			jvm.append(['-serverName','nodeagent'])
			for n in self.__cfg.getNodes("//composition/nodes/node"):
				nd = self.__cfg.getAttributes(n)
				prm = jvm
				prm.append(['-nodeName',nd['name']])
				prm=[p for pr in prm for p in pr]
				AdminTask.setJVMProperties(prm)
				AdminTask.setGenericJVMArguments('[-serverName nodeagent -nodeName %s -genericJvmArguments "%s"]' % (nd['name'],args))
				self.__log.info('nodeagent du node < %s > : java process configure' % nd['name'])
		else:
			self.__log.warning('configuration du process java des nodeagents impossible car les tailles de Heap specifiees sont incorrectes...')
		# confifure odr nodeagent
		jvm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='odrnode']/jvm"))
		jvm = filter(lambda a: a[1] != '', jvm)
		maxHeap = int(filter(lambda a: a[0]=='maximumHeapSize',jvm)[0][1])
		minHeap = int(filter(lambda a: a[0]=='initialHeapSize',jvm)[0][1])
		if maxHeap >= minHeap:
			args = filter(lambda a: a[0]=='genericJvmArguments',jvm)[0][1]
			jvm = filter(lambda a: a[0]!='genericJvmArguments',jvm)
			jvm=map(lambda a: ['-' + a[0],a[1]], jvm)
			jvm.append(['-serverName','nodeagent'])
			for n in self.__cfg.getNodes("//composition/odrnodes/node"):
				nd = self.__cfg.getAttributes(n)
				prm = jvm
				prm.append(['-nodeName',nd['name']])
				prm=[p for pr in prm for p in pr]
				AdminTask.setJVMProperties(prm)
				AdminTask.setGenericJVMArguments('[-serverName nodeagent -nodeName %s -genericJvmArguments "%s"]' % (nd['name'],args))
				self.__log.info('nodeagent du node < %s > : java process configure' % nd['name'])
		else:
			self.__log.warning('configuration du process java des nodeagents impossible car les tailles de Heap specifiees sont incorrectes...')

	#==================================================================
	# configure webservers
	# TODO: configuration SSL !!!
	#==================================================================
	def doConfigureWebServers(self):
		for w in self.__cfg.getNodes("//webservers/webserver"):
			ws = self.__cfg.getAttributes(w)
			try:
				wsid = AdminTask.createWebServer(ws['node'], '[-name %s -templateName IHS -serverConfig [-webPort %s -webInstallRoot %s -webProtocol HTTP -pluginInstallRoot %s -webAppMapping ALL] -remoteServerConfig [-adminPort %s -adminPasswd WebAS HTTP]]' % (ws['name'],ws['port'],ws['webInstallRoot'],ws['pluginInstallRoot'],ws['adminPort']))
				AdminTask.enableIntelligentManagement('[-node %s -webserver %s -cellIdentifier %s -retryInterval 60 -maxRetries "-1"]' % (ws['node'],ws['name'],AdminControl.getCell()))
				self.__log.info('WebServer < %s > cree. attention, vous devez realiser la configuration SSL manuellement !' % ws['name'])
			except:
				self.__log.info('WebServer < %s > deja existant, operation ignoree' % ws['name'])

	#==================================================================
	# configure On Demand Router servers
	# TODO: to be able to rerun the script
	#==================================================================
	def doConfigureODR(self):
		firstMember = 1
		clusterName = self.__cfg.getStringAttribute("//composition/clusters/odrcluster", 'name')
		clId = AdminConfig.getid('/ServerCluster:%s' % clusterName)
		for s in self.__cfg.getNodes("//composition/clusters/odrcluster/server"):
			so = self.__cfg.getAttributes(s)
			if not AdminConfig.getid('/ClusterMember:%s' % so['name']):
				if firstMember:
					AdminTask.createOnDemandRouter(so['node'], '[-name %s -templateName odr -genUniquePorts true ]' % so['name'])
					self.__log.info('OnDemandRouter < %s > cree sur le node < %s >' % (so['name'],so['node']))
					clId = AdminTask.createCluster(['-clusterConfig', ['-clusterName', clusterName, '-clusterType', 'ONDEMAND_ROUTER'], '-convertServer', ['-serverNode', so['node'], '-serverName', so['name']]])
					self.__log.info('Cluster de type "OnDemandRouter" < %s > cree.' % (clusterName))
					firstMember = 0
				else:
					AdminTask.createClusterMember(['-clusterName', clusterName, '-memberConfig', ['-memberNode', so['node'], '-memberName', so['name']]])
			offset = int(so['offsetPorts'])
			hostName = AdminConfig.showAttribute(self.__utl.getNodeId(so['name']),'hostName')
			for x in self.__cfg.getListNodes("//profile[@name='%s']/ports/port" % so['profile']):
				AdminTask.modifyServerPort(so['name'], '[-nodeName %s -endPointName %s -host %s -port %s -modifyShared true]' % (so['node'],x['name'],hostName,offset+int(x['value'])))
			self.__log.info('OnDemandRouter < %s > mise a jour des ports : OK' % so['name'])
			self.doConfigureJvm(so['name'])
		odrNGname = self.__cfg.getStringAttribute("//composition/odrnodes", 'nodeGroupName')
		AdminConfig.modify(clId,[['nodeGroupName',odrNGname]])
		self.__log.info('NodeGroup < %s > affecte au cluster < %s >' % (odrNGname,clusterName))

	#==================================================================
	# configure dynamic cluster
	# TODO: to be able to rerun the script
	#==================================================================
	def doConfigureDynamicCluster(self):
		dcn = self.__cfg.getNode("//composition/clusters/dynamiccluster")
		if dcn == None:
			self.__log.info('pas de cluster dynamique a configurer.')
			return
		dc = self.__cfg.getAttributes(dcn)
		if not AdminConfig.getid('/DynamicCluster:%s' % dc['name']):
			AdminTask.createDynamicCluster(dc['name'],'[-membershipPolicy "%s" -dynamicClusterProperties "[[operationalMode %s][minInstances %s][maxInstances %s][numVerticalInstances %s][serverInactivityTime %s]]" -clusterProperties "[[preferLocal %s][createDomain %s][templateName %s][coreGroup %s][clusterShortName %s][serverSpecificShortNames %s]]"]' %
										   (dc['membershipPolicy'],dc['operationalMode'],dc['minInstances'],dc['maxInstances'],dc['numVerticalInstances'],dc['serverInactivityTime'],dc['preferLocal'],dc['createDomain'],dc['templateName'],dc['coreGroup'],dc['clusterShortName'],dc['serverSpecificShortNames']))
			self.__log.info('le cluster dynamique < %s > existe deja, il ne sera pas recree.' % dc['name'])
		else:
			self.__log.info('le cluster dynamique < %s > est maintenant cree.' % dc['name'])

	#==================================================================
	# configure coregroup
	#==================================================================
	def doConfigureCoreGroup(self):
		if self.__cfg.getNode("//composition/clusters/coregroup") == None:
			self.__log.info('pas de coregroup a configurer.')
			return
		pcg = self.__cfg.convertAttributes(self.__cfg.getNode("//composition/clusters/coregroup"))
		name = filter(lambda a: a[0]=='name',pcg)[0][1]
		pcg = filter(lambda a: a[0]!='name',pcg)
		cgid = None
		for id in AdminConfig.list('CoreGroup', self.__utl.getCellId()).split(lineSeparator):
			if AdminConfig.showAttribute(id,'name') == name:
				cgid = id
				continue
		if cgid == None:
			cgid = AdminTask.createCoreGroup(['-coreGroupName', name])
			self.__log.info('creation du core group < %s > : OK' % name)
		AdminConfig.modify(cgid, pcg)
		self.__log.info('mise a niveau du parametrage du core group < %s > : OK' % name)
		lid = AdminConfig.showAttribute(cgid,'liveness')
		pln = self.__cfg.convertAttributes(self.__cfg.getNode("//composition/clusters/coregroup/liveness"))
		AdminConfig.modify(lid, pln)
		self.__log.info('mise a niveau des options "Liveness" du core group < %s > : OK' % name)
		# configure node groups
		for ng in self.__cfg.getNodes("//composition/nodes"):
			png = self.__cfg.getAttributes(n)
			ngname = filter(lambda a: a[0]=='name',png)[0][1]
			try:
				AdminTask.createNodeGroup(ngname, '[-shortName %s -description ]' % ngname)
				self.__log.info('creation du node group < %s > : OK' % ngname)
			except:
				self.__log.info('node group < %s > deja existant...' % ngname)
			for n in self.__cfg.getNodes("//composition/nodes[@nodeGroupName='%s']/node" % ngname):
				nn = self.__cfg.getAttributes(n)
				try:
					AdminTask.addNodeGroupMember(ngname, '[-nodeName %s]' % nn['name'])
					self.__log.info('node < %s > ajoute dans le node group < %s >' % (nn['name'],ngname))
				except:
					self.__log.info('node < %s > deja present dans le node groupe < %s >' % (nn['name'],ngname))

	#==================================================================
	# configure clusters
	#==================================================================
	def doConfigureClusters(self):
		cgname = self.__cfg.getStringAttribute("//composition/clusters/coregroup", 'name')
		for c in self.__cfg.getNodes("//composition/clusters/cluster"):
			cl = self.__cfg.getAttributes(c)
			clid = None
			if AdminConfig.list('ServerCluster', self.__utl.getCellId()) != '':
				for id in AdminConfig.list('ServerCluster', self.__utl.getCellId()).split(lineSeparator):
					if AdminConfig.showAttribute(id,'name') == cl['name']:
						clid = id
						continue
			if clid == None:
				clid = AdminTask.createCluster('[-clusterConfig [-clusterName %s -preferLocal true] -replicationDomain [-createDomain true]]' % cl['name'])
				AdminConfig.modify(clid, '[[serverIOTimeoutRetry "3"]]')
				self.__log.info('creation du cluster < %s > : OK' % cl['name'])
			drdid = None
			AdminConfig.modify(clid,[['nodeGroupName',cl['nodeGroupName']]])
			self.__log.info('association du cluster < %s > avec le node group < %s > : OK' % (cl['name'],cl['nodeGroupName']))
			if AdminConfig.list('DataReplicationDomain', self.__utl.getCellId()) != '':
				for id in AdminConfig.list('DataReplicationDomain', self.__utl.getCellId()).split(lineSeparator):
					if AdminConfig.showAttribute(id,'name') == cl['name']:
						drdid = id
						continue
			if drdid != None:
				drid = AdminConfig.showAttribute(drdid,'defaultDataReplicationSettings')
				if (drid != '') and (drid is not None):
					pdr = self.__cfg.convertAttributes(self.__cfg.getNode("//composition/clusters/cluster[@name='%s']/datareplication" % cl['name']))
					AdminConfig.modify(drid, pdr)
					self.__log.info('mise a niveau du domaine de replication du cluster < %s > : OK' % cl['name'])
			ngname = self.__cfg.getStringAttribute("//composition/nodes", 'nodeGroupName')
			members = AdminConfig.showAttribute(clid,'members')
			firstMember = (members.find('tpcomgf11') >= 0)
			for s in self.__cfg.getNodes("//composition/clusters/cluster[@name='%s']/server" % cl['name']):
				srv = self.__cfg.getAttributes(s)
				if srv['node'] in self.__nodes:
					if firstMember:
						try:
							AdminTask.createClusterMember('[-clusterName %s -memberConfig [-memberNode %s -memberName %s -memberWeight 2 -genUniquePorts true -replicatorEntry false] -firstMember [-templateName defaultXD -nodeGroup %s -coreGroup %s -resourcesScope cluster]]' % (cl['name'],srv['node'],srv['name'],ngname,cgname))
							self.__log.info('ajout de < %s > en tant que premier membre du cluster < %s > : OK' % (srv['name'],cl['name']))
						except:
							self.__log.info('< %s > est deja membre du cluster < %s >' % (srv['name'],cl['name']))
						firstMember = 0
					else:
						try:
							AdminTask.createClusterMember('[-clusterName %s -memberConfig [-memberNode %s -memberName %s -memberWeight 2 -genUniquePorts true -replicatorEntry false]]' % (cl['name'],srv['node'],srv['name']))
						except:
							self.__log.info('< %s > est deja membre du cluster < %s >' % (srv['name'],cl['name']))
					offset = int(srv['offsetPorts'])
					for x in self.__cfg.getListNodes("//profile[@name='%s']/ports/port" % srv['profile']):
						hostName = AdminConfig.showAttribute(self.__utl.getNodeId(srv['name']),'hostName')
						AdminTask.modifyServerPort(srv['name'], '[-nodeName %s -endPointName %s -host %s -port %s -modifyShared true]' % (srv['node'],x['name'],hostName,offset+int(x['value'])))
					self.__log.info('creation de < %s > appartenant au node < %s > dans le cluster < %s > realisee' % (srv['name'],srv['node'],cl['name']))
				else:
					self.__log.warning('creation de < %s > impossible car le node < %s > existe pas...' % (srv['name'],srv['node']))
			AdminTask.updateCluster('[-clusterName %s -preferLocal [-preferLocal true] -transactionLogRecovery [-transactionLogRecovery enabled]]' % cl['name'])
			self.__log.info('activation "transaction log recovery" pour le cluster < %s > realisee' % cl['name'])
			try:
				AdminTask.moveClusterToCoreGroup('[-source DefaultCoreGroup -target %s -clusterName %s]' % (cgname,cl['name']))
				self.__log.info('affectation du cluster < %s > au coregroup < %s > : OK' % (cl['name'],cgname))
			except:
				pass

	#==================================================================
	# configure jvm
	#==================================================================
	def doConfigureJvm(self, srvName):
		nodeName = self.__utl.getNodeName(srvName)
		hostName = AdminConfig.showAttribute(AdminConfig.getid('/Node:'+nodeName),'hostName')
		prfName = self.__cfg.getStringAttribute("//composition/clusters/cluster/server[@name='%s']" % srvName, 'profile')
		if prfName == '':
			prfName = self.__cfg.getStringAttribute("//composition/servers/server[@name='%s']" % srvName, 'profile')
			if prfName == '':
				prfName = self.__cfg.getStringAttribute("//composition/clusters/odrcluster/server[@name='%s']" % srvName, 'profile')
				if prfName == '':
					prfName = srvName
		if nodeName == '':
			nodeName = self.__cfg.getStringAttribute("//composition/servers/server[@name='%s']" % srvName, 'nodeName')
		if nodeName in self.__nodes:
			jvm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/jvm" % prfName))
			jvm = filter(lambda a: a[1] != '', jvm)
			maxHeap = int(filter(lambda a: a[0]=='maximumHeapSize',jvm)[0][1])
			minHeap = int(filter(lambda a: a[0]=='initialHeapSize',jvm)[0][1])
			args = filter(lambda a: a[0]=='genericJvmArguments',jvm)[0][1]
			jvm = filter(lambda a: a[0]!='genericJvmArguments',jvm)
			jvm=map(lambda a: ['-' + a[0],a[1]], jvm)
			jvm.append(['-serverName',srvName,'-nodeName',nodeName])
			jvm=[j for jv in jvm for j in jv]
			if maxHeap >= minHeap:
				AdminTask.setJVMProperties(jvm)
				AdminTask.setGenericJVMArguments('[-serverName %s -nodeName %s -genericJvmArguments "%s"]' % (srvName,nodeName,args))
				self.__log.info('app server < %s > : java process configure' % srvName)
			else:
				self.__log.warning('configuration du process java de < %s > impossible...' % srvName)
			for sp in self.__cfg.getListNodes("//profiles/profile[@name='%s']/ports/port" % prfName):
				AdminTask.modifyServerPort(srvName, '[-nodeName %s -endPointName %s -host %s -port %s -modifyShared true]' % (nodeName,sp['name'],hostName,sp['value']))
			self.__log.warning('configuration des ports de < %s > realisee.' % srvName)

	#==================================================================
	# clear virtual host
	#==================================================================
	def doClearVirtualHosts(self):
		vhid = AdminConfig.getid('/VirtualHost:default_host')
		for alias in self.__utl.splitlines(AdminConfig.list('HostAlias',vhid)):
			AdminConfig.remove(alias)
		self.__log.info('virtual hosts nettoyes.')

	#==================================================================
	# server's own configuration
	#==================================================================
	def doConfigureAppServer(self, srvName):
		nodeName = self.__utl.getNodeName(srvName)
		isClusterServer = 1
		prfName = self.__cfg.getStringAttribute("//composition/clusters/cluster/server[@name='%s']" % srvName, 'profile')
		if prfName == '':
			prfName = self.__cfg.getStringAttribute("//composition/clusters/dynamiccluster[@name='%s']/serverTemplate" % srvName, 'profile')
			if prfName == '':
				prfName = self.__cfg.getStringAttribute("//composition/servers/server[@name='%s']" % srvName, 'profile')
				isClusterServer = 0
				if prfName == '':
		self.__log.error('vous tentez de configurer le serveur < %s > mais ce n\'est pas un serveur manage !!! operation annulee.' % srvName)
		return
if nodeName == '':
	nodeName = self.__cfg.getStringAttribute("//composition/servers/server[@name='%s']" % srvName, 'nodeName')
if nodeName in self.__nodes:
	# configure virtual host
	vhid = AdminConfig.getid('/VirtualHost:default_host')
	httpPort = self.__cfg.getStringAttribute('//profiles/profile[@name="%s"]/ports/port[@name="WC_defaulthost"]' % (prfName),'value')
	httpsPort = self.__cfg.getStringAttribute('//profiles/profile[@name="%s"]/ports/port[@name="WC_defaulthost_secure"]' % (prfName),'value')
	hostName = AdminConfig.showAttribute(AdminConfig.getid('/Node:%s' % nodeName),'hostName')
	httpExists = 0
	httpsExists = 0
	for ha in self.__utl.splitlines(AdminConfig.list('HostAlias')):
		if (AdminConfig.showAttribute(ha,'hostname') == hostName) and (AdminConfig.showAttribute(ha,'port') == httpPort):
			httpExists = 1
		elif (AdminConfig.showAttribute(ha,'hostname') == hostName) and (AdminConfig.showAttribute(ha,'port') == httpsPort):
			httpsExists = 1
	if not httpExists:
		AdminConfig.create('HostAlias',vhid,[['hostname',hostName],['port',httpPort]])
	if not httpsExists:
		AdminConfig.create('HostAlias',vhid,[['hostname',hostName],['port',httpsPort]])
	self.__log.info('ajout des virtualhosts pour le serveur %s : OK' % (srvName))
	for sp in self.__cfg.getListNodes("//profiles/profile[@name='%s']/ports/port" % prfName):
		AdminTask.modifyServerPort(srvName, '[-nodeName %s -endPointName %s -host %s -port %s -modifyShared true]' % (nodeName,sp['name'],hostName,sp['value']))
	self.__log.info('ports du server < %s > : configure' % srvName)
	# begin with JVM parameters
jvm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/jvm" % prfName))
jvm = filter(lambda a: a[1] != '', jvm)
maxHeap = int(filter(lambda a: a[0]=='maximumHeapSize',jvm)[0][1])
minHeap = int(filter(lambda a: a[0]=='initialHeapSize',jvm)[0][1])
jvm=map(lambda a: ['-' + a[0],a[1]], jvm)
jvm=[j for jv in jvm for j in jv]
jvmprm = '['
for v in jvm:
	jvmprm += ' %s' % v
jvmprm += ' ]'
if maxHeap >= minHeap:
	AdminTask.setJVMProperties(self.__utl.getServerId(srvName),jvmprm)
	self.__log.info('app server < %s > : java process configure' % srvName)
else:
	self.__log.warning('configuration du process java de < %s > impossible...' % srvName)
# begin with classpath
prfClasspath = self.__cfg.getNodeValue("//profiles/profile[@name='%s']/classpath" % (prfName))
jvmClasspath = self.__cfg.getNodeValue("//composition/clusters/cluster/server[@name='%s']/classpath" % (srvName))
srvJvmClasspath = self.__cfg.getNodeValue("//composition/servers/server[@name='%s']/classpath" % (srvName))
if (prfClasspath != '') or (jvmClasspath != '') or (srvJvmClasspath != ''):
	jvmId = AdminConfig.list('JavaVirtualMachine',AdminConfig.getid('/Server:'+srvName))
	AdminConfig.unsetAttributes(jvmId, '["classpath"]')
	AdminTask.setJVMProperties('[-serverName %s -classpath [%s %s %s ]]' % (srvName,prfClasspath,jvmClasspath,srvJvmClasspath))
	self.__log.info('classpath mis a jour pour le serveur %s' % (srvName))
# !!! BUG on native memory management !!! : we must deactivate asynchronous processing for the webcontainer
webctn = AdminConfig.list('WebContainer',self.__utl.getServerId(srvName))
for p in AdminConfig.list('Property',webctn).splitlines():
	pName = AdminConfig.showAttribute(p,'name')
	if pName == 'com.ibm.ws.webcontainer.channelwritetype':
		AdminConfig.remove(p)
AdminConfig.create('Property', webctn, '[[validationExpression ""] [name "com.ibm.ws.webcontainer.channelwritetype"] [description "permet de reduire usage de la memoire native"] [value "sync"] [required "false"]]')
self.__log.info('ajout de la customproperty "channelwritetyp" au webcontainer du serveur %s' % (srvName))
tcsid=AdminConfig.list('TransportChannelService',self.__utl.getServerId(srvName))
tcpfact=AdminConfig.list('TCPFactory',tcsid)
if tcpfact != '':
	AdminConfig.remove(tcpfact)
tcpfact=AdminConfig.create('TCPFactory',tcsid,'')
# note : reactivate with value of 'com.ibm.ws.tcp.channel.impl.AioTCPChannel'
AdminConfig.create('Property',tcpfact,'[[name "commClass"] [value "com.ibm.ws.tcp.channel.impl.NioTCPChannel"]]')
self.__log.info('creation de la tcpfactory et ajout de la customproperty "commClass" pour le serveur %s' % (srvName))
# coredump directories
processDef = AdminConfig.list('JavaProcessDef', self.__utl.getServerId(srvName))
pVars = ['IBM_HEAPDUMP','IBM_HEAPDUMP_OUTOFMEMORY','IBM_JAVADUMP_OUTOFMEMORY','IBM_HEAPDUMPDIR','IBM_JAVACOREDIR']
for p in self.__utl.splitstrarray(AdminConfig.showAttribute(processDef,'environment')):
	pName = AdminConfig.showAttribute(p,'name')
	if pName in pVars:
		AdminConfig.remove(p)
AdminConfig.create('Property', processDef, '[[name IBM_HEAPDUMP][required false] [value true]]')
AdminConfig.create('Property', processDef, '[[name IBM_HEAPDUMP_OUTOFMEMORY][required false] [value true]]')
AdminConfig.create('Property', processDef, '[[name IBM_JAVADUMP_OUTOFMEMORY][required false] [value true]]')
AdminConfig.create('Property', processDef, '[[name IBM_HEAPDUMPDIR][required false] [value ${LOG_ROOT}/coredumps]]')
AdminConfig.create('Property', processDef, '[[name IBM_JAVACOREDIR][required false] [value ${LOG_ROOT}/coredumps]]')
self.__log.info('repertoire des coredump positionne sur "${LOG_ROOT}/coredumps" pour le serveur %s' % (srvName))
# configure recovery logs (only for cluster's servers)
if isClusterServer:
	rlprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/tranlog/recoveryLog" % prfName))
	rlprm = [ [a[0],a[1].replace('!SERVERNAME!',srvName)] for a in rlprm ]
	seid = AdminConfig.getid('/ServerEntry:'+srvName)
	rlid = AdminConfig.showAttribute(seid,'recoveryLog')
	if rlid is None:
		AdminConfig.create('RecoveryLog',seid,rlprm)
		self.__log.info('creation du recoverylog du serveur <%s> : OK' % srvName)
	else:
		AdminConfig.modify(rlid,rlprm)
		self.__log.info('mise a jour du recoverylog du serveur <%s> : OK' % srvName)
	# it's not all : we need also to setup the compensation service
	csprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/tranlog/compensationService" % prfName))
	csprm = [ [a[0],a[1].replace('!SERVERNAME!',srvName)] for a in csprm ]
	pme51id=AdminConfig.list('PME51ServerExtension',self.__utl.getServerId(srvName))
	cpid=AdminConfig.showAttribute(pme51id,'compensationService')
	if cpid is None:
		cpid=AdminConfig.create('CompensationService',pme51id,csprm)
	else:
		AdminConfig.modify(cpid,csprm)
# configure session manager
smid = AdminConfig.list('SessionManager',self.__utl.getServerId(srvName))
smprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/webcontainer/sessionManager" % prfName))
AdminConfig.modify(smid, smprm)
tpid = AdminConfig.list('TuningParams',self.__utl.getServerId(srvName))
tpprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/webcontainer/tuningParams" % prfName))
AdminConfig.modify(tpid, tpprm)
self.__log.info('mise a jour du session manager du serveur <%s> : OK' % srvName)
cookieid = ''
for cid in self.__utl.splitlines(AdminConfig.list('Cookie',self.__utl.getServerId(srvName))):
	cookieid = cid
if cookieid != '':
	ckprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/webcontainer/cookie" % prfName))
	AdminConfig.modify(cookieid, ckprm)
	self.__log.info('mise a jour de cookie pour <%s> : OK' % srvName)
else:
	self.__log.warning('pas de cookie pour <%s>, aucune mise a jour a realiser.' % srvName)
# update EJB container... if we need.
if self.__cfg.getNode("//profiles/profile[@name='%s']/ejbcontainer" % prfName) is not None:
	ecoid = AdminConfig.list('EJBContainer',self.__utl.getServerId(srvName))
	ecoprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/ejbcontainer" % prfName))
	AdminConfig.modify(ecoid, ecoprm)
	self.__log.info('mise a jour du container ejb de <%s> : OK' % srvName)
if self.__cfg.getNode("//profiles/profile[@name='%s']/ejbcontainer/ejbcache" % prfName) is not None:
	ecaid = AdminConfig.list('EJBCache',self.__utl.getServerId(srvName))
	ecaprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/ejbcontainer/ejbcache" % prfName))
	AdminConfig.modify(ecaid, ecaprm)
	self.__log.info('mise a jour du cache ejb de <%s> : OK' % srvName)
if self.__cfg.getNode("//profiles/profile[@name='%s']/ejbcontainer/ejbtimer" % prfName) is not None:
	etiid = AdminConfig.list('EJBTimer',self.__utl.getServerId(srvName))
	etiprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/ejbcontainer/ejbtimer" % prfName))
	AdminConfig.modify(etiid, etiprm)
	self.__log.info('mise a jour des timers ejb de <%s> : OK' % srvName)
if self.__cfg.getNode("//profiles/profile[@name='%s']/ejbcontainer/ejbasync" % prfName) is not None:
	easid = AdminConfig.list('EJBAsync',self.__utl.getServerId(srvName))
	easprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/ejbcontainer/ejbasync" % prfName))
	AdminConfig.modify(easid, easprm)
	self.__log.info('mise a jour du asynchronisme ejb de <%s> : OK' % srvName)
# configure server's threadpools
tpmid = AdminConfig.list('ThreadPoolManager',self.__utl.getServerId(srvName))
for t in self.__cfg.getNodes("//profiles/profile[@name='%s']/threadpools/threadpool" % prfName):
	tprm = self.__cfg.convertAttributes(t)
	tpname = filter(lambda a: a[0]=='name',tprm)[0][1]
	tprm = filter(lambda a: a[0]!='name',tprm)
	for tpid in self.__utl.splitstrarray(AdminConfig.showAttribute(tpmid,'threadPools')):
		if tpname == AdminConfig.showAttribute(tpid, 'name'):
			AdminConfig.modify(tpid, tprm)
			self.__log.info('mise a jour du threadpool < %s > pour le serveur < %s > : OK' % (tpname,srvName))
# configure server's services
for s in self.__cfg.getNodes("//profiles/profile[@name='%s']/services/service" % prfName):
	sa = self.__cfg.getAttributes(s)
	sid = AdminConfig.list(sa['name'],self.__utl.getServerId(srvName))
	if (sid is None) or (sid == ''):
		p = self.__cfg.getNodesList("//profiles/profile[@name='%s']/services/service[@name='%s']/properties/property" % (prfName,sa['name']))
		for i in range(0,p.getLength()):
			pName = p.item(i).getAttributes().getNamedItem('name').getNodeValue()
			pValue = p.item(i).getAttributes().getNamedItem('value').getNodeValue()
			pValue = pValue.replace('!SERVERNAME!',srvName)
			for pp in self.__utl.splitstrarray(AdminConfig.showAttribute(sid,'properties')):
				if pName == AdminConfig.showAttribute(pp,'name'):
					AdminConfig.remove(pp)
			AdminConfig.create('Property', sid, [['name', name], ['value', value]])
		self.__log.info('properties du service < %s > mise a jour sur < %s >' % (sa['name'],srvName))
# set ssl configuration for transport chain, if needed
for tchid in AdminTask.listChains(tcsid).split(lineSeparator):
	tchname = AdminConfig.showAttribute(tchid,'name')
	tchssl = self.__cfg.getStringAttribute("//profiles/profile[@name='%s']/transportChains/transportChain[@name='%s']" % (prfName,tchname), 'sslConfig')
	if tchssl != '':
		for tcs in self.__utl.splitstrarray(AdminConfig.showAttribute(tchid,'transportChannels')):
			if AdminConfig.getObjectType(tcs) == 'SSLInboundChannel':
				AdminConfig.modify(tcs,[['sslConfigAlias',tchssl]])
				self.__log.info('mise a jour SSL Inbound < %s > pour le serveur < %s > : OK' % (tchssl,srvName))
				continue
# configure server's custom properties
jvmid = AdminConfig.list('JavaVirtualMachine',self.__utl.getServerId(srvName))
for p in self.__utl.splitstrarray(AdminConfig.showAttribute(jvmid,'systemProperties')):
	AdminConfig.remove(p)
for p in self.__cfg.getNodes("//profiles/profile[@name='%s']/properties/property" % prfName):
	AdminConfig.create('Property', jvmid, self.__cfg.convertAttributes(p))
for p in self.__cfg.getNodes("//composition/clusters/cluster/server[@name='%s']/properties/property" % srvName):
	AdminConfig.create('Property', jvmid, self.__cfg.convertAttributes(p))
for p in self.__cfg.getNodes("//composition/servers/server[@name='%s']/properties/property" % srvName):
	AdminConfig.create('Property', jvmid, self.__cfg.convertAttributes(p))
self.__log.info('ajout des custom properties pour le serveur < %s > : OK' % srvName)
# and finally, configure classloader
asid = AdminConfig.list('ApplicationServer',self.__utl.getServerId(srvName))
for c in self.__cfg.getNodes("//profiles/profile[@name='%s']/classloaders/classloader" % prfName):
	cldr = self.__cfg.getAttributes(c)
	if AdminConfig.list('Classloader',self.__utl.getServerId(srvName))!= '':
		for scl in AdminConfig.list('Classloader',self.__utl.getServerId(srvName)).split(lineSeparator):
			if AdminConfig.list('LibraryRef',scl) != '':
				for sclr in AdminConfig.list('LibraryRef',scl).split(lineSeparator):
					lrName = AdminConfig.showAttribute(sclr,'libraryName')
					if lrName == cldr['libname']:
						AdminConfig.remove(scl)
						continue
	AdminConfig.create('LibraryRef', AdminConfig.create('Classloader', asid, [['mode', cldr['mode']]]), [['libraryName', cldr['libname']],	['sharedClassloader', 'true']])
	self.__log.info('configuration du classloader de < %s > pour la librairie < %s > : OK' % (srvName,cldr['libname']))
srvcldr = self.__cfg.getAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/classloaders/serverclassloader" % prfName))
if (srvcldr['policy'] != '') and (srvcldr['mode'] != ''):
	AdminConfig.modify(asid, [ ['name',srvName], ['applicationClassLoaderPolicy',srvcldr['policy']], ['applicationClassLoadingMode',srvcldr['mode']] ])
	self.__log.info('configuration classloader du serveur < %s > : OK' % srvName)

#==================================================================
# configure HPEL
#==================================================================
def doConfigureHPEL(self, nodeId, srvId):
	srvName = AdminConfig.showAttribute(srvId,'name')
	nodeName = AdminConfig.showAttribute(nodeId,'name')
	prfName = self.__cfg.getStringAttribute("//composition/clusters/cluster/server[@name='%s']" % srvName, 'profile')
	if prfName == '':
		prfName = self.__cfg.getStringAttribute("//composition/servers/server[@name='%s']" % srvName, 'profile')
		if prfName == '':
			prfName = self.__cfg.getStringAttribute("//composition/clusters/odrcluster/server[@name='%s']" % srvName, 'profile')
			if prfName == '':
				prfName = srvName
	if self.__cfg.getNode("//profiles/profile[@name='%s']/hpel" % prfName):
		raslid = AdminConfig.getid('/Cell:%s/Node:%s/Server:%s/RASLoggingService:/' % (AdminControl.getCell(),nodeName,srvName))
		if raslid:
			AdminConfig.modify(raslid,[['enable','false']])
			hpelid = AdminConfig.getid('/Cell:%s/Node:%s/Server:%s/HighPerformanceExtensibleLogging:/' % (AdminControl.getCell(),nodeName,srvName))
			if hpelid:
				hprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/hpel" % prfName))
				hlgprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/hpel/hpelLog" % prfName))
				htrprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/hpel/hpelTrace" % prfName))
				htxprm = self.__cfg.convertAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/hpel/hpelTextLog" % prfName))
				hprm.append(['hpelLog',hlgprm])
				hprm.append(['hpelTrace',htrprm])
				hprm.append(['hpelTextLog',htxprm])
				AdminConfig.modify(hpelid,hprm)
				self.__log.info('HPEL configure pour le serveur %s' % (srvName))

#==================================================================
# configure variables
#==================================================================
def doConfigureVariables(self):
	for v in self.__cfg.getNodes("//resources/variables/variable"):
		prm = self.__cfg.convertAttributes(v)
		vname = filter(lambda a: a[0]=='variableName',prm)[0][1]
		prm=map(lambda a: ['-' + a[0],a[1]],prm)
		prm=[p for pr in prm for p in pr]
		try:
			AdminTask.removeVariable(['-variableName',vname])
		except:
			pass
		AdminTask.setVariable(prm)
		self.__log.info('creation de la variable < %s > realisee' % (vname))

#==================================================================
# configure data sources
#==================================================================
def doConfigureDataSources(self,prvname,prvid):
	for d in self.__cfg.getNodes("//resources/providers/provider[@name='%s']/datasources/datasource" % prvname):
		prm = self.__cfg.convertAttributes(d)
		dbname = filter(lambda a: a[0]=='name',prm)[0][1]
		authname = filter(lambda a: a[0]=='componentManagedAuthenticationAlias',prm)[0][1]
		dsid = AdminConfig.getid('/DataSource:%s' % dbname)
		try:
			AdminTask.deleteDatasource(dsid)
			self.__log.info('suppression de la datasource < %s > appartenant au provider < %s > realisee' % (dbname,prvname))
		except:
			pass
		prm=map(lambda a: ['-' + a[0],a[1]],prm)
		prm=[p for pr in prm for p in pr]
		if prvname.find('DB2') >= 0:
			prm.append('-configureResourceProperties')
			prm.append(self.__cfg.getPropertiesList("//resources/providers/provider[@name='%s']/datasources/datasource[@name='%s']" % (prvname,dbname), ['driverType','databaseName','serverName','portNumber']))
		else:
			props = self.__cfg.getPropertiesList("//resources/providers/provider[@name='%s']/datasources/datasource[@name='%s']" % (prvname,dbname), ['driverType','databaseName'])
			if props:
				prm.append('-configureResourceProperties')
				prm.append(props)
		dsid = AdminTask.createDatasource(prvid,prm)
		self.__log.info('provider <%s> | creation datasource < %s > OK' % (prvname,dbname))
		if dbname.find('TRANLOG') >=0:
			AdminConfig.modify(dsid, '[[logMissingTransactionContext "true"] [statementCacheSize "10"]]')
			self.__log.info('provider <%s> | datasource < %s > | DB des tranlogs identifiee > PRM OK' % (prvname,dbname))
		if authname != '':
			mmid = AdminConfig.showAttribute(dsid,'mapping')
			if mmid == None:
				mmid = AdminConfig.create('MappingModule', dsid, '[[authDataAlias %s] [mappingConfigAlias ""]]' % authname)
				self.__log.info('provider <%s> | datasource < %s > | creation mapping module OK' % (prvname,dbname))
			else:
				AdminConfig.modify(mmid, '[[authDataAlias %s] [mappingConfigAlias ""]]' % authname)
				self.__log.info('provider <%s> | datasource < %s > | mise a jour mapping module OK' % (prvname,dbname))
		cpid = AdminConfig.showAttribute(dsid, 'connectionPool')
		AdminConfig.modify(cpid, self.__cfg.convertAttributes(self.__cfg.getNode("//resources/providers/provider[@name='%s']/datasources/datasource[@name='%s']/connectionPool" % (prvname,dbname))))
		self.__log.info('provider <%s> | datasource < %s > | creation du connection pool OK' % (prvname,dbname))
		psid = AdminConfig.create('J2EEResourcePropertySet', dsid, [])
		for p in self.__cfg.getNodes("//resources/providers/provider[@name='%s']/datasources/datasource[@name='%s']/properties/property" % (prvname,dbname)):
			self.__log.debug("AdminConfig.create('J2EEResourceProperty', %s, %s)" % (psid, self.__cfg.convertAttributes(p)))
			AdminConfig.create('J2EEResourceProperty', psid, self.__cfg.convertAttributes(p))
		self.__log.info('provider <%s> | datasource < %s > | creation des custom properties OK' % (prvname,dbname))

#==================================================================
# configure jdbc providers
#==================================================================
def doConfigureJDBCProviders(self):
	for x in self.__cfg.getNodes("//resources/providers/provider"):
		prm = self.__cfg.convertAttributes(x)
		providerName = filter(lambda a: a[0]=='name',prm)[0][1]
		prvId = ''
		self.__log.info('recherche du JDBCProvider <%s>...' % providerName)
		for p in AdminTask.listJDBCProviders().replace('"','').split(lineSeparator):
			if AdminConfig.showAttribute(p,'name') == providerName:
				prvId = p
				continue
		if prvId != '':
			self.__log.info('JDBCProvider <%s> existe deja, il ne sera pas re-cree.' % providerName)
		else:
			#prm.append(['scope','Cell=%s' % AdminControl.getCell()])
			prm = map(lambda a: ['-' + a[0],a[1]], prm)
			prm = [p for pr in prm for p in pr]
			prvId = AdminTask.createJDBCProvider(prm)
			self.__log.info('creation du JDBCProvider <%s> OK' % providerName)
		if prvId == '':
			raise 'le provider < %s > existe pas et ne peut etre cree : traitement annule.' % providerName
		self.doConfigureDataSources(providerName,prvId)

#==================================================================
# configure shared libraries
#==================================================================
def doConfigureSharedLibraries(self):
	for x in self.__cfg.getNodes("//resources/sharedlibs/sharelib"):
		prm = self.__cfg.convertAttributes(x)
		name = filter(lambda a: a[0]=='name',prm)[0][1]
		if AdminConfig.list('Library',self.__utl.getCellId()) != '':
			for lib in AdminConfig.list('Library',self.__utl.getCellId()).split(lineSeparator):
				libName = AdminConfig.showAttribute(lib,'name')
				if libName == name:
					AdminConfig.remove(lib)
					continue
		AdminConfig.create('Library', self.__utl.getCellId(), prm)
		self.__log.info('creation sharedlib < %s > OK' % (name))

#==================================================================
# class loader's configuration
#==================================================================
def doConfigureClassLoaders(self):
	for s in self.__cfg.getNodes("//composition/clusters/cluster/server"):
		srv = self.__cfg.getAttributes(s)
		if srv['name'] in self.__servers:
			asid = AdminConfig.list('ApplicationServer',self.__utl.getServerId(srv['name']))
			for c in self.__cfg.getNodes("//profiles/profile[@name='%s']/classloaders/classloader" % srv['profile']):
				cldr = self.__cfg.getAttributes(c)
				if AdminConfig.list('Classloader',self.__utl.getServerId(srv['name']))!= '':
					for scl in AdminConfig.list('Classloader',self.__utl.getServerId(srv['name'])).split(lineSeparator):
						if AdminConfig.list('LibraryRef',scl) != '':
							for sclr in AdminConfig.list('LibraryRef',scl).split(lineSeparator):
								lrName = AdminConfig.showAttribute(sclr,'libraryName')
								if lrName == cldr['libname']:
									AdminConfig.remove(scl)
									continue
				AdminConfig.create('LibraryRef', AdminConfig.create('Classloader', asid, [['mode', cldr['mode']]]), [['libraryName', cldr['libname']],	['sharedClassloader', 'true']])
				self.__log.info('configuration du classloader de < %s > pour la librairie < %s > : OK' % (srv['name'],cldr['libname']))
			srvcldr = self.__cfg.getAttributes(self.__cfg.getNode("//profiles/profile[@name='%s']/classloaders/serverclassloader" % srv['profile']))
			if (srvcldr['policy'] != '') and (srvcldr['mode'] != ''):
				AdminConfig.modify(asid, [ ['name',srv['name']],
										   ['applicationClassLoaderPolicy',srvcldr['policy']],
										   ['applicationClassLoadingMode',srvcldr['mode']] ])
				self.__log.info('configuration classloader du serveur < %s > : OK' % srv['name'])

#==================================================================
# scheduler's configuration
#==================================================================
def doConfigureSchedulers(self):
	try:
		wdsh = AdminControl.queryNames('WebSphere:*,type=DataSourceCfgHelper,process=dmgr')
		id=AdminConfig.getid('/DataSource:scheduler database')
		AdminControl.invoke(wdsh,'testConnection', [id], ['java.lang.String'])
		self.__log.info('test de la datasource du scheduler : OK')
	except:
		self.__log.warning('test de la datasource du scheduler : KO')
	for x in self.__cfg.getNodes("//resources/schedulers/scheduler"):
		prm = self.__cfg.convertAttributes(x)
		jndiname = filter(lambda a: a[0]=='jndiName',prm)[0][1]
		name = filter(lambda a: a[0]=='name',prm)[0][1]
		scope = filter(lambda a: a[0]=='scope',prm)[0][1]
		prm = filter(lambda a: a[0]!='scope',prm)
		if AdminConfig.list('SchedulerConfiguration') != '':
			for sc in AdminConfig.list('SchedulerConfiguration').split(lineSeparator):
				if AdminConfig.showAttribute(sc,'jndiName') == jndiname:
					AdminConfig.remove(sc)
		idsp = AdminConfig.getid('/%s/SchedulerProvider:SchedulerProvider' % scope)
		AdminConfig.create('SchedulerConfiguration', idsp, prm)
		self.__log.info('creation du scheduler <%s> : OK' % name)

#==================================================================
# work manager's configuration
#==================================================================
def doConfigureWorkManagers(self):
	wpid=AdminConfig.getid('/Cell:%s/WorkManagerProvider:WorkManagerProvider' % AdminControl.getCell())
	for x in self.__cfg.getNodes("//resources/workManagers/workManager"):
		prm = self.__cfg.convertAttributes(x)
		name = filter(lambda a: a[0]=='name',prm)[0][1]
		scope = filter(lambda a: a[0]=='scope',prm)[0][1]
		jndi = filter(lambda a: a[0]=='jndiName',prm)[0][1]
		prm = filter(lambda a: a[0]!='scope',prm)
		wid = AdminConfig.getid('/%s/WorkManagerProvider:WorkManagerProvider/WorkManagerInfo:%s' % (scope,name))
		if wid:
			AdminConfig.modify(wid,prm)
			self.__log.info('mise a jour du workmanager < %s > : OK' % name)
		else:
			for w in AdminConfig.list('WorkManagerInfo').split(lineSeparator):
				if AdminConfig.showAttribute(w,'jndiName') == jndi:
					AdminConfig.remove(w)
			AdminConfig.create('WorkManagerInfo',wpid,prm)
			self.__log.info('creation du workmanager < %s > : OK' % name)

#==================================================================
# mail session's configuration
#==================================================================
def doConfigureMailSessions(self):
	# why do we have to force with default provider ? because it's the only one that have all protocols...
	mpid = AdminConfig.getid('/Cell:%s/MailProvider:%s/' % (AdminControl.getCell(),'Built-in Mail Provider'))
	for x in self.__cfg.getNodes("//resources/mailSessions/mailSession"):
		prm = self.__cfg.convertAttributes(x)
		jndi = filter(lambda a: a[0]=='jndiName',prm)[0][1]
		name = filter(lambda a: a[0]=='name',prm)[0][1]
		mtp = filter(lambda a: a[0]=='mailTransportProtocol',prm)[0][1]
		msp = filter(lambda a: a[0]=='mailStoreProtocol',prm)[0][1]
		# we have to build this from websphere objects
		# search for transport and store protocols
		mailTransportProtocol = None
		mailStoreProtocol = None
		mailProtocols =	self.__utl.splitstrarray(AdminConfig.showAttribute(mpid,'protocolProviders'))
		for mp in mailProtocols:
			mpName = AdminConfig.showAttribute(mp,'protocol')
			if mpName == mtp:
				mailTransportProtocol = mp
			elif mpName == msp:
				mailStoreProtocol = mp
		# do we have already a mailsession ?
		mid = None
		for msid in self.__utl.splitlines(AdminConfig.list('MailSession',mpid)):
			if string.lower(jndi) == string.lower(AdminConfig.showAttribute(msid,'jndiName')):
				mid = msid
				continue
		# if we don't have any mailsession, then create a new one
		if mid is None:
			mid = AdminConfig.create('MailSession', mpid, [['name',name], ['jndiName',jndi]])
			self.__log.info('creation de la mailsession "%s" : OK' % name)
		# okay, now we can change settings
		prm = filter(lambda a: a[0] not in ['name','jndiName','mailTransportProtocol','mailStoreProtocol'],prm)
		AdminConfig.modify(mid, prm)
		AdminConfig.modify(mid, [['mailTransportProtocol',mailTransportProtocol], ['mailStoreProtocol',mailStoreProtocol]])
		self.__log.info('mise a jour de la mailsession "%s" : OK' % name)

#==================================================================
# SI Buse's configuration
#==================================================================
def doConfigureSIBuses(self):
	for x in self.__cfg.getNodes("//resources/SIBuses/SIBus"):
		prm = self.__cfg.convertAttributes(x)
		name = filter(lambda a: a[0]=='bus',prm)[0][1]
		bus = AdminConfig.getid('/SIBus:'+name)
		if len(bus) > 1:
			self.__log.warning('SIBus %s deja existant : modification impossible !!! operation annulee, la configuration va se poursuivre avec les autres elements...' % name)
			continue
		prm=map(lambda a: ['-' + a[0],a[1]],prm)
		prm=[p for pr in prm for p in pr]
		AdminTask.createSIBus(prm)
		self.__log.info('creation du SIBus < %s > : OK' % name)
		for permittedChain in ['InboundBasicMessaging','InboundSecureMessaging']:
			AdminTask.addSIBPermittedChain(['-bus',name, '-chain',permittedChain])
		self.__log.info('ajout des chaines de transport autorisees sur bus <%s>' % (name))
	# adding members & engine
	for x in self.__cfg.getNodes("//resources/SIBuses/SIBus"):
		s = self.__cfg.getAttributes(x)
		mbr = self.__cfg.convertAttributes(self.__cfg.getNode("//resources/SIBuses/SIBus[@bus='%s']/members" % s['bus']))
		mbrnod = ''
		mbrsrv = ''
		clname = ''
		try:
			clname = filter(lambda a: a[0]=='cluster',mbr)[0][1]
		except:
			mbrnod = filter(lambda a: a[0]=='node',mbr)[0][1]
			mbrsrv = filter(lambda a: a[0]=='server',mbr)[0][1]
		mbr = map(lambda a: ['-' + a[0],a[1]],mbr)
		mbr = [m for mb in mbr for m in mb]
		mbid = ''
		try:
			mbid = AdminTask.listSIBusMembers('[-bus %s]' % s['bus'])
		except:
			mbid = ''
		if mbid != '':
			self.__log.info('SIBus member deja present dans le SIBus < %s >' % s['bus'])
		else:
			try:
				AdminTask.addSIBusMember(mbr)
				self.__log.info('SIBus member ajoute au SIBus < %s >' % s['bus'])
				eng = self.__cfg.convertAttributes(self.__cfg.getNode("//resources/SIBuses/SIBus[@bus='%s']/members" % s['bus']))
				eng = filter(lambda a: a[0] in ['bus','cluster','node','server','dataStore','createDefaultDatasource','datasourceJndiName','authAlias','createTables','restrictLongDBLock','schemaName',
												'fileStore','logSize','logDirectory','minPermanentStoreSize','maxPermanentStoreSize','unlimitedPermanentStoreSize','permanentStoreDirectory',
												'minTemporaryStoreSize','maxTemporaryStoreSize','unlimitedTemporaryStoreSize','temporaryStoreDirectory'],eng)
				eng = map(lambda a: ['-' + a[0],a[1]],eng)
				eng = [e for en in eng for e in en]
				try:
					AdminTask.createSIBEngine(eng)
					self.__log.info('messages engines configures pour le SIBus < %s >' % s['bus'])
				except:
					error_type, error_value, tb = sys.exc_info()
					if error_type != 'exceptions.SystemExit':
						self.__log.error('[%s] (erreur de type %s) %s' % (error_value,error_type,tb))
						traceback.print_exc(file=sys.stdout)
					#self.__log.info('les engines sont deja configures pour le SIBus < %s >' % s['bus'])
			except:
				error_type, error_value, tb = sys.exc_info()
				if error_type != 'exceptions.SystemExit':
					self.__log.error('[%s] (erreur de type %s) %s' % (error_value,error_type,tb))
					traceback.print_exc(file=sys.stdout)
				#self.__log.info('le cluster < %s > est deja associe avec le SIBus < %s >' % (clname, s['bus']))
	# now, we add destinations.
	for x in self.__cfg.getNodes("//resources/SIBuses/SIBus"):
		s = self.__cfg.getAttributes(x)
		m = self.__cfg.getAttributes(self.__cfg.getNode("//resources/SIBuses/SIBus[@bus='%s']/members" % s['bus']))
		for d in self.__cfg.getNodes("//resources/SIBuses/SIBus[@bus='%s']/destinations/destination" % s['bus']):
			prm = self.__cfg.convertAttributes(d)
			name = filter(lambda a: a[0]=='name',prm)[0][1]
			dtyp = filter(lambda a: a[0]=='type',prm)[0][1]
			clname = ''
			mbrnod = ''
			mbrsrv = ''
			try:
				clname = m['cluster']
			except:
				mbrnod = m['node']
				mbrsrv = m['server']
			prm = filter(lambda a: a[0]!='name',prm)
			prm.append(['bus',s['bus']])
			dprm=map(lambda a: ['-' + a[0],a[1]],prm)
			dprm.append(['-name',name])
			if clname:
				dprm.append(['-cluster',clname])
			else:
				dprm.append(['-node',mbrnod])
				dprm.append(['-server',mbrsrv])
			dprm=[p for pr in dprm for p in pr]
			try:
				AdminTask.createSIBDestination(dprm)
				self.__log.info('la destination < %s > de type < %s > est correctement creee pour le bus < %s >' % (name,dtyp,s['bus']))
			except:
				dprm = filter(lambda a: a[0]!='type',prm)
				dprm=map(lambda a: ['-' + a[0],a[1]],dprm)
				dprm.append(['-name',name])
				dprm=[p for pr in dprm for p in pr]
				AdminTask.modifySIBDestination(dprm)
				self.__log.info('la destination < %s > de type < %s > est correctement mise a jour pour le bus < %s >' % (name,dtyp,s['bus']))

#==================================================================
# Java Messaging Service's configuration
#==================================================================
def doConfigureJavaMessagingServices(self):
	for x in self.__cfg.getNodes("//resources/jms/jmsfactories/jmsfactory"):
		prm = self.__cfg.convertAttributes(x)
		sibus = filter(lambda a: a[0]=='busName',prm)[0][1]
		name = filter(lambda a: a[0]=='name',prm)[0][1]
		qcftyp = filter(lambda a: a[0]=='type',prm)[0][1]
		qcfalias = filter(lambda a: a[0]=='authDataAlias',prm)[0][1]
		if string.lower(qcftyp) == 'topic':
			prm = filter(lambda a: a[0] in ['name','jndiName','busName','type'],prm)
		elif string.lower(qcftyp) != 'queue':
			prm = filter(lambda a: a[0] in ['name','jndiName','busName'],prm)
		if string.lower(qcftyp) == 'queue':
			# build providers endpoints chain
			# for secure : InboundSecureMessaging
			prm.append(['targetTransportChain','InboundBasicMessaging'])
			pep = ''
			for srv in self.__servers:
				sprf = self.__cfg.getStringAttribute("//composition/clusters/cluster/server[@name='%s']" % srv,'profile')
				sofs = self.__cfg.getIntegerAttribute("//composition/clusters/cluster/server[@name='%s']" % srv,'offsetPorts')
				# for secure, use port name SIB_ENDPOINT_SECURE_ADDRESS
				port = self.__cfg.getIntegerAttribute("//profiles/profile[@name='%s']/ports/port[@name='SIB_ENDPOINT_ADDRESS']" % sprf,'value')
				port += sofs
				# for secure, use 'BootstrapSecureMessaging' instead of 'BootstrapBasicMessaging'
				hn = AdminConfig.showAttribute(self.__utl.getNodeId(srv),'hostName')
				pep += '%s:%d:BootstrapBasicMessaging,' % (hn,port)
			pep=pep[:len(pep)-1]
			prm.append(['providerEndPoints',pep])
		prm=map(lambda a: ['-' + a[0],a[1]],prm)
		prm=[p for pr in prm for p in pr]
		if AdminConfig.list('J2CConnectionFactory',self.__utl.getCellId()) != '':
			for id in AdminConfig.list('J2CConnectionFactory',self.__utl.getCellId()).split(lineSeparator):
				if name == AdminConfig.showAttribute(id,'name'):
					AdminTask.deleteSIBJMSConnectionFactory(id)
					self.__log.info('JMS ConnectionFactory %s existe deja => supression au prealable OK' % name)
		AdminTask.createSIBJMSConnectionFactory(self.__utl.getCellId(), prm)
		self.__log.info('creation de la JMSConnectionFactory < %s > pour le SIBus < %s > : OK' % (name,sibus))
		# now configure associated queues
		for q in self.__cfg.getNodes("//resources/jms/jmsfactories/jmsfactory[@name='%s']/jmsqueues/jmsqueue" % name):
			qprm = self.__cfg.convertAttributes(q)
			qname = filter(lambda a: a[0]=='name',qprm)[0][1]
			qjndi = filter(lambda a: a[0]=='jndiName',qprm)[0][1]
			qprm.append(['busName',sibus])
			qprm=map(lambda a: ['-' + a[0],a[1]],qprm)
			qprm=[qp for qpr in qprm for qp in qpr]
			if AdminConfig.list('J2CAdminObject',self.__utl.getCellId()) != '':
				for id in AdminConfig.list('J2CAdminObject',self.__utl.getCellId()).split(lineSeparator):
					if qname == AdminConfig.showAttribute(id,'name'):
						AdminTask.deleteSIBJMSQueue(id)
						self.__log.info('JMS Queue %s existe deja => supression au prealable OK' % qname)
			AdminTask.createSIBJMSQueue(self.__utl.getCellId(), qprm)
			self.__log.info('creation de la JMSQueue < %s > pour le SIBus < %s > : OK' % (qname,sibus))
			# and now, configure derivated associations specs
			for ac in self.__cfg.getNodes("//resources/jms/jmsfactories/jmsfactory[@name='%s']/jmsqueues/jmsqueue[@name='%s']/jmsactivation" % (name,qname)):
				aprm = self.__cfg.convertAttributes(ac)
				aname = filter(lambda a: a[0]=='name',aprm)[0][1]
				aprm = filter(lambda a: a[0] not in ['busName','destinationJndiName','destinationType','authenticationAlias'],aprm)
				aprm = filter(lambda a: (a[1]!='') and (a[1] is not None),aprm)
				aprm.append(['busName',sibus])
				aprm.append(['destinationJndiName',qjndi])
				aprm.append(['destinationType',qcftyp])
				aprm.append(['authenticationAlias',qcfalias])
				aprm=map(lambda a: ['-' + a[0],a[1]],aprm)
				aprm=[ap for apr in aprm for ap in apr]
				if AdminConfig.list('J2CActivationSpec',self.__utl.getCellId()) != '':
					for id in AdminConfig.list('J2CActivationSpec',self.__utl.getCellId()).split(lineSeparator):
						if aname == AdminConfig.showAttribute(id,'name'):
							AdminTask.deleteSIBJMSActivationSpec(id)
							self.__log.info('JMS ActivationSpec %s existe deja => supression au prealable OK' % aname)
				AdminTask.createSIBJMSActivationSpec(self.__utl.getCellId(), aprm)
				self.__log.info('creation JMS ActivationSpec < %s > pour SIBus < %s > : OK' % (aname,sibus))

#==================================================================
# create scheduler tables
#==================================================================
def doCreateSchedulerTables(self):
	if AdminConfig.list('SchedulerConfiguration') != '':
		self.__log.info('<SCHD> creation des tables du scheduler...')
		for schid in AdminConfig.list('SchedulerConfiguration').split(lineSeparator):
			wsch = AdminControl.queryNames('WebSphere:*,type=WASSchedulerCfgHelper,process=dmgr')
			result = AdminControl.invoke(wsch,'createTables',[schid],['java.lang.String'])
			if result == 'true':
				self.__log.info('creation des tables du scheduler : OK')
			else:
				self.__log.info('creation des tables du scheduler : les tables existent deja')
			AdminControl.invoke(wsch,'verifyTables',[schid],['java.lang.String'])
			self.__log.info('verification des tables du scheduler : OK')

#==================================================================
# allow everyone to acces the sibuses
#==================================================================
def doAllowEveryoneToUseSIBuses(self):
	if AdminTask.listSIBuses() != '':
		self.__log.info('<SIB> autoriser tout le monde a utiliser les SIBus...')
		for b in AdminTask.listSIBuses().split(lineSeparator):
			name = AdminConfig.showAttribute(b,'name')
			for role in ['Sender','Receiver','Browser','Creator']:
				AdminTask.addGroupToDefaultRole('[-group Everyone -uniqueName -bus %s -role %s]' % (name,role))
			self.__log.info('affectation des droits pour Everyone et Server pour toutes les destinations par defaut du bus <%s> : OK' % (name))
		AdminConfig.save()
		self.__utl.synchronizeNodes()

#==================================================================
# configure the cell
#==================================================================
def doConfigureCell(self):
	rcode = 0
	try:
		self.__log.info('<SYNC> synchronisation des noeuds...')
		self.__utl.synchronizeNodes()

		self.__log.info('<BEGIN> application de la configuration...')

		self.__log.info('<TOPO> <STEP 1> Configuration des process administratif')
		self.doConfigureAdminJvm()

		self.__log.info('<TOPO> <STEP 2> Configuration des serveurs hors cluster')
		for x in self.__cfg.getListNodes("//composition/servers/server"):
			try:
				AdminTask.createApplicationServer(x['nodeName'], '[-name %s -templateName defaultXD -genUniquePorts true ]' % x['name'])
			except:
				self.__log.info('%s existe deja, il va etre reconfigure.' % x['name'])
			self.doConfigureJvm(x['name'])
		self.__log.info('<TOPO> <STEP 3> Configuration du coregroup et des nodegroups')
		self.doConfigureCoreGroup()
		self.__log.info('<TOPO> <STEP 4> Configuration des webservers')
		self.doConfigureWebServers()
		#self.__log.info('<TOPO> <STEP 4> Configuration du cluster ODR')
		#self.doConfigureODR()
		self.__log.info('<TOPO> <STEP 5> Configuration du dynamic cluster')
		self.doConfigureDynamicCluster()
		self.__log.info('<TOPO> <STEP 6> Configuration des clusters')
		self.doConfigureClusters()
		self.__log.info('<TOPO> <STEP 7> nettoyage des virtual hosts')
		self.doClearVirtualHosts()
		self.__log.info('<TOPO> <STEP 8> Configuration des serveurs manages')
		for x in self.__cfg.getListNodes("//composition/clusters/cluster/server"):
			self.doConfigureAppServer(x['name'])
		for x in self.__cfg.getListNodes("//composition/servers/server"):
			self.doConfigureAppServer(x['name'])
		for x in self.__cfg.getListNodes("//composition/clusters/dynamiccluster/serverTemplate"):
			self.doConfigureAppServer(x['profile'])
		self.__log.info('<TOPO> <STEP 9> Passer tous les serveurs en HPEL')
		for n in AdminConfig.list('Node').split(lineSeparator):
			for s in AdminConfig.list('Server',n).split(lineSeparator):
				self.doConfigureHPEL(n,s)

		self.__log.info('<RSRC> <STEP 1> Configuration des variables')
		self.doConfigureVariables()
		self.__log.info('<RSRC> <STEP 2> Configuration des providers JDBC')
		self.doConfigureJDBCProviders()
		self.__log.info('<RSRC> <STEP 3> Configuration des sharedlibs')
		self.doConfigureSharedLibraries()
		self.__log.info('<RSRC> <STEP 4> Configuration des classloaders')
		self.doConfigureClassLoaders()
		self.__log.info('<RSRC> <STEP 5> Configuration des schedulers')
		self.doConfigureSchedulers()
		self.__log.info('<RSRC> <STEP 6> Configuration des work managers')
		self.doConfigureWorkManagers()
		self.__log.info('<RSRC> <STEP 7> Configuration des mail sessions')
		self.doConfigureMailSessions()
		self.__log.info('<RSRC> <STEP 8> Configuration des SIBus')
		self.doConfigureSIBuses()
		self.__log.info('<RSRC> <STEP 9> Configuration des services JMS')
		self.doConfigureJavaMessagingServices()

		self.__log.info('<END> sauvegarde de la configuration...')
		AdminConfig.save()

		self.__log.info('<SYNC> synchronisation des noeuds...')
		self.__utl.synchronizeNodes()

		try:
			self.doCreateSchedulerTables()
		except:
			pass

		try:
			self.doAllowEveryoneToUseSIBuses()
		except:
			pass

	except:
		error_type, error_value, tb = sys.exc_info()
		if error_type != 'exceptions.SystemExit':
			self.__log.error('[%s] (erreur de type %s) %s' % (error_value,error_type,tb))
			if self.__log.getLogLevel() in ['DEBUG','INFO']:
				traceback.print_exc(file=sys.stdout)
		AdminConfig.reset()
		rcode = -69

	return rcode



#=================================================================
# main
#=================================================================
params = Parameters()
params.setParameter('project','nom du projet','le nom du projet a configurer','ged',None)
params.parseCmdLine(sys.argv)

configure = ConfigureCell(params.getParameterValue('project'))
exitCode = configure.doConfigureCell()
sys.exit(exitCode)
