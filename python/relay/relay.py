#!/usr/bin/env python
import sys

from twisted.words.protocols import irc
from twisted.internet import reactor, protocol, defer, ssl
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
# mx_relay.py 
#	v1.5 02-Feb-2011
#		Bug fix: file size regex now allows 5.4 digits
#	v1.4 31-Dec-2010
#		Bug fix: commmand upper/slower case issue
#	v1.3 29-Dec-2010
#		regex fixes nuke, delpre, unnuke
#	v1.2 28-Dec-2010
#		!info and !gn echo delayed - see callLater
#	v1.1 27-Dec-2010
#		added config parameter no_read. if 1, bot doesnt read the echoes
#		note: party-channel accept bot name format ?botname
#		added more separated cmd handlers as requested
#		dropped crc32, uppercase commands when template > 0
#		
#
#

class ircReplay(irc.IRCClient):

    lineRate = None 
    
    def connectionMade(self):
        self.config = self.factory.config
        self.network = self.config["network"]
        self.username = self.config["username"]
        self.password = self.config["password"]        
        self.nickname = None 
        irc.IRCClient.connectionMade(self)
        self.factory.bot = self 
        self.factory.dispatch.bot = self
	        
    def irc_RPL_WELCOME(self, prefix, params):
        self.nickname = params[0]
        self._registered = True 
        self.signedOn()        
        
    def signedOn(self):
        print "Connected to {network:10}: irc://{username}:{password}@{ipaddress}:{port}/".format(**self.config)     
        for channel in self.config["channels"]:
            chanparams = self.config["channels"][channel]
            if chanparams == None:
                self.sendLine("JOIN %s" % (channel))
            elif "channel_key" in chanparams:                
                self.sendLine("JOIN %s %s" % (channel, chanparams["channel_key"]))
            else:
                self.sendLine("JOIN %s" % (channel))

    def privmsg(self, user, channel, message):

	if "no_read" in self.factory.config:
	    if self.factory.config["no_read"] == 1:
		  #print "Not reading from network ", self.network
		  return

	username = user.split("!", 1)[0]
        channel = channel.lower()
        
        if not "!" in user and username.lower() != self.nickname.lower():
            return 
            
        (nickname, suffix) = user.split("!")        	
        if not message.startswith("!"):
            return

        message = {
                "message"     : message.strip(),
                "nickname"    : nickname,
                "channel"     : channel,
                "irc_network" : self.network,
                "timestamp"   : str(int(time())),
                "r_timestamp" : str(int(time())),
                }	                
        if "accept_bots" in self.factory.config:
            if nickname.lower() not in self.factory.config["accept_bots"]:		
		print "Not an accepted bot: {message} ({nickname}/{channel}@{irc_network})".format(**message)
                return

	self.factory.dispatch.incoming(message)

class ircFactory(protocol.ClientFactory):
   
    def __init__(self, config, dispatch):      
        self.config = config
        self.protocol = ircReplay
        self.protocol.factory = self
        self.bot = None
        self.dispatch = dispatch
        self.echo_template = config["template"]
        self.connect()
        
    def connect(self):
        print "Connecting to {network:15}: irc://{username}:{password}@{ipaddress}:{port}/".format(**self.config)
        if self.config["use_ssl"] == 1:
	    reactor.connectSSL(self.config["ipaddress"], self.config["port"], self, ssl.ClientContextFactory())
	else:
	    reactor.connectTCP(self.config["ipaddress"], self.config["port"], self)

    def clientConnectionFailed(self, connector, reason):
        reactor.stop()




class Validator(object):

    def __init__(self):
	# dummy test
	f = True 
    
    def tag_section(self, data):
        return (True, data)

    def tag_releasename(self, data):        
        return (True, data)

    def tag_genre(self, data):
        return (True, data)
        

    def tag_filesize(self, data):
        filesize = data["filesize"]
        if "." in filesize:
            filesize = str(filesize).rstrip("0").rstrip(".")
        data["filesize"] = filesize
        return (True, data)

    def tag_unixtime(self, data):
        unixtime = data["unixtime"]
        return (True, data)

        
    def tag_url(self, data):
        return (True, data)

    def tag_filename(self, data):
        return (True, data)
 

