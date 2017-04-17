use Test::More;
use Tie::IxHash;
use v5.10;
use Try::Tiny;
use lib '../lib';
use lib 't';
use lib '..';
use strict;

# $Carp::Verbose=1;
use_ok('Neo4j::Cypher::Abstract::Peeler');
my $o = Neo4j::Cypher::Abstract::Peeler->new();

# some examples from SQL::Abstract t/02where.t
# changes: strict dashed form for operators

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
        todo => "This is a kludge, won't fix",
        where => {
            priority  => [ {'>', 3}, {'<', 1} ],
            requestor => \'is not null',
        },
        stmt => " ( ( ( priority > ? ) OR ( priority < ? ) ) AND requestor is not null )",
        bind => [qw/3 1/],
    },
    {
        todo => "or with undef",
        where => {
	  requestor => { '<>', [undef, ''] }
        },
        stmt => "( requestor IS NOT NULL OR requestor <> ? )",
        bind => [''],
      },
    {
        todo => "and with undef",
        where => {
	  requestor => [ -and => '<>' => undef, '<>' => '']
	 },
        stmt => "( requestor IS NOT NULL AND requestor <> ? )",
        bind => [''],
    },
    {
        todo => "original not valid for Peeler",
        where => 
#	  requestor => { '<>', ['-and', undef, ''] },
	  [ -and => {requestor => {'<>' => undef}}, {requestor => {'<>' => ''}}]
        ,
        stmt => "( requestor IS NOT NULL AND requestor <> ? )",
        bind => [''],
    },

    {
        where => {
            priority  => [ {'>', 3}, {'<', 1} ],
            requestor => { '<>', undef },
        },
        stmt => "( ( ( priority > ? ) OR ( priority < ? ) ) AND requestor IS NOT NULL )",
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
        todo => 'manage literal + binds',
        where => {
            foo => \["IN (?, ?)", 22, 33],
            bar => [-and =>  \["> ?", 44], \["< ?", 55] ],
        },
        stmt => "( (bar > ? AND bar < ?) AND foo IN (?, ?) )",
        bind => [44, 55, 22, 33],
    },

  {
     done =>  'this works, but requires hashes in the implicit or array',
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
       todo => 'this is a weird one',
       where => { -and => [{}, { 'me.id' => '1'}] },
       stmt => "( ( me.id = ? ) )",
       bind => [ 1 ],
   },

  {
    todo => 'manage literal + bind',
       where => [ \[ 'foo = ?','bar' ] ],
       stmt => "(foo = ?)",
       bind => [ "bar" ],
   },

  {
       done => "NOT should work",
       where => { -not => { -not => { -not => 'bool2' } } },
       stmt => "( NOT ( NOT ( NOT bool2 ) ) )",
       bind => [],
   },

# Tests for -not
# Basic tests only
  {
           done => "NOT should work",
        where => { -not => { a => 1 } },
        stmt  => "( (NOT a = ?) ) ",
        bind => [ 1 ],
    },
  {
           todo => "NOT should work: fix 'mix of ops and nonops'",
        where => { a => 1, -not => { b => 2 } },
        stmt  => "( ( (NOT b = ?) AND a = ? ) ) ",
        bind => [ 2, 1 ],
    },
  {
        done  => "NOT should work",
        where => { -not => { a => 1, b => 2, c => 3 } },
        stmt  => "( (NOT ( a = ? AND b = ? AND c = ? )) ) ",
        bind => [ 1, 2, 3 ],
    },
  {
           todo => "NOT should work: fix implicit -or",
        where => { -not => [ a => 1, b => 2, c => 3 ] },
        stmt  => "( (NOT ( a = ? OR b = ? OR c = ? )) ) ",
        bind => [ 1, 2, 3 ],
    },
  {
           todo => "NOT should work: fix 'mix of ops and nonops'",
        where => { -not => { c => 3, -not => { b => 2, -not => { a => 1 } } } },
        stmt  => "( (NOT ( (NOT ( (NOT a = ?) AND b = ? )) AND c = ? )) ) ",
        bind => [ 1, 2, 3 ],
    },
);

$DB::single = 1;

for my $t (@handle_tests) {
  my ($got_can, $got_peel);
  my $stmt = $t->{stmt};
  $stmt =~ s/\?/$_/ for @{$t->{bind}};
  diag $stmt;
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
    say $got_peel;
    say;
  }
}

done_testing;

sub sort_test {
  my $x = shift;
  my $do;
  $do = sub {
    for (ref $_[0]) {
      ($_ eq 'HASH') && do {
	tie my %t, "Tie::IxHash";
	for my $k (sort keys %{$_[0]}) {
	  $t{$k} = $do->(${$_[0]}{$k});
	}
	return \%t;
      };
      ($_ eq 'ARRAY') && do {
	return [ map { $do->($_) } @{$_[0]} ];
      };
      return $_[0];
    }
  };
  $do->($x);
}
