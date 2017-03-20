use Neo4j::Cypher::Abstract;
use Neo4j::Cypher::Pattern;
# examples that might work


$c = Neo4j::Cypher::Abstract->new();

$c->match("(p)-[r:KNOWS]->(q)")->where("p.name = 'Fred' and r.kind = 'biblical'")->return("q.name");

$p = Neo4j::Cypher::Pattern->new();
$q = Neo4j::Cypher::Pattern->new();
$p->N("p")->R("r", "KNOWS", {kind=>'biblical'})->N("q");
$q->N("q",["Person"], { name => 'Wilma' });

$c->match($p)->return("q.name");

$c->match($p)->where(
  [ -and => { 'p.name' => 'Fred',
	      'r.kind' => 'biblical' }
   ])->return( ['p.name', 'q.name'] );

$c->match($p)->merge($q);





