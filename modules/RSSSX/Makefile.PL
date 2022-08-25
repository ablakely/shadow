use 5.008005;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'Shadow::RSS::RSSSX',
	VERSION_FROM => 'lib/XS/RSS.pm',
	CONFIGURE_REQUIRES => { 'ExtUtils::MakeMaker' => '7.12' },
	ABSTRACT_FROM => 'lib/XS/RSS.pm',
	AUTHOR => 'Aaron Blakely',
	CCFLAGS => '-Wall -std=c99',
	OPTIMIZE => '-O3',
	LICENSE => 'mit',
	XSMULTI => 1,
);
