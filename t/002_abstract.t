use Test::More;
use Tie::IxHash;
use lib '../lib';


use_ok('Neo4j::Cypher::Abstract::Peeler');

is Neo4j::Cypher::Abstract::Peeler::infix_binary("+", [1, 2]), "1 + 2";
is Neo4j::Cypher::Abstract::Peeler::infix_distributable("-and", [1, 2,"fred","bob"]), "1 AND 2 AND fred AND bob";
is Neo4j::Cypher::Abstract::Peeler::prefix("-not", ['a.name']), "NOT a.name";
is Neo4j::Cypher::Abstract::Peeler::postfix("-is_not_null", ['a.name']), "a.name IS NOT NULL";
is Neo4j::Cypher::Abstract::Peeler::function("-sin", [1.5]), "sin(1.5)";
is Neo4j::Cypher::Abstract::Peeler::function("-coalesce", [1.5, 'mabel','dood']), "coalesce(1.5,mabel,dood)";

my $o = Neo4j::Cypher::Abstract::Peeler->new();

my @test_pairs = (
  [ 'canonical - no change',
    [ -or => [ '=' => [ -sin => 1.5 ], .005 ], [ '<>' => 5, 4 ]],
    [ -or => [ '=' => [ -sin => 1.5 ], .005 ], [ '<>' => 5, 4 ]] ],
  [ 'simple function',
    { -radians => 1 },
    [ -radians => 1 ] ],
  [ 'simple infix (comparison)',
    { 5 => { "<>" => 4 } },
    [ "<>" => 5, 4 ] ],
  [ 'is null',
    { status => undef },
    [ -is_null => 'status'] ],
  [ 'is not null',
    { status => { '<>' => undef } },
    [ -is_not_null => 'status' ] ],
  [ '-and over comparsions (hash form)',
    { 5 => { "<=" => 6, "<>" => 4 } },
    [ -and => [ "<=" => 5, 6 ], ["<>" => 5, 4] ] ],
  [ '-and over comparsions, nested function',
    { 12 => { "<=" => { -haversin => 90 }, ">=" => 10 } },
    [ -and => [ "<=" => 12, [ -haversin => 90 ] ],[ ">=" => 12, 10 ] ] ],
  [ 'implicit equality over array (-or)',
    { zzyxx => [ 'narf', 'boog', 'frelb' ] },
    [ -or => ['=' => 'zzyxx', 'narf'],['=' => 'zzyxx', 'boog'],['=' => 'zzyxx', 'frelb'] ] ],
  [ 'implicit equality over array with null (-or)',
    { zzyxx => [ 'narf', 'boog', undef, 'frelb' ] },
    [ -or => ['=' => 'zzyxx', 'narf'],['=' => 'zzyxx', 'boog'], [ -is_null => 'zzyxx'], ['=' => 'zzyxx', 'frelb'] ] ],  
  [ 'implicit equality over hash (-and)',
    { al => 'king', 'eddie' => 'prince', vicky => 'queen' },
    [ -and => ['=' => 'al', 'king'], ['=' => 'eddie', 'prince' ], [ '=' => 'vicky', 'queen'] ] ],
  [ 'implicit equality over hash with null (-and)',
    { al => 'king', 'eddie' => 'prince', vicky => 'queen', 'xandor' => undef },
    [ -and => ['=' => 'al', 'king'], ['=' => 'eddie', 'prince' ], [ '=' => 'vicky', 'queen'], [ -is_null => 'xandor' ] ] ],
  [ '-in function (list argument)',
    { flintstone => { -in => [ 'fred', 'wilma', 'pebbles' ]  } },
    [ -in => 'flintstone', [ -list => 'fred', 'wilma', 'pebbles'] ] ],
 );

for (@test_pairs) {
#  $DB::single=1;
  is_deeply( $o->canonize(sort_test($$_[1])), $$_[2], $$_[0] );
  1;
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
