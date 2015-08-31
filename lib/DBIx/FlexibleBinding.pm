package DBIx::FlexibleBinding;

=pod

=head1 NAME

DBIx::FlexibleBinding - Flexible parameter binding and record fetching

=head1 SYNOPSIS

This module extends the DBI allowing you choose from a variety of supported
parameter placeholder and binding patterns as well as offering simplified
ways to interact with datasources, while improving general readability.

    ###############################################################################
    # SCENARIO 1
    # A connect followed by a prepare-execute-process cycle
    ###############################################################################

    use DBIx::FlexibleBinding ':all';
    use constant DSN => 'dbi:mysql:test;host=127.0.0.1';
    use constant SQL => << '//';
    SELECT name
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

    ###############################################################################
    # SCENARIO 2
    # Let's simplify the previous scenario using the database handle's version
    # of that processall_hashref method.
    ###############################################################################

    use DBIx::FlexibleBinding ':all', -alias => 'DFB';
    use constant DSN => 'dbi:mysql:test;host=127.0.0.1';
    use constant SQL => << '//';
    SELECT name
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

    ###############################################################################
    # SCENARIO 3
    # The subclass import method provides a versatile mechanism for simplifying
    # matters further.
    ###############################################################################

    use DBIx::FlexibleBinding ':all', -subs => [ 'MyDB' ];
    use constant DSN => 'dbi:mysql:test;host=127.0.0.1';
    use constant SQL => << '//';
    SELECT name
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

=item * Parameter placeholder and data binding

=item * Data retrieval and processing


=back

=head2 Accessing and interacting with datasources

The module's C<-subs> import option may be used to create and import special
soubroutines into the caller's own namespace to act as representations of
datasources. To begin with, these subroutines exist in an undefined state
and aren't very useful until connected with a DBI database. They operate
according to the context in which they are used.

=over 2

=item * Use for connecting to datasources

    # Decide what name to use for your datasource and include it in
    # the "-subs" list for export ...
    #
    use DBIx::FlexibleBinding ':all', -subs => [ 'MyDB' ];

    # Pass in any set of well-formed DBI->connect(...) arguments to associate
    # your name with a live database connection ...
    #
    MyDB 'dbi:mysql:test;host=127.0.0.1', '', '', { RaiseError => 1 };

    # Or, simply assign one you made earlier ...
    #
    MyDB $dbh;

=item * Use as DBI database handles

    # If your name is associated with a database connection then call it with
    # no parameters to get the DBI database handle ...
    #
    my $dbh = MyDB;

    # Use it in this context as you would any DBI database handle ...
    #
    my $sth = MyDB->prepare(...);

=item * Use to have the database connection do useful stuff ...

    use constant SQL => << '//';
    SELECT *
      FROM mapsolarsystems
     WHERE regional  = :is_regional
       AND security >= :minimum_security
    //

    # A function to retrieve result sets ...
    #
    my $rv = MyDB(SQL,
                  is_regional => 1,
                  minimum_security => 1.0);

    # Void context calls look kind of pretty, too ...
    #
    MyDB SQL, is_regional => 1, minimum_security => 1.0, callback {
        my ($row) = @_;
        printf "%-16s %.1f\n", $row->{name}, $row->{security};
    };

=back

Just be aware that this option automatically relaxes C<strict 'refs'> for the
remainder of the caller's scope containing the C<use> directive. That is,
unless C<use strict 'refs'> or C<use strict> appears after that point.

=head2 Parameter placeholder and data binding

The module augments the DBI prepare-execute cycle first by enabling C<prepare>
method calls to benefit from support for a wider range of parameter placeholder
schemes. In addition to continuing support for positional (C<?>) placeholders,
this modules also supports numeric placeholders (C<:N>) and (C<?N>), and named
placeholders (C<:NAME> and C<@NAME>).

Any C<execute> method calls will benefit from a more flexible approach to
the packaging of data bindings.

The module's default behaviour is to bind parameters to values automatically,
thereby removing some of the cognitive overhead from constructing the cycle. For
those of a more masochistic disposition, it is possible to switch off the
automatic binding feature.

=head2 Data retrieval and processing

