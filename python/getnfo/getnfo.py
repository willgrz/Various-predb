#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys

from twisted.words.protocols import irc
from twisted.internet import reactor, protocol, defer, ssl
from twisted.enterprise import adbapi
import MySQLdb
from pprint import pprint
from time import time, mktime
import re
import yaml
from datetime import datetime
import shlex
import string
import os
from zlib import crc32
import binascii
import struct

#
# mx_shellbot.py 
#	v1.2 15-Jan-2011 (cont.from 14th)
#		Added mySQL update routines / rls checks to ScriptControl
#		Added echo-back to ircShellbot <-> ScriptControl
#		Note: needs twisted.enterprise + MySQLdb (apt-get install python-mysqldb)
#	v1.1 13-Jan-2011
#		Added site info to ScriptControl output
#	v1.0 30-Dec-2010
#		Initial version
#		
#
#
class ExternalProcessProtocol(protocol.ProcessProtocol):

    def outReceived(self, data):
        self.control.receive(data)

    def errReceived(self, data):
        self.control.receive(data)

    def processEnded(self, status_object):
        self.control.processEnded(status_object)


class ExternalProcessControl(object):
    processProtocol = ExternalProcessProtocol

    def __init__(self, cmdline):
        self.cmdline = cmdline
        self.executable = self.cmdline.split(" ")[0]
        self.arguments = shlex.split(self.cmdline)
        self.protocol = self.buildProtocol()        
        reactor.spawnProcess(self.protocol, self.executable, self.arguments, env=os.environ)

    def buildProtocol(self):
        p = self.processProtocol()
        p.control = self 
        return p

    def receive(self, data):
        pass 

    def processEnded(self, status_object):
        pass 


class ScriptControl(ExternalProcessControl):
    
    def __init__(self, command, arguments, site, release, notifier, dbpool, dbtable):
        # 
        # init script control  
        #        
        self.dbpool = dbpool
        self.dbtable = dbtable
        self.release = release
        self.notifier = notifier
        self.returndata = ""
	self.site = site
        self.cmdline = "/bin/sh " + command + " " + arguments
	ExternalProcessControl.__init__(self, self.cmdline)
    
    def receive(self, data):
	self.returndata += data
	#print "Received from process : ", data	
    
    def processEnded(self, status_object):
        #return self.dbpool.runInteraction(self.insert)
        print ">>> Process ended, site: ", self.site
        # update mysql
	data = self.returndata
        if "\n" in data:
	    data = data.split('\n')[0]	
	data = data.rstrip()
	self.returndata = data
	self.dbpool.runInteraction(self.updateDb)
	if data == "":
	    pass        
        # give captured data back to ircbot	
        self.notifier(self.site, data)        
        pass

    # updates db
    def updateDb(self, txn):
	#
	# if shell script has return empty string, lets not update db
	# otherwise assume nfo output = !addnfo releasename url nfofile
	#
	
	data = self.returndata
	#print "before db: ", data
	#if "\n" in data:
	#    data = data.split('\n')[0]	
	#data = data.rstrip()
	print "final result ", data
	nfoname = ""
	if data == "":
	    return
	#    
	# only update if we have valid !addnfo
	#
	if data.startswith("!sitenfo"):
	    parts = data.split(' ')
	    try:
		nfoname = parts[3]
	    except:
		print "updateDB, bad !sitenfo echo"
		return
	else:
	    return
	sql = "UPDATE %s SET `nfofile` = '%s', `nfofrom` = '%s/SITE' WHERE `release` = '%s'" % (self.dbtable, nfoname, self.site.upper(), self.release)
	try:
            txn.execute(sql)
        except:
            print "UpdateDb SQL ERROR:"
            print sql
            return
	


class ReconnectingConnectionPool(adbapi.ConnectionPool):
    """Reconnecting adbapi connection pool for MySQL.

    This class improves on the solution posted at
    http://www.gelens.org/2008/09/12/reinitializing-twisted-connectionpool/
    by checking exceptions by error code and only disconnecting the current
    connection instead of all of them.

    Also see:
    http://twistedmatrix.com/pipermail/twisted-python/2009-July/020007.html

    """
    def _runInteraction(self, interaction, *args, **kw):
        try:
            return adbapi.ConnectionPool._runInteraction(self, interaction, *args, **kw)
        except MySQLdb.OperationalError, e:
            if e[0] not in (2006, 2013):
                raise
            log.msg("RCP: got error %s, retrying operation" %(e))
            conn = self.connections.get(self.threadID())
            self.disconnect(conn)
            # try the interaction again
            return adbapi.ConnectionPool._runInteraction(self, interaction, *args, **kw)


