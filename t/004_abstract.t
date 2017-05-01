use Test::More;
use lib '../lib';
use Neo4j::Cypher::Abstract qw/cypher ptn/;

isa_ok(cypher, 'Neo4j::Cypher::Abstract');
isa_ok(ptn, 'Neo4j::Cypher::Pattern');

$DB::single=1;
my $c = cypher->match('(n)')->where({ 'n.name' => 'Fred' })->return('n.spouse');
isa_ok($c, 'Neo4j::Cypher::Abstract');

is "$c", "MATCH (n) WHERE (n.name = 'Fred') RETURN n.spouse";

my $p = ptn->N(n);
$c = cypher->match($p)->where({ 'n.name' => 'Fred' })->return('n.spouse');
is "$c", "MATCH (n) WHERE (n.name = 'Fred') RETURN n.spouse";

#examples from https://neo4j.com/docs/developer-manual/current/cypher/clauses

is cypher->match(ptn->N('movie:Movie'))->return('movie.title'),
  'MATCH (movie:Movie) RETURN movie.title', '3.3.1.2';

is cypher->match(ptn->N('director',{name=>'Oliver Stone'})->R()->N('movie'))
  ->return('movie.title'),
  , "MATCH (director {name:'Oliver Stone'})--(movie) RETURN movie.title",
  '3.3.1.2';

is cypher->match(ptn->N(':Person',{name=>'Oliver Stone'})->R("r>")->N('movie'))->return('type(r)'),
  "MATCH (:Person {name:'Oliver Stone'})-[r]->(movie) RETURN type(r)",'3.3.1.3';

is cypher->match(ptn->N("wallstreet:Movie",{title => 'Wall Street'})->R("<:ACTED_IN")->N('actor'))->return('actor.name'),
  "MATCH (wallstreet:Movie {title:'Wall Street'})<-[:ACTED_IN]-(actor) RETURN actor.name",'3.3.1.3';

is cypher->match(ptn->N('wallstreet',{title=>'Wall Street'})->R("<:ACTED_IN|:DIRECTED")->N('person'))->return('person.name'),
"MATCH (wallstreet {title:'Wall Street'})<-[:ACTED_IN|:DIRECTED]-(person) RETURN person.name",'3.3.1.3';

is cypher->match(ptn->N("a:Movie",{title=>'Wall Street'}))
  ->optional_match(ptn->N('a')->R("r:ACTS_IN>")->N())
  ->return('r'),
  "MATCH (a:Movie {title:'Wall Street'}) OPTIONAL MATCH (a)-[r:ACTS_IN]->() RETURN r",'3.3.2.4';

is cypher->match(ptn->N('a',{name=>'A'}))
  ->return('a.age > 30', 'I\'m a literal',ptn->N('a')->R('>')->N()),
  "MATCH (a {name:'A'}) RETURN a.age > 30,'I\'m a literal',(a)-->()",'3.3.4.9';

done_testing;
