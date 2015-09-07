package DBIx::FlexibleBinding;
BEGIN { $DBIx::FlexibleBinding::VERSION = '1.152500'; }
=head1 NAME

DBIx::FlexibleBinding - Flexible parameter binding and record fetching

=head1 VERSION

version 1.152500

=cut

=head1 SYNOPSIS

This module extends the DBI allowing you choose from a variety of supported
parameter placeholder and binding patterns as well as offering simplified
ways to interact with datasources, while improving general readability.

    #########################################################
    # SCENARIO 1                                            #
    # A connect followed by a prepare-execute-process cycle #
    #########################################################

    use DBIx::FlexibleBinding;
    use constant DSN => 'dbi:mysql:test;host=127.0.0.1';
    use constant SQL => << '//';
    SELECT solarSystemName AS name
      FROM mapsolarsystems
     WHERE regional  = :is_regional
       AND security >= :minimum_security
    //

    # Pretty standard connect, just with the new DBI subclass ...
    #
    my $dbh = DBIx::FlexibleBinding->connect(DSN, '', '', { RaiseError => 1 });

    # Prepare statement using named placeholders (not bad for MySQL, eh) ...
    #
    my $sth = $dbh->prepare(SQL);

    # Execute the statement (parameter binding is automatic) ...
    #
    my $rv = $sth->execute(is_regional => 1,
                           minimum_security => 1.0);

    # Fetch and transform rows with a blocking callback to get only the data you
    # want without cluttering the place up with intermediate state ...
    #
    my @system_names = $sth->getall_hashref(callback { $_->{name} });

    ############################################################################
    # SCENARIO 2                                                               #
    # Let's simplify the previous scenario using the database handle's version #
    # of that getall_hashref method.                                       #
    ############################################################################

    use DBIx::FlexibleBinding -alias => 'DFB';
    use constant DSN => 'dbi:mysql:test;host=127.0.0.1';
    use constant SQL => << '//';
    SELECT solarSystemName AS name
      FROM mapsolarsystems
     WHERE regional  = :is_regional
       AND security >= :minimum_security
    //

    # Pretty standard connect, this time with the DBI subclass package alias ...
    #
    my $dbh = DFB->connect(DSN, '', '', { RaiseError => 1 });

    # Cut out the middle men ...
    #
    my @system_names = $dbh->getall_hashref(SQL,
                                                is_regional => 1,
                                                minimum_security => 1.0,
                                                callback { $_->{name} });

    #############################################################################
    # SCENARIO 3                                                                #
    # The subclass import method provides a versatile mechanism for simplifying #
    # matters further.                                                          #
    #############################################################################

    use DBIx::FlexibleBinding -subs => [ 'MyDB' ];
    use constant DSN => 'dbi:mysql:test;host=127.0.0.1';
    use constant SQL => << '//';
    SELECT solarSystemName AS name
      FROM mapsolarsystems
     WHERE regional  = :is_regional
       AND security >= :minimum_security
    //

    # MyDB will represent our datasource; initialise it ...
    #
    MyDB DSN, '', '', { RaiseError => 1 };

    # Cut out the middle men and some of the line-noise, too ...
    #
    my @system_names = MyDB(SQL,
                            is_regional => 1,
                            minimum_security => 1.0,
                            callback { $_->{name} });
=cut

=head1 DESCRIPTION

This module subclasses the DBI to provide improvements and greater flexibility
in the following areas:

=over 2

=item * Parameter placeholders and data binding

=item * Data retrieval and processing

=item * Accessing and interacting with datasources

=back

=head2 Parameter placeholders and data binding

This module provides support for a wider range of parameter placeholder and
data-binding schemes. As well as continued support for the simple positional
placeholders (C<?>), additional support is provided for numeric placeholders (C<:N>
and C<?N>), and named placeholders (C<:NAME> and C<@NAME>).

As for the process of binding data values to parameters: that is, by default,
now completely automated, removing a significant part of the workload from the
prepare-bind-execute cycle. It is, however, possible to swtch off automatic
data-binding globally and on a statement-by-statement basis.

The following familiar operations have been modified to accommodate all of these
changes, though developers continue to use them as they always have done:

=over 2

=item * C<$DATABASE_HANDLE-E<gt>prepare($STATEMENT, \%ATTR);>

=item * C<$DATABASE_HANDLE-E<gt>do($STATEMENT, \%ATTR, @DATA);>

=item * C<$STATEMENT_HANDLE-E<gt>bind_param($NAME_OR_POSITION, $VALUE, \%ATTR);>

=item * C<$STATEMENT_HANDLE-E<gt>execute(@DATA);>

=back

=head2 Data retrieval and processing

Four new methods, each available for database B<and> statement handles, have
been implemented:

=over 2

=item * C<getrow_arrayref>

=item * C<getrow_hashref>

=item * C<getall_arrayref>

=item * C<getall_hashref>

=back

These methods complement DBI's existing fetch methods, providing new ways to
retrieve and process data.

=head2 Accessing and interacting with datasources

The module's C<-subs> import option may be used to create subroutines,
during the compile phase, and export them to the caller's namespace for
use later as representations of database and statement handles.

=over 2

