my $clauses = {
  read => [qw/match optional_match where start/],
  write => [qw/create merge set delete remove foreach 
	       create_unique/],
  general => [qw/return order_by limit skip with unwind union call/]
 };

my $functions = {
  predicate => [qw/all any exists none single/],
  scalar => [qw/coalesce endNode head id last length startNode
		size timestamp toInt toFloat type/],
  list => [ qw/extract filter keys labels nodes range reduce
	       relationships tail/ ],
  math => {
    numeric => [qw/abs ceil floor rand round sign/],
    log => [qw/e exp log log10 sqrt/],
    trig => [qw/acos asin atan atan2 cos cot haversin pi radians
		sin tan/],
    string => [qw/left lower ltrim replace reverse right
		  rtrim split substring toString trim upper/],
  },
};


