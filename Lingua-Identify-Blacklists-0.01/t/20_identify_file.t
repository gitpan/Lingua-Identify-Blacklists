#!/usr/bin/env perl
#-*-perl-*-

use Test::More;
use utf8;

use FindBin qw/$Bin/;
use lib "$Bin/..";

use Lingua::Identify::Blacklists ':all';

my %files = ( bs => "$Bin/data/eval/dnevniavaz.ba.200.check",
	      hr => "$Bin/data/eval/vecernji.hr.200.check",
	      sr => "$Bin/data/eval/politika.rs.200.check" );

foreach my $lang (keys %files){
    is( identify_file($files{$lang}), $lang) ;
    is (my @pred = identify_file($files{$lang}, every_line => 1), 200);
}

done_testing;
