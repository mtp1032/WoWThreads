#!/usr/bin/perl
use strict;
use warnings;

# Set locale settings to avoid warnings
$ENV{'LANG'} = 'en_US.UTF-8';
$ENV{'LC_ALL'} = 'en_US.UTF-8';

# Check if the input file is provided
die "Usage: $0 <path_to_lua_file>\n" if @ARGV < 1;

my $file = $ARGV[0];

open(my $fh, '<', $file) or die "Cannot open file $file: $!\n";

my $in_comment_block = 0;

while (my $line = <$fh>) {
    chomp $line;

    if ($line =~ /^--- \@brief (.*)/) {
        print "/** \\brief $1\n";
        $in_comment_block = 1;
    }
    elsif ($line =~ /^--- \@(.*)/) {
        print "/** \@$1\n";
        $in_comment_block = 1;
    }
    elsif ($line =~ /^-- \@param\s+(\w+)\s+\(([^)]+)\)\s+(.*)$/) {
        my ($param_name, $type, $description) = ($1, $2, $3);
        print " * \\param $type $param_name $description\n";
    }
    elsif ($line =~ /^-- \@return (.*)/) {
        print " * \\return $1\n";
    }
    elsif ($line =~ /^---/) {
        if (!$in_comment_block) {
            print " * \n";
            $in_comment_block = 1; # Start a new comment block if not already inside one
        }
    }
    elsif ($line =~ /^function/ && $in_comment_block) {
        print " */\n$line\n";  # Corrected comment block closure
        $in_comment_block = 0; # Close the comment block before a function
    }
    else {
        print "$line\n" unless $in_comment_block;  # Potentially adjust based on whether you want these lines printed within the comment block
    }
}

close($fh);
close($log);  # Ensure the log file is properly closed after writing
