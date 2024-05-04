#!/usr/bin/perl
use strict;
use warnings;
use POSIX qw(locale_h);

# Set locale settings to avoid warnings and ensure consistent behavior
setlocale(LC_ALL, "en_US.UTF-8");

# Check if the input file is provided
die "Usage: $0 <path_to_lua_file>\n" if @ARGV < 1;

my $file = $ARGV[0];
my $output_file = "converted_comments.txt";  # Define the output file name

open(my $fh, '<', $file) or die "Cannot open file $file: $!\n";
open(my $log_fh, '>', $output_file) or die "Cannot open output file $output_file: $!\n";

my $in_comment_block = 0;

sub print_both {
    my $text = shift;
    print $log_fh $text;  # Print to the log file
    print $text;          # Print to standard output
}

while (my $line = <$fh>) {
    chomp $line;

    if ($line =~ /^--- \@brief (.*)/) {
        print_both("/** \\brief $1\n");
        $in_comment_block = 1;
    }
    elsif ($line =~ /^--- \@(.*)/) {
        print_both("/** \@$1\n");
        $in_comment_block = 1;
    }
    elsif ($line =~ /^-- \@param\s+(\w+)\s+\(([^)]+)\)\s+(.*)$/) {
        my ($param_name, $type, $description) = ($1, $2, $3);
        print_both(" * \\param $type $param_name $description\n");
    }
    elsif ($line =~ /^-- \@return (.*)/) {
        print_both(" * \\return $1\n");
    }
    elsif ($line =~ /^---/) {
        if (!$in_comment_block) {
            print_both(" * \n");
            $in_comment_block = 1; # Start a new comment block if not already inside one
        }
    }
    elsif ($line =~ /^function/ && $in_comment_block) {
        print_both(" */\n$line\n");  # Close the comment block before a function
        $in_comment_block = 0; # Close the comment block
    }
    else {
        print_both("$line\n") unless $in_comment_block;  # Print non-comment lines outside of comment blocks
    }
}

close($fh);
close($log_fh);
