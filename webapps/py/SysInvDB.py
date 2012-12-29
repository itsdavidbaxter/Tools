#!/usr/bin/env /usr/bin/python

import time
import sys
import cgi
import pgdb

timeoutcommand = 'set statement_timeout to 300000'

def dbtransaction(command,config):

    pahmadb  = pgdb.connect(config.get('connect','connect_string'))
    cursor   = pahmadb.cursor()
    cursor.execute(command)

def setquery(type,location):

    if type == 'inventory':
	return  """
SELECT distinct on (locationkey,sortableobjectnumber,h3.name)
l.termdisplayName AS storageLocation,
concat(replace(l.termdisplayName,' ','0'),regexp_replace(ma.crate, '^.*\\)''(.*)''$', '\\1')) AS locationkey,
m.locationdate,
cc.objectnumber objectnumber,
cc.numberofobjects objectCount,
(case when ong.objectName is NULL then '' else ong.objectName end) objectName,
rc.subjectcsid movementCsid,
lc.refname movementRefname,
rc.objectcsid  objectCsid,
''  objectRefname,
m.id moveid,
rc.subjectdocumenttype,
rc.objectdocumenttype,
cp.sortableobjectnumber sortableobjectnumber,
ma.crate crateRefname,
regexp_replace(ma.crate, '^.*\\)''(.*)''$', '\\1') crate

FROM loctermgroup l

join hierarchy h1 on l.id = h1.id
join locations_common lc on lc.id = h1.parentid
join movements_common m on m.currentlocation = lc.refname


join hierarchy h2 on m.id = h2.id
join relations_common rc on rc.subjectcsid = h2.name
join movements_anthropology ma on ma.id = h2.id

join hierarchy h3 on rc.objectcsid = h3.name
join collectionobjects_common cc on h3.id = cc.id

left outer join hierarchy h5 on (cc.id = h5.parentid and h5.name =
'collectionobjects_common:objectNameList' and h5.pos=0)
left outer join objectnamegroup ong on (ong.id=h5.id)

left outer join collectionobjects_pahma cp on (cp.id=cc.id)

WHERE 
   l.termdisplayName = '""" + str(location) + """'
   
ORDER BY locationkey,sortableobjectnumber,h3.name desc
LIMIT 30000"""

    elif type == 'keyinfo' or type == 'barcodeprint':
	return """
SELECT distinct on (locationkey,sortableobjectnumber,h3.name)
l.termdisplayName AS storageLocation,
replace(l.termdisplayName,' ','0') AS locationkey,
m.locationdate,
cc.objectnumber objectnumber,
(case when ong.objectName is NULL then '' else ong.objectName end) objectName,
cc.numberofobjects objectCount,
case when (pfc.item is not null and pfc.item <> '') then
 substring(pfc.item, position(')''' IN pfc.item)+2, LENGTH(pfc.item)-position(')''' IN pfc.item)-2)
end AS fieldcollectionplace,
case when (apg.assocpeople is not null and apg.assocpeople <> '') then
 substring(apg.assocpeople, position(')''' IN apg.assocpeople)+2, LENGTH(apg.assocpeople)-position(')''' IN apg.assocpeople)-2)
end as culturalgroup,
rc.objectcsid  objectCsid,
case when (pef.item is not null and pef.item <> '') then
 substring(pef.item, position(')''' IN pef.item)+2, LENGTH(pef.item)-position(')''' IN pef.item)-2)
end as ethnographicfilecode,
pfc.item fcpRefName,
apg.assocpeople cgRefName,
pef.item efcRefName

FROM loctermgroup l

join hierarchy h1 on l.id = h1.id
join locations_common lc on lc.id = h1.parentid
join movements_common m on m.currentlocation = lc.refname

join hierarchy h2 on m.id = h2.id
join relations_common rc on rc.subjectcsid = h2.name

join hierarchy h3 on rc.objectcsid = h3.name
join collectionobjects_common cc on h3.id = cc.id

left outer join hierarchy h4 on (cc.id = h4.parentid and h4.name =
'collectionobjects_common:objectNameList' and (h4.pos=0 or h4.pos is null))
left outer join objectnamegroup ong on (ong.id=h4.id)

left outer join collectionobjects_pahma cp on (cp.id=cc.id)
left outer join collectionobjects_pahma_pahmafieldcollectionplacelist pfc on (pfc.id=cc.id)
left outer join collectionobjects_pahma_pahmaethnographicfilecodelist pef on (pef.id=cc.id)

left outer join hierarchy h5 on (cc.id=h5.parentid and h5.primarytype =
'assocPeopleGroup' and (h5.pos=0 or h5.pos is null))
left outer join assocpeoplegroup apg on (apg.id=h5.id)

WHERE 
   l.termdisplayName = '""" + str(location) + """'
   
AND (pfc.pos=0 or pfc.pos is null)
AND (h5.pos=0 or h5.pos is null)
AND (pef.pos=0 or pef.pos is null)
   
ORDER BY locationkey,sortableobjectnumber,h3.name desc
LIMIT 30000
"""

