
=head1 NAME

DBIx::FlexibleBinding - Greater flexibility on statement placeholder choice and data binding

=head1 VERSION

version 2.0.0

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
    my @system_names = $sth->getrows_hashref(callback { $_->{name} });

    ############################################################################
    # SCENARIO 2                                                               #
    # Let's simplify the previous scenario using the database handle's version #
    # of that getrows_hashref method.                                       #
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
    my @system_names = $dbh->getrows_hashref(SQL,
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

=item * C<getrows_arrayref>

=item * C<getrows_hashref>

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

use strict;
use warnings;

package DBIx::FlexibleBinding;
our $VERSION = '2.0.0'; # VERSION
# ABSTRACT: Greater flexibility on statement placeholder choice and data binding.
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

=cut

our $AUTO_BINDING_ENABLED = 1;

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
our $VERSION = '2.0.0'; # VERSION

use Carp 'confess';
use Params::Callbacks 'callbacks';
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

B<Examples>

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

B<Examples>

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
    return $sth->_init_private_attributes( \@params );
}

=head2 getrows_arrayref I<(database handles)>

    $results = $dbh->getrows_arrayref($statement_string, @bind_values);
    @results = $dbh->getrows_arrayref($statement_string, @bind_values);
    $results = $dbh->getrows_arrayref($statement_string, \%attr, @bind_values);
    @results = $dbh->getrows_arrayref($statement_string, \%attr, @bind_values);
    $results = $dbh->getrows_arrayref($statement_handle, @bind_values);
    @results = $dbh->getrows_arrayref($statement_handle, @bind_values);

Prepares (if necessary) and executes a single statement with the specified data
bindings and fetches the result set as an array of array references.

The C<getrows_arrayref> method accepts optional callbacks for further processing
of the results by the caller.

B<Examples>

=over

