#! /usr/bin/perl -w


# parses the list of booths and results 
# outputs a geoJSON file of booth with information and 
# heatmap data for each party.


use TEXT::CSV;
use Data::Dumper;
use XML::LibXML;
use XML::LibXML::XPathContext; 

my %booths;
my %parties; # keep track of parties for dumping our files later

# first read in the booth information and load into a hash

$csv = Text::CSV->new();

open (BOOTHS, "<", "booths.csv")  or die $!;

print "\n\nParsing booths...";

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


print "\n\nParsing results...";


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
		my @can_details = ();
		
		# now loop through candidates for each polling place
		foreach my $pp_candidate ($xpc->findnodes('./ns:FirstPreferences/ns:Candidate', $pp)){
			$pp_can_id = $xpc->findvalue('./eml:CandidateIdentifier/@Id', $pp_candidate);
			$pp_votes = $xpc->findvalue('./ns:Votes/@Percentage', $pp_candidate);
			
			# add the data to the booths hash
			$pp_shortcode = $candidate_details{$pp_can_id}->{shortcode};
			if($pp_shortcode){
				$booths{$pp_id}->{$pp_shortcode} = $pp_votes;	
				$parties{$pp_shortcode}++;
			}
			

			push (@can_details, {"name"  => $candidate_details{$pp_can_id}->{name}, 
			            "party" => $candidate_details{$pp_can_id}->{party},
			            "vote"  => $pp_votes});

		}
	
		@{$booths{$pp_id}->{candidates}} = @can_details;
		
	}

}

print "\n\nGenerating heatmap data...";

# now write out our json data files for heat map
foreach my $shortcode (keys %parties){

	my @data;
	$maxcount = 0;

	# don't bother if it is a small party and not in many booths
	next if $parties{$shortcode} < 200;

	print "processing $shortcode ...\n";


	foreach my $key (keys %booths){
		if($booths{$key}->{$shortcode} && $booths{$key}->{lat} && $booths{$key}->{lng}){
			$line =  '{ "lat": '   . $booths{$key}->{lat}
                               . ', "lng": '   . $booths{$key}->{lng}
                               . ', "count": ' . $booths{$key}->{$shortcode}
                               . '}';

			push(@data, $line);
			$maxcount = $booths{$key}->{$shortcode} if $booths{$key}->{$shortcode} > $maxcount;
		}	
	}

	print "found " . @data . " booths, max is ". $maxcount. "\n";

	# open a data file
	my $file = "$shortcode.json";
	open my $fh, '>', $file or die "Can't open output file: $!";
		print $fh '{"max": '. $maxcount .', "data": [';
		print $fh join ",", @data;
		print $fh ']}';

	close $fh;
}


print "\n\nGenerating booth information...";
# and write our geoJSON details for the booths

my @features;

foreach $key (keys %booths){

	
	if ($booths{$key}->{lat} && $booths{$key}->{lng}){
		$feature = '{';
		$feature.= '"type": "Feature", "geometry": ';
		$feature.=		 '{"type": "Point", "coordinates": [';
		$feature.= 		$booths{$key}->{lng} .',' . $booths{$key}->{lat};
		$feature.=   ']},';
		$feature.=  '"properties": {';
		$feature.= '"name": "' . $booths{$key}->{name} . '",'	;
		$feature.= '"candidates": ';
	
		my @cans;
		my @shortcans;

		foreach my $can (@{$booths{$key}->{candidates}}){
			push(@cans, '"' . $can->{name} . ' (' . $can->{party} . ') '. $can->{vote}. '%"');
		}
		foreach my $can (@{$booths{$key}->{candidates}}){
			push(@shortcans, '"'. $can->{party} . ' '. $can->{vote}. '%"');
		}
		$feature.= '[';
		$feature.= join ',', @shortcans;
		$feature.= ']';

		$feature.=  '}';
		$feature.= '}';

		push(@features, $feature);
	}

}
open GEO, ">", "booths.json" or die "Can't open output file: $!";

print GEO '{ "type": "FeatureCollection", "features": [';
print GEO join ',', @features;
print GEO ']}';

close GEO;

print "Done.\n\n";




1;




