#-*-perl-*-

package Lingua::Identify::Blacklists;

use 5.008;
use strict;
use warnings;

use File::ShareDir 'dist_dir';

use Exporter 'import';
our @EXPORT = qw( identify identify_file identify_stdin );
our %EXPORT_TAGS = ( all => \@EXPORT );

=encoding UTF-8

=head1 NAME

Lingua::Identify::Blacklists - Language identification for related languages based on blacklists

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';
our $VERBOSE = 0;


our $BLACKLISTDIR;
eval{ $BLACKLISTDIR = &dist_dir('Lingua-Identify-Blacklists') . '/blacklists' };

our $LOWERCASE = 1;
our $TOKENIZE = 1;
our $ALPHA_ONLY = 1;

my %blacklists = ();



sub identify{
  my $text = shift;
  my %options = @_;

  my %dic = ();
  my $total = 0;

  &process_string( $text, \%dic, $total );
  return &classify( \%dic, %options );
}


sub identify_stdin{
    return identify_file( undef, @_ );
}


sub identify_file{
    my $file = shift;
    my %options = @_;
    
    my %dic = ();
    my $total = 0;
    my @predictions = ();
    
    my $fh = *STDIN;
    if (defined $file){
	open $fh,"<$file" || die "cannot read from '$file'\n";
	binmode($fh,":encoding(UTF-8)");
    }
    
    while (<$fh>){
	chomp;
	&process_string($_,\%dic,$total);
	if ($options{every_line}){                        # classify every line separately
            push( @predictions, &classify( \%dic, %options ) );
            %dic=();
	}
	elsif ($options{text_size}){                     # use only a certain number of words
	    if ($total > $options{text_size}){
		print STDERR "use $total tokens for classification\n" if ($VERBOSE);
		last;
	    }
	}
    }
    unless ($options{every_line}){
	push( @predictions, &classify( \%dic, %options ) );
    }
    return @predictions;
}












sub classify{
    my $dic         = shift;
    my %options     = @_;
    $options{langs} = '' unless ($options{langs});

    my @langs = ref($options{langs}) eq 'ARRAY' ? 
	@{$options{langs}} : split( /\s+/, $options{langs} ) ;

    @langs = available_languages() unless (@langs);

    return &classify_with_margin( $dic, $options{use_margin}, @langs ) 
	if ($options{use_margin});
    return &classify_cascaded( $dic, @langs );
}




sub available_languages{
    unless (keys %blacklists){
	&load_all_blacklists( $BLACKLISTDIR );
    }
    my %langs = ();
    foreach (keys %blacklists){
	my ($lang1,$lang2) = split(/\-/);
	$langs{$lang1}=1;
	$langs{$lang2}=1;
    }
    return keys %langs;
}



sub classify_cascaded{
    my $dic = shift;
    my @langs = @_;

    my $lang1 = shift(@langs);
    foreach my $lang2 (@langs){

        # load blacklists on demand
        unless (exists $blacklists{"$lang1-$lang2"}){
            $blacklists{"$lang1-$lang2"}={};
            &load_blacklist($blacklists{"$lang1-$lang2"},
                            $BLACKLISTDIR,$lang1,$lang2);
        }
        my $list = $blacklists{"$lang1-$lang2"};

        my $score = 0;
	foreach my $w (keys %{$dic}){
	    if (exists $$list{$w}){
                $score += $$dic{$w} * $$list{$w};
                print STDERR "$$dic{$w} x $w found ($$list{$w})\n" if ($VERBOSE);
            }
        }
        if ($score < 0){
            $lang1 = $lang2;
        }
        print STDERR "select $lang1 ($score)\n" if ($VERBOSE);
    }
    return $lang1;
}


# OTHER WAY OF CLASSIFYING
# test all against all ...

