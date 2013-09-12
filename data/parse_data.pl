#! /usr/bin/perl -w


# parses the list of booths and results 
# outputs a geoJSON file of booth with information and 
# heatmap data for each party.


use TEXT::CSV;
use Data::Dumper;
use XML::LibXML;
use XML::LibXML::XPathContext; 


my %booths;

# first read in the booth information and load into a hash

$csv = Text::CSV->new();

open (BOOTHS, "<", "booths.csv")  or die $!;

while(<BOOTHS>){
	# skip header row
	next if ($. == 1); 

	$status = $csv->parse($_);

	if($status){

		@fields = $csv->fields();	

		my $name = $fields[5];
		my $id =   $fields[14];
		my $lat =  $fields[18];
		my $lng =  $fields[19];

		$booths{$id}->{'name'} = $name;
		$booths{$id}->{'lat'}  = $lat;
		$booths{$id}->{'lng'}  = $lng;
	
	}

}
		# print Dumper($booths);



# now we parse the xml and associate the lat and long 
# with the booth results

my $parser = XML::LibXML->new();
my $doc    = $parser->parse_file('xml/results.xml');

my $xpc = XML::LibXML::XPathContext->new($doc);
$xpc->registerNs(eml => 'urn:oasis:names:tc:evs:schema:eml');
$xpc->registerNs(ns => 'http://www.aec.gov.au/xml/schema/mediafeed');


my @contests = $xpc->findnodes("//ns:House/ns:Contests/ns:Contest");

foreach my $contest (@contests){

	my %candidate_details;

	print $xpc->findvalue('./eml:ContestIdentifier/eml:ContestName', $contest);
	print "\n";

	foreach my $candidate ($xpc->findnodes('./ns:FirstPreferences/ns:Candidate', $contest)){
		my $id = $xpc->findvalue('.//eml:CandidateIdentifier/@Id', $candidate);	
		my $name = $xpc->findvalue('.//eml:CandidateName', $candidate);	
		my $party = $xpc->findvalue('.//eml:RegisteredName', $candidate);	
		my $is_independent = $xpc->findvalue('@Independent', $candidate);
		my $shortcode = $xpc->findvalue('./eml:AffiliationIdentifier/@ShortCode', $candidate);
		$party = "Independent" if $is_independent;

		$candidate_details{$id}->{name} = $name;
		$candidate_details{$id}->{shortcode} = $shortcode;
		$candidate_details{$id}->{party} = $party;

	}


	# now get the individual polling places 
	foreach my $pp ($xpc->findnodes('./ns:PollingPlaces/ns:PollingPlace', $contest)){
		$pp_id = $xpc->findvalue('./ns:PollingPlaceIdentifier/@Id', $pp);	
		
		#print "Polling place id: $pp_id \n";
		
		# now loop through candidates for each polling place
		foreach my $pp_candidate ($xpc->findnodes('./ns:FirstPreferences/ns:Candidate', $pp)){
			$pp_can_id = $xpc->findvalue('./eml:CandidateIdentifier/@Id', $pp_candidate);
			$pp_votes = $xpc->findvalue('./ns:Votes/@Percentage', $pp_candidate);
			
			# add the data to the booths hash
			$pp_shortcode = $candidate_details{$pp_can_id}->{shortcode};
			if($pp_shortcode){
				$booths{$pp_id}->{$pp_shortcode} = $pp_votes;	
			}

		}
		
	}
	print "-----------\n\n";

}


# write to some json files
open GRN, ">", "GRN.json" or die $!;

@grn;

foreach my $key (keys %booths){
	if($booths{$key}->{name}){
		if ($booths{$key}->{"GRN"} && $booths{$key}->{lat} && $booths{$key}->{lng}){
			$line =  '{ "lat": '   . $booths{$key}->{lat}
			       . ', "lng": '   . $booths{$key}->{lng}
			       . ', "count": ' . $booths{$key}->{GRN}	
			       . '}';
			push(@grn, $line);
		}
		print $booths{$key}->{name};
		print " GRN: ". $booths{$key}->{"GRN"};
		print " ALP: ". $booths{$key}->{"ALP"};
		print " LP: ". $booths{$key}->{"LP"};
		print "\n\n";
	}
}

print GRN '{"max": 50, "data": [';
print GRN join ",", @grn;
print GRN ']}';

close GRN;
1;




