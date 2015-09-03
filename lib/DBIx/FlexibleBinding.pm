package DBIx::FlexibleBinding;

=pod

=head1 NAME

DBIx::FlexibleBinding - Flexible parameter binding and record fetching

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
    my @system_names = $sth->processall_hashref(callback { $_->{name} });

    ############################################################################
    # SCENARIO 2                                                               #
    # Let's simplify the previous scenario using the database handle's version #
    # of that processall_hashref method.                                       #
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
    my @system_names = $dbh->processall_hashref(SQL,
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

=head1 DESCRIPTION

This module subclasses the DBI to provide improvements and greater flexibility
in the following areas:

=over 2

=item * Accessing and interacting with datasources

=item * Parameter placeholders and data binding

=item * Data retrieval and processing

=back

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

=item * C<processrow_arrayref>

=item * C<processrow_hashref>

=item * C<processall_arrayref>

=item * C<processall_hashref>

=back

These methods complement DBI's existing fetch methods, providing new ways to
retrieve and process data.

=cut

use 5.006;
use strict;
use warnings;
use Carp qw(confess);
use Exporter ();
use DBI      ();
use MRO::Compat 'c3';
use Scalar::Util qw(reftype blessed);
use Sub::Name;
use namespace::clean;
use Params::Callbacks 'callback';

our $VERSION = '0.001006';
our @ISA     = ( 'DBI', 'Exporter' );
our @EXPORT  = qw(callback);

=head1 PACKAGE GLOBALS

=head2 $DBIx::FlexibleBinding::AUTO_BINDING_ENABLED

A boolean setting used to determine whether or not automatic binding is enabled
or disabled globally.

The default setting is C<"1"> (I<enabled>).

=head2 $DBIx::FlexibleBinding::PROXIES_PROCESSALL_USING

The subroutines created with the C<-subs> import option may be used to
retrieve result sets. By default, any such subroutines delegate that particular
task to a method called C<"processall_hashref">, which is provided by this module
for both database and statement handles alike.

For reasons of efficiency the developer may prefer array references over hash
references, in which case they only need assign the value C<"processall_arrayref">
to this global.

=cut

our $AUTO_BINDING_ENABLED     = 1;
our $PROXIES_PROCESSALL_USING = 'processall_hashref';


sub _dbix_set_err
{
    my ( $handle, @args ) = @_;
    return $handle->set_err( $DBI::stderr, @args );
}
{
    my %proxies;


    sub _proxy
    {
        my ( $package, $name, @args ) = @_;
        $proxies{$name} = undef unless exists $proxies{$name};

        if (@args) {
            if ( @args == 1 && !defined( $args[0] ) ) {
                undef $proxies{$name};
            }
            elsif ( @args == 1 && blessed( $args[0] ) ) {
                if ( $args[0]->isa('DBI::db') || $args[0]->isa('DBI::st') ) {
                    $proxies{$name} = $args[0];
                }
                else {
                    confess "A database or statement handle was expected";
                }
            }
            elsif ( $args[0] =~ /^dbi:/i ) {
                $proxies{$name} = $package->connect(@args);
            }
            else {
                if ( $proxies{$name}->isa('DBI::st') ) {
                    if ( $proxies{$name}->{NUM_OF_PARAMS} ) {
                        $proxies{$name}->execute(@args);
                    }
                    else {
                        $proxies{$name}->execute();
                    }
                }
                return $proxies{$name}->$PROXIES_PROCESSALL_USING(@args);
            }
        }

        return $proxies{$name};
    }
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
                for my $proxy_name (@$list) {
                    no strict 'refs';    ## no critic [TestingAndDebugging::ProhibitNoStrict]
                    my $sub = sub { _proxy( $package, $proxy_name, @_ ) };
                    *{ $caller . '::' . $proxy_name } = subname( $proxy_name => $sub );
                }
                $caller->unimport( 'strict', 'subs' );
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

=head1 METHODS

=cut

=head2 connect

    $dbh = DBIx::FlexibleBinding->connect($data_source, $username, $password);
    $dbh = DBIx::FlexibleBinding->connect($data_source, 
                                          $username, 
                                          $password, 
                                          \%attr);

Establishes a database connection, or session, to the requested data_source and
returns a database handle object if the connection succeeds or undef if it does
not.

I<Refer to L<http://search.cpan.org/dist/DBI/DBI.pm#connect> for a more detailed
explanation of how to use this method>.

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

=head1 METHODS (C<DBIx::FlexibleBinding::db>)

=cut

=head2 do

    $rows = $dbh->do($statement_string);
    $rows = $dbh->do($statement_string, \%attr);
    $rows = $dbh->do($statement_string, \%attr, @bind_values);

    $rows = $dbh->do($statement_handle);
    $rows = $dbh->do($statement_handle, @bind_values);


Prepare if necessary and execute a single statement. Returns the number of rows
affected or undef on error. A return value of -1 means the number of rows is not
known, not applicable, or not available.

I<Refer to L<http://search.cpan.org/dist/DBI/DBI.pm#do> for a more detailed
explanation of how to use this method>.

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

    return if $sth->err;

    my $result = $sth->execute(@bind_values);

    return if $sth->err;

    if ($result) {
        if (@$callbacks) {
            local $_;
            $result = $callbacks->smart_transform( $_ = $result );
        }
        else {
            $result = $result;
        }
    }

    return $result;
}


=head2 prepare

    $sth = $dbh->prepare($statement_string);
    $sth = $dbh->prepare($statement_string, \%attr);

Prepares a statement for later execution by the database engine and returns a
reference to a statement handle object.

I<Refer to L<http://search.cpan.org/dist/DBI/DBI.pm#prepare> for a more detailed
explanation of how to use this method>.

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

    if (@params) {
        $sth->{private_auto_binding} = $DBIx::FlexibleBinding::AUTO_BINDING_ENABLED;
        $sth->{private_numeric_placeholders_only} = ( any { /\D/ } @params ) ? 0 : 1;
        $sth->{private_param_counts}              = { map { $_ => 0 } @params };
        $sth->{private_param_order}               = \@params;
        $sth->{private_param_counts}{$_}++ for @params;
    }

    $sth->{private_using_positionals} = !exists( $sth->{private_param_order} );
    return $sth;
}


