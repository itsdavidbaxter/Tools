#!/usr/bin/env /usr/bin/python

import sys
import time
import cgi
import cgitb; cgitb.enable()  # for troubleshooting
from SysInvUtils import *

reload(sys)
sys.setdefaultencoding('utf-8')

config  = getConfig('/var/www/cgi-bin/searchDev.cfg')
form    = cgi.FieldStorage()
# we don't do anything with debug now, but it is a comfort to have
debug = form.getvalue("debug")

updateType = config.get('info','updatetype')
action     = form.getvalue("action")
print starthtml(form,config)
#print form
elapsedtime = time.time()
if action == "Enumerate Objects":
    doEnumerateObjects(form,config)
elif action == config.get('info','updateactionlabel'):
    if updateType == 'packinglist':  doPackingList(form,config)
    if updateType == 'barcodeprint': doBarCodes(form,config)
    if updateType == 'inventory':    doUpdateLocations(form,config)
    if updateType == 'keyinfo':      doUpdateKeyinfo(form,config)
    if updateType == 'upload':       uploadFile(form,config)
elif action == "Recent Activity":
    viewLog(form,config)
# special case: if one one location in range, jump to enumerate
elif form.getvalue("lo.location1") != None and str(form.getvalue("lo.location1")) == str(form.getvalue("lo.location2")) :
    if updateType in ['keyinfo', 'inventory']: 
	doEnumerateObjects(form,config)
    else:
	countLocations(form,config)
elif action == "Search":
    if updateType == 'packinglist':  countLocations(form,config)
    if updateType == 'barcodeprint': countLocations(form,config)
    if updateType == 'inventory':    doSearch(form,config)
    if updateType == 'keyinfo':      doSearch(form,config)
elif action in ['<<','>>']:
    print "<h3>Sorry not implemented yet! Please try again tomorrow!</h3>"
else:
    pass
    #print "<h3>Unimplemented action %s!</h3>" % str(action)

elapsedtime = time.time() - elapsedtime

print endhtml(form,config,elapsedtime)
