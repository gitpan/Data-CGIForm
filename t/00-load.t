# $Id: 00-load.t,v 1.2 2002/11/10 12:19:26 ctriv Exp $


use Test::More tests => 2;
use strict;

BEGIN { 
    use_ok('Data::CGIForm'); 
    use_ok('t::FakeRequest');
}
