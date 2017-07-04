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
        todo => 'manage literal + binds',
        where => {
            foo => \["IN (?, ?)", 22, 33],
            bar => [-and =>  \["> ?", 44], \["< ?", 55] ],
        },
        stmt => "( (bar > ? AND bar < ?) AND foo IN (?, ?) )",
        bind => [44, 55, 22, 33],
    },
  {
    todo => 'manage literal + bind',
       where => [ \[ 'foo = ?','bar' ] ],
       stmt => "(foo = ?)",
       bind => [ "bar" ],
   },

);

test_peeler(@tests);

done_testing;


