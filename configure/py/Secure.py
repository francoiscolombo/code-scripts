#--------------------------------------------------------------------
# secure a profile
#--------------------------------------------------------------------
# author : F. Colombo
#--------------------------------------------------------------------

import sys
import traceback

from Logger import Logger
from XML import XML
from Utilities import Utilities
from Parameters import Parameters

#--------------------------------------------------------------------
# This is the class for manage configuration of a environment
#--------------------------------------------------------------------
class Secure:

	#==================================================================
	# private members
	#==================================================================
	__secId = AdminConfig.getid('/Security:/')
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

	#=================================================================
	# configuration globale de la securite (fixe pour chaque serveur)
	#=================================================================
	def doConfigGlobalSecurity(self):
		node = self.__cfg.getNode("//security/globalSecurity")
		params = self.__cfg.convertAttributes(node)
		AdminConfig.modify(self.__secId, params)
		node = self.__cfg.getNode("//security/authMechanism")
		params = self.__cfg.convertAttributes(node)
		authConfigValue = filter(lambda x: x[0] == 'authConfig', params)[0][1]
		params = filter(lambda x: x[0] != 'authConfig', params)
		for id in self.__utl.splitstrarray(AdminConfig.showAttribute(self.__secId,'authMechanisms')):
			authConfig=AdminConfig.showAttribute(id,'authConfig')
			if authConfig == authConfigValue:
				AdminConfig.modify(id,params)
		self.__log.info('configuration de la securite globale OK')

	#=================================================================
	# configuration of certificate expiration
	#=================================================================
	def doConfigManageCertificateExpiration(self):
		wsNotificationId = None
		for id in self.__utl.splitlines(AdminConfig.list('WSNotification')):
			wsNotificationName = AdminConfig.showAttribute(id,'name')
			if wsNotificationName == 'syteb_host':
				wsNotificationId = id
		node = self.__cfg.getNode("//security/wsNotification")
		params = self.__cfg.convertAttributes(node)
		if wsNotificationId is not None:
			AdminConfig.modify(wsNotificationId,params)
		else:
			params.append(['name', 'syteb_host'])
			AdminConfig.create('WSNotification',self.__secId,params)
		AdminTask.modifyWSCertExpMonitor('[-name "Certificate Expiration Monitor" -autoReplace true -deleteOld true -daysBeforeNotification 60 -wsScheduleName ExpirationMonitorSchedule -wsNotificationName syteb_host -isEnabled true ]')
		AdminTask.modifyWSSchedule('[-name ExpirationMonitorSchedule -frequency 40]')
		self.__log.info('activation expiration des certificats par defaut (avec envoi de mail a syteb_host) => OK')

	#=================================================================
	# SSO configuration
	#=================================================================
	def doConfigSSO(self):
		node = self.__cfg.getNode("//security/singleSignon")
		params = self.__cfg.convertAttributes(node)
		ssoId = AdminConfig.list('SingleSignon')
		AdminConfig.modify(ssoId,params)
		self.__log.info('configuration SSO OK')

	#=================================================================
	# change default password for some keystores
	#=================================================================
	def doConfigKeyStorePasswords(self):
		defaultPassword = self.__cfg.getPasswordAttribute('//security/certificates/defaultpassword','password')
		for id in self.__utl.splitlines(AdminTask.listKeyStores()):
			ksName = AdminConfig.showAttribute(id,'name')
			# we don't change the NodeDefaultKeyStore and the NodeDefaultTrustStore, only the others
			if not ksName in ['NodeDefaultKeyStore','NodeDefaultTrustStore','CellDefaultKeyStore','CellDefaultTrustStore']:
				try:
					AdminTask.changeKeyStorePassword('[-keyStoreName %s -keyStorePassword %s -newKeyStorePassword %s -newKeyStorePasswordVerify %s ]' % (ksName,'WebAS',password,password))
					self.__log.info('mise a jour de password du keystore %s (%s) : OK' % (ksName,password))
				except:
					pass

	#=================================================================
	# CSIv2 configuration
	# note : not used anymore.
	# if you want to activate it, just call this method and add the
	# following bloc inside the "security" bloc of your XML config
	# file, after "singleSignon".
	# <csiv2>
	#	 <inbound>
	#		 <messageLayer name="supportedQOP" establishTrustInClient="true"/>
	#		 <messageLayer name="requiredQOP" establishTrustInClient="false"/>
	#		 <transportLayer name="supportedQOP" enableProtection="true"/>
	#		 <transportLayer name="requiredQOP" enableProtection="false"/>
	#		 <identityAssertionLayer enable="true"/>
	#		 <securityProtocolConfig stateful="true"/>
	#	 </inbound>
	#	 <outbound>
	#		 <messageLayer name="supportedQOP" establishTrustInClient="true"/>
	#		 <messageLayer name="requiredQOP" establishTrustInClient="false"/>
	#		 <transportLayer name="supportedQOP" enableProtection="true"/>
	#		 <transportLayer name="requiredQOP" enableProtection="false"/>
	#		 <identityAssertionLayer enable="true"/>
	#		 <securityProtocolConfig stateful="true"/>
	#	 </outbound/>
	# </csiv2>
	#=================================================================
	def doConfigCSIv2(self):
		mlayers = self.__utl.splitlines(AdminConfig.list('MessageLayer'))
		tlayers = self.__utl.splitlines(AdminConfig.list('TransportLayer'))
		ilayers = self.__utl.splitlines(AdminConfig.list('IdentityAssertionLayer'))
		claims	= self.__utl.splitlines(AdminConfig.list('SecurityProtocolConfig'))
		s_mqop = AdminConfig.showAttribute(mlayers[0], 'supportedQOP')
		r_mqop = AdminConfig.showAttribute(mlayers[0], 'requiredQOP')
		s_tqop = AdminConfig.showAttribute(tlayers[0], 'supportedQOP')
		r_tqop = AdminConfig.showAttribute(tlayers[0], 'requiredQOP')
		i_qop	= AdminConfig.showAttribute(ilayers[0], 'supportedQOP')
		AdminConfig.create('ServerIdentity',ilayers[0],[['serverId','*']])
		AdminConfig.modify(s_mqop, [['establishTrustInClient', self.__cfg.getStringAttribute("//csiv2/inbound/messageLayer[@name='supportedQOP']","establishTrustInClient")]])
		AdminConfig.modify(r_mqop, [['establishTrustInClient', self.__cfg.getStringAttribute("//csiv2/inbound/messageLayer[@name='requiredQOP']","establishTrustInClient")]])
		AdminConfig.modify(s_tqop, [['enableProtection', self.__cfg.getStringAttribute("//csiv2/inbound/transportLayer[@name='supportedQOP']","enableProtection")]])
		AdminConfig.modify(r_tqop, [['enableProtection', self.__cfg.getStringAttribute("//csiv2/inbound/transportLayer[@name='requiredQOP']","enableProtection")]])
		AdminConfig.modify(claims[0], [['stateful', self.__cfg.getStringAttribute("//csiv2/inbound/securityProtocolConfig","stateful")]] )
		AdminConfig.modify(i_qop, [['enable', self.__cfg.getStringAttribute("//csiv2/inbound/identityAssertionLayer","enable")]] )
		self.__log.info('configuration CSIv2 InBound OK')
		s_mqop = AdminConfig.showAttribute(mlayers[1], 'supportedQOP')
		r_mqop = AdminConfig.showAttribute(mlayers[1], 'requiredQOP')
		s_tqop = AdminConfig.showAttribute(tlayers[1], 'supportedQOP')
		r_tqop = AdminConfig.showAttribute(tlayers[1], 'requiredQOP')
		i_qop	= AdminConfig.showAttribute(ilayers[1], 'supportedQOP')
		AdminConfig.modify(s_mqop, [['establishTrustInClient', self.__cfg.getStringAttribute("//csiv2/outbound/messageLayer[@name='supportedQOP']","establishTrustInClient")]])
		AdminConfig.modify(r_mqop, [['establishTrustInClient', self.__cfg.getStringAttribute("//csiv2/outbound/messageLayer[@name='requiredQOP']","establishTrustInClient")]])
		AdminConfig.modify(s_tqop, [['enableProtection', self.__cfg.getStringAttribute("//csiv2/outbound/transportLayer[@name='supportedQOP']","enableProtection")]])
		AdminConfig.modify(r_tqop, [['enableProtection', self.__cfg.getStringAttribute("//csiv2/outbound/transportLayer[@name='requiredQOP']","enableProtection")]])
		AdminConfig.modify(claims[1], [['stateful', self.__cfg.getStringAttribute("//csiv2/outbound/securityProtocolConfig","stateful")]] )
		AdminConfig.modify(i_qop, [['enable', self.__cfg.getStringAttribute("//csiv2/outbound/identityAssertionLayer","enable")]] )
		self.__log.info('configuration CSIv2 OutBound OK')

	#=================================================================
	# configuration LDAP
	# note : another possibility is to use AdminTask :
	#				AdminTask.configureAdminLDAPUserRegistry()
	#				see doc for details
	#=================================================================
	def doConfigLDAPServer(self):
		ldapId=AdminConfig.getid('/LDAPUserRegistry:/')
		if ldapId != "":
			AdminConfig.remove(ldapId)
		useRegistryRealm='false'
		useRegistryServerId='true'
		if self.__cfg.getStringAttribute('//security/ldap','autoGenerateServerId') == 'true':
			useRegistryRealm='true'
			useRegistryServerId='false'
		if self.__cfg.getStringAttribute('//security/ldap','ssl') == 'true':
			try:
				AdminTask.retrieveSignerFromPort( [ '-keyStoreName','NodeDefaultTrustStore',
													'-keyStoreScope','(cell):%s:(node):%s' % (AdminControl.getCell(), AdminControl.getNode()),
													'-host',self.__cfg.getStringAttribute('//security/ldap','host'),
													'-port',self.__cfg.getIntegerAttribute('//security/ldap','port'),
													'-certificateAlias','ldap-secure',
													'-sslConfigName','NodeDefaultSSLSettings',
													'-sslConfigScopeName','(cell):%s:(node):%s' % (AdminControl.getCell(), AdminControl.getNode()) ])
				self.__log.info('recuperation du certificat du LDAP pour acces secure : OK')
			except:
				self.__log.warning('recuperation du certificat du LDAP pour acces secure : KO, le certificat est probablement deja present. merci de verifier par vous-meme.')
		ldapId=AdminConfig.create('LDAPUserRegistry',self.__secId,[ ['serverId',self.__cfg.getStringAttribute('//security/ldap/serverId','user')],
																	['serverPassword',self.__cfg.getStringAttribute('//security/ldap/serverId','password')],
																	['realm',self.__cfg.getStringAttribute('//security/ldap','realm')],
																	['primaryAdminId',self.__cfg.getStringAttribute('//security/ldap/primaryAdminId','user')],
																	['baseDN',self.__cfg.getStringAttribute('//security/ldap','baseDN')],
																	['bindDN',self.__cfg.getStringAttribute('//security/ldap/bind','user')],
																	['bindPassword',self.__cfg.getPasswordAttribute('//security/ldap/bind','password')],
																	['searchTimeout',self.__cfg.getStringAttribute('//security/ldap','timeout')],
																	['limit','0'],
																	['ignoreCase','true'],
																	['useRegistryRealm',useRegistryRealm],
																	['useRegistryServerId',useRegistryServerId],
																	['type','CUSTOM'],
																	['sslEnabled',self.__cfg.getStringAttribute('//security/ldap','ssl')],
																	['sslConfig',[]],
																	['monitorInterval','0'],
																	['reuseConnection','true']])
		AdminConfig.create('EndPoint',ldapId, [['host',self.__cfg.getStringAttribute('//security/ldap','host')], ['port',self.__cfg.getStringAttribute('//security/ldap','port')]])
		AdminConfig.create('LDAPSearchFilter', ldapId, [['userFilter',self.__cfg.getNodeValue('//security/ldap/filters/users')],
														['userIdMap',self.__cfg.getStringAttribute('//security/ldap/filters/users','idMap')],
														['groupFilter',self.__cfg.getNodeValue('//security/ldap/filters/groups')],
														['groupIdMap',self.__cfg.getStringAttribute('//security/ldap/filters/groups','idMap')],
														['groupMemberIdMap',self.__cfg.getStringAttribute('//security/ldap/filters/groups','memberIdMap')],
														['krbUserFilter',self.__cfg.getNodeValue('//security/ldap/filters/krbUserFilter')],
														['certificateMapMode','EXACT_DN']])
		self.__log.info('configuration du LDAP OK')

	#=================================================================
	# finalize configuration
	#=================================================================
	def doConfigActiveSecurity(self):
		try:
			myAuthMechanism = 'system.LTPA'
			authMecanisms = self.__utl.splitlines(AdminConfig.list('AuthMechanism'))
			for amId in authMecanisms:
				amName = AdminConfig.showAttribute(amId,'authConfig')
				if amName == myAuthMechanism:
					AdminConfig.modify(self.__secId,[['activeAuthMechanism',amId]])
			self.__log.info('configuration "active authentication mechanism" OK')
		except:
			self.__log.warning('configuration "active authentication mechanism" KO, peut etre deja activee ? merci de verifier par vous-meme.')
		try:
			usrRegistries = self.__utl.splitlines(AdminConfig.list('UserRegistry'))
			for urId in usrRegistries:
				urName = AdminConfig.showAttribute(urId,'realm')
				if urName == self.__cfg.getStringAttribute('//security/ldap','realm'):
					AdminConfig.modify(self.__secId,[['activeUserRegistry',urId]])
			self.__log.info('configuration "active user registry" OK')
		except:
			self.__log.warning('configuration "active user registry" KO, peut etre deja activee ? merci de verifier par vous-meme.')

	#=================================================================
	# creation d'un user de type "admin"
	#=================================================================
	def doUserAddAdmin(self,userName):
		ldapHost = self.__cfg.getStringAttribute('//security/ldap','host')
		ldapPort = self.__cfg.getStringAttribute('//security/ldap','port')
		baseDN = self.__cfg.getStringAttribute('//security/ldap','baseDN')
		for role in ['adminsecuritymanager','administrator','configurator','deployer','iscadmins','monitor','operator']:
			AdminTask.mapUsersToAdminRole('[-accessids [user:%s:%s/uid=%s,%s ] -userids [uid=%s,%s ] -roleName %s]' % (ldapHost,ldapPort,userName,baseDN,userName,baseDN,role))
		self.__log.info('ajout administrateur "%s" OK' % userName)

	#=================================================================
	# creation d'un user de type "operator"
	#=================================================================
	def doUserAddOperator(self,userName):
		ldapHost = self.__cfg.getStringAttribute('//security/ldap','host')
		ldapPort = self.__cfg.getStringAttribute('//security/ldap','port')
		baseDN = self.__cfg.getStringAttribute('//security/ldap','baseDN')
		for role in ['configurator','deployer','operator']:
			AdminTask.mapUsersToAdminRole('[-accessids [user:%s:%s/uid=%s,%s ] -userids [uid=%s,%s ] -roleName %s]' % (ldapHost,ldapPort,userName,baseDN,userName,baseDN,role))
		self.__log.info('ajout operateur "%s" OK' % userName)

	#=================================================================
	# creation d'un user de type "monitor"
	#=================================================================
	def doUserAddMonitor(self,userName):
		ldapHost = self.__cfg.getStringAttribute('//security/ldap','host')
		ldapPort = self.__cfg.getStringAttribute('//security/ldap','port')
		baseDN = self.__cfg.getStringAttribute('//security/ldap','baseDN')
		AdminTask.mapUsersToAdminRole('[-accessids [user:%s:%s/uid=%s,%s ] -userids [uid=%s,%s ] -roleName monitor]' % (ldapHost,ldapPort,userName,baseDN,userName,baseDN))
		self.__log.info('ajout moniteur "%s" OK' % userName)

	#=================================================================
	# creation d'un alias d'authentification
	#=================================================================
	def doCreateAlias(self,aliasName):
		self.__log.debug('tentative de creation pour alias %s...' % aliasName)
		username = self.__cfg.getStringAttribute('//security/aliases/alias[@name="%s"]' % (aliasName), 'user')
		userpwd = self.__cfg.getPasswordAttribute('//security/aliases/alias[@name="%s"]' % (aliasName),'password')
		jaasId = ''
		for j in self.__utl.splitlines(AdminConfig.list('JAASAuthData')):
			jname = AdminConfig.showAttribute(j,'alias')
			if jname == aliasName:
				self.__log.debug('alias JAAS "%s" trouve dans la liste des alias existants...' % jname)
				jaasId = j
		if jaasId == '':
			sec = AdminConfig.getid('/Cell:' + AdminControl.getCell() + '/Security:/')
			AdminConfig.create('JAASAuthData', sec, [['alias', aliasName],
													 ['description', 'authentication information for user '+username],
													 ['userId', username],
													 ['password', userpwd]])
			self.__log.info('creation alias JAAS "%s" avec username="%s" et password="%s" OK' % (aliasName,username,userpwd))
		else:
			AdminConfig.modify(jaasId, [['description', 'authentication information for user '+username],
										['userId', username],
										['password', userpwd]])
			self.__log.info('alias JAAS "%s" deja existant : modification avec username="%s" et password=%s" OK' % (aliasName,username,userpwd))

	#=================================================================
	# iterate and create all JAAS aliases
	#=================================================================
	def doCreateAliases(self):
		aliases = self.__cfg.getNodesList('//security/aliases/alias')
		for i in range(0,aliases.getLength()):
			name = aliases.item(i).getAttributes().getNamedItem('name').getNodeValue()
			self.doCreateAlias(name)

	#=================================================================
	# iterate and create all roles
	#=================================================================
	def doCreateRoles(self):
		users = self.__cfg.getNodesList('//security/roles/monitors/monitor')
		for i in range(0,users.getLength()):
			id = users.item(i).getAttributes().getNamedItem('id').getNodeValue()
			try:
				self.doUserAddMonitor(id)
			except:
				self.__log.warning('username "%s" ne peut etre ajoute en tant que "monitor" ; peut-etre existe-t-il deja ? merci de controler.' % (id))
		users = self.__cfg.getNodesList('//security/roles/operators/operator')
		for i in range(0,users.getLength()):
			id = users.item(i).getAttributes().getNamedItem('id').getNodeValue()
			try:
				self.doUserAddOperator(id)
			except:
				self.__log.warning('username "%s" ne peut etre ajoute en tant que "operator" ; peut-etre existe-t-il deja ? merci de controler.' % (id))
		users = self.__cfg.getNodesList('//security/roles/administrators/administrator')
		for i in range(0,users.getLength()):
			id = users.item(i).getAttributes().getNamedItem('id').getNodeValue()
			try:
				self.doUserAddAdmin(id)
			except:
				self.__log.warning('username "%s" ne peut etre ajoute en tant que "administrator" ; peut-etre existe-t-il deja ? merci de controler.' % (id))

	#=================================================================
	# additionnal keystore configuration
	#=================================================================
	def doConfigureKeyStores(self):
		# scope : cell
		scopeName='(cell):'+AdminControl.getCell()
		# iterate for all keystores
		keystores = self.__cfg.getNodesList('//security/keystores/keystore')
		for i in range(0,keystores.getLength()):
			attrs = self.__cfg.getAttributes(keystores.item(i))
			ksExists = 0
			for ksid in self.__utl.splitlines(AdminTask.listKeyStores()):
				ksname = AdminConfig.showAttribute(ksid,'name')
				if ksname == attrs['name']:
					ksExists = 1
			if ksExists == 0:
				AdminTask.createKeyStore('[-keyStoreName %s -scopeName %s -keyStoreDescription "" -keyStoreLocation %s -keyStorePassword %s -keyStorePasswordVerify %s -keyStoreType %s -keyStoreInitAtStartup true -keyStoreReadOnly false -keyStoreStashFile true -keyStoreUsage SSLKeys ]' % (attrs['name'],scopeName,attrs['path'],attrs['password'],attrs['password'],attrs['type']))
			else:
				AdminTask.modifyKeyStore('[-keyStoreName %s -scopeName %s -keyStoreDescription "" -keyStoreLocation %s -keyStorePassword %s -keyStoreType %s -keyStoreInitAtStartup true -keyStoreReadOnly false -keyStoreUsage SSLKeys ]' % (attrs['name'],scopeName,attrs['path'],attrs['password'],attrs['type']))
		if keystores.getLength() > 0:
			AdminConfig.save()
		self.__log.info('configuration des keystores OK')

	#=================================================================
	# add signer certificates to default truststore
	#=================================================================
	def doConfigureAddCertificatesToTruststore(self):
		certs = self.__cfg.getNodesList('//security/certificates/signers/signer')
		for i in range(0,certs.getLength()):
			alias = certs.item(i).getAttributes().getNamedItem('alias').getNodeValue()
			path = certs.item(i).getAttributes().getNamedItem('path').getNodeValue()
			base64Encoded = certs.item(i).getAttributes().getNamedItem('base64Encoded').getNodeValue()
			try:
				AdminTask.addSignerCertificate('[-keyStoreName NodeDefaultTrustStore -keyStoreScope (cell):%s:(node):%s -certificateFilePath %s -base64Encoded %s -certificateAlias %s ]' % (self.__utl.getCellName(),AdminControl.getNode(),path,base64Encoded,alias))
				self.__log.info('ajout du certificat <%s> dans le truststore du node <%s> : OK' % (alias,AdminControl.getNode()))
			except:
				try:
					AdminTask.addSignerCertificate('[-keyStoreName CellDefaultTrustStore -keyStoreScope (cell):%s -certificateFilePath %s -base64Encoded %s -certificateAlias %s ]' % (self.__utl.getCellName(),path,base64Encoded,alias))
					self.__log.info('ajout du certificat <%s> dans le truststore de la cellule : OK' % (alias))
				except:
					error_type, error_value, tb = sys.exc_info()
					if error_type != 'exceptions.SystemExit':
						self.__log.error('[%s] (erreur de type %s) %s' % (error_value,error_type,tb))
						if self.__log.getLogLevel() in ['DEBUG','INFO']:
							traceback.print_exc(file=sys.stdout)
					self.__log.warning('ajout du certificat <%s> : KO' % (alias))
					pass

	#=================================================================
	# complete configuration for SSL suports
	#=================================================================
	def doConfigureSecureSocketLayer(self):
		sslCfgs = self.__cfg.getNodesList('//security/sslConfigs/sslConfig')
		for i in range(0,sslCfgs.getLength()):
			attrs = self.__cfg.getAttributes(sslCfgs.item(i))
			# check if SSLConfig already exists
			sslcExists = 0
			for sslc in self.__utl.splitlines(AdminTask.listSSLConfigs('')):
				if sslc.find(attrs['name']) > 0:
					sslcExists = 1
			scopeName='(cell):'+AdminControl.getCell()
			if attrs['node'] != "":
				scopeName = scopeName+':(node):'+attrs['node']
			# create or modify associated SSL Configurations
			if sslcExists == 0:
				AdminTask.createSSLConfig('[-alias %s -type JSSE -scopeName %s -keyStoreName %s -keyStoreScopeName %s -trustStoreName %s -trustStoreScopeName %s -serverKeyAlias %s -clientKeyAlias %s ]' % (attrs['name'],scopeName,attrs['keystore'],scopeName,attrs['truststore'],scopeName,attrs['serverCertificateAlias'],attrs['clientCertificateAlias']))
				AdminConfig.save()
				self.__log.info('creation nouvelle configurations SSL : %s <OK>' % attrs['name'])
			else:
				AdminTask.modifySSLConfig('[-alias %s -scopeName %s -keyStoreName %s -keyStoreScopeName %s -trustStoreName %s -trustStoreScopeName %s -serverKeyAlias %s -clientKeyAlias %s ]' % (attrs['name'],scopeName,attrs['keystore'],scopeName,attrs['truststore'],scopeName,attrs['serverCertificateAlias'],attrs['clientCertificateAlias']))
				self.__log.info('mise a jour configurations SSL : %s <OK>' % attrs['name'])
			# update endpoints with new SSL configurations ?
			if (attrs['direction'] == 'inbound') or (attrs['direction'] == 'both'):
				AdminTask.modifySSLConfigGroup('[-name %s -direction inbound -certificateAlias %s -scopeName %s -sslConfigAliasName %s -sslConfigScopeName %s ]' % (nodeName,attrs['clientCertificateAlias'],scopeName,attrs['name'],scopeName))
				AdminConfig.save()
				self.__log.info('mise a jour SSL configuration inbound : OK')
			if (attrs['direction'] == 'outbound') or (attrs['direction'] == 'both'):
				try:
					AdminTask.modifySSLConfigGroup('[-name %s -direction outbound -certificateAlias %s -scopeName %s -sslConfigAliasName %s -sslConfigScopeName %s ]' % (nodeName,attrs['serverCertificateAlias'],scopeName,attrs['name'],scopeName))
					AdminConfig.save()
					self.__log.info('mise a jour SSL configuration outbound : OK')
					# assign new sslconfig for outbound secure communication
					for ocid in self.__utl.splitlines(AdminConfig.list('SSLOutboundChannel')):
						AdminConfig.modify(ocid,[['sslConfigAlias',nodeName+'-SSL-Config-Outbound']])
						self.__log.info('	 > '+AdminConfig.showAttribute(ocid,'name')+' : OK')
					AdminConfig.save()
					self.__log.info('assignation des SSL configuration sur les outbound channels secure : OK')
				except:
					self.__log.warning('mise a jour de la configuration SSL impossible...')

	#=================================================================
	# initialize all new domains security
	# note : if I have to modify custom properties, I have to update
	#				DTD, read new properties and use this :
	# AdminTask.setAppActiveSecuritySettings('[-securityDomainName S2IJT_RACF_REALM -customProperties ["com.ibm.security.SAF.authorization="]]')
	# AdminTask.setAppActiveSecuritySettings('[-securityDomainName S2IJT_RACF_REALM -customProperties ["com.ibm.websphere.security.util.authCacheEnabled=","com.ibm.websphere.security.util.authCacheCustomKeySupport=","com.ibm.websphere.security.util.authCacheSize=","com.ibm.websphere.security.util.authCacheMaxSize="]]')
	# AdminTask.setAppActiveSecuritySettings('[-securityDomainName S2IJT_RACF_REALM -customProperties ["was.security.EnableSyncToOSThread=","was.security.EnableRunAsIdentity="]]')
	#=================================================================
	def doInitializeDomainSecurity(self):
		domains = self.__cfg.getNodesList('//security/domains/realm')
		for i in range(0,domains.getLength()):
			d = self.__cfg.getAttributes(domains.item(i))
			domainExists = 0
			for dname in self.__utl.splitlines(AdminTask.listSecurityDomains()):
				if dname == d['name']:
					domainExists = 1
			# create new security domain ONLY IF AN ANOTHER ONE DOESN'T EXISTS !!!
			if domainExists:
				AdminTask.modifySecurityDomain(['-securityDomainName',d['name'],'-securityDomainDescription',d['description']])
				self.__log.info('realm <%s> existe deja, il va juste etre mis a jour' % d['name'])
			else:
				AdminTask.createSecurityDomain(['-securityDomainName',d['name'],'-securityDomainDescription',d['description']])
				self.__log.info('creation du realm <%s> OK' % d['name'])
			AdminTask.configureAppCustomUserRegistry(['-securityDomainName',d['name'],'-realmName',d['realName'],'-customRegClass',d['customRegClass'],'-ignoreCase',d['ignoreCase'],'-verifyRegistry',d['verifyRegistry']])

	#==================================================================
	# security configuration
	#==================================================================
	def doConfigureSecurity(self):
		code = 0
		try:
			self.__log.info('<BEGIN> configuration initiale : application de la securite')
			self.__log.info('<SSL> <STEP 1> Ajout des keystores additionnels')
			self.doConfigureKeyStores()
			self.__log.info('<SSL> <STEP 2> Autorisation de certificats dans le default truststore')
			self.doConfigureAddCertificatesToTruststore()
			self.__log.info('<SSL> <STEP 3> Configuration SSL')
			self.doConfigureSecureSocketLayer()
			self.__log.info('<SECURITY> <STEP 1> Configuration globale de la securite')
			self.doConfigGlobalSecurity()
			self.__log.info('<SECURITY> <STEP 2> Configuration expiration des certificats')
			self.doConfigManageCertificateExpiration()
			self.__log.info('<SECURITY> <STEP 3> Configuration SSO')
			self.doConfigSSO()
			self.__log.info('<SECURITY> <STEP 4> Configuration du LDAP')
			self.doConfigLDAPServer()
			self.__log.info('<SECURITY> <STEP 5> Configuration des roles administratif')
			self.doCreateRoles()
			self.__log.info('<SECURITY> <STEP 6> Mise a jour des passwords par defaut')
			self.doConfigKeyStorePasswords()
			self.__log.info('<SECURITY> <STEP 7> Finalisation')
			self.doConfigActiveSecurity()
			self.__log.info('<SECURITY> <STEP 8> Configuration des alias JAAS')
			self.doCreateAliases()
			self.__log.info('<SECURITY> <STEP 9> Initialisation des domaines de securite complementaires')
			self.doInitializeDomainSecurity()
			# if you need it... but read the comments on the method before
			# uncomment this line.
			#self.__log.info('<SECURITY> <STEP 10> Configuration CSIv2')
			#self.doConfigCSIv2()
			self.__log.info('<END> sauvegarde de la configuration...')
			AdminConfig.save()
			self.__utl.synchronizeNodes()
		except:
			error_type, error_value, tb = sys.exc_info()
			if error_type != 'exceptions.SystemExit':
				self.__log.error('[%s] (erreur de type %s) %s' % (error_value,error_type,tb))
				if self.__log.getLogLevel() in ['DEBUG','INFO']:
					traceback.print_exc(file=sys.stdout)
			AdminConfig.reset()
			code = -69
		return code



#=================================================================
# main
#=================================================================
params = Parameters()
params.setParameter('project','nom du projet','le nom du projet a configurer','ged',None)
params.parseCmdLine(sys.argv)

secure = Secure(params.getParameterValue('project'))
exitCode = secure.doConfigureSecurity()
sys.exit(exitCode)