=item * Use for connecting to datasources

    use DBIx::FlexibleBinding -subs => [ 'MyDB' ];

    # Pass in any set of well-formed DBI->connect(...) arguments to associate
    # your name with a live database connection ...
    #
    MyDB( 'dbi:mysql:test;host=127.0.0.1', '', '', { RaiseError => 1 } );

    # Or, simply pass an existing database handle as the only argument ...
    #
    MyDB($dbh);

=item * Use them to represent database handles

    use DBIx::FlexibleBinding -subs => [ 'MyDB' ];
    use constant SQL => << '//';
    SELECT *
      FROM mapsolarsystems
     WHERE regional  = :is_regional
       AND security >= :minimum_security
    //

    MyDB( 'dbi:mysql:test;host=127.0.0.1', '', '', { RaiseError => 1 } );

    # If your name is already associated with a database handle then just call
    # it with no parameters to use it as such ...
    #
    my $sth = MyDB->prepare(SQL);

=item * Use them to represent statement handles

    use DBIx::FlexibleBinding -subs => [ 'MyDB', 'solar_systems' ];
    use constant SQL => << '//';
    SELECT *
      FROM mapsolarsystems
     WHERE regional  = :is_regional
       AND security >= :minimum_security
    //

    MyDB( 'dbi:mysql:test;host=127.0.0.1', '', '', { RaiseError => 1 } );

    my $sth = MyDB->prepare(SQL);

    # Simply call the statement handle proxy, passing a statement handle in as
    # the only argument ...
    #
    solar_systems($sth);

=item * Use to interact with the represented database and statement handles

    use DBIx::FlexibleBinding -subs => [ 'MyDB', 'solar_systems' ];
    use constant SQL => << '//';
    SELECT *
      FROM mapsolarsystems
     WHERE regional  = :is_regional
       AND security >= :minimum_security
    //

    MyDB( 'dbi:mysql:test;host=127.0.0.1', '', '', { RaiseError => 1 } );

    # Use the database handle proxy to prepare, bind and execute statements, then
    # retrieve the results ...
    #
    # Use the database handle proxy to prepare, bind and execute statements, then
    # retrieve the results ...
    #
    my $array_of_hashrefs = MyDB(SQL,
                                 is_regional => 1,
                                 minimum_security => 1.0);

    # In list context, results come back as lists ...
    #
    my @array_of_hashrefs = MyDB(SQL,
                                 is_regional => 1,
                                 minimum_security => 1.0);

    # Using -subs also relaxes strict 'subs' in the caller's scope, so pretty-up
    # void context calls by losing the parentheses, if you wish to use callbacks
    # to process the results ...
    #
    MyDB SQL, is_regional => 1, minimum_security => 1.0, callback {
        printf "%-16s %.1f\n", $_->{solarSystemName}, $_->{security};
    };

    # You can use proxies to represent statements, too. Simply pass in a statement
    # handle as the only argument ...
    #
    my $sth = MyDB->prepare(SQL);
    solar_systems($sth);    # Using "solar_systems" as statement proxy.

    # Now, when called with other types of arguments, those argument values are
    # bound and the statement is executed ...
    #
    my $array_of_hashrefs = solar_systems(is_regional => 1,
                                          minimum_security => 1.0);

    # In list context, results come back as lists ...
    #
    my @array_of_hashrefs = solar_systems(is_regional => 1,
                                          minimum_security => 1.0);

    # Statements requiring no parameters cannot be used in this manner because
    # making a call to a statement proxy with an arity of zero results in the
    # statement handle being returned. In this situation, use something like
    # undef as an argument (it will be ignored in this particular instance) ...
    #
    my $rv = statement_proxy(undef);
    #
    # Meh, you can't win 'em all!

=back

=cut

use 5.006;
use strict;
use warnings;
use Carp qw(confess);
use Exporter ();
use DBI      ();
use MRO::Compat 'c3';
use Scalar::Util qw(reftype);
use namespace::clean;
use Params::Callbacks 'callback';

our @ISA = ( 'DBI', 'Exporter' );
our @EXPORT = qw(callback);

=head1 PACKAGE GLOBALS

=head2 $DBIx::FlexibleBinding::AUTO_BINDING_ENABLED

A boolean setting used to determine whether or not automatic binding is enabled
or disabled globally.

The default setting is C<"1"> (I<enabled>).

=head2 $DBIx::FlexibleBinding::PROXIES_GETALL_USING

The subroutines created with the C<-subs> import option may be used to
retrieve result sets. By default, any such subroutines delegate that particular
task to a method called C<"getall_hashref">, which is provided by this module
for both database and statement handles alike.

For reasons of efficiency the developer may prefer array references over hash
references, in which case they only need assign the value C<"getall_arrayref">
to this global.

=cut

our $AUTO_BINDING_ENABLED     = 1;
our $PROXIES_GETALL_USING = 'getall_hashref';


sub _dbix_set_err
{
    my ( $handle, @args ) = @_;
    return $handle->set_err( $DBI::stderr, @args );
}

=head1 IMPORT TAGS AND OPTIONS

=head2 -alias

