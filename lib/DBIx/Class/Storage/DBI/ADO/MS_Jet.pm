package DBIx::Class::Storage::DBI::ADO::MS_Jet;

use strict;
use warnings;
use base qw/
  DBIx::Class::Storage::DBI::ADO
  DBIx::Class::Storage::DBI::ODBC::ACCESS
/;
use mro 'c3';

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

# Cast GUIDs to remove the {}s that surround them by default.
sub _select_args {
  my $self = shift;
  my ($ident, $select) = @_;

  my $col_info = $self->_resolve_column_info($ident);

  for my $select_idx (0..$#$select) {
    my $selected = $select->[$select_idx];

    next if ref $selected;

    my $data_type = $col_info->{$selected}{data_type};

    if ($data_type && $self->_is_guid_type($data_type)) {
      my $selected = $self->sql_maker->_quote($selected);
      $select->[$select_idx] = \"CAST($selected AS VARCHAR)";
    }
  }

  return $self->next::method(@_);
}


1;

=head1 AUTHOR

See L<DBIx::Class/AUTHOR> and L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
# vim:sts=2 sw=2:
