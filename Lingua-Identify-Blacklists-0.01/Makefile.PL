use inc::Module::Install;

name          'Lingua::Identify::Blacklists';
all_from      'lib/Lingua/Identify/Blacklists.pm';

install_script 'bin/blacklist_classifier';
install_share;

# requires 'Getopt::Std'     => 0;
# requires 'FindBin'     => 0;

WriteAll;