This option may be used by the caller to select an alias to use for this
package's unwieldly namespace.

    use DBIx::FlexibleBinding -alias => 'DBIF';

    my $dbh = DBIF->connect('dbi:SQLite:test.db', '', '');

=head2 -subs

This option may be used to create subroutines, during the compile phase, in
the caller's namespace to be used as representations of database and statement
handles.

    use DBIx::FlexibleBinding -subs => [ 'MyDB' ];

    # Initialise by passing in a valid set of DBI->connect(...) arguments.
    # The database handle will be the return value.
    #
    MyDB 'dbi:mysql:test;host=127.0.0.1', '', '', { RaiseError => 1 };

    # Or, initialise by passing in a DBI database handle.
    # The handle is also the return value.
    #
    MyDB $dbh;

    # Once initialised, use the subroutine as you would a DBI database handle.
    #
    my $statement = << '//';
    SELECT solarSystemName AS name
      FROM mapsolarsystems
     WHERE security >= :minimum_security
    //
    my $sth = MyDB->prepare($statement);

    # Or use it as an expressive time-saver!
    #
    my $array_of_hashrefs = MyDB($statement, security => 1.0);
    my @system_names = MyDB($statement, minimum_security => 1.0, callback {
        return $_->{name};
    });
    MyDB $statement, minimum_security => 1.0, callback {
        my ($row) = @_;
        print "$row->{name}\n";
    };

Use of this option automatically relaxes C<strict 'subs'> for the remainder of
scope containing the C<use> directive. That is unless C<use strict 'subs'> or
C<use strict> appears afterwards.

=cut


sub import
{
    my ( $package, @args ) = @_;
    my $caller = caller;
    @_ = ($package);

    while (@args) {
        my $arg = shift(@args);

        if ( substr( $arg, 0, 1 ) eq '-' ) {
            if ( $arg eq '-alias' ) {
                no strict 'refs';    ## no critic [TestingAndDebugging::ProhibitNoStrict]
                my $package_alias = shift(@args);
                *{ $package_alias . '::' }     = *{ __PACKAGE__ . '::' };
                *{ $package_alias . '::db::' } = *{ __PACKAGE__ . '::db::' };
                *{ $package_alias . '::st::' } = *{ __PACKAGE__ . '::st::' };
            }
            elsif ( $arg eq '-subs' ) {
                my $list = shift(@args);
                confess "Expected anonymous list or array reference after '$arg'"
                  unless ref($list) && reftype($list) eq 'ARRAY';
                $caller->unimport( 'strict', 'subs' );
                for my $name (@$list) {
                    DBIx::FlexibleBinding::ObjectProxy->create( $name, $caller );
                }
            }
            else {
                confess "Unrecognised import option '$arg'";
            }
        }
        else {
            push @_, $arg;
        }
    }

    goto &Exporter::import;
}

=head1 CLASS METHODS

=cut

=head2 connect

    $dbh = DBIx::FlexibleBinding->connect($data_source, $user, $pass)
      or die $DBI::errstr;
    $dbh = DBIx::FlexibleBinding->connect($data_source, $user, $pass, \%attr)
      or die $DBI::errstr;

Establishes a database connection, or session, to the requested data_source and
returns a database handle object if the connection succeeds or undef if it does
not.

Refer to L<http://search.cpan.org/dist/DBI/DBI.pm#connect> for a more detailed
description of this method.

=cut


sub connect
{
    my ( $invocant, $dsn, $user, $pass, $attr ) = @_;
    $attr = {} unless defined $attr;
    $attr->{RootClass} = ref($invocant) || $invocant unless defined $attr->{RootClass};
    return $invocant->SUPER::connect( $dsn, $user, $pass, $attr );
}

package    # Hide from PAUSE
  DBIx::FlexibleBinding::db;

use List::MoreUtils qw(any);
use Params::Callbacks qw(callbacks);
use namespace::clean;

our @ISA = 'DBI::db';

=head1 DATABASE HANDLE METHODS

=cut

=head2 do

    $rows = $dbh->do($statement_string) or die $dbh->errstr;
    $rows = $dbh->do($statement_string, @bind_values) or die $dbh->errstr;
    $rows = $dbh->do($statement_string, \%attr) or die $dbh->errstr;
    $rows = $dbh->do($statement_string, \%attr, @bind_values) or die $dbh->errstr;
    $rows = $dbh->do($statement_handle) or die $dbh->errstr;
    $rows = $dbh->do($statement_handle, @bind_values) or die $dbh->errstr;


Prepares (if necessary) and executes a single statement. Returns the number of
rows affected or undef on error. A return value of -1 means the number of rows
is not known, not applicable, or not available. When no rows have been affected
this method continues the C<DBI> tradition of returning C<0E0> on successful
execution and C<undef> on failure.

The C<do> method accepts optional callbacks for further processing of the result.

The C<do> implementation provided by this module allows for some minor
deviations in usage over the standard C<DBI> implementation. In spite
of this, the new method may be used just like the original.

Refer to L<http://search.cpan.org/dist/DBI/DBI.pm#do> for a more detailed
description of this method.

=head3 Examples

=over