=item 1. Prepare, execute it then get the results as a reference:

    $sql = << '//';
    SELECT solarSystemName AS name
         , security
      FROM mapsolarsystems
     WHERE regional  = 1
       AND security >= :minimum_security
    //

    $systems = $dbh->getrows_arrayref($sql, minimum_security => 1.0);

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

    @systems = $dbh->getrows_arrayref($sql, minimum_security => 1.0);

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

    $systems = $dbh->getrows_arrayref($sql, minimum_security => 1.0, callback {
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

sub getrows_arrayref
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

    return $sth->getrows_arrayref($callbacks);
}

=head2 getrows_hashref I<(database handles)>

    $results = $dbh->getrows_hashref($statement_string, @bind_values);
    @results = $dbh->getrows_hashref($statement_string, @bind_values);
    $results = $dbh->getrows_hashref($statement_string, \%attr, @bind_values);
    @results = $dbh->getrows_hashref($statement_string, \%attr, @bind_values);
    $results = $dbh->getrows_hashref($statement_handle, @bind_values);
    @results = $dbh->getrows_hashref($statement_handle, @bind_values);

Prepares (if necessary) and executes a single statement with the specified data
bindings and fetches the result set as an array of hash references.

The C<getrows_hashref> method accepts optional callbacks for further processing
of the results by the caller.

B<Examples>

=over

=item 1. Prepare, execute it then get the results as a reference:

    $sql = << '//';
    SELECT solarSystemName AS name
         , security
      FROM mapsolarsystems
     WHERE regional  = 1
       AND security >= :minimum_security
    //

    $systems = $dbh->getrows_hashref($sql, minimum_security => 1.0);

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

    @systems = $dbh->getrows_hashref($sql, minimum_security => 1.0);

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

    $systems = $dbh->getrows_hashref($sql, minimum_security => 1.0, callback {
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

sub getrows_hashref
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

    return $sth->getrows_hashref($callbacks);
}

=head2 getrows I<(database handles)>

    $results = $dbh->getrows($statement_string, @bind_values);
    @results = $dbh->getrows($statement_string, @bind_values);
    $results = $dbh->getrows($statement_string, \%attr, @bind_values);
    @results = $dbh->getrows($statement_string, \%attr, @bind_values);
    $results = $dbh->getrows($statement_handle, @bind_values);
    @results = $dbh->getrows$statement_handle, @bind_values);

Alias for C<getrows_hashref>.

If array references are preferred, have the symbol table glob point alias the 
C<getrows_arrayref> method.

The C<getrows> method accepts optional callbacks for further processing
of the results by the caller.

=cut

BEGIN { *getrows = \&getrows_hashref }

=head2 getrow_arrayref I<(database handles)>

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

=head2 getrow_hashref I<(database handles)>

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

=head2 getrow I<(database handles)>

    $result = $dbh->getrow($statement_string, @bind_values);
    $result = $dbh->getrow($statement_string, \%attr, @bind_values);
    $result = $dbh->getrow($statement_handle, @bind_values);

Alias for C<getrow_hashref>.

If array references are preferred, have the symbol table glob point alias the 
C<getrows_arrayref> method.

The C<getrow> method accepts optional callbacks for further processing
of the result by the caller.

=cut

BEGIN { *getrow = \&getrow_hashref }

package    # Hide from PAUSE
    DBIx::FlexibleBinding::st;
our $VERSION = '2.0.0'; # VERSION

use Carp 'confess';
use List::MoreUtils 'any';
use Params::Callbacks 'callbacks';
use Scalar::Util 'reftype';
use namespace::clean;

our @ISA = 'DBI::st';

sub _init_private_attributes
{
    my ( $sth, $params_arrayref ) = @_;

    if ( ref($params_arrayref) && reftype($params_arrayref) eq 'ARRAY' ) {
        $sth->_param_order($params_arrayref);
        return $sth->_using_positional(1) unless @$params_arrayref;

        $sth->_auto_bind($DBIx::FlexibleBinding::AUTO_BINDING_ENABLED);

        my $param_count = $sth->_param_count;
        for my $param (@$params_arrayref) {
            if ( defined $param_count->{$param} ) {
                $param_count->{$param}++;
            }
            else {
                $param_count->{$param} = 1;
            }
        }

        return $sth->_using_named(1) if any {/\D/} @$params_arrayref;
        return $sth->_using_numbered(1);
    }

    return $sth;
}

sub _auto_bind
{
    if ( @_ > 1 ) {
        $_[0]{private_dbix_flexbind}{auto_bind} = !!$_[1];
        return $_[0];
    }

    return $_[0]{private_dbix_flexbind}{auto_bind};
}

sub _param_count
{
    if ( @_ > 1 ) {
        $_[0]{private_dbix_flexbind}{param_count} = $_[1];
        return $_[0];
    }
    else {
        $_[0]{private_dbix_flexbind}{param_count} = {}
            unless exists $_[0]{private_dbix_flexbind}{param_count};
    }

    return %{ $_[0]{private_dbix_flexbind}{param_count} } if wantarray;
    return $_[0]{private_dbix_flexbind}{param_count};
}

sub _param_order
{
    if ( @_ > 1 ) {
        $_[0]{private_dbix_flexbind}{param_order} = $_[1];
        return $_[0];
    }
    else {
        $_[0]{private_dbix_flexbind}{param_order} = []
            unless exists $_[0]{private_dbix_flexbind}{param_order};
    }

    return @{ $_[0]{private_dbix_flexbind}{param_order} } if wantarray;
    return $_[0]{private_dbix_flexbind}{param_order};
}

sub _using_named
{
    if ( @_ > 1 ) {
        # If new value is true, set alternatives to false to save us the overhead
        # of making the other two calls that would have had to be made anyway.
        # Apologies for the terse code, these need to be zippy because they're
        # called a lot, and often in loops.            +--(naughty assignment)
        #                                              v
        if ( $_[0]{private_dbix_flexbind}{using_named} = !!$_[1] ) {
            $_[0]{private_dbix_flexbind}{using_numbered}   = '';
            $_[0]{private_dbix_flexbind}{using_positional} = '';
        }
        return $_[0];
    }

    return $_[0]{private_dbix_flexbind}{using_named};
}

sub _using_numbered
{
    if ( @_ > 1 ) {
        # If new value is true, set alternatives to false to save us the overhead
        # of making the other two calls that would have had to be made anyway.
        # Apologies for the terse code, these need to be zippy because they're
        # called a lot, and often in loops.               +--(naughty assignment)
        #                                                 v
        if ( $_[0]{private_dbix_flexbind}{using_numbered} = !!$_[1] ) {
            $_[0]{private_dbix_flexbind}{using_named}      = '';
            $_[0]{private_dbix_flexbind}{using_positional} = '';
        }
        return $_[0];
    }

    return $_[0]{private_dbix_flexbind}{using_numbered};
}

sub _using_positional
{
    if ( @_ > 1 ) {
        # If new value is true, set alternatives to false to save us the overhead
        # of making the other two calls that would have had to be made anyway.
        # Apologies for the terse code, these need to be zippy because they're
        # called a lot, and often in loops.                 +--(naughty assignment)
        #                                                   v
        if ( $_[0]{private_dbix_flexbind}{using_positional} = !!$_[1] ) {
            $_[0]{private_dbix_flexbind}{using_numbered} = '';
            $_[0]{private_dbix_flexbind}{using_named}    = '';
        }
        return $_[0];
    }

    return $_[0]{private_dbix_flexbind}{using_positional};
}

sub _bind_arrayref
{
    my ( $sth, $arrayref ) = @_;

    for ( my $n = 0; $n < @$arrayref; $n++ ) {
        $sth->bind_param( $n + 1, $arrayref->[$n] );
    }

    return $sth;
}

sub _bind_hashref
{
    my ( $sth, $hashref ) = @_;

    while ( my ( $k, $v ) = each %$hashref ) {
        $sth->bind_param( $k, $v );
    }

    return $sth;
}

sub _bind
{
    my ( $sth, @args ) = @_;
    return $sth unless @args;
    return $sth->_bind_arrayref( \@args ) if $sth->_using_positional;

    my $ref = ( @args == 1 ) && reftype( $args[0] );

    if ($ref) {
        unless ( $ref eq 'HASH' || $ref eq 'ARRAY' ) {
            return $sth->set_err( $DBI::stderr, 'Expected a reference to a HASH or ARRAY' );
        }

        return $sth->_bind_hashref( $args[0] )  if $ref eq 'HASH';
        return $sth->_bind_arrayref( $args[0] ) if $sth->_using_numbered;
        return $sth->_bind_hashref( { @{ $args[0] } } );
    }
    else {
        if (@args) {
            return $sth->_bind_arrayref( \@args ) if $sth->_using_numbered;
            return $sth->_bind_hashref( {@args} );
        }
    }

    return $sth;
}

=head1 STATEMENT HANDLE METHODS

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

    unless ( !!$param ) {
        return $sth->set_err( $DBI::stderr, "Binding identifier is missing" );
    }

    if ( $param =~ /[^\@\w]/ ) {
        return $sth->set_err( $DBI::stderr,
                              'Malformed binding identifier "' . $param . '"' );
    }

    my $bind_rv;

    if ( $sth->_using_positional ) {
        $bind_rv = $sth->SUPER::bind_param( $param, $value, $attr );
    }
    else {
        my $pos         = 0;
        my $count       = 0;
        my $param_count = $sth->_param_count;

        for my $identifier ( $sth->_param_order ) {
            $pos++;

            if ( $identifier eq $param ) {
                $count++;
                last if $count > $param_count->{$param};
                $bind_rv = $sth->SUPER::bind_param( $pos, $value, $attr );
            }
        }
    }

    return $bind_rv;
}

