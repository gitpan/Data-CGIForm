#
# $Id: Makefile.PL,v 1.4 2002/11/27 05:54:42 ctriv Exp $
#
use ExtUtils::MakeMaker;

eval { require 5.006 };

die <<AMEN if $@;

Data::CGIForm requires 5.6.0.  5.6.1 is probably best.

AMEN

WriteMakefile(
	NAME		  => 'Data::CGIForm',
	VERSION_FROM  => 'CGIForm.pm',
	PREREQ_PM	  => {
		Test::More => 0,
	},	
	ABSTRACT_FROM => 'CGIForm.pm',
	AUTHOR        => 'Chris Reinhardt <ctriv@dyndns.org>',
);