=item 1. Statement attributes are now optional:

    $sql = << '//';
    UPDATE employees
       SET salary = :salary
     WHERE employee_id = :employee_id
    //

    $dbh->do($sql, employee_id => 52, salary => 35_000)
      or die $dbh->errstr;

A reference to the statement attributes hash is no longer required, even if it's
empty. If, however, a hash reference is supplied as the first parameter then it 
would be used for that purpose.

=item 2. Prepared statements now may be re-used:

    $sth = $dbh->prepare(<< '//');
    UPDATE employees
       SET salary = ?
     WHERE employee_id = ?
    //

    $dbh->do($sth, 35_000, 52) or die $dbh->errstr;

A prepared statement may also be used in lieu of a statement string. In such
cases, referencing a statement attributes hash is neither required nor expected.

=back

=cut


sub do
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    if ( !ref($sth) ) {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
        return if $sth->err;
    }

    my $result;
    return $result if $sth->err;

    $result = $sth->execute(@bind_values);
    return $result if $sth->err;

    if ($result) {
        if (@$callbacks) {
            local $_;
            $result = $callbacks->smart_transform( $_ = $result );
        }
    }

    return $result;
}

=head2 prepare

    $sth = $dbh->prepare($statement_string);
    $sth = $dbh->prepare($statement_string, \%attr);

Prepares a statement for later execution by the database engine and returns a
reference to a statement handle object.

Refer to L<http://search.cpan.org/dist/DBI/DBI.pm#prepare> for a more detailed
description of this method.

=head3 Examples

=over

=item 1. Prepare a statement using positional placeholders:

    $sql = << '//';
    UPDATE employees
       SET salary = ?
     WHERE employee_id = ?
    //

    $sth = $dbh->prepare($sql);

=item 2. Prepare a statement using named placeholders:

I<(Yes, even for those MySQL connections!)>

    $sql = << '//';
    UPDATE employees
       SET salary = :salary
     WHERE employee_id = :employee_id
    //

    $sth = $dbh->prepare($sql);

=back

=cut


sub prepare
{
    my ( $dbh, $stmt, @args ) = @_;
    my @params;

    if ( $stmt =~ /:\w+\b/ ) {
        @params = ( $stmt =~ /:(\w+)\b/g );
        $stmt =~ s/:\w+\b/?/g;
    }
    elsif ( $stmt =~ /\@\w+\b/ ) {
        @params = ( $stmt =~ /(\@\w+)\b/g );
        $stmt =~ s/\@\w+\b/?/g;
    }
    elsif ( $stmt =~ /\?\d+\b/ ) {
        @params = ( $stmt =~ /\?(\d+)\b/g );
        $stmt =~ s/\?\d+\b/?/g;
    }
    my $sth = $dbh->SUPER::prepare( $stmt, @args ) or return;
    $sth->{private_using_positionals} = 1;

    if (@params) {
        $sth->{private_auto_binding} = $DBIx::FlexibleBinding::AUTO_BINDING_ENABLED;
        $sth->{private_numeric_placeholders_only} = ( any { /\D/ } @params ) ? 0 : 1;
        $sth->{private_param_counts}              = { map { $_ => 0 } @params };
        $sth->{private_param_order}               = \@params;
        $sth->{private_using_positionals}         = 0;

        for my $param (@params) {
            $sth->{private_param_counts}{$param}++;
        }
    }

    return $sth;
}


=head2 getall_arrayref I<(Database Handles)>

    $results = $dbh->getall_arrayref($statement_string, @bind_values);
    @results = $dbh->getall_arrayref($statement_string, @bind_values);
    $results = $dbh->getall_arrayref($statement_string, \%attr, @bind_values);
    @results = $dbh->getall_arrayref($statement_string, \%attr, @bind_values);
    $results = $dbh->getall_arrayref($statement_handle, @bind_values);
    @results = $dbh->getall_arrayref($statement_handle, @bind_values);

Prepares (if necessary) and executes a single statement with the specified data
bindings and fetches the result set as an array of array references.

The C<getall_arrayref> method accepts optional callbacks for further processing 
of the results by the caller.

=head3 Examples

=over 

=item 1. Prepare, execute it then get the results as a reference:

    $sql = << '//';
    SELECT solarSystemName AS name
         , security
      FROM mapsolarsystems
     WHERE regional  = 1
       AND security >= :minimum_security
    //
    
    $systems = $dbh->getall_arrayref($sql, minimum_security => 1.0);
    
    # Returns a structure something like this:
    #
    # [ [ 'Kisogo',      '1' ],
    #   [ 'New Caldari', '1' ],
    #   [ 'Amarr',       '1' ],
    #   [ 'Bourynes',    '1' ],
    #   [ 'Ryddinjorn',  '1' ],
    #   [ 'Luminaire',   '1' ],
    #   [ 'Duripant',    '1' ],
    #   [ 'Yulai',       '1' ] ]

=item 2. Re-use a prepared statement, execute it then return the results as a list:

We'll use the query from Example 1 but have the results returned as a list for
further processing by the caller.

    $sth = $dbh->prepare($sql);
    
    @systems = $dbh->getall_arrayref($sql, minimum_security => 1.0);
    
    for my $system (@systems) {
        printf "%-11s %.1f\n", @$system;
    }

    # Output:
    #
    # Kisogo      1.0
    # New Caldari 1.0
    # Amarr       1.0
    # Bourynes    1.0
    # Ryddinjorn  1.0
    # Luminaire   1.0
    # Duripant    1.0
    # Yulai       1.0