class database(object):

    def __init__(self, config):
        #self.dbpool = adbapi.ConnectionPool("MySQLdb", **config["database"])
        self.dbpool = ReconnectingConnectionPool("MySQLdb", **config)
        self.size = 10000
        self.page = 0
        self.delay = 1.000
    
        print "Database object initialized"



class ircShellbot(irc.IRCClient):

    lineRate = None 
    
    def connectionMade(self):
        self.config = self.factory.config
        self.network = self.config["network"]
        self.username = self.config["username"]
        self.password = self.config["password"]
        # sectionmap, script, dirs and indexes
        self.sectionmap = self.config["section_map"]
        self.site_script = self.config["site_script"]
        self.nfo_dir = self.config["nfodir"]
        #
        # new triggers/index section
        #
        self.triggers = self.config["triggers"]
        
        self.nickname = None 
        irc.IRCClient.connectionMade(self)
        self.factory.bot = self 
        self.factory.dispatch.bot = self
        self.debugchannel = None
        if "debugchannel" in self.config:
	    if self.config["debugchannel"] != None:
		self.debugchannel = self.config["debugchannel"]
		self.join(self.config["debugchannel"])
	# compile REs
        self.mircStrip = re.compile("\x1f|\x02|\x12|\x0f|\x16|\x03(?:\d{1,2}(?:,\d{1,2})?)?", re.UNICODE)
        
        #self.rlsRe = re.compile("[a-zA-Z0-9()_.-]+-([a-zA-Z0-9_]+)", re.UNICODE)
        
        if "strip_chars" in self.config:
	    self.genStrip = re.compile(self.config["strip_chars"], re.UNICODE)

	        
    def irc_RPL_WELCOME(self, prefix, params):
        self.nickname = params[0]
        self._registered = True 
        self.signedOn()        
        
    def write_debug(self, msg):      
	if self.debugchannel != None:
	    self.msg(self.debugchannel, msg)
	else:
	    print msg

    def signedOn(self):
        print "Connected to {network:10}: irc://{username}:{password}@{ipaddress}:{port}/".format(**self.config)     
        for channel in self.config["channels"]:
            chanparams = self.config["channels"][channel]
            if chanparams == None:
                self.sendLine("JOIN %s" % (channel))
            elif "channel_key" in chanparams and chanparams["channel_key"] != None:                
                self.sendLine("JOIN %s %s" % (channel, chanparams["channel_key"]))
            else:
                self.sendLine("JOIN %s" % (channel))

    #@defer.inlineCallbacks
    #def cmd_run(self, command, args):
    # yield ScriptControl(command, args, self.network)
    #	return


    def privmsg(self, user, channel, message):
        username = user.split('!', 1)[0]
        #channel = channel.lower()        
        if not "!" in user:
            return

        (nickname, suffix) = user.split("!")
                        
        # check valid channels, bots and handle msg
        if channel in self.config["channels"]:
	    if username == self.config["sitebot"]:
		message = message.strip()
		# strip mirc codes
		message = self.mircStrip.sub('', message)
		# strip other possible chars
		if "strip_chars" in self.config:
		    message = self.genStrip.sub('', message)
		# strip possible triple & double spaces last
		message = message.strip()
		while ("  " in message):		
		    message = string.replace(message, "  ", " ")
		# end-resultself.triggers["PRE"].key_index
		self.write_debug("Got User: %s, channel: %s, msg: %s" % (username, channel, message))
		# print config?
		if message.startswith("#pconfig"):
		    pprint(self.config)
		    return
		if message.startswith("#psect"):
		    pprint(self.sectionmap)
		    return		
		if message.startswith("#ptrig"):
		    pprint(self.triggers)
		mparts = message.split(' ')
		for keyword in self.triggers:
		    key_index = self.triggers[keyword]["key_index"]
		    rls_index = self.triggers[keyword]["rls_index"]
		    sect_index = self.triggers[keyword]["sect_index"]
		    #print "Keyword %s has indexes %d, %d, %d" % (keyword, key_index, rls_index, sect_index)
		    try: 
			matching = mparts[key_index]
		    except:
			self.write_debug("keyword %s, out of index %d" % (keyword, key_index))
			return
		    if matching == keyword:
			try:
			    release = mparts[rls_index]
			except:
			    self.write_debug("Release index %d out of range" % (rls_index))			    
			    return
			try:
			    section = mparts[sect_index]
			except:
			    self.write_debug("Section index %d out of range" % (sect_index))
			    return
			if "requests" in section.lower(): 
			    self.write_debug("Error: Requests found in section")
			    return			    
			if "/" in release:
			    self.write_debug("Error: / found in NEW")
			    return
			# replacement check
			sect = section.upper()
			if sect in self.sectionmap:
			    sect = self.sectionmap[sect]
		    
			nfo_file = self.nfo_dir + release + ".nfo"		    
			if os.path.isfile(nfo_file):
			    self.write_debug("Error: nfo file %s already exists" % (nfo_file))
			    return
			cmd = self.site_script
			args = sect + release		    
			self.write_debug("-> spawner parameters: %s %s" % (cmd, args))
			self.factory.dispatch.spawner(cmd, args, self.network, release )
			#self.cmd_run(cmd, args)
	

