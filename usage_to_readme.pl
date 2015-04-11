#!/usr/bin/perl
use strict;
use warnings;

sub main(@){
  my $readme = `cat README`;
  $readme =~ s/\nUsage:\n.*//sg;
  my $usage = `export HOME="~"; email.pl -h 2>&1`;
  open FH, "> README";
  print FH "$readme\nUsage:\n$usage";
  close FH;
}

&main(@ARGV);
