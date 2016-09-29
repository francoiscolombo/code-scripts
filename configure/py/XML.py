#--------------------------------------------------------------------
# reading and managing the XML configuration file
#--------------------------------------------------------------------
# author : F. Colombo
#--------------------------------------------------------------------

import sys
import string
import base64

import java.lang.String as Str

from java.util import Date
from java.util import Properties
from java.text import SimpleDateFormat
from java.io import FileInputStream, FileOutputStream, StringWriter
from org.xml.sax import ErrorHandler
from javax.xml.xpath import XPathConstants, XPathFactory
from javax.xml.parsers import DocumentBuilderFactory
from javax.xml.transform import TransformerFactory
from javax.xml.transform.dom import DOMSource
from javax.xml.transform.stream import StreamResult

from Logger import Logger


#--------------------------------------------------------------------
# handler for display errors messages when we try to validate XML
# properties file
#--------------------------------------------------------------------
class XmlErrorHandler(ErrorHandler):

	def warning(self,e):
		print "<XML:WARNING> at line %d, column %d : %s" % (e.getLineNumber(),e.getColumnNumber(),e.getMessage())

	def error(self,e):
		print "<XML:ERROR> at line %d, column %d : %s" % (e.getLineNumber(),e.getColumnNumber(),e.getMessage())
		sys.exit(-11)

	def fatalError(self,e):
		print "<XML:FATAL> at line %d, column %d : %s" % (e.getLineNumber(),e.getColumnNumber(),e.getMessage())
		sys.exit(-13)

