package DBIx::Class::Storage::DBI::ODBC::ACCESS;

use strict;
use warnings;
use base 'DBIx::Class::Storage::DBI::UniqueIdentifier';
use mro 'c3';
use List::Util 'first';
use namespace::clean;

__PACKAGE__->sql_limit_dialect ('Top');
__PACKAGE__->sql_quote_char ([qw/[ ]/]);

=head1 NAME

DBIx::Class::Storage::DBI::ODBC::ACCESS - Support specific to MS Access over ODBC

=head1 DESCRIPTION

This class implements support specific to Microsoft Access over ODBC.

It is loaded automatically by by DBIx::Class::Storage::DBI::ODBC when it
detects a MS Access back-end.

This driver supports L<last_insert_id|DBIx::Class::Storage::DBI/last_insert_id>,
empty inserts for tables with C<AUTOINCREMENT> columns, nested transactions via
L<auto_savepoint|DBIx::Class::Storage::DBI/auto_savepoint>, C<GUID> columns via
L<DBIx::Class::Storage::DBI::UniqueIdentifier> and L<Data::UUID> and
C<IMAGE>/C<MEMO> columns, as well as support for
L<DBIx::Class::InflateColumn::DateTime> for C<DATETIME> columns.

=head1 SUPPORTED VERSIONS

This module has currently only been tested on MS Access 2007 using the Jet 4.0 engine.

Information about how well it works on different version of MS Access is welcome
(write the mailing list, or submit a ticket to RT if you find bugs.)

=head1 KNOWN ACCESS PROBLEMS

=over

=item Invalid precision value

This error message is received when trying to store more than 255 characters in a MEMO field.
The problem is (to my knowledge) an error in the MS Access ODBC driver. The problem is fixed
by setting the C<data_type> of the column to C<SQL_LONGVARCHAR> in C<add_columns>. 
C<SQL_LONGVARCHAR> is a constant in the C<DBI> module.

=back

=cut

sub _dbh_last_insert_id { $_[1]->selectrow_array('select @@identity') }

sub sqlt_type { 'ACCESS' }

# support empty insert
sub insert {
    my $self = shift;
    my ($source, $to_insert) = @_;

    if (keys %$to_insert == 0) {
        my $columns_info = $source->columns_info;
        my $autoinc_col = first {
          $columns_info->{$_}{is_auto_increment}
        } keys %$columns_info;

        if (not $autoinc_col) {
          $self->throw_exception(
'empty insert only supported for tables with an autoincrement column'
          );
        }

        my $table = $source->from;
        $table = $$table if ref $table;

        $to_insert->{$autoinc_col} = \"dmax('${autoinc_col}', '${table}')+1";
    }

    $self->next::method(@_);
}

sub bind_attribute_by_data_type {
  my $self = shift;
  my ($data_type) = @_;

  my $attributes = $self->next::method(@_) || {};

  if ($self->_is_text_lob_type($data_type)) {
    $attributes->{TYPE} = DBI::SQL_LONGVARCHAR;
  }
  elsif ($self->_is_binary_lob_type($data_type)) {
    $attributes->{TYPE} = DBI::SQL_LONGVARBINARY;
  }

  return $attributes;
}

sub _new_uuid { undef }

# savepoints are not supported, but nested transactions are.
# Unfortunately DBI does not support nested transaction.
# WARNING: this code uses the undocumented 'BegunWork' DBI attribute.

sub _svp_begin {
  my ($self, $name) = @_;
  local $self->_dbh->{AutoCommit} = 1;
  local $self->_dbh->{BegunWork}  = 0;
  $self->_dbh_begin_work;
}

# A new nested transaction on the same level releases the previous one.
sub _svp_release { 1 }

sub _svp_rollback {
  my ($self, $name) = @_;
  local $self->_dbh->{AutoCommit} = 0;
  local $self->_dbh->{BegunWork}  = 1;
  $self->_dbh_rollback;
}

1;

=head1 AUTHOR

See L<DBIx::Class/AUTHOR> and L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
# vim:sts=2 sw=2:
