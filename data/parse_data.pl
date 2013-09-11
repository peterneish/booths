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

		$booths->{$id}->{'name'} = $name;
		$booths->{$id}->{'lat'}  = $lat;
		$booths->{$id}->{'lng'}  = $lng;
	
	}

}
		# print Dumper($booths);



# now we parse the xml and associate the lat and long 
# with the booth results

my $parser = XML::LibXML->new();
my $doc    = $parser->parse_file('xml/results.xml');

my $xpc = XML::LibXML::XPathContext->new($doc);
$xpc->registerNs(eml => 'urn:oasis:names:tc:evs:schema:eml');


my @contests = $doc->getElementsByTagName("Contest");

foreach my $contest (@contests){

	print "Contest\n";

	my %candidate_details;

	foreach my $candidate ($contest->findnodes('./FirstPreferences/Candidate')){
		my $id = $candidate->findvalue('./eml:CandidateIdentifier@Id');	
		my $name  = $candidate->findnodes("./eml:CandidateIdentifier/eml:CandidateName")->to_literal;

		print "$id : $name \n\n";

	}

	

}
1;