=head2 execute

    $rv = $sth->execute() or die $DBI::errstr;
    $rv = $sth->execute(@bind_values) or die $DBI::errstr;

Perform whatever processing is necessary to execute the prepared statement. An
C<undef> is returned if an error occurs. A successful call returns true regardless
of the number of rows affected, even if it's zero.

Refer to L<http://search.cpan.org/dist/DBI/DBI.pm#execute> for a more detailed
description of this method.

B<Examples>

=over

=item Use prepare, execute and getrow_hashref with a callback to modify my data:

    use strict;
    use warnings;

    use DBIx::FlexibleBinding -subs => [ 'TestDB' ];
    use Data::Dumper;
    use Test::More;

    $Data::Dumper::Terse  = 1;
    $Data::Dumper::Indent = 1;

    TestDB 'dbi:mysql:test', '', '', { RaiseError => 1 };

    my $sth = TestDB->prepare(<< '//');
       SELECT solarSystemID   AS id
            , solarSystemName AS name
            , security
         FROM mapsolarsystems
        WHERE solarSystemName RLIKE "^U[^0-9\-]+$"
     ORDER BY id, name, security DESC
        LIMIT 5
    //

    $sth->execute() or die $DBI::errstr;

    my @rows;
    my @callback_list = (
        callback {
            my ($row) = @_;
            $row->{filled_with} = ( $row->{security} >= 0.5 )
                ? 'Carebears' : 'Yarrbears';
            $row->{security} = sprintf('%.1f', $row->{security});
            return $row;
        }
    );

    while ( my $row = $sth->getrow_hashref(@callback_list) ) {
        push @rows, $row;
    }

    my $expected_result = [
       {
         'name' => 'Uplingur',
         'filled_with' => 'Yarrbears',
         'id' => '30000037',
         'security' => '0.4'
       },
       {
         'security' => '0.4',
         'id' => '30000040',
         'name' => 'Uzistoon',
         'filled_with' => 'Yarrbears'
       },
       {
         'name' => 'Usroh',
         'filled_with' => 'Carebears',
         'id' => '30000068',
         'security' => '0.6'
       },
       {
         'filled_with' => 'Yarrbears',
         'name' => 'Uhtafal',
         'id' => '30000101',
         'security' => '0.5'
       },
       {
         'security' => '0.3',
         'id' => '30000114',
         'name' => 'Ubtes',
         'filled_with' => 'Yarrbears'
       }
    ];

    is_deeply( \@rows, $expected_result, 'iterate' )
        and diag( Dumper(\@rows) );
    done_testing();

