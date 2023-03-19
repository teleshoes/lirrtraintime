#!/usr/bin/perl
use strict;
use warnings;

my $USAGE = "Usage:
  $0 TOP_TEXT BOTTOM_TEXT OUTPUT_FILENAME
    generate an 80x80 icon with imagemagick,
      consisting of a red circle with two lines of white text
    write image to OUTPUT_FILENAME
";

sub main(@){
  die $USAGE if @_ != 3;
  my ($top, $bot, $file) = @_;

  my $maxLen = length $top > length $bot ? length $top : length $bot;

  my $typeface = "Inconsolata";
  my $fontPt = 30;
  my $textTopX = 35 - (6 * length $top);
  my $textTopY = 2*$maxLen + $fontPt;
  my $textBotX = 35 - (6 * length $bot);
  my $textBotY = 2*$maxLen + $fontPt*2 - 4;

  system "convert",
    "-size", "80x80",
    "xc:black",
    "-transparent", "black",

    "-fill", "red",
    "-stroke", "darkred",
    "-strokewidth", 2,
    "-draw", "circle 40,40 40,78",

    "-fill", "white",
    "-strokewidth", "1",
    "-stroke", "white",
    "-font", $typeface,
    "-pointsize", $fontPt,
    "-draw", "text $textTopX,$textTopY $top",
    "-draw", "text $textBotX,$textBotY $bot",
    "-strip",

    $file,
  ;
}

&main(@ARGV);