Four new methods have been implemented for use in fetching and optionally
transforming rows using blocking callbacks. These methods exists for database
handles and statement handles, doing the same jobs but differing only in the
size of their argument lists.

=over 2

=item * processrow_arrayref

    # For statement handles
    #
    my $value = $sth->processrow_arrayref(@optional_callbacks);

    # For database handles
    #
    my $value = $dbh->processrow_arrayref($statement_handle_or_string,
                                          \%optional_statement_attr,
                                          @optional_data_bindings,
                                          @optional_callbacks);

=item * processrow_hashref

    # For statement handles
    #
    my $value = $sth->processrow_hashref(@optional_callbacks);

    # For database handles
    #
    my $value = $dbh->processrow_hashref($statement_handle_or_string,
                                         \%optional_statement_attr,
                                         @optional_data_bindings,
                                         @optional_callbacks);

=item * processall_arrayref

    # For statement handles
    #
    my $array_of_values = $sth->processall_arrayref(@optional_callbacks);
    my @array_of_values = $sth->processall_arrayref(@optional_callbacks);

    # For database handles
    #
    my $array_of_values = $dbh->processall_arrayref($statement_handle_or_string,
                                                    \%optional_statement_attr,
                                                    @optional_data_bindings,
                                                    @optional_callbacks);
    my @array_of_values = $dbh->processall_arrayref($statement_handle_or_string,
                                                    \%optional_statement_attr,
                                                    @optional_data_bindings,
                                                    @optional_callbacks);

=item * processall_hashref

    # For statement handles
    #
    my $array_of_values = $sth->processall_hashref(@optional_callbacks);
    my @array_of_values = $sth->processall_hashref(@optional_callbacks);

    # For database handles
    #
    my $array_of_values = $dbh->processall_hashref($statement_handle_or_string,
                                                   \%optional_statement_attr,
                                                   @optional_data_bindings,
                                                   @optional_callbacks);
    my @array_of_values = $dbh->processall_hashref($statement_handle_or_string,
                                                   \%optional_statement_attr,
                                                   @optional_data_bindings,
                                                   @optional_callbacks);

=back

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

our $VERSION     = '0.001003';
our @ISA         = ( 'DBI', 'Exporter' );
our @EXPORT_OK   = qw(callback);
our %EXPORT_TAGS = ( all => \@EXPORT_OK, ALL => \@EXPORT_OK );

=head1 PACKAGE GLOBALS

=over 2

=item B<$DBIx::FlexibleBinding::DEFAULT_AUTO_BIND>

A boolean setting used to determine whether or not automatic parameter binding
should take place when executing statements prepared using a non-standard
placeholder scheme (i.e anything other than the standard positional (C<?>)
scheme).

The default setting is C<1> and binding is automatic. You should rarely, if
ever, need to change this.

=item B<$DBIx::FlexibleBinding::DEFAULT_PROCESSOR>

A string setting used by subroutines named in the C<-subs =E<gt> [ LIST ]> import
option, to determine which method gets called to fetch result sets.

The default setting is C<processall_hashref>, a method defined by the
C<DBIx::FlexibleBinding::db> package.

=back

=cut

our $DEFAULT_AUTO_BIND = 1;
our $DEFAULT_PROCESSOR = 'processall_hashref';


sub _dbix_set_err
{
    my ( $handle, @args ) = @_;
    return $handle->set_err( $DBI::stderr, @args );
}

{
    my %tags;


    sub _tag
    {
        my ( $package, $tag, @args ) = @_;
        $tags{$tag} = {} unless exists $tags{$tag};
        if ( @args == 0 ) {
            return $tags{$tag}{dbh};
        }
        elsif ( @args == 1 && blessed( $args[0] ) ) {
            if ( $args[0]->isa('DBI::db') ) {
                $tags{$tag}{dbh} = $args[0];
                return $tags{$tag}{dbh};
            }
            else {
                confess "Expected a DBI database handle";
            }
        }
        elsif ( @args >= 1 && !ref( $args[0] ) ) {
            if ( $args[0] =~ /^dbi:/i ) {
                $tags{$tag}{dbh} = $package->connect(@args);
                return $tags{$tag}{dbh};
            }
            else {
                return $tags{$tag}{dbh}->$DEFAULT_PROCESSOR(@args);
            }
        }
        else {
            confess "Malformed argument list";
        }
    } ## end sub _tag
}