def getlocations(location1,location2,num2ret,config,updateType):

    pahmadb  = pgdb.connect(config.get('connect','connect_string'))
    objects  = pahmadb.cursor()
    objects.execute(timeoutcommand)
   
    debug = False
 
    result = []

    for loc in getloclist('set',location1,'',num2ret,config):
        getobjects = setquery(updateType,loc[0])

        try:
	    elapsedtime = time.time()
            objects.execute(getobjects)
	    elapsedtime = time.time() - elapsedtime
            if debug: sys.stderr.write('all objects: %s :: %s\n' % (loc[0],elapsedtime))
	except pgdb.DatabaseError, e:
            sys.stderr.write('getlocations select error: %s' % e)
            return result       
        except:
	    sys.stderr.write("some other getlocations database error!")
            return result       

        # a hack: check each object to make it is really in this location
	try:
	    rows = objects.fetchall()
	except pgdb.DatabaseError, e:
            sys.stderr.write("fetchall getlocations database error!")

        if debug: sys.stderr.write('number objects to be checked: %s\n' % len(rows))
        try:
            # a hack: check each object to make it is really in this location
            for row in rows:
	        elapsedtime = time.time()
	        cf = findcurrentlocation(row[8],config)
	        elapsedtime = time.time() - elapsedtime
                if debug: sys.stderr.write('currentlocation: %s :: %s\n' % (row[8],elapsedtime))
                if debug: sys.stderr.write('checking csid %s %s %s\n' % (row[8],cf,row[0]))
	        if cf  == row[0]:
	        #if findcurrentlocation(row[8]) == row[0]:
    	            result.append(row)
	        elif cf  == 'findcurrentlocation error':
    	            result.append(row)
                    sys.stderr.write('%s : %s (%s)\n' % (row[8],cf,str(loc[0])))
	        elif str(loc[0]) in str(cf):
		    row[0] = cf
    	            result.append(row)
                    if debug: sys.stderr.write('%s found at (%s) : but in a "crate": %s' % (row[8],str(loc[0]),cf))
	        else:
		    #print 'not here',row
                    if debug: sys.stderr.write('%s not here (%s) : found at %s\n' % (row[8],str(loc[0]),cf))
    	            #result.append(row)
		    pass
	except:
           raise
           sys.stderr.write("other getobjects error: %s" % len(rows))

    return result

