#!/usr/bin/env perl

use strict;
use warnings;

use File::Find;
use File::Spec;
use Getopt::Long;
use TAP::Harness;

my $opts = {
  clean => 0,
  help => 0,
  verbose => 0
};
my @args = ('clean|clear|c', 'help|h', 'verbose|v', 'list|tests|list-tests|l');

my $parse = GetOptions($opts, @args);
if(!$parse) {
  print STDERR "Could not parse the given arguments. Please consult the help\n";
  usage();
  exit 1;
} 

# If we were not given a directory as an argument, assume current directory
push(@ARGV, File::Spec->curdir()) if ! @ARGV;

# Print usage on '-h' command line option
if ($opts->{help}) {
  usage();
  exit;
}

# Get the tests
my $input_files_directories = [@ARGV];
my @tests = eval {
  get_all_tests($input_files_directories);
};
if($@) {
  printf(STDERR "Could not continue processing due to error: %s\n", $@);
  exit 1;
}

#Tests without cleans
my @no_clean_tests = grep { $_ !~ /CLEAN\.t$/ } @tests;

# List test files on '-l' command line option
if ($opts->{list}) {
  print "$_\n" for @no_clean_tests;
  exit;
}

# Make sure proper cleanup is done if the user interrupts the tests
$SIG{'HUP'} = $SIG{'KILL'} = $SIG{'INT'} = sub { 
  warn "\n\nINTERRUPT SIGNAL RECEIVED\n\n"; 
  clean(); 
  exit 
};

# Harness
my $harness = TAP::Harness->new({verbosity => $opts->{verbose}});

# Set environment variables
$ENV{'RUNTESTS_HARNESS'} = 1;

# Run all specified tests
eval {
  $harness->runtests(@no_clean_tests);
};

clean($input_files_directories);


sub usage {
    print <<EOT;
Usage:
\t$0 [-c] [-v] [<test files or directories> ...]
\t$0 -l        [<test files or directories> ...]
\t$0 -h

\t-l|--list|--tests|--list-tests\n\t\tlist available tests
\t-c|--clean|--clear\n\t\trun tests and clean up in each directory
\t\tvisited (default is not to clean up)
\t-v|--verbose\n\t\tbe verbose
\t-h|--help\n\t\tdisplay this help text

If no directory or test file is given on the command line, the script
will assume the current directory.
EOT
}

=head2 get_all_tests

  Arg [21]    :(optional) listref $input_files_or_directories
               testfiles or directories to retrieve. If not specified all 
               "./" directory is the default.
  Example    : @test_files = read_test_dir('t');
  Description: Returns a list of testfiles in the directories specified by
               the @tests argument.  The relative path is given as well as
               with the testnames returned.  Only files ending with .t are
               returned.  Subdirectories are recursively entered and the test
               files returned within them are returned as well.
  Returntype : listref of strings.
  Exceptions : none
  Caller     : general

=cut

sub get_all_tests {
  my ($input_files_directories) = @_;

  my @files;
  my @out;

  #If we had files use them
  if ( $input_files_directories && @{$input_files_directories} ) {
    @files = @{$input_files_directories};
  }
  #Otherwise use current directory
  else {
    push(@files, File::Spec->curdir());
  }

  my $is_test = sub {
    my ($suspect_file) = @_;
    return 0 unless $suspect_file =~ /\.t$/;
    if(! -f $suspect_file) {
      warn "Cannot find file '$suspect_file'";
    }
    elsif(! -r $suspect_file) {
      warn "Cannot read file '$suspect_file'";
    }
    return 1;
  };

  while (my $file = shift @files) {
    #If it was a directory use it as a point to search from
    if(-d $file) {
      my $dir = $file;
      #find cd's to the dir in question so use relative for tests
      find(sub {
        if( $_ ne '.' && $_ ne '..' && $_ ne 'CVS') {
          if($is_test->($_)) {
            push(@out, $File::Find::name);
          }
        } 
      }, $dir);
    }
    #Otherwise add it if it was a test
    else {
      push(@files, $file) if $is_test->($file);
    }
  }

  return @out;
}

sub clean {
  my ($input_files_directories) = @_;
  
  # Unset environment variable indicating final cleanup should be
  # performed
  delete $ENV{'RUNTESTS_HARNESS'};
  if($opts->{clean}) {
    my @clean_tests = grep { $_ =~ /CLEAN\.t$/ } @tests;
    eval { $harness->runtests(@clean_tests) };
  }
  return;
}
