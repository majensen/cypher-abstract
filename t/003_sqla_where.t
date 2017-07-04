use Test::More;
use Tie::IxHash;
use v5.10;
use Try::Tiny;
use lib '../lib';
use lib 't';
use lib '..';
use t::SimpleTree;
use strict;

# $Carp::Verbose=1;
use_ok('Neo4j::Cypher::Abstract::Peeler');
my $o = Neo4j::Cypher::Abstract::Peeler->new();

# some examples from SQL::Abstract t/02where.t
# changes: strict dashed form for operators
my $p = t::SimpleTree->new;
my $q = t::SimpleTree->new;

my @handle_tests = (
    {
        where => {
            requestor => 'inna',
            worker => ['nwiger', 'rcwe', 'sfz'],
            status => { '<>', 'completed' }
        },
        stmt => "( requestor = ? AND status <> ? AND ( ( worker = ? ) OR"
              . " ( worker = ? ) OR ( worker = ? ) ) )",
        bind => [qw/inna completed nwiger rcwe sfz/],
    },

    {
        where  => [
            status => 'completed',
            user   => 'nwiger',
        ],
        stmt => "( status = ? OR user = ? )",
        bind => [qw/completed nwiger/],
    },

    {
        where  => {
            user   => 'nwiger',
            status => 'completed'
        },
        stmt => "( status = ? AND user = ? )",
        bind => [qw/completed nwiger/],
    },

    {
        where  => {
            user   => 'nwiger',
            status => { '<>', 'completed' }
        },
        stmt => "( status <> ? AND user = ? )",
        bind => [qw/completed nwiger/],
    },

    {
        where  => {
            status   => 'completed',
            reportid => { -in => [567, 2335, 2] }
        },
        stmt => "( reportid IN ( ?, ?, ? ) AND status = ? )",
        bind => [qw/567 2335 2 completed/],
    },

    {
        where => [
            {
                user   => 'nwiger',
                status => { -in => ['pending', 'dispatched'] },
            },
            {
                user   => 'robot',
                status => 'unassigned',
            },
        ],
        stmt => "( ( status IN ( ?, ? ) AND user = ? ) OR ( status = ? AND user = ? ) )",
        bind => [qw/pending dispatched nwiger unassigned robot/],
    },

    {
        skip => "This is a kludge, won't fix",
        where => {
            priority  => [ {'>', 3}, {'<', 1} ],
            requestor => \'is not null',
        },
        stmt => " ( ( ( priority > ? ) OR ( priority < ? ) ) AND requestor is not null )",
        bind => [qw/3 1/],
    },
    {
      done => "or with undef",
      no_tree => 1,
        where => {
	  requestor => { '<>', [undef, ''] }
        },
        stmt => "(requestor IS NOT NULL OR (requestor <> ?))",
        bind => [''],
      },
    {
      done => "and with undef",
      no_tree => 1,
        where => {
	  requestor => [ -and => '<>' => undef, '<>' => '']
	 },
        stmt => "(requestor IS NOT NULL AND (requestor <> ?))",
        bind => [''],
    },
    {
      skip => "fix later maybe",
      no_tree => 1,
        where => 
	  { requestor => { '<>', ['-and', undef, ''] } },
        stmt => "(requestor IS NOT NULL AND (requestor <> ?))",
        bind => [''],
    },

    {
      no_tree => 1,
        where => {
            priority  => [ {'>', 3}, {'<', 1} ],
            requestor => { '<>', undef },
        },
      stmt => "(((priority > ?) OR (priority < ?)) AND requestor IS NOT NULL)",
      stmt2 => "(requestor IS NOT NULL AND ((priority > 3) OR (priority < 1)))",
        bind => [qw/3 1/],
    },

    {
        where => {
          id  => 1,
          num => {
           '<=' => 20,
           '>'  => 10,
          },
        },
        stmt => "( id = ? AND ( num <= ? AND num > ? ) )",
        bind => [qw/1 20 10/],
    },


  {
     done =>  'this works, but requires hashes in the implicit OR array',
        where => {
          -and => [
            user => 'nwiger',
            [
              {-and => [ workhrs => {'>', 20}, geo => 'ASIA' ]},
              {-or => { workhrs => {'<', 50}, geo => 'EURO' }},
            ],
          ],
        },
        stmt => "( user = ? AND (
               ( workhrs > ? AND geo = ? )
            OR ( geo = ? OR workhrs < ? )
          ) )",
        bind => [qw/nwiger 20 ASIA EURO 50/],
    },

  {
       done => 'this is a weird one',
       where => { -and => [{}, { 'me.id' => '1'}] },
       stmt => "( ( me.id = ? ) )",
       bind => [ 1 ],
   },

  {
       where => { -not => { -not => { -not => 'bool2' } } },
       stmt => "( NOT ( NOT ( NOT 'bool2' ) ) )",
       bind => [],
   },

# Tests for -not
# Basic tests only
  {
        where => { -not => { a => 1 } },
        stmt  => "( (NOT a = ?) ) ",
        bind => [ 1 ],
    },
  {
        where => { a => 1, -not => { b => 2 } },
        stmt  => "( ( (NOT b = ?) AND a = ? ) ) ",
        bind => [ 2, 1 ],
    },
  {
        where => { -not => { a => 1, b => 2, c => 3 } },
        stmt  => "( (NOT ( a = ? AND b = ? AND c = ? )) ) ",
        bind => [ 1, 2, 3 ],
    },
  {
        where => { -not => [ a => 1, b => 2, c => 3 ] },
        stmt  => "( (NOT ( a = ? OR b = ? OR c = ? )) ) ",
        bind => [ 1, 2, 3 ],
    },
  {
        where => { -not => { c => 3, -not => { b => 2, -not => { a => 1 } } } },
        stmt  => "( (NOT ( (NOT ( (NOT a = ?) AND b = ? )) AND c = ? )) ) ",
        bind => [ 1, 2, 3 ],
	 },
);


for my $t (@handle_tests) {
  my ($got_can, $got_peel);
  my $stmt = $t->{stmt};
  if ($t->{skip}) {
    diag "skipping ($$t{stmt}) : $$t{skip}";
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
    if ($t->{no_tree}) {
      if ($t->{stmt2}) {
	if ($got_peel eq $stmt or $got_peel eq $t->{stmt2}) {
	  pass "equivalent";
	}
	else {
	  fail "not equivalent";
	}
      }
      else {
	is $got_peel, $stmt, "equivalent";
      }
    }
    else {
      try {
	$p->parse($stmt);
	$q->parse($got_peel);
	if ($p == $q) {
	  pass "equivalent";
	}
	else {
	  fail "not equivalent";
	  diag $stmt;
	  diag $got_peel;
	}
      } catch {
	fail "Error in t::SimpleTree";
	diag "on $stmt";
	diag "could not completely reduce expression" if /Could not completely reduce/;
      };
    }
  }
  say;
}

done_testing;


