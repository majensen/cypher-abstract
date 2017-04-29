use Test::More;
use lib '../lib';
use Neo4j::Cypher::Abstract qw/cypher pattern/;

isa_ok(cypher, 'Neo4j::Cypher::Abstract');
isa_ok(pattern, 'Neo4j::Cypher::Pattern');

$DB::single=1;
my $c = cypher->match('(n)')->where({ 'n.name' => 'Fred' })->return('n.spouse');
isa_ok($c, 'Neo4j::Cypher::Abstract');

is "$c", "MATCH (n) WHERE n.name = 'Fred' RETURN n.spouse";

my $p = pattern->N(n);
$c = cypher->match($p)->where({ 'n.name' => 'Fred' })->return('n.spouse');
is "$c", "MATCH (n) WHERE n.name = 'Fred' RETURN n.spouse";

done_testing;
