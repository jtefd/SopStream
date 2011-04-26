use 5.010001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'SopStream',
    VERSION_FROM      => 'sopstream.pl',
    PREREQ_PM         => { 'Getopt::Long', 'HTML::TreeBuilder', 'IO::Socket', 'LWP::UserAgent', 'Pod::Usage', 'Sys::Hostname' },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       => 'Wrapper utility around SopCast P2P video streaming application',
       AUTHOR         => 'James Telford <james@tefd.co.uk>') : ()),
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
    EXE_FILES         => ['sopstream.pl'],
);
