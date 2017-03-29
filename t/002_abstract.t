use Test::More;
use lib '../lib';


use_ok('Neo4j::Cypher::Abstract');

is Neo4j::Cypher::Abstract::infix_binary("+", [1, 2]), "1 + 2";
is Neo4j::Cypher::Abstract::infix_distributable("-and", [1, 2,"fred","bob"]), "1 AND 2 AND fred AND bob";
is Neo4j::Cypher::Abstract::prefix("-not", ['a.name']), "NOT a.name";
is Neo4j::Cypher::Abstract::postfix("-is_not_null", ['a.name']), "a.name IS NOT NULL";
is Neo4j::Cypher::Abstract::function("-sin", [1.5]), "sin(1.5)";
is Neo4j::Cypher::Abstract::function("-coalesce", [1.5, 'mabel','dood']), "coalesce(1.5,mabel,dood)";


done_testing;

