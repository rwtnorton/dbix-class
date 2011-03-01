package DBIx::Class::Storage::DBI::Sybase::FreeTDS;

use strict;
use warnings;
use base qw/DBIx::Class::Storage::DBI::Sybase/;
use mro 'c3';
use Try::Tiny;
use namespace::clean;

=head1 NAME

DBIx::Class::Storage::DBI::Sybase - Base class for drivers using L<DBD::Sybase>
over FreeTDS.

=head1 DESCRIPTION

This is the base class for Storages designed to work with L<DBD::Sybase> over
FreeTDS.

It is a subclass of L<DBIx::Class::Storage::DBI::Sybase>.

=head1 METHODS

=cut

# The subclass storage driver defines _set_autocommit_stmt
sub _set_autocommit {
  my $self = shift;

  if ($self->_dbh_autocommit) {
    $self->_dbh->do($self->_set_autocommit_stmt(1));
  } else {
    $self->_dbh->do($self->_set_autocommit_stmt(0));
  }
}

# Handle AutoCommit and SET TEXTSIZE because LongReadLen doesn't work.
#
sub _run_connection_actions {
  my $self = shift;

  if ($self->using_freetds) {
    # based on LongReadLen in connect_info
    $self->set_textsize;

    $self->_set_autocommit;
  }

  $self->next::method(@_);
}

=head2 set_textsize

When using FreeTDS and/or MSSQL, C<< $dbh->{LongReadLen} >> is not available,
use this function instead. It does:

  $dbh->do("SET TEXTSIZE $bytes");

Takes the number of bytes, or uses the C<LongReadLen> value from your
L<connect_info|DBIx::Class::Storage::DBI/connect_info> if omitted, lastly falls
back to the C<32768> which is the L<DBD::Sybase> default.

=cut

sub set_textsize {
  my $self = shift;
  my $text_size =
    shift
      ||
    try { $self->_dbi_connect_info->[-1]->{LongReadLen} }
      ||
    32768; # the DBD::Sybase default

  $self->_dbh->do("SET TEXTSIZE $text_size");
}

sub _dbh_begin_work {
  my $self = shift;

  if (not $self->using_freetds) {
    return $self->next::method(@_);
  }

  if ($self->{_in_dbh_do}) {
    my $dbh = $self->_dbh; 
    $dbh->do('BEGIN TRAN');
  } else {
    $self->dbh_do(sub {
      $_[1]->do('BEGIN TRAN');
    });
  }
}

sub _dbh_commit {
  my $self = shift;

  if (not $self->using_freetds) {
    return $self->next::method(@_);
  }

  my $dbh = $self->_dbh
    or $self->throw_exception('cannot COMMIT on a disconnected handle');

  $dbh->do('COMMIT');
}

sub _dbh_rollback {
  my $self = shift;

  if (not $self->using_freetds) {
    return $self->next::method(@_);
  }

  my $dbh  = $self->_dbh
    or $self->throw_exception('cannot ROLLBACK on a disconnected handle');

  $dbh->do('ROLLBACK');
}

1;

=head1 AUTHORS

See L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
