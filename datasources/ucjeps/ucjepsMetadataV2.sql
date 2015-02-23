select
    h1.name as CSID,
    co.objectnumber as AccessionNumber,
    case when (tig.taxon is not null and tig.taxon <> '')
                then regexp_replace(regexp_replace(tig.taxon, '^.*\)''(.*)''$', '\1'),E'[\\t\\n\\r]+', ' ', 'g')
    end as Determination,
    tu.taxonmajorgroup as MajorGroup,
    case when (fc.item is not null and fc.item <> '')
                then regexp_replace(regexp_replace(fc.item, '^.*\)''(.*)''$', '\1'),E'[\\t\\n\\r]+', ' ', 'g')
    end as Collector,
    co.fieldcollectionnumber as CollectorNumber,
    sdg.datedisplaydate as CollectionDate,
    case
        when
            sdg.dateearliestsingleyear != 0
            and sdg.dateearliestsinglemonth != 0
            and sdg.dateearliestsingleday != 0
        then
            to_date(
            sdg.dateearliestsingleyear::varchar(4) || '-' ||
            sdg.dateearliestsinglemonth::varchar(2) || '-' ||
            sdg.dateearliestsingleday::varchar(2),
            'yyyy-mm-dd')
        else null
    end as EarlyCollectionDate,
    case
        when
            sdg.datelatestyear != 0
            and sdg.datelatestmonth != 0
            and sdg.datelatestday != 0
        then
            to_date(
            sdg.datelatestyear::varchar(4) || '-' ||
            sdg.datelatestmonth::varchar(2) || '-' ||
            sdg.datelatestday::varchar(2),
            'yyyy-mm-dd')
        else null
    end as LateCollectionDate,
    regexp_replace(lg.fieldlocverbatim,E'[\\t\\n\\r]+', ' ', 'g') as Locality,
    lg.fieldloccounty as CollCounty,
    lg.fieldlocstate as CollState,
    lg.fieldloccountry as CollCountry,
    lg.velevation as Elevation,
    lg.minelevation as MinElevation,
    lg.maxelevation as MaxElevation,
    lg.elevationunit as ElevationUnit,
    regexp_replace(co.fieldcollectionnote,E'[\\t\\n\\r]+', ' ', 'g') as Habitat,
    lg.decimallatitude as DecLatitude,
    lg.decimallongitude as DecLongitude,
    case when lg.vcoordsys like 'Township%'
                then lg.vcoordinates
    end as TRSCoordinates,
    lg.geodeticdatum as Datum,
    lg.localitysource as CoordinateSource,
    lg.coorduncertainty as CoordinateUncertainty,
    lg.coorduncertaintyunit as CoordinateUncertaintyUnit,
    cc.updatedat as UpdatedAt,
    case when conh.labelheader like 'urn:%' then getdispl(conh.labelheader)
        else conh.labelheader
    end as Label_Header,
    case when conh.labelfooter like 'urn:%' then getdispl(conh.labelfooter)
        else conh.labelfooter
    end as Label_Footer,
    array_to_string(array
      (SELECT CASE WHEN (tig2.taxon IS NOT NULL AND tig2.taxon <>'' and tig2.taxon not like '%no name%') THEN getdispl(regexp_replace(tig2.taxon,E'[\\t\\n\\r]+', ' ', 'g')) 
	||CASE WHEN (tig2.identby IS NOT NULL AND tig2.identby <>'' and tig2.identby not like '%unknown%') THEN ', by ' || getdispl(tig2.identby) ELSE '' END
	||CASE WHEN (tig2.institution IS NOT NULL AND tig2.institution <>'') THEN ', ' || getdispl(tig2.institution) ELSE '' END
	||CASE WHEN (prevdetsdg.datedisplaydate IS NOT NULL AND prevdetsdg.datedisplaydate <>'' and prevdetsdg.datedisplaydate <>' ') THEN ', ' || prevdetsdg.datedisplaydate ELSE '' END
	||CASE WHEN (tig2.identkind IS NOT NULL AND tig2.identkind <>'') THEN  ' (' || tig2.identkind || ')' ELSE '' END) ELSE '' END
       from collectionobjects_common co1
        inner join hierarchy h1int on co1.id = h1int.id
        left outer join hierarchy htig2 on (co1.id = htig2.parentid and htig2.pos > 0
        and htig2.name = 'collectionobjects_naturalhistory:taxonomicIdentGroupList')
        left outer join taxonomicIdentGroup tig2 on (tig2.id = htig2.id)
        left outer join hierarchy hprevdet on (tig2.id = hprevdet.parentid and hprevdet.name = 'identDateGroup')
        left outer join structureddategroup prevdetsdg on (prevdetsdg.id = hprevdet.id)
       where h1int.name=h1.name order by htig2.pos), '␥', '') Previous_Determinations,
    lng.localname as Local_Name,
    case when cocbd.item is null or cocbd.item = '' then null else cocbd.item end as Brief_Description,
    lg.vdepth as Depth,
    lg.mindepth as MinDepth,
    lg.maxdepth as MaxDepth,
    lg.depthunit as DepthUnit,
    array_to_string(array
      (SELECT CASE WHEN (atg.associatedtaxon IS NOT NULL AND atg.associatedtaxon<>'') THEN (getdispl(atg.associatedtaxon) 
	||CASE WHEN (atg.interaction IS NOT NULL AND atg.interaction<>'') THEN ' (' || atg.interaction||')' ELSE '' END) ELSE '' END
      from collectionobjects_common co4
      inner join hierarchy h4int on co4.id = h4int.id
      left outer join hierarchy hatg on (co4.id = hatg.parentid 
        and hatg.name = 'collectionobjects_naturalhistory:associatedTaxaGroupList')
      left outer join associatedtaxagroup atg on (hatg.id = atg.id)
      where h4int.name = h1.name
      order by hatg.pos), '␥', '') Associated_Taxa,    
    array_to_string(array
      (SELECT CASE WHEN (tsg.typespecimenkind IS NOT NULL AND tsg.typespecimenkind <>'') THEN (tsg.typespecimenkind 
	||CASE WHEN (tsg.typespecimenbasionym IS NOT NULL AND tsg.typespecimenbasionym <>'') THEN ' (' || getdispl(tsg.typespecimenbasionym)||')' ELSE '' END) ELSE '' END
       from collectionobjects_common co2
       inner join hierarchy h2int on co2.id = h2int.id
       left outer join hierarchy htsg on (co2.id = htsg.parentid 
        and htsg.name = 'collectionobjects_naturalhistory:typeSpecimenGroupList')
       left outer join typespecimengroup tsg on (tsg.id = htsg.id)
       where h2int.name = h1.name
       order by htsg.pos), '␥', '') Type_Assertions,
    case when conh.cultivated is null or conh.cultivated = '' then null else conh.cultivated end as Cultivated,
    case when co.sex is null or co.sex = '' then null else co.sex end as Sex,
    co.phase as Phase,
    array_to_string(array
      (SELECT CASE WHEN (ong.numbervalue IS NOT NULL AND ong.numbervalue<>'') THEN (ong.numbervalue 
	||CASE WHEN (ong.numbertype IS NOT NULL AND ong.numbertype <>'') THEN ' (' || ong.numbertype||')' ELSE '' END) ELSE '' END
       from collectionobjects_common co3
       inner join hierarchy h3int on co3.id = h3int.id
       left outer join hierarchy hong on (co3.id = hong.parentid 
         and hong.name = 'collectionobjects_common:otherNumberList')
       left outer join othernumber ong on (ong.id = hong.id)
       where h3int.name = h1.name
       order by hong.pos), '␥', '') Other_Numbers,
    CASE WHEN (tig.identby IS NOT NULL AND tig.identby <>'' and tig.identby not like '%unknown%') THEN (getdispl(tig.identby) 
	||CASE WHEN (tig.institution IS NOT NULL AND tig.institution <>'') THEN ', ' || getdispl(tig.institution) ELSE '' END
	||CASE WHEN (detdetailssdg.datedisplaydate IS NOT NULL AND detdetailssdg.datedisplaydate <>'' and detdetailssdg.datedisplaydate <>' ') THEN ', ' || detdetailssdg.datedisplaydate ELSE '' END
	||CASE WHEN (tig.identkind IS NOT NULL AND tig.identkind <>'') THEN ' (' || tig.identkind || ')' ELSE '' END) ELSE '' END AS Determination_Details