=head1 IMPORT TAGS AND OPTIONS

=over 2

=item B<:all>

Use this import tag to pull all of the package's exportable symbol table entries
into the caller's namespace. Currently, only one subroutine (C<callback>) is
exported upon request.

=item B<-alias>

This option may be used by the caller to select an alias to use for this
package's unwieldly namespace.

    use DBIx::FlexibleBinding -alias => 'DBIFB';

    my $dbh = DBIFB->connect('dbi:SQLite:test.db', '', '');

=item B<-subs>

This option creates special subroutines that may be used to instantiate and
interact with DBI database handles, and exports those subroutines into the
caller's namespace at compile time.

    use DBIx::FlexibleBinding ':all', -subs => [ 'MyDB' ];

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
    my $statement
      = 'SELECT name FROM mapsolarsystems WHERE security >= :minimum_security';
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

Just be aware that this option automatically relaxes C<strict 'refs'> for the
remainder of the caller's scope containing the C<use> directive. That is,
unless C<use strict 'refs'> or C<use strict> appears after that point.

=back

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
                no strict 'refs';
                my $package_alias = shift(@args);
                *{ $package_alias . '::' }     = *{ __PACKAGE__ . '::' };
                *{ $package_alias . '::db::' } = *{ __PACKAGE__ . '::db::' };
                *{ $package_alias . '::st::' } = *{ __PACKAGE__ . '::st::' };
            }
            elsif ( $arg eq '-subs' ) {
                my $list = shift(@args);
                confess "Expected anonymous list or array reference after '$arg'"
                  unless ref($list) && reftype($list) eq 'ARRAY';
                for my $tag (@$list) {
                    no strict 'refs';
                    my $sub = sub { _tag( $package, $tag, @_ ) };
                    *{ $caller . '::' . $tag } = subname( $tag => $sub );
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
    } ## end while (@args)

    goto &Exporter::import;
} ## end sub import

=head1 METHODS

=head2 DBIx::FlexibleBinding

=cut

=pod

=over 2

=item B<connect>

=back

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

=head2 DBIx::FlexibleBinding::db

=cut

=pod

=over 2

=item B<prepare>

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

    if (@params) {
        $sth->{private_auto_binding} = $DBIx::FlexibleBinding::DEFAULT_AUTO_BIND;
        $sth->{private_numeric_placeholders_only} = ( any { /\D/ } @params ) ? 0 : 1;
        $sth->{private_param_counts}              = { map { $_ => 0 } @params };
        $sth->{private_param_order}               = \@params;
        $sth->{private_param_counts}{$_}++ for @params;
    }

    return $sth;
} ## end sub prepare

=pod

=over 2

=item B<do>

=back

=cut


sub do
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) ) {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
    }

    my $result;
    
    if ( $sth->auto_bind() ) {
        $sth->bind(@bind_values);
        $result = $sth->execute();
    }
    else {
        $result = $sth->execute(@bind_values);
    }
    
    $result = $callbacks->smart_transform( $_ = $result ) unless $sth->err;
    return $result;
}

=pod

=over 2

=item B<processrow_arrayref>

    my $value = $dbh->processrow_arrayref($statement_handle_or_string,
                                          \%optional_statement_attr,
                                          @optional_data_bindings,
                                          @optional_callbacks);

If the statement is presented as a string then it is first prepared using, if
present, the optional statement attributes. The statement may also be a pre-
prepared statement handle.

If auto binding is enabled and there are data bindings, these are bound to their
respective parameter placeholders and the statement is executed.

The method will then fetch the first and only row, B<initially> presented as an
array reference, optionally transforming it using a chain of zero or more blocking
callbacks.

Returns the transformed scalar value.

A transformation stage need not present the transformed data in the same manner
it was presented, though it is better if a scalar value of some sort is returned.

A transformation stage may eliminate a row from the result set by returning an
empty list.