=head2 processall_arrayref I<(Database Handles)>

    $array_of_values = $dbh->processall_arrayref($statement_string,
                                                 \%optional_attr,
                                                 @optional_data_bindings,
                                                 @optional_callbacks);

    @array_of_values = $dbh->processall_arrayref($statement_string,
                                                 \%optional_attr,
                                                 @optional_data_bindings,
                                                 @optional_callbacks);

    $array_of_values = $dbh->processall_arrayref($statement_handle,
                                                 @optional_data_bindings,
                                                 @optional_callbacks);

    @array_of_values = $dbh->processall_arrayref($statement_handle,
                                                 @optional_data_bindings,
                                                 @optional_callbacks);

Prepares the statement if necessary, executes it with the specified data
bindings, and fetches all the rows in the result set.

Though presented initially as an array reference, the value of each row may be
transformed, by the caller, with the aid of callbacks.



=cut


sub processall_arrayref
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
    return $sth->processall_arrayref($callbacks);
}

=head2 processall_hashref I<(Database Handles)>

    $array_of_values = $dbh->processall_hashref($statement_string,
                                                \%optional_attr,
                                                @optional_data_bindings,
                                                @optional_callbacks);

    @array_of_values = $dbh->processall_hashref($statement_string,
                                                \%optional_attr,
                                                @optional_data_bindings,
                                                @optional_callbacks);

    $array_of_values = $dbh->processall_hashref($statement_handle,
                                                @optional_data_bindings,
                                                @optional_callbacks);

    @array_of_values = $dbh->processall_hashref($statement_handle,
                                                @optional_data_bindings,
                                                @optional_callbacks);

Prepares the statement if necessary, executes it with the specified data
bindings, and fetches all the rows in the result set.

Though presented initially as a hash reference, the value of each row may be
transformed, by the caller, with the aid of callbacks.

=cut


sub processall_hashref
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
    return $sth->processall_hashref($callbacks);
}

=head2 processrow_arrayref I<(Database Handles)>

    $value = $dbh->processrow_arrayref($statement_string,
                                       \%optional_attr,
                                       @optional_data_bindings,
                                       @optional_callbacks);

    $value = $dbh->processrow_arrayref($statement_handle,
                                       @optional_data_bindings,
                                       @optional_callbacks);

Prepares the statement (if necessary) and executes it immediately with the
specified data bindings, and fetches one and only one row.

Though presented initially as an array reference, the value of that row may be
transformed, by the caller, with the aid of callbacks.

=cut


sub processrow_arrayref
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
    return $sth->processrow_arrayref($callbacks);
}

=head2 processrow_hashref I<(Database Handles)>

    $value = $dbh->processrow_hashref($statement_string,
                                      \%optional_attr,
                                      @optional_data_bindings,
                                      @optional_callbacks);

    $value = $dbh->processrow_hashref($statement_handle,
                                      @optional_data_bindings,
                                      @optional_callbacks);

Prepares the statement (if necessary) and executes it immediately with the
specified data bindings, and fetches one and only one row.

Though presented initially as a hash reference, that value of that row may be
transformed , by the caller, with the aid of callbacks.

=cut


sub processrow_hashref
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
    return $sth->processrow_hashref($callbacks);
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

=head1 METHODS (C<DBIx::FlexibleBinding::st>)

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

The bind_param method associates (binds) a value to a placeholder embedded in the
prepared statement.

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

=head2 processall_arrayref I<(Statement Handles)>

    $array_of_values = $sth->processall_arrayref(@optional_callbacks);
    @array_of_values = $sth->processall_arrayref(@optional_callbacks);

Fetches the entire result set.

Though presented initially as an array reference, the value of each row may be
transformed, by the caller, with the aid of callbacks.

=cut


sub processall_arrayref
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

=head2 processall_hashref I<(Statement Handles)>

    $array_of_values = $sth->processall_hashref(@optional_callbacks);
    @array_of_values = $sth->processall_hashref(@optional_callbacks);

Fetches the entire result set.

Though presented initially as an hash reference, the value of each row may be
transformed, by the caller, with the aid of callbacks.

=cut


sub processall_hashref
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

=head2 processrow_arrayref I<(Statement Handles)>

    $value = $sth->processrow_arrayref(@optional_callbacks);

Fetches the next row of a result set if one exists.

Though presented initially as an array reference, the value of that row may be
transformed, by the caller, with the aid of callbacks.


=cut


sub processrow_arrayref
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


=head2 processrow_hashref I<(Statement Handles)>

    $value = $sth->processrow_hashref(@optional_callbacks);

Fetches the next row of a result set if one exists.

Though presented initially as an hash reference, the value of that row may be
transformed, by the caller, with the aid of callbacks.


=cut


sub processrow_hashref
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

=head1 AUTHOR

Iain Campbell, C<< <cpanic at cpan.org> >>

=head1 REPOSITORY

L<DBIx-FlexibleBinding at GitHub|https://github.com/cpanic/DBIx-FlexibleBinding>

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

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Iain Campbell.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 dated June, 1991 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA


=cut