from collectionobjects_common co
inner join misc on co.id = misc.id
inner join hierarchy h1 on co.id = h1.id
inner join collectionspace_core cc on co.id=cc.id
left outer join collectionobjects_common_fieldCollectors fc
        on (co.id = fc.id and fc.pos = 0)
left outer join hierarchy hfcdg
        on (co.id = hfcdg.parentid and hfcdg.name = 'collectionobjects_common:fieldCollectionDateGroup')
left outer join structureddategroup sdg on (sdg.id = hfcdg.id)
left outer join hierarchy htig
        on (co.id = htig.parentid and htig.pos = 0
        and htig.name = 'collectionobjects_naturalhistory:taxonomicIdentGroupList')
left outer join taxonomicIdentGroup tig on (tig.id = htig.id)
left outer join hierarchy hdetdetailsdate on (tig.id = hdetdetailsdate.parentid and hdetdetailsdate.name = 'identDateGroup')
left outer join structureddategroup detdetailssdg on (detdetailssdg.id = hdetdetailsdate.id)
left outer join hierarchy hlg
        on (co.id = hlg.parentid and hlg.pos = 0
        and hlg.name = 'collectionobjects_naturalhistory:localityGroupList')
left outer join taxon_common tc on (tig.taxon = tc.refname)
left outer join taxon_ucjeps tu on (tu.id = tc.id)
left outer join localitygroup lg on (lg.id = hlg.id)
left outer join collectionobjects_naturalhistory conh on (co.id = conh.id)
left outer join hierarchy hlng on (co.id = hlng.parentid and hlng.primarytype = 'localNameGroup' and hlng.pos = 0)
left outer join localNameGroup lng on (hlng.id = lng.id)
left outer join collectionobjects_common_briefdescriptions cocbd on (co.id = cocbd.id and cocbd.pos = 0)
where misc.lifecyclestate <> 'deleted'
-- and h1.name = '3380bad9-5bea-4eed-860e' -- UCcrhtest on ucjeps-dev
-- and h1.name = '338075de-821c-49b3-8f34-969cc666a61e' -- JEPS46872 
-- and h1.name = '33803cfe-e6a8-4025-bf53-a3814cf4da82'	-- JEPS105623
-- and h1.name like '3380%'
and substring(co.objectnumber from '^[A-Z]*') in ('UC', 'UCLA', 'JEPS', 'GOD')
order by co.objectnumber