=back

=cut


sub processrow_arrayref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) ) {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
    }

    if ( $sth->auto_bind() ) {
        $sth->bind(@bind_values);
        $sth->execute();
    }
    else {
        $sth->execute(@bind_values);
    }

    my $result;
    $result = $sth->fetchrow_arrayref() unless $sth->err;
    $sth->finish();

    if ($result) {
        local $_;
        $result = $callbacks->smart_transform( $_ = [@$result] ) unless $sth->err;
    }

    return $result;
} ## end sub processrow_arrayref

=pod

=over 2

=item B<processrow_hashref>

    my $value = $dbh->processrow_hashref($statement_handle_or_string,
                                         \%optional_statement_attr,
                                         @optional_data_bindings,
                                         @optional_callbacks);

If the statement is presented as a string then it is first prepared using, if
present, the optional statement attributes. The statement may also be a pre-
prepared statement handle.

If auto binding is enabled and there are data bindings, these are bound to their
respective parameter placeholders and the statement is executed.

The method will then fetch the first and only row, B<initially> presented as a
hash reference, optionally transforming it using a chain of zero or more blocking
callbacks.

Returns the transformed scalar value.

A transformation stage need not present the transformed data in the same manner
it was presented, though it is better if a scalar value of some sort is returned.

A transformation stage may eliminate a row from the result set by returning an
empty list.

=back

=cut


sub processrow_hashref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) ) {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
    }

    if ( $sth->auto_bind() ) {
        $sth->bind(@bind_values);
        $sth->execute();
    }
    else {
        $sth->execute(@bind_values);
    }

    my $result;
    $result = $sth->fetchrow_hashref() unless $sth->err;
    $sth->finish();

    if ($result) {
        local $_;
        $result = $callbacks->smart_transform( $_ = {%$result} ) unless $sth->err;
    }

    return $result;
} ## end sub processrow_hashref

=pod

=over 2

=item B<processall_arrayref>

    my $array_of_values = $dbh->processall_arrayref($statement_handle_or_string,
                                                    \%optional_statement_attr,
                                                    @optional_data_bindings,
                                                    @optional_callbacks);

    my @array_of_values = $dbh->processall_arrayref($statement_handle_or_string,
                                                    \%optional_statement_attr,
                                                    @optional_data_bindings,
                                                    @optional_callbacks);

If the statement is presented as a string then it is first prepared using, if
present, the optional statement attributes. The statement may also be a pre-
prepared statement handle.

If auto binding is enabled and there are data bindings, these are bound to their
respective parameter placeholders and the statement is executed.

The method will then fetch the entire result set, B<initially> presenting rows
as array references, optionally transforming each rows using a chain of zero or
more blocking callbacks.

Returns the transformed result set as a reference to an array or as a list
depending on calling context.

A transformation stage need not present the transformed data in the same manner
it was presented, though it is better if a scalar value of some sort is returned.

A transformation stage may eliminate a row from the result set by returning an
empty list.

=back

=cut


sub processall_arrayref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) ) {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
    }

    if ( $sth->auto_bind() ) {
        $sth->bind(@bind_values);
        $sth->execute();
    }
    else {
        $sth->execute(@bind_values);
    }

    my $result;
    $result = $sth->fetchall_arrayref() unless $sth->err;

    if ($result) {
        local $_;
        $result = [ map { $callbacks->transform($_) } @$result ] unless $sth->err;
    }

    return $result unless defined $result;
    return wantarray ? @$result : $result;
} ## end sub processall_arrayref

=pod

=over 2

=item B<processall_hashref>

    my $array_of_values = $dbh->processall_hashref($statement_handle_or_string,
                                                   \%optional_statement_attr,
                                                   @optional_data_bindings,
                                                   @optional_callbacks);

    my @array_of_values = $dbh->processall_hashref($statement_handle_or_string,
                                                   \%optional_statement_attr,
                                                   @optional_data_bindings,
                                                   @optional_callbacks);

If the statement is presented as a string then it is first prepared using, if
present, the optional statement attributes. The statement may also be a pre-
prepared statement handle.