=item 3. Re-use a prepared statement, execute it then return modified results as a 
reference:

We'll use the query from Example 1 but have the results returned as a list 
for further processing by a caller who will be using callbacks to modify those 
results.

    $sth = $dbh->prepare($sql);
    
    $systems = $dbh->getall_arrayref($sql, minimum_security => 1.0, callback {
        my ($row) = @_;
        return sprintf("%-11s %.1f\n", @$row);
    });
    
    # Returns a structure something like this:
    # 
    # [ 'Kisogo      1.0',
    #   'New Caldari 1.0',
    #   'Amarr       1.0',
    #   'Bourynes    1.0',
    #   'Ryddinjorn  1.0',
    #   'Luminaire   1.0',
    #   'Duripant    1.0',
    #   'Yulai       1.0' ]

=back

=cut


sub getall_arrayref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    if ( !ref($sth) ) {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
        return if $sth->err;
    }

    $sth->execute(@bind_values);
    return if $sth->err;

    return $sth->getall_arrayref($callbacks);
}

=head2 getall_hashref I<(Database Handles)>

    $results = $dbh->getall_hashref($statement_string, @bind_values);
    @results = $dbh->getall_hashref($statement_string, @bind_values);
    $results = $dbh->getall_hashref($statement_string, \%attr, @bind_values);
    @results = $dbh->getall_hashref($statement_string, \%attr, @bind_values);
    $results = $dbh->getall_hashref($statement_handle, @bind_values);
    @results = $dbh->getall_hashref($statement_handle, @bind_values);

Prepares (if necessary) and executes a single statement with the specified data
bindings and fetches the result set as an array of hash references.

The C<getall_hashref> method accepts optional callbacks for further processing 
of the results by the caller.

=head3 Examples

=over 

=item 1. Prepare, execute it then get the results as a reference:

    $sql = << '//';
    SELECT solarSystemName AS name
         , security
      FROM mapsolarsystems
     WHERE regional  = 1
       AND security >= :minimum_security
    //
    
    $systems = $dbh->getall_hashref($sql, minimum_security => 1.0);
    
    # Returns a structure something like this:
    #
    # [ { name => 'Kisogo',      security => '1' },
    #   { name => 'New Caldari', security => '1' },
    #   { name => 'Amarr',       security => '1' },
    #   { name => 'Bourynes',    security => '1' },
    #   { name => 'Ryddinjorn',  security => '1' },
    #   { name => 'Luminaire',   security => '1' },
    #   { name => 'Duripant',    security => '1' },
    #   { name => 'Yulai',       security => '1' } ]

=item 2. Re-use a prepared statement, execute it then return the results as a list:

We'll use the query from Example 1 but have the results returned as a list for
further processing by the caller.

    $sth = $dbh->prepare($sql);
    
    @systems = $dbh->getall_hashref($sql, minimum_security => 1.0);
    
    for my $system (@systems) {
        printf "%-11s %.1f\n", @{$system}{'name', 'security'}; # Hash slice
    }

    # Output:
    #
    # Kisogo      1.0
    # New Caldari 1.0
    # Amarr       1.0
    # Bourynes    1.0
    # Ryddinjorn  1.0
    # Luminaire   1.0
    # Duripant    1.0
    # Yulai       1.0

=item 3. Re-use a prepared statement, execute it then return modified results as a 
reference:

We'll use the query from Example 1 but have the results returned as a list 
for further processing by a caller who will be using callbacks to modify those 
results.

    $sth = $dbh->prepare($sql);
    
    $systems = $dbh->getall_hashref($sql, minimum_security => 1.0, callback {
        sprintf("%-11s %.1f\n", @{$_}{'name', 'security'}); # Hash slice
    });
    
    # Returns a structure something like this:
    # 
    # [ 'Kisogo      1.0',
    #   'New Caldari 1.0',
    #   'Amarr       1.0',
    #   'Bourynes    1.0',
    #   'Ryddinjorn  1.0',
    #   'Luminaire   1.0',
    #   'Duripant    1.0',
    #   'Yulai       1.0' ]

=back

=cut


sub getall_hashref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    if ( !ref($sth) ) {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
        return if $sth->err;
    }

    $sth->execute(@bind_values);
    return if $sth->err;

    return $sth->getall_hashref($callbacks);
}

=head2 getrow_arrayref I<(Database Handles)>

    $result = $dbh->getrow_arrayref($statement_string, @bind_values);
    $result = $dbh->getrow_arrayref($statement_string, \%attr, @bind_values);
    $result = $dbh->getrow_arrayref($statement_handle, @bind_values);

Prepares (if necessary) and executes a single statement with the specified data 
bindings and fetches the first row as an array reference.

The C<getrow_arrayref> method accepts optional callbacks for further processing 
of the result by the caller.

=cut


