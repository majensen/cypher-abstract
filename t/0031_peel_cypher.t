use Test::More;
use lib '../lib';
use lib 't';
use lib '..';
use Tie::IxHash;
use v5.10;
use Try::Tiny;
use t::PeelerTest;
use strict;

our $peeler;
isa_ok $peeler, 'Neo4j::Cypher::Abstract::Peeler';
my @tests = (
  {
    todo => 'cypher predicate',
    where =>  { -all => ['x', [1,2,3], {'x' => 3}] },
    stmt => 'all( x IN [1,2,3] WHERE x = 3 )',
  },
  
);

test_peeler(@tests);

done_testing;


