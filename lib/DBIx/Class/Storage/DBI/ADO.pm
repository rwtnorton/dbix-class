package DBIx::Class::Storage::DBI::ADO;

use base 'DBIx::Class::Storage::DBI';
use mro 'c3';
use Try::Tiny;
use Sub::Name;
use namespace::clean;

=head1 NAME

DBIx::Class::Storage::DBI::ADO - Support for L<DBD::ADO>

=head1 DESCRIPTION

This class provides a mechanism for discovering and loading a sub-class
for a specific ADO backend, as well as some workarounds for L<DBD::ADO>. It
should be transparent to the user.

=cut

sub _rebless {
  my $self = shift;

  my $dbtype = $self->_dbh_get_info(17);

  if (not $dbtype) {
    warn 'Unable to determine ADO driver, failling back to generic support';
    return;
  }

  $dbtype =~ s/\W/_/gi;
  my $subclass = "DBIx::Class::Storage::DBI::ADO::${dbtype}";
  if ($self->load_optional_class($subclass) && !$self->isa($subclass)) {
    bless $self, $subclass;
    $self->_rebless;
  }
}

# cleanup some warnings from DBD::ADO
sub _dbh_get_info {
  my $self = shift; 

  my $warn_handler = $SIG{__WARN__} || sub { warn @_ };

  local $SIG{__WARN__} = sub {
    $warn_handler->(@_)
      unless $_[0] =~ m{^Missing argument in sprintf at \S+/ADO/GetInfo\.pm};
  };

  $self->next::method(@_);
}

# Monkeypatch out the horrible warnings during global destruction.
# A patch to DBD::ADO has been submitted as well.
sub _init {
  no warnings 'redefine';
  require DBD::ADO;

  my $disconnect = *DBD::ADO::db::disconnect{CODE};

  *DBD::ADO::db::disconnect = subname 'DBD::ADO::db::disconnect' => sub {
    my $warn_handler = $SIG{__WARN__} || sub { warn @_ };
    local $SIG{__WARN__} = sub {
      $warn_handler->(@_)
        unless $_[0] =~ /Not a Win32::OLE object|uninitialized value/;
    };
    $disconnect->(@_);
  };
}

# Here I was just experimenting with ADO cursor types, left in as a comment in
# case you want to as well. See the DBD::ADO docs.
#sub _dbh_sth {
#  my ($self, $dbh, $sql) = @_;
#
#  my $sth = $self->disable_sth_caching
#    ? $dbh->prepare($sql, { CursorType => 'adOpenStatic' })
#    : $dbh->prepare_cached($sql, { CursorType => 'adOpenStatic' }, 3);
#
#  $self->throw_exception($dbh->errstr) if !$sth;
#
#  $sth;
#}

1;

=head1 AUTHOR

See L<DBIx::Class/AUTHOR> and L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
# vim:sts=2 sw=2:
