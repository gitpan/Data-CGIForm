#
# $Id: Makefile.PL,v 1.5 2006/03/07 18:33:22 twilde Exp $
#
use ExtUtils::MakeMaker;

eval { require 5.006 };

die <<AMEN if $@;

Data::CGIForm requires 5.6.0.  5.6.1 or higher is probably best.

AMEN

WriteMakefile(
	NAME		  => 'Data::CGIForm',
	VERSION_FROM  => 'CGIForm.pm',
	PREREQ_PM	  => {
		Test::More => 0,
	},	
	ABSTRACT_FROM => 'CGIForm.pm',
	AUTHOR        => 'Tim Wilde <twilde@dyndns.com>',
);
