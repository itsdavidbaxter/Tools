use strict;

my %count ;
my $delim = "\t";

open MEDIA,$ARGV[0] || die "couldn't open media file $ARGV[0]";
my %blobs ;
my %seen;
my $restricted = '59a733dd-d641-4e1a-8552';
my $ispublic = 'public';
my $imagetype = 'image';
my $runtype = $ARGV[2]; # generate media for public or internal

while (<MEDIA>) {
  $count{'media'}++;
  chomp;
  my ($objectcsid,$objectnumber,$mediacsid,$description,$name,$creatorrefname,$creator,$blobcsid,$copyrightstatement,$identificationnumber,$rightsholderrefname,$rightsholder,$contributor,$approvedforweb,$pahmatmslegacydepartment,$objectstatus,$primarydisplay) = split /$delim/;
  #print "$blobcsid $objectcsid\n";
  # skip this blob if we've already seen it
  #next if $seen{$mediacsid}++;
  $imagetype = 'image';
  # mark catalog card images as such
  $imagetype = 'card' if $description =~ /(catalog card|HSR Datasheet)/i;
  $imagetype = 'card' if $description =~ /^Index/i ;
  $ispublic = 'public';
  # we don't need to match a pattern here, it's a vocabulary. But just in case...
  $ispublic = 'notpublic' if ($pahmatmslegacydepartment =~ /Human Remains/i) ;
  $ispublic = 'notpublic' if ($pahmatmslegacydepartment =~ /NAGPRA-associated Funerary Objects/i) ;
  $ispublic = 'notpublic' if ($objectstatus =~ /culturally/i) ;
  # NB: the test 'burial' in context of use occurs below -- we only mask if the FCP is in North America
  $ispublic = 'notapprovedforweb' if ($approvedforweb eq 'f') ;
  # warn $ispublic . $imagetype;
  $count{$imagetype}++;
  $count{$ispublic}++;
  if ($imagetype eq 'card') {
    $blobs{$objectcsid}{'card'} .= $blobcsid   . ',' ;
  }
  else {
    $blobs{$objectcsid}{'hasimages'} = 'yes';
    # if this run is to generate the public datastore, use the restricted image if this blob is restricted.
    if ($runtype eq 'public') {
      $blobcsid = $restricted if ($ispublic ne 'public');
    }
    if ($primarydisplay eq 't') {
      $blobs{$objectcsid}{'primary'} = $blobcsid;
    }
    else {
      # add this blob to the list of blobs, unless we somehow already have it (no dups allowed!)
      $blobs{$objectcsid}{'image'} .= $blobcsid . ',' unless $blobs{$objectcsid}{'image'} =~ /$blobcsid/;
    }
  }
  $blobs{$objectcsid}{'type'} .= $imagetype  . ',' unless $blobs{$objectcsid}{'type'} =~ /$imagetype/;
  $blobs{$objectcsid}{'type'} .= $ispublic   . ',' unless $blobs{$objectcsid}{'type'} =~ /$ispublic/;
}

open METADATA,$ARGV[1] || die "couldn't open metadata file $ARGV[1]";
while (<METADATA>) {
  chomp;
  my ($id, $objectcsid, @rest) = split /$delim/;
  # handle header line
  if ($id eq 'id') {
    print $_ . $delim . join($delim,qw(blob_ss card_ss primaryimage_s imagetype_ss hasimages_s)) . "\n";
    next;
  }
  $count{'metadata'}++;
  my $mediablobs;
  $blobs{$objectcsid}{'hasimages'} = 'no' unless $blobs{$objectcsid}{'hasimages'} eq 'yes';
  my $foundimage = $blobs{$objectcsid}{'image'};
  if ($foundimage) {
    # if context of use field contains the word burial
    $blobs{$objectcsid}{'image'} = $restricted if (@rest[12] =~ /burial/i && @rest[34] =~ /United States/i);
    # if object name contains something like "charm stone"
    $blobs{$objectcsid}{'image'} = $restricted if (@rest[8] =~ /charm.*stone/i && @rest[34] =~ /United States/i);

    # insert list of blobs, etc. as final columns
    $blobs{$objectcsid}{'type'} =~ s/,$//;
    $blobs{$objectcsid}{'type'} = join(',', sort(split(',', $blobs{$objectcsid}{'type'})));
    for my $column (qw(image card primary type hasimages)) {
      $mediablobs .= $delim . $blobs{$objectcsid}{$column};
    }
    $count{'object: ' . $blobs{$objectcsid}{'type'}}++;
    $count{'matched'}++;
  }
  else {
    $count{'unmatched'}++;
    $mediablobs = $delim x 5;
  }
  $mediablobs =~ s/,$delim/$delim/g; # get rid of trailing commas
  print $_ . $mediablobs . "\n";
}

foreach my $s (sort keys %count) {
 warn $s . ": " . $count{$s} . "\n";
}