sub getrow_arrayref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    if ( !ref($sth) ) {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
        return if $sth->err;
    }

    $sth->execute(@bind_values);
    return if $sth->err;

    return $sth->getrow_arrayref($callbacks);
}

=head2 getrow_hashref I<(Database Handles)>

    $result = $dbh->getrow_hashref($statement_string, @bind_values);
    $result = $dbh->getrow_hashref($statement_string, \%attr, @bind_values);
    $result = $dbh->getrow_hashref($statement_handle, @bind_values);

Prepares (if necessary) and executes a single statement with the specified data 
bindings and fetches the first row as a hash reference.

The C<getrow_hashref> method accepts optional callbacks for further processing 
of the result by the caller.

=cut


sub getrow_hashref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    if ( !ref($sth) ) {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
        return if $sth->err;
    }

    $sth->execute(@bind_values);
    return if $sth->err;

    return $sth->getrow_hashref($callbacks);
}

package    # Hide from PAUSE
  DBIx::FlexibleBinding::st;


BEGIN {
    *_dbix_set_err = \&DBIx::FlexibleBinding::_dbix_set_err;
}

use Params::Callbacks qw(callbacks);
use Scalar::Util qw(reftype);
use namespace::clean;

our @ISA = 'DBI::st';


sub _bind_array_ref
{
    my ( $sth, $array_ref ) = @_;

    for ( my $n = 0 ; $n < @$array_ref ; $n++ ) {
        $sth->bind_param( $n + 1, $array_ref->[$n] );
    }

    return $sth;
}


sub _bind_hash_ref
{
    my ( $sth, $hash_ref ) = @_;
    $sth->bind_param( $_, $hash_ref->{$_} ) for keys %$hash_ref;
    return $sth;
}

=head1 STATEMENT HANDLE METHODS

=cut

=head2 auto_bind

    $sth->auto_bind($boolean);
    $state = $sth->auto_bind();

Use this method to enable, disable or inspect the current state of automatic
binding for a particular statement handle.

=cut


sub auto_bind
{
    my ( $sth, $bool ) = @_;
    if ( @_ > 1 ) {
        $sth->{private_auto_binding} = $bool ? 1 : 0;
        return $sth;
    }

    return $sth->{private_auto_binding};
}

=head2 bind

    $sth->bind(@bind_values);       # For positional and numeric placeholders
    $sth->bind(\@bind_values);      # For positional and numeric placeholders
    $sth->bind(%bind_values);       # For numeric and named placeholders
    $sth->bind(\%bind_values);      # For numeric and named placeholders
    $sth->bind([%bind_values]);     # For numeric and named placeholders

The bind method associates (binds) the values supplied in the parameter list with
the placeholders embedded in the prepared statement.

With automatic binding enabled (and it is by default), any operation that results
in a subsequent call to the C<execute> method will almost certainly complete any
parameter binding automatically using this method.

With automatic binding disabled, this method will not be called at all and the
execute method will almost dutifully convey bind values as they are presented up
the DBI inheritance chain to the handler's execute method. I<Almost dutifully>
because a lone array reference will be de-referenced and passed up as a list. The
general assumption here is that you won't present any bind values because the hard
work of doing the C<bind_param> calls has already been done, or a manual call to
the C<bind> method has already taken place.

In any case, it's pretty hard to screw-up when relying on this method to bind
your data values. Provided that what you present can be interpreted as a list of
values for positional placeholders, a list of key-value pairs for named
placeholders, or either for numeric placeholders, then you'll be absolutely
fine.

=cut


sub bind
{
    my ( $sth, @args ) = @_;
    return $sth unless @args;
    return $sth->_bind_array_ref( \@args ) if $sth->{private_using_positionals};

    my $ref = ( @args == 1 ) && reftype( $args[0] );

    if ($ref) {

        return
          _dbix_set_err( $sth,
                  'A reference to either a HASH or ARRAY was expected for autobind operation' )
          unless $ref eq 'HASH' || $ref eq 'ARRAY';

        if ( $ref eq 'HASH' ) {
            $sth->_bind_hash_ref( $args[0] );
        }
        else {
            if ( $sth->{private_numeric_placeholders_only} ) {
                $sth->_bind_array_ref( $args[0] );
            }
            else {
                $sth->_bind_hash_ref( { @{ $args[0] } } );
            }
        }
    }
    else {
        if (@args) {
            if ( $sth->{private_numeric_placeholders_only} ) {
                $sth->_bind_array_ref( \@args );
            }
            else {
                $sth->_bind_hash_ref( {@args} );
            }
        }
    }

    return $sth;
}


=head2 bind_param

    $sth->bind_param($param_num, $bind_value)
    $sth->bind_param($param_num, $bind_value, \%attr)
    $sth->bind_param($param_num, $bind_value, $bind_type)

    $sth->bind_param($param_name, $bind_value)
    $sth->bind_param($param_name, $bind_value, \%attr)
    $sth->bind_param($param_name, $bind_value, $bind_type)

The C<bind_param> method associates (binds) a value to a placeholder embedded in the
prepared statement. The implementation provided by this module allows the use of
parameter names, if appropriate, in addition to parameter positions.

I<Refer to L<http://search.cpan.org/dist/DBI/DBI.pm#bind_param> for a more detailed
explanation of how to use this method>.