def getloclist(searchType,location1,location2,num2ret,config):

    # 'set' means 'next num2ret locations', otherwise prefix match
    if searchType == 'set':
	whereclause = "WHERE locationkey >= replace('" + location1 + "',' ','0')"
    elif searchType == 'prefix':
	whereclause = "WHERE locationkey LIKE replace('" + location1 + "%',' ','0')"
    elif searchType == 'range':
	whereclause = "WHERE locationkey >= replace('" + location1 + "',' ','0') AND locationkey <= replace('" + location2 + "',' ','0')"

    pahmadb  = pgdb.connect(config.get('connect','connect_string'))
    objects  = pahmadb.cursor()
    objects.execute(timeoutcommand)
    if int(num2ret) > 30000: num2ret = 30000
    if int(num2ret) < 1:    num2ret = 1

    getobjects = """
select * from (
select termdisplayname,replace(termdisplayname,' ','0') locationkey from loctermgroup) as t
""" + whereclause + """
order by locationkey
limit """ + str(num2ret)
    
    objects.execute(getobjects)
    #for object in objects.fetchall():
        #print object
    return objects.fetchall()

def findcurrentlocation(csid,config):

    pahmadb  = pgdb.connect(config.get('connect','connect_string'))
    objects  = pahmadb.cursor()
    objects.execute(timeoutcommand)

    getloc = "select findcurrentlocation('" + csid + "')"
   
    try: 
        objects.execute(getloc)
    except:
	return "findcurrentlocation error"

    return objects.fetchone()[0]

def getrefname(table,term,config):

    pahmadb  = pgdb.connect(config.get('connect','connect_string'))
    objects  = pahmadb.cursor()
    objects.execute(timeoutcommand)

    if term == None or term == '':
	return ''

    query = "select refname from %s where refname ILIKE '%%''%s''%%' LIMIT 1" % (table,term)

    try:
        objects.execute(query)
        return objects.fetchone()[0]
    except:
	return ''
        raise


def findrefnames(table,termlist,config):

    pahmadb  = pgdb.connect(config.get('connect','connect_string'))
    objects  = pahmadb.cursor()
    objects.execute(timeoutcommand)

    result = []
    for t in termlist:
        query = "select refname from %s where refname ILIKE '%%''%s''%%'" % (table,t)

        try:
            objects.execute(query)
	    refname = objects.fetchone()
	    result.append([t,refname])
        except:
	    raise
            return "findrefnames error"

    return result


if __name__ == "__main__":

    from SysInvUtils import getConfig
    config = getConfig('sysinvProd.cfg')
    print '\nrefnames\n'
    print getrefname('concepts_common','zzz',config)
    print getrefname('concepts_common','',config)
    print getrefname('concepts_common','Yurok',config)
    print findrefnames('places_common',['zzz','Sudan, Northern Africa, Africa'],config)
    print '\ncurrentlocation\n'
    print findcurrentlocation('c65b2ffa-6e5f-4a6d-afa4-e0b57fc16106',config)

    print '\nset of locations\n'
    for loc in getloclist('set','Kroeber, 20A, W B','',10,config):
        print loc

    print '\nlocations by prefix\n'
    for loc in getloclist('prefix','Kroeber, 20A, W B','',1000,config):
        print loc

    print '\nlocations by range\n'
    for loc in getloclist('range','Kroeber, 20A, W B2, 1','Kroeber, 20A, W B5, 11',1000,config):
        print loc

    print '\nobjects\n'
    #for loc in getlocations('no location entered',1):
    #for i,loc in enumerate(getlocations('Regatta, A150, Cat. 3 cabinet  1 A,  4',1,config)):
    #for i,loc in enumerate(getlocations('Kroeber, 20A, W 23,  9',1,config,'inventory')):
    #for i,loc in enumerate(getlocations('Regatta, A150, RiveTier 27, C',1,config,'inventory')):
    #for i,loc in enumerate(getlocations('Kroeber, 20AMez, 128 A','',1,config,'inventory')):
    for i,loc in enumerate(getlocations('Regatta, A150, South Nexel Unit 6, C','',1,config,'inventory')):
	print 'location',i+1,loc[0:6]

    print '\nkeyinfo\n'
    for i,loc in enumerate(getlocations('Kroeber, 20AMez, 128 A','',1,config,'keyinfo')):
	print 'location',i+1,loc[0:12]
