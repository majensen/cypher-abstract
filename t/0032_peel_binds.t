use Test::More;
use lib '../lib';
use lib 't';
use lib '..';
use Neo4j::Cypher::Abstract::Peeler;
use Tie::IxHash;
use v5.10;
use Try::Tiny;
use t::SimpleTree;
use strict;


my $o = Neo4j::Cypher::Abstract::Peeler->new();

my $p = t::SimpleTree->new;
my $q = t::SimpleTree->new;

my @handle_tests = (
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


for my $t (@handle_tests) {
  my ($got_can, $got_peel);
  my $stmt = $t->{stmt};
  if ($t->{skip}) {
    diag "skipping ($$t{stmt})";
    next;
  }
  $stmt =~ s{\?}{/[0-9]+/ ? "$_" : "'$_'"}e for @{$t->{bind}};
  if (!$t->{todo}) {
    try {
      ok $got_can = $o->canonize($t->{where}), 'canonize passed';
      ok $got_peel = $o->peel($got_can), 'peeled';
      1;
    } catch {
      say "bad peel: $_";
      fail;
      1;
    };
  }
  else {
  TODO: {
      local $TODO = $t->{todo};
	try {
	  ok $got_can = $o->canonize($t->{where}), 'canonize passed';
	  ok $got_peel = $o->peel($got_can), 'peeled';
	  1;
	} catch {
	  say "bad peel: $_";
	  fail;
	  1;
	};
    }
  }
  if ($got_peel) {
    try {
      $p->parse($stmt);
      $q->parse($got_peel);
      diag $stmt;
      diag $got_peel;
      $DB::single=1;
      if ($p == $q) {
	pass "equivalent";
      }
      else {
	fail "not equivalent";
	diag $stmt;
	diag $got_peel;
      }
    } catch {
      diag "Error in t::SimpleTree";
      diag "on $stmt";
      diag "could not completely reduce expression" if /Could not completely reduce/;
    };
    say;
  }
}

done_testing;