=cut


sub bind_param
{
    my ( $sth, $param, $value, $attr ) = @_;
    return _dbix_set_err( $sth, "Binding identifier is missing" )
      unless defined($param) && $param;

    return _dbix_set_err( $sth, 'Binding identifier "' . $param . '" is malformed' )
      if $param =~ /[^\@\w]/;

    return $sth->SUPER::bind_param( $param, $value, $attr )
      if $sth->{private_using_positionals};

    my $bind_rv = undef;
    my $pos     = 0;
    my $count   = 0;

    for my $name_or_number ( @{ $sth->{private_param_order} } ) {
        $pos += 1;
        next if $name_or_number ne $param;

        $count += 1;
        last if $count > $sth->{private_param_counts}{$param};

        $bind_rv = $sth->SUPER::bind_param( $pos, $value, $attr );
    }

    return $bind_rv;
}

=head2 execute

    $rv = $sth->execute;
    $rv = $sth->execute(@bind_values);

Perform whatever processing is necessary to execute the prepared statement. An
undef is returned if an error occurs. A successful execute always returns true
regardless of the number of rows affected, even if it's zero.

I<Refer to L<http://search.cpan.org/dist/DBI/DBI.pm#execute> for a more detailed
explanation of how to use this method>.

=cut


sub execute
{
    my ( $sth, @bind_values ) = @_;
    my $rows;

    if ( $sth->{private_auto_binding} ) {
        $sth->bind(@bind_values);
        $rows = $sth->SUPER::execute();
    }
    else {
        if (    @bind_values == 1
             && ref( $bind_values[0] )
             && reftype( $bind_values[0] ) eq 'ARRAY' )
        {
            $rows = $sth->SUPER::execute( @{ $bind_values[0] } );
        }
        else {
            $rows = $sth->SUPER::execute(@bind_values);
        }
    }

    return ( $rows == 0 ) ? '0E0' : $rows;
}

=head2 getall_arrayref I<(Statement Handles)>

    $results = $sth->getall_arrayref();
    @results = $sth->getall_arrayref();

Fetches the entire result set as an array of array references.

The C<getall_arrayref> method accepts optional callbacks for further processing 
of the results by the caller.

=cut


sub getall_arrayref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchall_arrayref();

    if ($result) {
        unless ( $sth->err ) {
            if (@$callbacks) {
                local $_;
                $result = [ map { $callbacks->transform($_) } @$result ];
            }
        }
    }

    return $result unless defined $result;
    return wantarray ? @$result : $result;
}

=head2 getall_hashref I<(Statement Handles)>

    $results = $sth->getall_hashref();
    @results = $sth->getall_hashref();

Fetches the entire result set as an array of hash references.

The C<getall_hashref> method accepts optional callbacks for further processing 
of the results by the caller.

=cut


sub getall_hashref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchall_arrayref( {} );

    if ($result) {
        unless ( $sth->err ) {
            if (@$callbacks) {
                local $_;
                $result = [ map { $callbacks->transform($_) } @$result ];
            }
        }
    }

    return $result unless defined $result;
    return wantarray ? @$result : $result;
}

=head2 getrow_arrayref I<(Statement Handles)>

    $result = $sth->getrow_arrayref();

Fetches the next row as an array reference. Returns C<undef> if there are no more
rows available.

The C<getrow_arrayref> method accepts optional callbacks for further processing
of the result by the caller.

=cut


sub getrow_arrayref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchrow_arrayref();

    if ($result) {
        unless ( $sth->err ) {
            $result = [@$result];

            if (@$callbacks) {
                local $_;
                $result = $callbacks->smart_transform( $_ = $result );
            }
        }
    }

    return $result;
}


=head2 getrow_hashref I<(Statement Handles)>

    $result = $sth->getrow_hashref();

Fetches the next row as a hash reference. Returns C<undef> if there are no more
rows available.

The C<getrow_hashref> method accepts optional callbacks for further processing 
of the result by the caller.

=cut


sub getrow_hashref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchrow_hashref();

    if ($result) {
        unless ( $sth->err ) {
            if (@$callbacks) {
                local $_;
                $result = $callbacks->smart_transform( $_ = $result );
            }
        }
    }

    return $result;
}


package    # Hide from PAUSE
  DBIx::FlexibleBinding::ObjectProxy;

use Carp 'confess';
use Scalar::Util 'blessed';
use Sub::Name;
use namespace::clean;

use Test::More;
use YAML::Syck 'Dump';

our $AUTOLOAD;

my %proxies;


sub create
{
    my ( $class, $name, $caller ) = @_;
    $class = ref($class) || $class;
    no strict 'refs';    ## no critic [TestingAndDebugging::ProhibitNoStrict]
    *{ $caller . '::' . $name }
      = subname( $name => sub { $class->handle( $name, @_ ) } );
    return $class->get($name);
}