If auto binding is enabled and there are data bindings, these are bound to their
respective parameter placeholders and the statement is executed.

The method will then fetch the entire result set, B<initially> presenting rows
as hash references, optionally transforming each rows using a chain of zero or
more blocking callbacks.

Returns the transformed result set as a reference to an array or as a list
depending on calling context.

A transformation stage need not present the transformed data in the same manner
it was presented, though it is better if a scalar value of some sort is returned.

A transformation stage may eliminate a row from the result set by returning an
empty list.

=back

=cut


sub processall_hashref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) ) {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
    }

    if ( $sth->auto_bind() ) {
        $sth->bind(@bind_values);
        $sth->execute();
    }
    else {
        $sth->execute(@bind_values);
    }

    my $result;
    $result = $sth->fetchall_arrayref( {} ) unless $sth->err;

    if ($result) {
        local $_;
        $result = [ map { $callbacks->transform($_) } @$result ] unless $sth->err;
    }

    return $result unless defined $result;
    return wantarray ? @$result : $result;
} ## end sub processall_hashref

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

=head2 DBIx::FlexibleBinding::st

=cut

=pod

=over 2

=item B<auto_bind>

=back

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

=pod

=over 2

=item B<bind>

=back

=cut


sub bind
{
    my ( $sth, @args ) = @_;
    return $sth unless @args;

    return $sth->_bind_array_ref( \@args ) unless @{ $sth->{private_param_order} };

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
} ## end sub bind

=pod

=over 2

=item B<bind_param>

=back

=cut


sub bind_param
{
    my ( $sth, $param, $value, $attr ) = @_;

    return _dbix_set_err( $sth, "Binding identifier is missing" )
      unless defined($param) && $param;

    return _dbix_set_err( $sth, 'Binding identifier "' . $param . '" is malformed' )
      if $param =~ /[^\@\w]/;

    return $sth->SUPER::bind_param( $param, $value, $attr )
      unless @{ $sth->{private_param_order} };

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
} ## end sub bind_param

=pod

=over 2

=item B<execute>

=back

=cut


sub execute
{
    my ( $sth, @bind_values ) = @_;
    my $rows;

    if ( $sth->auto_bind() ) {
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

=pod

=over 2

=item B<processrow_arrayref>

=back

=cut


sub processrow_arrayref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchrow_arrayref();

    if ($result) {
        local $_;
        $result = $callbacks->smart_transform( $_ = [@$result] ) unless $sth->err;
    }

    return $result;
}


=pod

=over 2

=item B<processrow_hashref>

=back

=cut


sub processrow_hashref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchrow_hashref();

    if ($result) {
        local $_;
        $result = $callbacks->smart_transform( $_ = {%$result} ) unless $sth->err;
    }

    return $result;
}

=pod

=over 2

=item B<processall_arrayref>

=back

=cut


sub processall_arrayref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchall_arrayref();

    if ($result) {
        local $_;
        $result = [ map { $callbacks->transform($_) } @$result ] unless $sth->err;
    }

    return $result unless defined $result;
    return wantarray ? @$result : $result;
}

=pod

=over 2

=item B<processall_hashref>

=back

=cut


sub processall_hashref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchall_arrayref( {} );

    if ($result) {
        local $_;
        $result = [ map { $callbacks->transform($_) } @$result ] unless $sth->err;
    }

    return $result unless defined $result;
    return wantarray ? @$result : $result;
}

1;

=head1 EXPORTS

The following symbols are exported when requested by name or through the
use of the C<:all> tag.

=over 2

=item B<callback>

A simple piece of syntactic sugar that announces a callback. The code
reference it precedes is blessed as a C<Params::Callbacks::Callback>
object, disambiguating it from unblessed subs that are being passed as
standard arguments.

Multiple callbacks may be chained together with or without comma
separators:

    callback { ... }, callback { ... }  # Valid
    callback { ... }  callback { ... }  # Valid, too!

=back

There are no automatic exports.

=cut

=head1 AUTHOR

Iain Campbell, C<< <cpanic at cpan.org> >>

=head1 REPOSITORY

L<https://github.com/cpanic/DBIx-FlexibleBinding>

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