sub classify_with_margin{
    my $dic = shift;
    my $margin = shift;
    my @langs = @_;

    my %selected = ();
    while (@langs){
        my $lang1 = shift(@langs);
        foreach my $lang2 (@langs){

            # load blacklists on demand
            unless (exists $blacklists{"$lang1-$lang2"}){
                $blacklists{"$lang1-$lang2"}={};
                &load_blacklist($blacklists{"$lang1-$lang2"},
                                $BLACKLISTDIR,$lang1,$lang2);
            }
            my $list = $blacklists{"$lang1-$lang2"};

            my $score = 0;
            foreach my $w (keys %{$dic}){
                if (exists $$list{$w}){
                    $score += $$dic{$w} * $$list{$w};
                    print STDERR "$$dic{$w} x $w found ($$list{$w})\n" 
                        if ($VERBOSE);
                }
            }
            next if (abs($score) < $margin);
            if ($score < 0){
                # $selected{$lang2}-=$score;
                $selected{$lang2}++;
                print STDERR "select $lang2 ($score)\n" if ($VERBOSE);
            }
            else{
                # $selected{$lang1}+=$score;
                $selected{$lang1}++;
                print STDERR "select $lang1 ($score)\n" if ($VERBOSE);
            }
        }
    }
    my ($best) = sort { $selected{$b} <=> $selected{$a} } keys %selected;
    return $best;
}




sub load_all_blacklists{
    my $dir = shift;

    opendir(my $dh, $dir) || die "cannot read directory '$dir'\n";
    while(readdir $dh) {
	if (/^(.*)-(.*).txt$/){
	    $blacklists{"$1-$2"}={};
	    &load_blacklist($blacklists{"$1-$2"}, $dir, $1, $2);
	}
    }
    closedir $dh;
}


sub load_blacklist{
    my ($list,$dir,$lang1,$lang2) = @_;

    my $inverse = 0;
    if (! -e "$dir/$lang1-$lang2.txt"){
	($lang1,$lang2) = ($lang2,$lang1);
        $inverse = 1;
    }

    open F,"<:encoding(UTF-8)","$dir/$lang1-$lang2.txt" || die "...";
    while (<F>){
	chomp;
	my ($score,$word) = split(/\t/);
        $$list{$word} = $inverse ? 0-$score : $score;
    }
    close F;
}






sub read_file{
    my ($file,$dic,$max)=@_;
    my $total = 0;
    if ($file=~/\.gz$/){
	open F,"gzip -cd < $file |" || die "...";
	binmode(F,":encoding(UTF-8)");
    }
    else{
	open F,"<:encoding(UTF-8)",$file || die "...";
    }
    while (<F>){
	chomp;
        &process_string($_,$dic,$total);
        if ($max){
            if ($total > $max){
                print STDERR "read $total tokens from $file\n";
                last;
            }
        }
    }
    close F;
    return $total;
}




# process_string($string,\%dic,\$wordcount)

sub process_string{
    $_[0]=lc($_[0]) if ($LOWERCASE);
    $_[0]=~s/((\A|\s)\P{IsAlpha}+|\P{IsAlpha}+(\s|\Z))/ /gs if ($TOKENIZE);

    my @words = $ALPHA_ONLY ? 
        grep(/^\p{IsAlpha}/,split(/\s+/,$_[0])) :
        split(/\s+/,$_[0]);

    foreach my $w (@words){${$_[1]}{$w}++;$_[2]++;}
}


1;


__END__


=head1 AUTHOR

Jörg Tiedemann, L<https://bitbucket.org/tiedemann>

=head1 BUGS

Please report any bugs or feature requests to
L<https://bitbucket.org/tiedemann/blacklist-classifier>.  I will be notified,
and then you'll automatically be notified of progress on your bug as I
make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Lingua::Identify::Blacklists

=head1 LICENSE AND COPYRIGHT

   Copyright 2012 Jörg Tiedemann.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU Lesser General Public License as published
   by the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
   GNU Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
