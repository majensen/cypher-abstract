use Test::More;
use lib '..';

use t::SimpleTree;

my $p = t::SimpleTree->new();

my $expr = $p->parse( 'a + b + exp(c) and ( ( m <> ln(2) ) or ( max(l,m,q) ) )' );

done_testing;
