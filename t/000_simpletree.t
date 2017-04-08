use Test::More;
use lib '..';

use t::SimpleTree;

my $p = t::SimpleTree->new();
my $q = t::SimpleTree->new();
my $r = t::SimpleTree->new();

my $expr1 = $p->parse( 'a + b + exp(c) and ( ( m <> ln(2) ) or ( max(l,m,q) ) )' );
my $expr2 = $q->parse( '(((a + b + exp(c) and ( (( m <> ln(2)) ) or ( max(l,m,q) ) ))))' );
my $expr3 = $r->parse( '(((exp(c) + a + b and ( (( m <> ln(2)) ) or ( max(l,m,q) ) ))))' );

is_deeply $expr1, $expr2;

my $expr2 = $q->parse( '(((b + a + exp(c) and ( ( max(l,m,q) ) or (( m <> ln(2)) )  ))))' );

is $p->hash, $q->hash;
is $p->hash, $r->hash;

done_testing;