class ircFactory(protocol.ClientFactory):
   
    def __init__(self, config, dispatch):      
        self.config = config        
        self.protocol = ircShellbot
        self.protocol.factory = self
        self.bot = None
        self.dispatch = dispatch        
        self.connect()
        
    def connect(self):
        print "Connecting to {network:15}: irc://{username}:{password}@{ipaddress}:{port}/".format(**self.config)
        if self.config["use_ssl"] == 1:
	    reactor.connectSSL(self.config["ipaddress"], self.config["port"], self, ssl.ClientContextFactory())
	else:
	    reactor.connectTCP(self.config["ipaddress"], self.config["port"], self)

    def clientConnectionFailed(self, connector, reason):
        reactor.stop()





class Dispatcher(object):
    
    def __init__(self, cfg_filename, db_config, db_table):
	self.db_config = db_config
        self.config = self.loadConfig(cfg_filename)
        self.table = db_table;
        self.mydb = database(self.db_config)
        self.echonet = None
        self.irc = self.startIRC() 
        
    def loadConfig(self, filename):
        f = open(filename, "r")
        cfg = yaml.load(f)
        f.close()
        return cfg

    def startIRC(self):
        networks = {}
        #
        # first connect to echo-net
        #   - this is the global result net/channel
        netparams = self.config["echo-net"]
        netparams["network"] = "echo-net"
        self.echonet = ircFactory(netparams, self)
        
        for network in self.config["networks"]:
            netparams = self.config["networks"][network]
            netparams["network"] = network
            networks[network] = ircFactory(netparams, self)
        return networks
    
    
    @defer.inlineCallbacks
    def checkNfoExist(self, release):	
	sql = "SELECT `nfofile` from %s WHERE `release` = '%s'" % (self.table, release)
	#print sql	
	try:        
            result = yield self.mydb.dbpool.runQuery(sql)
        except MySQLdb.Error, e:
            print "Nfo check error %d: %s" % (e.args[0], e.args[1])            
            return
        except:
            #traceback.print_exc()            
            print "Nfo check failed"
            return
	defer.returnValue(result) 	
	
    @defer.inlineCallbacks
    def spawner(self, command, args, network, release):
	nfo_exist = False
	nforet = yield self.checkNfoExist(release)
        if len(nforet) != 0:
	    if nforet[0][0] != None:
		  nfo_exist = True
		  print "nfo file exist, no spawning ", nforet[0][0]

	if not nfo_exist:
	    ScriptControl(command, args, network, release, self.handleResult, self.mydb.dbpool, self.table)
	pass

    def handleResult(self, network, message):
	print "Got result %s, msg %s " % (network, message)
	#
	# echo the result to given channels on echonet
	#
	if message != "":
	    for channel in self.echonet.config["channels"]:
		self.echonet.bot.msg(channel, message)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print "Must specify a config file."
        sys.exit(1)
#
      # mysql config goes here
      #
    d_config =  {
        "database" : {
        "host"      : "mysql.local",
        "db"        : "DATABASENAME",
        "user"      : "USERNAME",
        "passwd"    : "PASSWORD",
        "cp_noisy"  : False,
        "cp_max"    : 20,
        "cp_reconnect" : True,
        },
    }
    # last parameter = table name inside the db
    dispatch = Dispatcher(sys.argv[1], d_config["database"], "RELEASETABLE")
    reactor.run()