sub handle
{
    my ( $self, $name, @args ) = &get;

    if (@args) {
        if ( @args == 1 && !defined( $args[0] ) ) {
            $self->assign_nothing();
        }
        elsif ( @args == 1 && blessed( $args[0] ) ) {
            if ( $args[0]->isa('DBI::db') ) {
                $self->assign_database_connection(@args);
            }
            elsif ( $args[0]->isa('DBI::st') ) {
                $self->assign_statement(@args);
            }
            else {
                confess "A database or statement handle was expected";
            }
        }
        elsif ( $args[0] =~ /^dbi:/i ) {
            $self->assign_database_connection(@args);
        }
        else {
            return $self->process(@args);
        }
    }

    return $self->{target};
}


sub get
{
    my ( $class, $name, @args ) = @_;
    $class = ref($class) || $class;
    my $self = $proxies{$name};

    unless ( defined $self ) {
        $self = bless( { name => $name }, $class );
        $proxies{$name} = $self->assign_nothing();
    }

    return ( $self, $name, @args );
}


sub assign_nothing
{
    my ($self) = @_;
    delete $self->{target} if exists $self->{target};
    return bless( $self, 'DBIx::FlexibleBinding::UnassignedProxy' );
}


sub assign_database_connection
{
    my ( $self, @args ) = @_;

    if ( @args == 1 && blessed( $args[0] ) ) {
        confess "Expected a database handle" unless $args[0]->isa('DBI::db');
        $self->{target} = $args[0];
        bless $self->{target}, 'DBIx::FlexibleBinding::db'
          unless $self->{target}->isa('DBIx::FlexibleBinding::db');
    }
    else {
        confess "Expected a set of database connection parameters"
          unless $args[0] =~ /^dbi:/i;
        $self->{target} = DBIx::FlexibleBinding->connect(@args);
    }

    return bless( $self, 'DBIx::FlexibleBinding::DatabaseConnectionProxy' );
}


sub assign_statement
{
    my ( $self, @args ) = @_;

    confess "Expected a statement handle" unless $args[0]->isa('DBI::st');
    $self->{target} = $args[0];
    bless $self->{target}, 'DBIx::FlexibleBinding::st'
      unless $self->{target}->isa('DBIx::FlexibleBinding::st');
    return bless( $self, 'DBIx::FlexibleBinding::StatementProxy' );
}


sub AUTOLOAD
{
    my ( $self, @args ) = @_;
    ( my $method = $AUTOLOAD ) =~ s/.*:://;
    unless ( defined &$AUTOLOAD ) {
        no strict 'refs';    ## no critic [TestingAndDebugging::ProhibitNoStrict]
        my $endpoint = $self->{target}->can($method) or confess "Invalid method '$method'";
        *$AUTOLOAD = sub {
            my ( $object, @args ) = @_;
            $object->{target}->$method(@args);
        };
    }
    goto &$AUTOLOAD;
}


package                      # Hide from PAUSE
  DBIx::FlexibleBinding::UnassignedProxy;

our @ISA = 'DBIx::FlexibleBinding::ObjectProxy';


package                      # Hide from PAUSE
  DBIx::FlexibleBinding::DatabaseConnectionProxy;

use Carp 'confess';

our @ISA = 'DBIx::FlexibleBinding::ObjectProxy';


package                      # Hide from PAUSE
  DBIx::FlexibleBinding::StatementProxy;


use Carp 'confess';

our @ISA = 'DBIx::FlexibleBinding::ObjectProxy';


sub process
{
    my ( $self, @args ) = @_;

    if ( $self->{target}->isa('DBIx::FlexibleBinding::st') ) {
        if ( $self->{target}->{NUM_OF_PARAMS} ) {
            $self->{target}->execute(@args);
        }
        else {
            $self->{target}->execute();
        }
    }

    return $self->{target}->$PROXIES_GETALL_USING(@args);
}

1;

=head1 EXPORTS

The following symbols are exported by default:

=head2 callback

To enable the namespace using this module to take advantage of the callbacks,
which are one of its main features, without the unnecessary burden of also
including the module that provides the feature I<(see L<Params::Callbacks> for
more detailed information)>.

=cut

=pod

=head1 SEE ALSO

=over 2

=item * L<DBI>

=item * L<Params::Callbacks>

=back

=head1 REPOSITORY

=over 2

=item * L<https://github.com/cpanic/DBIx-FlexibleBinding>

=item * L<http://search.cpan.org/dist/DBIx-FlexibleBinding/lib/DBIx/FlexibleBinding.pm>

=back

=head1 BUGS

Please report any bugs or feature requests to C<bug-dbix-anybinding at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-FlexibleBinding>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::FlexibleBinding


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-FlexibleBinding>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DBIx-FlexibleBinding>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DBIx-FlexibleBinding>

=item * Search CPAN

L<http://search.cpan.org/dist/DBIx-FlexibleBinding/>

=back

=head1 ACKNOWLEDGEMENTS

Test data set extracted from Fuzzwork's MySQL conversion of CCP's EVE Online Static
Data Export:

=over 2

=item * Fuzzwork L<https://www.fuzzwork.co.uk/>

=item * EVE Online L<http://www.eveonline.com/>

=back

Eternal gratitude to GitHub contributors:

=over 2

=item * Syohei Yoshida L<http://search.cpan.org/~syohex/>

=back

=head1 AUTHOR

Iain Campbell <cpanic@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012-2015 by Iain Campbell.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