#--------------------------------------------------------------------
# This is the class for managing XML file
#--------------------------------------------------------------------
class XML:

	#==================================================================
	# private members
	#==================================================================
	__xmlFileName = None
	__builder = None
	__document = None
	__xpath = None
	__log = Logger()

	#==================================================================
	# constructor
	#==================================================================
	def __init__(self, project):
		self.__xpath = XPathFactory.newInstance().newXPath()
		factory = DocumentBuilderFactory.newInstance()
		self.__builder = factory.newDocumentBuilder()
		self.__builder.setErrorHandler(XmlErrorHandler())
		self.__xmlFileName = string.lower('../conf/%s-cell.xml' % (project))
		self.__document = self.__builder.parse(FileInputStream(self.__xmlFileName))
		self.__log.info('Chargement du fichier XML "%s" realise...' % self.__xmlFileName)

	#==================================================================
	# encypher password
	#==================================================================
	def encodePassword(self,s):
		a='{dcu}'+base64.encodestring(s)
		if a[len(a)-1:] == '\n':
			return a[:len(a)-1]
		else:
			return a

	#==================================================================
	# decypher password
	#==================================================================
	def decodePassword(self,s):
		return base64.decodestring(s[5:])

	#==================================================================
	# get text content of a tag
	#==================================================================
	def getNodeValue(self,expression):
		expr = self.__xpath.compile(expression+'/text()')
		node = expr.evaluate(self.__document, XPathConstants.NODE)
		if node is None:
			v = ''
		else:
			v = node.getNodeValue()
		self.__log.debug('Valeur pour expression "%s" = "%s"' % (expression,v))
		return v

	#==================================================================
	# get a node
	#==================================================================
	def getNode(self,expression):
		expr = self.__xpath.compile(expression)
		node = expr.evaluate(self.__document, XPathConstants.NODE)
		return node

	#==================================================================
	# get nodes list
	#==================================================================
	def getNodesList(self,expression):
		expr = self.__xpath.compile(expression)
		nodes = expr.evaluate(self.__document, XPathConstants.NODESET)
		self.__log.debug('expression "%s" retourne une liste de %d elements' % (expression,nodes.getLength()))
		return nodes

	#==================================================================
	# get nodes list
	#==================================================================
	def getListNodes(self,expression):
		expr = self.__xpath.compile(expression)
		nodes = expr.evaluate(self.__document, XPathConstants.NODESET)
		self.__log.debug('expression "%s" retourne une liste de %d elements' % (expression,nodes.getLength()))
		result = []
		for i in range(0,nodes.getLength()):
			node = nodes.item(i)
			n = {}
			if node.hasAttributes():
				attrs = node.getAttributes()
				for j in range(0,attrs.getLength()):
					n[attrs.item(j).getName()] = attrs.item(j).getValue()
			result.append(n)
		return result

	#==================================================================
	# get a properties list
	#==================================================================
	def getPropertiesList(self,expression,fields):
		expr = self.__xpath.compile('%s/properties/property' % expression)
		nodes = expr.evaluate(self.__document, XPathConstants.NODESET)
		self.__log.debug('expression "%s" retourne une liste de %d elements' % (expression,nodes.getLength()))
		result = '[ '
		for i in range(0,nodes.getLength()):
			node = nodes.item(i)
			n = {}
			if node.hasAttributes():
				attrs = node.getAttributes()
				for j in range(0,attrs.getLength()):
					n[attrs.item(j).getName()] = attrs.item(j).getValue()
			if n['name'] in fields:
				result += '[%s %s %s] ' % (n['name'],n['type'],n['value'])
		result += ']'
		if result == '[ ]':
			return None
		return result

	#==================================================================
	# get nodes array
	#==================================================================
	def getNodes(self,expression):
		expr = self.__xpath.compile(expression)
		nodes = expr.evaluate(self.__document, XPathConstants.NODESET)
		self.__log.debug('expression "%s" retourne une liste de %d elements' % (expression,nodes.getLength()))
		result = []
		for i in range(0,nodes.getLength()):
			result.append(nodes.item(i))
		return result

	#==================================================================
	# create a dictionnary with the attributes of a DOM Node
	#==================================================================
	def getAttributes(self,node):
		result = {}
		if node.hasAttributes():
			attrs = node.getAttributes()
			for i in range(0,attrs.getLength()):
				result[attrs.item(i).getName()] = attrs.item(i).getValue()
		return result

	#==================================================================
	# convert attributes of a DOM nodes to a WAS array
	#==================================================================
	def convertAttributes(self,node):
		result = []
		if node.hasAttributes():
			attrs = node.getAttributes()
			for i in range(0,attrs.getLength()):
				attr = []
				name = attrs.item(i).getName()
				value = attrs.item(i).getValue()
				if value[:5] == '{dcu}':
					value = self.decodePassword(value)
				attr.extend([name, value])
				result.append(attr)
		return result
			
	#==================================================================
	# convert attributes of a DOM nodes to AdminTask parameters array
	#==================================================================
	def convertToParameters(self,node,scope):
		result = []
		if node.hasAttributes():
			attrs = node.getAttributes()
			for i in range(0,attrs.getLength()):
				attr = []
				name = attrs.item(i).getName()
				value = attrs.item(i).getValue()
				if value[:5] == '{dcu}':
					value = self.decodePassword(value)
				attr.extend([name, value])
				result.append(attr)
		result.append(['scope',scope])
		result = map(lambda a: ['-' + a[0],a[1]], result)
		result = [p for pr in result for p in pr]
		return result

	#==================================================================
	# convert attributes of a DOM nodes to a flat WAS array
	#==================================================================
	def attributesToArray(self,node):
		result = []
		if node.hasAttributes():
			attrs = node.getAttributes()
			for i in range(0,attrs.getLength()):
				name = attrs.item(i).getName()
				value = attrs.item(i).getValue()
				if value[:5] == '{dcu}':
					value = self.decodePassword(value)
				result.extend([name, value])
		return result

	#==================================================================
	# get string value of a tag
	#==================================================================
	def getStringAttribute(self,expression,attrName):
		v = ''
		expr = self.__xpath.compile(expression+"/@"+attrName)
		node = expr.evaluate(self.__document, XPathConstants.NODE)
		if node is not None:
			v = node.getNodeValue()
			if v is None:
				v = ''
		self.__log.debug('Valeur de %s pour expression "%s" = "%s"' % (attrName,expression,v))
		return v

	#==================================================================
	# get password. if it's not yet cypher, then cypher it and update
	# XML configuration file
	#==================================================================
	def getPasswordAttribute(self,expression,attrName):
		v = ''
		expr = self.__xpath.compile(expression+"/@"+attrName)
		node = expr.evaluate(self.__document, XPathConstants.NODE)
		if node is not None:
			v = node.getNodeValue()
			if v is None:
				v = ''
		# beware : if password is already cypher then decypher it.
		# if password is in clear then cypher it and update XML file.
		if v != '':
			if v[:5] == '{dcu}':
				v = self.decodePassword(v)
			else:
				self.setAttributeValue(expression,attrName,self.encodePassword(v))
				self.updateXmlConfigFile()
				self.__log.debug('< attribut %s du tag %s encode >' % (attrName,expression))
		self.__log.debug('Valeur de %s pour expression "%s" = "%s"' % (attrName,expression,v))
		return v

	#==================================================================
	# get the value of a tag and convert it in integer
	#==================================================================
	def getIntegerAttribute(self,expression,attrName):
		expr = self.__xpath.compile(expression+"/@"+attrName)
		node = expr.evaluate(self.__document, XPathConstants.NODE)
		if node is not None:
			v = node.getNodeValue()
			if (v is not None) and (v != ''):
				self.__log.debug('Valeur de %s pour expression "%s" = "%s"' % (attrName,expression,v))
				return int(v)
		self.__log.debug('Valeur de %s pour expression "%s" = "0"' % (attrName,expression))
		return 0

	#==================================================================
	# update attribut value
	#==================================================================
	def setAttributeValue(self,expression,attrName,attrValue):
		expr = self.__xpath.compile(expression)
		node = expr.evaluate(self.__document, XPathConstants.NODE)
		node.setAttribute(attrName,attrValue)
		self.__log.debug('Mise a jour attribut %s par expression "%s" avec comme valeur "%s" realisee...' % (attrName,expression,attrValue))

	#==================================================================
	# update XML configuration file
	#==================================================================
	def updateXmlConfigFile(self):
		transfac = TransformerFactory.newInstance()
		trans = transfac.newTransformer()
		trans.setOutputProperty('omit-xml-declaration', 'no')
		trans.setOutputProperty('indent', 'yes')
		#trans.setOutputProperty('doctype-system', '/s2ipgm/was/scripts/wasconfigure/environment.dtd')
		sw = StringWriter()
		xmlResult = StreamResult(sw)
		xmlSource = DOMSource(self.__document)
		trans.transform(xmlSource,xmlResult)
		xmlOutputFile = FileOutputStream(self.__xmlFileName)
		xmlString = Str(sw.toString())
		buf = xmlString.getBytes()
		for i in range(0,len(buf)):
			xmlOutputFile.write(buf[i])
		xmlOutputFile.close()
		self.__log.debug('Mise a jour du fichier XML "%s" realise...' % (self.__xmlFileName[self.__xmlFileName.rindex('/')+1:]))