=back

=cut

sub execute
{
    my ( $sth, @bind_values ) = @_;
    my $rows;

    if ( $sth->_auto_bind ) {
        $sth->_bind(@bind_values);
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

    return $rows;
}

=head2 iterate

    $iterator = $sth->iterate() or die $DBI::errstr;
    $iterator = $sth->iterate(@bind_values) or die $DBI::errstr;

Perform whatever processing is necessary to execute the prepared statement. An
C<undef> is returned if an error occurs. A successful call returns an iterator
which can be used to traverse the result set.

B<Examples>

=over

=item 1. Using an iterator and callbacks to process the result set:

    use strict;
    use warnings;

    use DBIx::FlexibleBinding -subs => [ 'TestDB' ];
    use Data::Dumper;
    use Test::More;

    $Data::Dumper::Terse  = 1;
    $Data::Dumper::Indent = 1;

    my @drivers = grep { /^SQLite$/ } DBI->available_drivers();

    SKIP: {
      skip("iterate tests (No DBD::SQLite installed)", 1) unless @drivers;

      TestDB "dbi:SQLite:test.db", '', '', { RaiseError => 1 };

      my $sth = TestDB->prepare(<< '//');
       SELECT solarSystemID   AS id
            , solarSystemName AS name
            , security
         FROM mapsolarsystems
        WHERE solarSystemName REGEXP "^U[^0-9\-]+$"
     ORDER BY id, name, security DESC
        LIMIT 5
    //

    # Iterate over the result set
    # ---------------------------
    # We also queue up a sneaky callback to modify each row of data as it
    # is fetched from the result set.

      my $it = $sth->iterate( callback {
          my ($row) = @_;
          $row->{filled_with} = ( $row->{security} >= 0.5 )
              ? 'Carebears' : 'Yarrbears';
          $row->{security} = sprintf('%.1f', $row->{security});
          return $row;
      } );

      my @rows;
      while ( my $row = $it->() ) {
          push @rows, $row;
      }

    # Done, now check the results ...

      my $expected_result = [
         {
           'name' => 'Uplingur',
           'filled_with' => 'Yarrbears',
           'id' => '30000037',
           'security' => '0.4'
         },
         {
           'security' => '0.4',
           'id' => '30000040',
           'name' => 'Uzistoon',
           'filled_with' => 'Yarrbears'
         },
         {
           'name' => 'Usroh',
           'filled_with' => 'Carebears',
           'id' => '30000068',
           'security' => '0.6'
         },
         {
           'filled_with' => 'Yarrbears',
           'name' => 'Uhtafal',
           'id' => '30000101',
           'security' => '0.5'
         },
         {
           'security' => '0.3',
           'id' => '30000114',
           'name' => 'Ubtes',
           'filled_with' => 'Yarrbears'
         }
      ];

      is_deeply( \@rows, $expected_result, 'iterate' )
          and diag( Dumper(\@rows) );
    }

    done_testing();

In this example, we're traversing the result set using an iterator. As we iterate
through the result set, a callback is applied to each row and we're left with
an array of transformed rows.

=item 2. Using an iterator's C<for_each> method and callbacks to process the
result set:

    use strict;
    use warnings;

    use DBIx::FlexibleBinding -subs => [ 'TestDB' ];
    use Data::Dumper;
    use Test::More;

    $Data::Dumper::Terse  = 1;
    $Data::Dumper::Indent = 1;

    my @drivers = grep { /^SQLite$/ } DBI->available_drivers();

    SKIP: {
      skip("iterate tests (No DBD::SQLite installed)", 1) unless @drivers;

      TestDB "dbi:SQLite:test.db", '', '', { RaiseError => 1 };

      my $sth = TestDB->prepare(<< '//');
       SELECT solarSystemID   AS id
            , solarSystemName AS name
            , security
         FROM mapsolarsystems
        WHERE solarSystemName REGEXP "^U[^0-9\-]+$"
     ORDER BY id, name, security DESC
        LIMIT 5
    //

    # Iterate over the result set
    # ---------------------------
    # This time around we call the iterator's "for_each" method to process
    # the data. Bonus: we haven't had to store the iterator anywhere or
    # pre-declare an empty array to accommodate our rows.

      my @rows = $sth->iterate->for_each( callback {
          my ($row) = @_;
          $row->{filled_with} = ( $row->{security} >= 0.5 )
              ? 'Carebears' : 'Yarrbears';
          $row->{security} = sprintf('%.1f', $row->{security});
          return $row;
      } );

    # Done, now check the results ...

      my $expected_result = [
         {
           'name' => 'Uplingur',
           'filled_with' => 'Yarrbears',
           'id' => '30000037',
           'security' => '0.4'
         },
         {
           'security' => '0.4',
           'id' => '30000040',
           'name' => 'Uzistoon',
           'filled_with' => 'Yarrbears'
         },
         {
           'name' => 'Usroh',
           'filled_with' => 'Carebears',
           'id' => '30000068',
           'security' => '0.6'
         },
         {
           'filled_with' => 'Yarrbears',
           'name' => 'Uhtafal',
           'id' => '30000101',
           'security' => '0.5'
         },
         {
           'security' => '0.3',
           'id' => '30000114',
           'name' => 'Ubtes',
           'filled_with' => 'Yarrbears'
         }
      ];

      is_deeply( \@rows, $expected_result, 'iterate' )
          and diag( Dumper(\@rows) );
    }

    done_testing();

Like the previous example, we're traversing the result set using an iterator but
this time around we have done away with C<$it> in favour of calling the iterator's
own C<for_each> method. The callback we were using to process each row of the
result set has now been passed into the C<for_each> method also eliminating a
C<while> loop and an empty declaration for C<@rows>.

=back

=cut

sub iterate
{
    my ( $callbacks, $sth, @bind_values ) = &callbacks;
    my $rows = $sth->execute(@bind_values);
    return $rows unless defined $rows;
    DBIx::FlexibleBinding::Iterator->new( sub { $sth->getrow($callbacks) } );
}

=head2 getrows_arrayref I<(database handles)>

    $results = $sth->getrows_arrayref();
    @results = $sth->getrows_arrayref();

Fetches the entire result set as an array of array references.

The C<getrows_arrayref> method accepts optional callbacks for further processing
of the results by the caller.

=cut

sub getrows_arrayref
{
    local $_;
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchall_arrayref();

    if ($result) {
        unless ( $sth->err ) {
            if (@$callbacks) {
                $result = [ map { $callbacks->transform($_) } @$result ];
            }
        }
    }

    return $result unless defined $result;
    return wantarray ? @$result : $result;
}

=head2 getrows_hashref I<(database handles)>

    $results = $sth->getrows_hashref();
    @results = $sth->getrows_hashref();

Fetches the entire result set as an array of hash references.

The C<getrows_hashref> method accepts optional callbacks for further processing
of the results by the caller.

=cut

sub getrows_hashref
{
    local $_;
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchall_arrayref( {} );

    if ($result) {
        unless ( $sth->err ) {
            if (@$callbacks) {
                $result = [ map { $callbacks->transform($_) } @$result ];
            }
        }
    }

    return $result unless defined $result;
    return wantarray ? @$result : $result;
}

=head2 getrows I<(database handles)>

    $results = $sth->getrows();
    @results = $sth->getrows();

Alias for C<getrows_hashref>.

If array references are preferred, have the symbol table glob point alias the 
C<getrows_arrayref> method.

The C<getrows> method accepts optional callbacks for further processing
of the results by the caller.

=cut

BEGIN { *getrows = \&getrows_hashref }

=head2 getrow_arrayref I<(database handles)>

    $result = $sth->getrow_arrayref();

Fetches the next row as an array reference. Returns C<undef> if there are no more
rows available.

The C<getrow_arrayref> method accepts optional callbacks for further processing
of the result by the caller.

=cut

sub getrow_arrayref
{
    local $_;
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchrow_arrayref();

    if ($result) {
        unless ( $sth->err ) {
            $result = [@$result];

            if (@$callbacks) {
                $result = $callbacks->smart_transform( $_ = $result );
            }
        }
    }

    return $result;
}

=head2 getrow_hashref I<(database handles)>

    $result = $sth->getrow_hashref();

Fetches the next row as a hash reference. Returns C<undef> if there are no more
rows available.

The C<getrow_hashref> method accepts optional callbacks for further processing
of the result by the caller.

=cut

sub getrow_hashref
{
    local $_;
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchrow_hashref();

    if ($result) {
        unless ( $sth->err ) {
            if (@$callbacks) {
                $result = $callbacks->smart_transform( $_ = $result );
            }
        }
    }

    return $result;
}

=head2 getrow I<(database handles)>

    $result = $sth->getrow();

Alias for C<getrow_hashref>.

If array references are preferred, have the symbol table glob point alias the 
C<getrows_arrayref> method.

The C<getrow> method accepts optional callbacks for further processing
of the result by the caller.

=cut

BEGIN { *getrow = \&getrow_hashref }

package    # Hide from PAUSE
    DBIx::FlexibleBinding::ObjectProxy;
our $VERSION = '2.0.0'; # VERSION

use Carp 'confess';
use Scalar::Util 'blessed';
use Sub::Install ();
use namespace::clean;

our $AUTOLOAD;

my %proxies;

sub create
{
    my ( $class, $name, $caller ) = @_;
    $class = ref($class) || $class;
    Sub::Install::install_sub(
        { code => sub { $class->handle( $name, @_ ) },
          into => $caller,
          as   => $name
        }
    );
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
our $VERSION = '2.0.0'; # VERSION

our @ISA = 'DBIx::FlexibleBinding::ObjectProxy';

package                      # Hide from PAUSE
    DBIx::FlexibleBinding::DatabaseConnectionProxy;
our $VERSION = '2.0.0'; # VERSION

use Carp 'confess';

our @ISA = 'DBIx::FlexibleBinding::ObjectProxy';

package                      # Hide from PAUSE
    DBIx::FlexibleBinding::StatementProxy;
our $VERSION = '2.0.0'; # VERSION

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

    return $self->{target}->getrows(@args);
}

package    # Hide from PAUSE
    DBIx::FlexibleBinding::Iterator;
our $VERSION = '2.0.0'; # VERSION

use Carp 'confess';
use Params::Callbacks 'callbacks';
use Scalar::Util 'reftype';
use namespace::clean;

sub new
{
    my ( $class, $coderef ) = @_;
    confess "Expected a code reference"
        unless ref($coderef) && reftype($coderef) eq 'CODE';
    $class = ref($class) || $class;
    bless $coderef, $class;
}

sub for_each
{
    local $_;
    my ( $callbacks, $self ) = &callbacks;
    my @results;

    while ( my @items = $self->() ) {
        last if @items == 1 && !defined( $items[0] );
        push @results, map { $callbacks->transform($_) } @items;
    }

    return @results;
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
