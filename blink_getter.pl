#! /usr/bin/perl

# Usage: cat some_file.csv | blink_getter output_filename.csv lostgis.csv
# The input file should be a comma delimited file with two columns: a label,
# and a gi. 

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
