#! /usr/bin/perl

# Purpose: Automatically retrieve data from BLink
#
# Usage: cat some_file.csv | blink_getter output_filename.csv lostgis.csv
#
# The input file should be a comma delimited file with two columns: a label,
# and a gi. 
#
# Example:
# $ cat input.csv
#   a, 186509637
#   b, 186509637
# $ cat input.csv | blink_getter.pl out.csv lost.csv
# $ cat out.csv
#  label, gi, Archae, Bacteria, Metazoa, Fungi, Plants, Viruses, Other eukaryotes, nhits, nproteins, nspecies
#  'a', 186509637,0,7,312,38,585,0,49,991,908,185
#  'b', 186509637,0,7,312,38,585,0,49,991,908,185
#
# The ammount of work I have to do to get anything out of BLink is quite
# absurd. It is downright shameful that they don't provide a means of bulk
# downloading their data. Running this script may seem like a denial of service
# attack from their end. Good riddance. The deserve it.
#
# Occasionally entries vanish, these will be collected in the lost.csv file.
# This file can be passed through the blink_getter.pl script a second (or third) time and
# usually the entries will then be found. If not, then BLink doesn't have the id.
#
# If you find a better way please contact me.
#
# Author: Zebulun Arendsee
# email: arendsee@iastate.edu

use strict;
use warnings;
use LWP::Simple;
use Term::ProgressBar;

my $outfile = shift;
my $lostfile = shift;

my @COLUMNS = ('Archae', 'Bacteria', 'Metazoa', 'Fungi', 'Plants', 'Viruses', 'Other eukaryotes',
               'nhits', 'nproteins', 'nspecies');
my @rows = ();
my $taxpat = qr/new\s*tax_item\('\d+',\s*'(.+?)'.*'(\d+)'\)/;
my $countpat = qr/Selected:\s*(\d+)\s*hits\s*in\s*(\d+)\s*proteins\s*in\s*(\d+)\s*species/;

my @ids = <STDIN>;

my $nids = scalar @ids;
my $progress = Term::ProgressBar->new({
        count => scalar $nids, 
        ETA => 'linear'});

my @lost = ();

open(OUT, '>', $outfile);
open(LOST, '>', $lostfile);

print OUT "label, gi";
print OUT ", $_" foreach (@COLUMNS);
print OUT "\n";

for (@ids){
    my %blink;
    if(/^(.*),\s*(\d+)$/){
        $blink{'label'} = $1;
        $blink{'gi'} = $2;
    } else {
        print STDERR "\nEach line of input should be formatted as '<label>,<gi>': Goodbye ...\n";
        exit;
    }
    my $url = "http://www.ncbi.nlm.nih.gov/sutils/blink.cgi?" .
              "mode=result" .
              "&pid=" . $blink{'gi'} . 
              "&taxon_mode=all" .
              "&org=2" . # 1 - best hits, 2 - all hits, 3 - hide identical
              "&set=0" . # 0 - all, 1 - PDB, 2 - SWISSPROPT, 3 - refseq, 4 - genomes 
              "&cut=100" . # bitscore cutoff
              "&maxcut=" .
              "&per_page=1"; # Setting to one minimizes file size
    my $xml = get($url);

    if(not defined $xml){
        print LOST "$blink{'label'}, $blink{'gi'}\n";
        next;
    }
    
    while($xml =~ /$taxpat/g){
        $blink{$1} = $2;
        last if $1 eq 'Other_eukaryotes';
    }

    # Extract hit, protein and species counts
    while($xml =~ /$countpat/g){
        $blink{'nhits'} = $1;
        $blink{'nproteins'} = $2;
        $blink{'nspecies'} = $3;
        last;
    }

    $progress->update();

    my $good = 1;
    my $row = "$blink{'label'}, $blink{'gi'}";
    foreach (@COLUMNS){
        if(exists $blink{$_}){
            $row .= ",$blink{$_}";
        }
        else{
            print LOST "$blink{'label'},$blink{'gi'}\n";
            $good = 0;
        }
    }
    print OUT "$row\n" if $good;
}

close OUT;
close LOST;
