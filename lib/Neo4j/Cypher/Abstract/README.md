# Neo4j::Cypher::Abstract::Peeler

Neo4j::Cypher::Abstract::Peeler - Parse Perl structures as expressions

# SYNOPSIS

# DESCRIPTION

`Neo4j::Cypher::Abstract::Peeler` allows the user to write [Neo4j 
Cypher](https://neo4j.com/docs/developer-manual/current/cypher/) query
language expressions as Perl data structures. The interpretation of
data structures follows [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract) very closely, but attempts to
be more systematic and general.

`Peeler` only produces expressions, typically used as arguments to
`WHERE` clauses. It is integrated into [Neo4j::Cypher::Abstract](https://metacpan.org/pod/Neo4j::Cypher::Abstract),
which produces full Cypher statements.

Like [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract), `Peeler` translates scalars, scalar refs,
array refs, and hash refs syntactically to create expression
components such as functions and operators. The contents of the
scalars or references are generally operators or the arguments to
operators or functions.

Contents of scalar references are always treated as literals and
inserted into the expression verbatim.

- Functions

    Ordinary functions in Cypher are written as the name of the function preceded by a dash. They can be expressed as follows:

        { -func => $arg }
        [ -func => $arg ]
        \"func($arg)"

        { -sin => $pi/2 }
        # returns sin(<value of $pi>/2)

- Infix Operators

    Infix operators, like equality (`=`), inequality (`><`), binary operations (`+,-,*,/`), and certain string operators (`-contains`, `-starts_with`,`ends_with`) are expressed as follows:

        { $expr1 => { $infix_op => $expr2 } }

        { 'n.name'  => { '<>' => 'Fred' } }
        # returns n.name <> "Fred"

    This may seem like overkill, but comes in handy for...

- AND and OR

    `Peeler` implements the [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract) convention that hash refs
    represent conditions joined by `AND` and array refs represent
    conditions joined by `OR`. Key-value pairs and array value pairs are
    interpreted as an implicit equalities to be ANDed or ORed.

        { $lhs1 => $rhs1, $lhs2 => $rhs2 }
        { al => 'king', 'eddie' => 'prince', vicky => 'queen' }
        # returns al = "king" AND eddie = "prince" AND vicky = "queen"

        [ $lhs1 => $rhs1, $lhs2 => $rhs2 ]
        [ 'a.name' => 'Fred', 'a.name' => 'Barney']
        # returns a.name = "Fred" OR a.name = "Barney"

    A single left-hand side can be "distributed" over a set of conditions,
    with corresponding conjunction:

        { zzyxx => [ 'narf', 'boog', 'frelb' ] } # implicit equality, OR
        # returns zzyxx = "narf" OR zzyxx = "boog" OR zzyxx = "frelb"
        { zzyxx => { '<>' =>  'narf', '<>' => 'boog' } } # explicit infix, AND
        # returns zzyxx <> "narf" AND zzyxx <> "boog"
        { zzyxx => [ '<>' =>  'narf', -contains => 'boog' ] } # explicit infix, OR
        # returns zzyxx <> "narf" OR zzyxx CONTAINS "boog"

- Expressing null

    `undef` can be used to express NULL mostly as in [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract) so that the following are equivalent

        { a.name => { '<>' => undef}, b.name => undef}
        { -is_not_null => 'a.name', -is_null => 'b.name' }
        # returns a.name IS NOT NULL  AND b.name IS NULL

- Predicates: -all, -any, -none, -single, -filter

    These Cypher functions have the form

        func(variable IN list WHERE predicate)

    To render these, provide an array ref of the three arguments in order:

        { -all => ['x', [1,2,3], {'x' => 3}] }
        # returns all(x IN [1,2,3] WHERE x = 3)

- List arguments

## Parameters and Bind Values

Cypher parameters (which use the '$' sigil) may be included in
expressions (with the dollar sign appropriately escaped). These are
collected during parsing and can be reported in order with the the
`parameters()` method.

[SQL::Abstract](https://metacpan.org/pod/SQL::Abstract) automatically collects literal values and replaces
them with anonymous placeholders (`?`), returning an array of values
for binding in [DBI](https://metacpan.org/pod/DBI). `Peeler` will collect values and report them
with the `bind_values()` method. If the config key
`anon_placeholder` is set:

    $peeler->{config}{anon_placeholder} = '?'

then `Peeler` will also do the replacement in the final expression
production like [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract).

The real reason to pay attention to literal values is to be able to
appropriately quote them in the final production. When
`anon_placeholder` is not set (default), then an attempt is made to
correctly quote string values and such.

# GUTS

 TBD

# METHODS

- express()
- canonize()
- peel()
- parameters()
- bind\_values()

# SEE ALSO

[Neo4j::Cypher::Abstract](https://metacpan.org/pod/Neo4j::Cypher::Abstract), [SQL::Abstract](https://metacpan.org/pod/SQL::Abstract).

# AUTHOR

    Mark A. Jensen
    CPAN: MAJENSEN
    majensen -at- cpan -dot- org

# COPYRIGHT

    (c) 2017 Mark A. Jensen
