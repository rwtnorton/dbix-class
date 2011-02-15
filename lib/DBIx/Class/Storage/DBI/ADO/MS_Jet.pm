package DBIx::Class::Storage::DBI::ADO::MS_Jet;

use strict;
use warnings;
use base qw/
  DBIx::Class::Storage::DBI::ADO
  DBIx::Class::Storage::DBI::ODBC::ACCESS
/;
use mro 'c3';
use DBIx::Class::Storage::DBI::ADO::MS_Jet::Cursor ();

__PACKAGE__->cursor_class('DBIx::Class::Storage::DBI::ADO::MS_Jet::Cursor');

__PACKAGE__->disable_sth_caching_for_image_insert_or_update(0);

=head1 NAME

DBIx::Class::Storage::DBI::ADO::MS_Jet - Support for MS Access over ADO

=head1 DESCRIPTION

This driver is a subclass of L<DBIx::Class::Storage::DBI::ADO> and
L<DBIx::Class::Storage::DBI::ODBC::ACCESS> for connecting to MS Access via
L<DBD::ADO>.

See the documentation for L<DBIx::Class::Storage::DBI::ODBC::ACCESS> for
information on the MS Access driver for L<DBIx::Class>.

=head1 EXAMPLE DSNs

  # older Access versions:
  dbi:ADO:Microsoft.Jet.OLEDB.4.0;Data Source=C:\Users\rkitover\Documents\access_sample.accdb

  # newer Access versions:
  dbi:ADO:Provider=Microsoft.ACE.OLEDB.12.0;Data Source=C:\Users\rkitover\Documents\access_sample.accdb;Persist Security Info=False'

=head1 TEXT/IMAGE/MEMO COLUMNS

The ADO driver does not suffer from the
L<problems|DBIx::Class::Storage::DBI::ODBC::ACCESS/"TEXT/IMAGE/MEMO COLUMNS">
the L<ODBC|DBIx::Class::Storage::DBI::ODBC::ACCESS> driver has with these types
of columns. You can use them safely.

=cut

# AutoCommit does not get reset properly after transactions for some reason
# (probably because of my nested transaction hacks in ODBC/ACCESS.pm) fix it up
# here.

sub _dbh_commit {
  my $self = shift;
  $self->next::method(@_);
  $self->_dbh->{AutoCommit} = $self->_dbh_autocommit
    if $self->{transaction_depth} == 1;
}

sub _dbh_rollback {
  my $self = shift;
  $self->next::method(@_);
  $self->_dbh->{AutoCommit} = $self->_dbh_autocommit
    if $self->{transaction_depth} == 1;
}

# Fix up GUIDs for ->find, for cursors see the cursor_class above.

sub select_single {
  my $self = shift;
  my ($ident, $select) = @_;

  my @row = $self->next::method(@_);

  my $col_info = $self->_resolve_column_info($ident);

  for my $select_idx (0..$#$select) {
    my $selected = $select->[$select_idx];

    next if ref $selected;

    my $data_type = $col_info->{$selected}{data_type};

    if ($self->_is_guid_type($data_type)) {
      my $returned = $row[$select_idx];

      $row[$select_idx] = substr($returned, 1, 36)
        if substr($returned, 0, 1) eq '{';
    }
  }

  return @row;
}

sub datetime_parser_type {
  'DBIx::Class::Storage::DBI::ADO::MS_Jet::DateTime::Format'
}

package # hide from PAUSE
  DBIx::Class::Storage::DBI::ADO::MS_Jet::DateTime::Format;

my $datetime_format = '%m/%d/%Y %I:%M:%S %p';
my $datetime_parser;

sub parse_datetime {
  shift;
  require DateTime::Format::Strptime;
  $datetime_parser ||= DateTime::Format::Strptime->new(
    pattern  => $datetime_format,
    on_error => 'croak',
  );
  return $datetime_parser->parse_datetime(shift);
}

sub format_datetime {
  shift;
  require DateTime::Format::Strptime;
  $datetime_parser ||= DateTime::Format::Strptime->new(
    pattern  => $datetime_format,
    on_error => 'croak',
  );
  return $datetime_parser->format_datetime(shift);
}

1;

=head1 AUTHOR

See L<DBIx::Class/AUTHOR> and L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
# vim:sts=2 sw=2:
