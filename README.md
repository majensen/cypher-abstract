# Neo4j::Cypher::Abstract

Neo4j::Cypher::Abstract - Generate Cypher query statements

# SYNOPSIS

 TBD

# DESCRIPTION

When writing code to automate database queries, sometimes it is
convenient to use a wrapper that generates desired query strings. Then
the user can think conceptually and avoid having to remember precise
syntax or write and debug string manipulations. A good wrapper can
also allow the user to produce query statements dynamically, hide
dialect details, and may include some simple syntax
checking. `SQL::Abstract` is an example of a widely-used wrapper for
SQL.

The graph database [Neo4j](https://www.neo4j.com) allows SQL-like
declarative queries through its query language
[Cypher](https://neo4j.com/docs/developer-manual/current/cypher/). `Neo4j::Cypher::Abstract`
is a Cypher wrapper in the spirit of `SQL::Abstract` that creates
very general Cypher productions in an intuitive, Perly way.

## Basic idea : stringing clauses together with method calls

A clause is a portion of a complete query statement that plays a
specific functional role in the statement and is set off by one or
more reserved words. [Clauses in
Cypher](https://neo4j.com/docs/developer-manual/current/cypher/clauses/)
include reading (e.g., MATCH), writing (CREATE), importing (LOAD CSV), and
schema (CREATE CONSTRAINT) clauses, among others. They have
arguments that define the clause's scope of action.

[Cypher::Abstract](https://metacpan.org/pod/Neo4j::Cypher::Abstract) objects possess methods
for every Cypher clause. Each method adds its clause, with arguments,
to the object's internal queue. Every method returns the object
itself. When an object is rendered as a string, it concatenates its
clauses to yield the entire query statement.

These features add up to the following idiom. Suppose we want to
render the Cypher statement

    MATCH (n:Users) WHERE n.name =~ 'Fred.*' RETURN n.manager

In `Cypher::Abstract`, we do

    $s = Neo4j::Cypher::Abstract->new()->match('n:Users')
         ->where("n.name =~ 'Fred.*'")->return('n.manager');
    print "$s;\n"; # "" is overloaded by $s->as_string()

Because you may create many such statements in a program, a short
alias for the constructor can be imported, and extra variable
assignments can be avoided.

    use Neo4j::Cypher::Abstract qw/cypher/;
    use DBI;

    my $dbh = DBI->connect("dbi:Neo4p:http://127.0.0.1:7474;user=foo;pass=bar");
    my $sth = $dbh->prepare(
      cypher->match('n:Users')->where("n.name =~ 'Fred.*'")->return('n.manager')
      );
    $sth->execute();
    ...

## Patterns

[Patterns](https://neo4j.com/docs/developer-manual/current/cypher/syntax/patterns/)
are representations of subgraphs with constraints that are key
components of Cypher queries. They have their own syntax and are also
amenable to wrapping.  In the example [above](#basic-idea-stringing-clauses-together-with-method-calls), `match()` uses a simple
built-in shortcut:

    $s->match('n:User') eq $s->match('(n:User)')

where `(n:User)` is the simple pattern for "all nodes with label
'User'".  The module [Neo4j::Cypher::Pattern](#Neo4j::Cypher::Pattern) handles
complex and arbitrary patterns. It is loaded automatically on `use
Neo4j::Cypher::Abstract`. Abstract patterns are written in a similar
idiom as Cypher statements. They can be used anywhere a string is
allowed. For example:

    use Neo4j::Cypher::Abstract qw/cypher ptn/;

    ptn->N(':Person',{name=>'Oliver Stone'})->R("r>")->N('movie') eq
     '(:Person {name:'Oliver Stone'})-[r]->(movie)'
    $sth = $dbh->prepare(
       cypher->match(ptn->N(':Person',{name=>'Oliver Stone'})->R("r>")->N('movie'))
             ->return('type(r)')
       );

See [Neo4j::Cypher::Pattern](#Neo4j::Cypher::Pattern) for a full description of how
to specify patterns.

## WHERE clauses

As in SQL, Cypher has a WHERE clause that is used to filter returned
results.  Rather than having to create custom strings for common WHERE
expressions, [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract) provides an intuitive system for
constructing valid expressions from Perl data structures made up of
hash, array, and scalar references. [Neo4j::Cypher::Abstract](#Neo4j::Cypher::Abstract)
contains a new implementation of the [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract) expression
"compiler". If the argument to the `where()` method (or any other
method, in fact) is an array or hash reference, it is interpreted as
an expression in [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract) style. (The parser is a complete
reimplementation, so some idioms in that style may not result in
exactly the same productions.)

## Parameters

Parameters in Cypher are named, and given as alphanumeric tokens
prefixed (sadly) with '$'. The `Cypher::Abstract` object collects
these in the order they appear in the complete statement. The list of
parameters can be recovered with the `parameters()` method.

    $c = cypher->match('n:Person')->return('n.name')
               ->skip('$s')->limit('$l');
    @p = $c->parameters; # @p is ('$s', '$l') /;

# METHODS

## Reading clauses

- match(@ptns)
- optional\_match(@ptns)
- where($expr)
- start($ptn)

## Writing clauses

- create(@ptns), create\_unique($ptn)
- merge(@ptns)
- foreach($running\_var => $list, cypher->&lt;update statement>)
- set()
- delete(), detach\_delete()
- on\_create(), on\_match()

## Modifiers

- limit($num)
- skip($num)
- order\_by($identifier)

## General clauses

- return(@items), return\_distinct(@items)
- with(@identifiers), with\_distinct(@identifiers)
- unwind($list => $identifier)
- union()
- call()
- yield()

## Hinting

- using\_index($index)
- using\_scan()
- using\_join($identifier)

## Loading

- load\_csv($file => $identifier), load\_csv\_with\_headers(...)

## Schema

- create\_constraint\_exist($node => $label, $property),create\_constraint\_unique($node => $label, $property)
- drop\_constraint(...)
- create\_index($label => $property), drop\_index($label => $property)

## Utility Methods

- parameters()

    Return a list of statement parameters.

- as\_string()

    Render the Cypher statement as a string. Overloads `""`.

# SEE ALSO

[REST::Neo4p](https://metacpan.org/pod/REST::Neo4p), [DBD::Neo4p](https://metacpan.org/pod/DBD::Neo4p), [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract)

# Neo4j::Cypher::Pattern

Neo4j::Cypher::Pattern - Generate Cypher pattern strings

# SYNOPSIS

    # express a cypher pattern
    use Neo4j::Cypher::Pattern qw/ptn/;

    ptn->node();
    ptn->N(); #alias
    ptn->N("varname");
    ptn->N("varname",["label"],{prop => "value"});
    ptn->N("varname:label");
    ptn->N(["label"],{prop => "value"});

    ptn->node('a')->related_to()->node('b'); # (a)--(b)
    ptn->N('a')->R()->N('b'); # alias
    # additional forms
    ptn->N('a')->R("varname","typename",[$minhops,$maxhops],{prop => "value"})
       ->N('b'); # (a)-[varname:typename*minhops..maxhops { prop:"value }]-(b)
    ptn->N('a')->R("varname:typename")->N('b'); # (a)-[varname:typename]-(b)
    ptn->N('a')->R(":typename")->N('b'); # (a)-[:typename]-(b)
    ptn->N('a')->R("", "typename")->N('b'); # (a)-[:typename]-(b)
    # directed relns
    ptn->N('a')->R("<:typename")->N('b'); # (a)<-[:typename]-(b)
    ptn->N('a')->R("varname:typename>")->N('b'); # (a)-[varname:typename]->(b)

    # these return strings
    $pattern->path('varname'); # path variable assigned to a pattern
    $pattern->as('varname'); # alias
    ptn->compound($pattern1, $pattern2); # comma separated patterns
    ptn->C($pattern1, $pattern2); # alias

# DESCRIPTION

The [Cypher](https://neo4j.com/docs/developer-manual/current/cypher/)
query language of the graph database [Neo4j](https://neo4j.com) uses
[patterns](https://neo4j.com/docs/developer-manual/current/cypher/syntax/patterns)
to represent graph nodes and their relationships, for selecting and
matching in queries. `Neo4j::Cypher::Pattern` can be used to create
Cypher pattern productions in Perl in an intuitive way. It is part of
the [Neo4j::Cypher::Abstract](https://metacpan.org/pod/Neo4j::Cypher::Abstract) distribution.

## Basic idea : produce patterns by chaining method calls

`Neo4j::Cypher::Pattern` objects possess methods to represent nodes
and relationships. Each method adds its portion of the pattern, with
arguments, to the object's internal queue. Every method returns the
object itself. When an object is rendered as a string, it concatenates
nodes and relationship productions to yield the entire query statement
as a string.

These features add up to the following idiom. Suppose we want to
render the Cypher pattern

    (b {name:"Slate"})<-[:WORKS_FOR]-(a {name:"Fred"})-[:KNOWS]->(c {name:"Barney"})

In `Neo4j::Cypher::Pattern`, we do

    $p = Neo4j::Cypher::Pattern->new()->N('b',{name=>'Slate')
         ->R('<:WORKS_FOR')->N('a',{name => 'Fred'})
         ->R(':KNOWS>')->N('c',{name=>'Barney'});
    print "$p\n"; # "" is overloaded by $p->as_string()

Because you may create many patterns in a program, a short
alias for the constructor can be imported, and extra variable
assignments can be avoided.

    print ptn->N('b',{name=>'Slate'})
         ->R('<:WORKS_FOR')->N('a',{name => 'Fred'})
         ->R(':KNOWS>')->N('c',{name=>'Barney'}), "\n";

## Quoting

In pattern productions, values for properties will be quoted by
default with single quotes (single quotes that are present will be
escaped) unless the values are numeric.

To prevent quoting Cypher statement list variable names (for example), make the name an argument to the pattern _constructor_:

    ptn('event')->N('y')->R("<:IN")->N('e:Event'=> { id => 'event.id' });

    # renders (y)<-[:IN]-(e:Event {id:event.id})
    # rather than (y)<-[:IN]-(e:Event {id:"event.id"})

# METHODS

- Constructor new()
- pattern(), ptn()

    Exportable aliases for the constructor. Arguments are variable names
    that should not be quoted in rendering values of properties.

- node(), N()

    Render a node. Arguments in any order:

        scalar string: variable name or variable:label
        array ref: array of node labels
        hash ref: hash of property => value

- related\_to(), R()

    Render a relationship. Arguments in any order:

        scalar string: variable name or variable:type
        array ref: variable-length pattern:
          [$minhops, $maxhops] 
          [] (empty array)- any number of hops
          [$hops] - exactly $hops
        hash ref : hash of property => value

- path(), as()

    Render the pattern set equal to a path variable:

        $p = ptn->N('a')->_N('b');
        print $p->as('pth'); # gives 'pth = (a)--(b)'

- compound(), C()

    Render multiple patterns separated by commas

        ptn->compound( ptn->N('a')->to_N('b'), ptn->N('a')->from_N('c'));
        # (a)-->(b), (a)<--(c)

- Shortcuts \_N, to\_N, from\_N

        ptn->N('a')->_N('b'); # (a)--(b)
        ptn->N('a')->to_N('b'); # (a)-->(b)
        pth->N('a')->from_N('b'); # (a)<--(b)

# SEE ALSO

[Neo4j::Cypher::Abstract](https://metacpan.org/pod/Neo4j::Cypher::Abstract)

# AUTHOR

    Mark A. Jensen
    CPAN: MAJENSEN
    majensen -at- cpan -dot- org

# COPYRIGHT

    (c) 2017 Mark A. Jensen