class Dispatcher(object):
    
    def __init__(self, cfg_filename):        
        self.announces = {}        	
        self.config = self.loadConfig(cfg_filename)
        self.irc = self.startIRC()
        self.validator = Validator()
        self.statistics = None
        self.play = None                
        self.skiplist = []
        self.cache = {}
        self.tags = {
                "releasename" : "(?P<releasename>[a-zA-Z0-9()_.-]+-(?P<group>[a-zA-Z0-9_]+))",
                "section"     : "(?P<section>[a-zA-Z0-9-]+)",
                "filecount"   : "(?P<filecount>[0-9]{1,3})",
                "filecountx"  : "(?P<filecountx>\S+)",
                "filesizex"   : "(?P<filesizex>\S+)",
                "genrex"      : "(?P<genrex>\S+)",
                "filesize"    : "(?P<filesize>[0-9]{1,5}(?:\.[0-9]{1,3})?)",
                "genre"       : "(?P<genre>[a-zA-Z/_\-&,\.+]+)",                
                "url"         : "(?P<url>(?:http://|https://|ftp://|www\.)(?:[-A-Za-z0-9+][-A-Za-z0-9&@/%%=~_()!?:,.;]*[-A-Za-z0-9+/=]))",
                "filename"    : "(?P<filename>[a-zA-Z0-9()_.-]+)",
                "network"     : "(?P<network>[a-zA-Z0-9.-]+)",
                "reason"      : "(?P<reason>[a-zA-Z0-9()_.-]+)",
                "unixtime"    : "(?P<unixtime>[0-9]{1,10})",
                "timestamp"   : "(?P<timestamp>[0-9]{1,10})",
                }

        print "Pre-compiling ruleset"
        self.commands = {}
        for function in dir(self):
            if function.startswith("cmd_"):
                try:
                    data = yaml.load(getattr(self, function).__doc__)
                except yaml.scanner.ScannerError:
                    print "YAML Parse error in docstring of %s" % (function)
                    continue

                if data["Regex"]:
                    data["cregex"] = re.compile(data["Regex"].format(**self.tags))
                    self.commands[function] = data

        print "Supported functions:"
        for function in self.commands:
            print "-" * 80
            print "Commands    :", ", ".join(self.commands[function]["Commands"])
            print "Description :", self.commands[function]["Description"]
            print "Function    :", function
        print

        #pprint(self.commands)

    def loadConfig(self, filename):
        f = open(filename, "r")
        cfg = yaml.load(f)
        f.close()
        return cfg


    def startIRC(self):
        networks = {}
        for network in self.config["networks"]:
            netparams = self.config["networks"][network]
            netparams["network"] = network
            networks[network] = ircFactory(netparams, self)
            for channel in netparams["channels"]:
                if netparams["channels"][channel] == None:
                    continue
                if "announce" in netparams["channels"][channel]:
                    if network not in self.announces:
                        self.announces[network] = {}

                    for command in netparams["channels"][channel]["announce"]:
                        if command not in self.announces[network]:
                            self.announces[network][command] = []
                        self.announces[network][command].append(channel)

        for network in self.announces:
            for command in self.announces[network]:
                for channel in self.announces[network][command]:
                    print "Announcing %s to %s on %s" % (command, channel, network)
        return networks


    def inCache(self, command, releasename):
        if not command in self.cache:
            self.cache[command] = []

        if releasename in self.cache[command]:
            return True

        self.cache[command].append(releasename)
        return False

    def outgoing(self, data):	            
        command = data["command"]
        command = command.replace("!", "")
	message = None
        for network in self.announces:
            if command in self.announces[network]:
                for channel in self.announces[network][command]:
		    if self.irc[network].echo_template == 0:
			data["command"] = data["command"].lower()
			message = self.commands[data["function"]]["Output"].format(**data)
		    if self.irc[network].echo_template == 1:
			data["command"] = data["command"].upper()
			message = self.commands[data["function"]]["Output_1"].format(**data)
			data["command"] = data["command"].lower()
		    if self.irc[network].echo_template == 2:
			data["command"] = data["command"].upper()
			message = self.commands[data["function"]]["Output_2"].format(**data)
			data["command"] = data["command"].lower()
		    if self.irc[network].echo_template == 3:
			data["command"] = data["command"].upper()
			message = self.commands[data["function"]]["Output_3"].format(**data)
			data["command"] = data["command"].lower()
		    #
		    # new delay hack, will printout before echo
		    #
		    delayed = False
                    if self.irc[network].echo_template > 0:
			if command.lower() == "gn" or command.lower() == "info":
			    delayed = True
                    print "-> %s (%s/%s@%s)" % (message, self.irc[network].bot.nickname, channel, network)
                    if not delayed:
			self.irc[network].bot.msg(channel, message)
		    else:
			reactor.callLater(1.0, self.irc[network].bot.msg, channel, message)


    @defer.inlineCallbacks
    def incoming(self, data):
        command = data["message"].strip()
        if " " in data["message"]:
            command = data["message"].split()[0]

        if command in self.skiplist:
            return
              
        
        for function in self.commands:
            regex_obj = re.match(self.commands[function]["cregex"], data["message"])
            if regex_obj:
                data.update(regex_obj.groupdict())
                data["function"] = function

                for tag in regex_obj.groupdict():
                    try:
                        validate_function = getattr(self.validator, "tag_%s" % (tag))
                    except AttributeError:
                        continue

                    # basic validation
                    (isValid, data) = validate_function(data)

                    if not isValid:
                        print "Invalid tag: %s for message: %s" % (tag, data["message"])
                        return

                inCache = self.inCache(data["type"], data["releasename"])
                if inCache and "announce" not in data:
                    return

                isValid = True
                                
                try:
                    func = getattr(self, data["function"])
                    if "announce" not in data:
                        print "<- {message} ({nickname}/{channel}@{irc_network})".format(**data)
                except AttributeError:                    
                    return

                func(data)

                return
	# print "msg not handled"
	if self.statistics != None:
            yield self.statistics.command(data)

        if self.play != None:
            yield self.play.command(data)

    def cmd_nuke_delpre(self, data):
	"""
        Description:
            Echo nuke/delpre to other channels

        Commands:
            - nuke
            - delpre

        Regex: "!(?P<command>(?P<type>nuke|delpre)) {releasename} {reason} {network}"
        Output: "!{command} {releasename} {reason} {network}"
        Output_1: "\\x034[{command}]\\x03 <-> \\x034[\\x03 {releasename} \\x034]\\x03 <-> \\x034[\\x03 {reason} \\x034]\\x03 \\x034[\\x03 {network} \\x034]\\x03"
        Output_2: "\\x034[{command}]\\x03 - \\x034[\\x03 {releasename} \\x034]\\x03 - \\x034[\\x03 {reason} \\x034]\\x03 \\x034[\\x03 {network} \\x034]\\x03"
        Output_3: "\\x034[{command}]\\x03 \\x034[\\x03 {releasename} \\x034]\\x03 \\x034[\\x03 {reason} \\x034]\\x03 \\x034[\\x03 {network} \\x034]\\x03"
        """
	if self.inCache(data["type"], (data["releasename"], data["reason"])):
	    return	
	self.outgoing(data)

    def cmd_unnukedel(self, data):
	"""
        Description:
            Echo unnuke/undelpre to other channels

        Commands:
            - unnuke
            - undelpre
    
        Regex: "!(?P<command>(?P<type>unnuke|undelpre)) {releasename} {reason} {network}"
        Output: "!{command} {releasename} {reason} {network}"
        Output_1: "\\x033[{command}]\\x03 <-> \\x033[\\x03 {releasename} \\x033]\\x03 <-> \\x033[\\x03 {reason} \\x033]\\x03 \\x033[\\x03 {network} \\x033]\\x03"
        Output_2: "\\x033[{command}]\\x03 - \\x033[\\x03 {releasename} \\x033]\\x03 - \\x033[\\x03 {reason} \\x033]\\x03 \\x033[\\x03 {network} \\x033]\\x03"
        Output_3: "\\x033[{command}]\\x03 \\x033[\\x03 {releasename} \\x033]\\x03 \\x033[\\x03 {reason} \\x033]\\x03 \\x033[\\x03 {network} \\x033]\\x03"
        """
	if self.inCache(data["type"], (data["releasename"], data["reason"])):
	    return	
	self.outgoing(data)


    def cmd_modder(self, data):
        """
        Description:
            Echo modnuke/modunnuke to other channels

        Commands:                        
            - modnuke
            - modunnuke                        

        Regex: "!(?P<command>(?P<type>modnuke|modunnuke)) {releasename} {reason} {network}"
        Output: "!{command} {releasename} {reason} {network}"
        Output_1: "\\x0311[{command}]\\x03 <-> \\x0311[\\x03 {releasename} \\x0311]\\x03 <-> \\x0311[\\x03 {reason} \\x0311]\\x03 \\x0311[\\x03 {network} \\x0311]\\x03"
        Output_2: "\\x0311[{command}]\\x03 - \\x0311[\\x03 {releasename} \\x0311]\\x03 - \\x0311[\\x03 {reason} \\x0311]\\x03 \\x0311[\\x03 {network} \\x0311]\\x03"
        Output_3: "\\x0311[{command}]\\x03 \\x0311[\\x03 {releasename} \\x0311]\\x03 \\x0311[\\x03 {reason} \\x0311]\\x03 \\x0311[\\x03 {network} \\x0311]\\x03"
        """
	if self.inCache(data["type"], (data["releasename"], data["reason"])):
	    return	
	self.outgoing(data)
	
    def cmd_oldstatus(self, data):
        """
        Description:
            Oldnuke etc to other channels

        Commands:
            - oldnuke
            - oldunnuke
            - oldmodnuke
            - oldmodunnuke
            - olddelpre
            - oldundelpre

        Regex: "!(?P<command>old(?P<type>nuke|unnuke|modnuke|modunnuke|undelpre|delpre)) {releasename} {reason} {timestamp} {network}"
        Output: "!{command} {releasename} {reason} {timestamp} {network}"
        Output_1: "[OLDSTATUS] {releasename} {reason} {timestamp}"
        """
        if self.inCache(data["type"], (data["releasename"], data["reason"])):
            return

        self.outgoing(data)

    def cmd_addold(self, data):
        """
        Description:
            Echo old release to other networks

        Commands:
            - addold

        Regex: "!(?P<command>(?P<type>addold)) {releasename} {section} {unixtime} {filecountx} {filesizex} {genrex} {reason}"
        Output: "!{command} {releasename} {section} {unixtime} {filecountx} {filesizex} {genrex} {reason}"
        Output_1: "\\x032[OLD]\\x03 {releasename} {section} {unixtime} {filecountx} {filesizex} {genrex} {reason}"
        """
        self.outgoing(data)

    def cmd_addpre(self, data):
        """
        Description:
            Relay release to other networks.

        Commands:
            - addpre

        Regex: "!(?P<command>(?P<type>addpre)) {releasename} {section}"
        Output: "!{command} {releasename} {section}"
        Output_1: "\\x037[PRE]\\x03 <-> \\x037[\\x03 {releasename} \\x037]\\x03 <-> \\x037[\\x03 {section} \\x037]\\x03"
        Output_2: "\\x037[PRE]\\x03 - \\x037[\\x03 {releasename} \\x037]\\x03 - \\x037[\\x03 {section} \\x037]\\x03"
        Output_3: "\\x037[PRE]\\x03 \\x0315[\\x03 \\x0306{section}\\x03 \\x0315]\\x03 \\x0315[\\x03 {releasename} \\x0315]\\x03"
        """
	self.outgoing(data)
	
    def cmd_info(self, data):
        """
        Description:
            Echo info to other networks

        Commands:
            - info            
            - oldinfo

        Regex: "!(?P<command>(?:old|)(?P<type>(?:g|)info)) {releasename} {filecount} {filesize}"
        Output: "!{command} {releasename} {filecount} {filesize}"
        Output_1: "\\x0314[INFO]\\x03 <-> \\x0314[\\x03 {releasename} \\x0314]\\x03 <-> \\x0314[\\x03 {filesize}\\x0314MB\\x03 in {filecount}\\x0314F ]\\x03"
        """
        if "isOld" in data:
            if data["isOld"] == 1:
                data["command"] = "old" + data["type"]
	
	if self.inCache(data["type"], (data["releasename"], data["filecount"])):
            return        
	
	self.outgoing(data)
	

    def cmd_gn(self, data):
        """
        Description:
            Echo genre to other networks

        Commands:
            - gn
            - oldgn

        Regex: "!(?P<command>(?:old|)(?P<type>gn)) {releasename} {genre}"
        Output: "!{command} {releasename} {genre}"
        Output_1: "\\x0306[GENRE]\\x03 <-> \\x0306[\\x03 {releasename} \\x0306]\\x03 <-> \\x0306[\\x03 {genre} \\x0306]\\x03"
        """
        if "isOld" in data:
            if data["isOld"] == 1:
                data["command"] = "old" + data["type"]
		
	if self.inCache(data["type"], (data["releasename"], data["genre"])):
            return
	
	self.outgoing(data)
    
        
    def cmd_addsfv(self, data):
        """
        Description:
            Echo sfv to other networks

        Commands:
            - addsfv
            - oldsfv
            
        Regex: "!(?P<command>(?:add|old)(?P<type>(?:sfv))) {releasename} {url} {filename}(?: (?P<given_crc32>[A-F0-9]{{8}}))?"
        Output: "!{command} {releasename} {url} {filename}"
        Output_1: "\\x0310[SFV]\\x03 <.> [{releasename}] <.> [ {url} ]"
        """

        if "isOld" in data:
            if data["isOld"] == 1:
                data["command"] = "old" + data["type"]
        
        if self.inCache(data["type"], (data["releasename"], data["filename"])):
            return
        
        self.outgoing(data)
        
        
    def cmd_addnfo(self, data):
        """
        Description:
            Echo nfo to other networks

        Commands:
            - addnfo
            - oldnfo

        Regex: "!(?P<command>(?:add|old)(?P<type>(?:nfo))) {releasename} {url} {filename}(?: (?P<given_crc32>[A-F0-9]{{8}}))?"
        Output: "!{command} {releasename} {url} {filename}"
        Output_1: "\\x0310[NFO]\\x03 <.> [{releasename}] <.> [ {url} ]"
        """
        if "isOld" in data:
            if data["isOld"] == 1:
                data["command"] = "old" + data["type"]
        
        if self.inCache(data["type"], (data["releasename"], data["filename"])):
            return               
        self.outgoing(data)



if __name__ == "__main__":
    if len(sys.argv) != 2:
        print "Must specify a config file."
        sys.exit(1)

    dispatch = Dispatcher(sys.argv[1])
    reactor.run()
