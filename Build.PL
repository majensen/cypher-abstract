use Module::Build;
$build = Module::Build->new(
  dist_author => 'Mark A. Jensen',
  dist_name => 'Neo4j-Cypher-Abstract',
  dist_version_from => 'lib/Neo4j/Cypher/Abstract.pm',
  dist_abstract => 'Generate Cypher queries in Perl',
  requires => {
   },
  configure_requires => {
    'Module::Build' => 0
   },
  build_requires => {
    'Tie::IxHash' => 0,
    'Try::Tiny' => 0,
   },
);
$build->create_build_script;
