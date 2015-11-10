package deploy::Git;

use strict;
use warnings;

use Error qw(:try);
use Git::Repository;
use Git::Repository::Command;

use deploy::Config;

sub new {
	my ($class) = @_;

	my $self = {
		repo => Git::Repository->new( work_tree => deploy::Config->git_dir )
	};

	return bless $self, $class;
}

sub _command {
	my ($self, @args) = @_;
	my $cmd = Git::Repository::Command->new( $self->{repo}, @args );
	my $stdout = '';
	my $stderr = '';
	my $out_fh = $cmd->stdout();
	my $err_fh = $cmd->stderr();

	while (<$out_fh>) { $stdout .= $_; }
	while (<$err_fh>) { $stderr .= $_; }
	$cmd->close();
	my $code = $cmd->exit();
	if ($code) {
		throw Error::Simple("git $args[0] failed with exit code $code\nstdout: $stdout\nstderr: $stderr");
	}
	return($code, $stdout, $stderr);
}

sub was_merged {
	my ($self, $release, $branch) = @_;
	my $cmd = Git::Repository::Command->new( $self->{repo}, 'log', '--merges', '--pretty=format:%s', $release, '-1000', { quiet => 1 } );
	my $out_fh = $cmd->stdout();

	my $merged = 0;
	while (<$out_fh>) { if (/$branch/) { $merged = 1; last; } }
	$cmd->close();
	my $code = $cmd->exit();
	if ($code) {
		throw Error::Simple("git log failed with exit code $code\n");
	}
	return($merged);
}

sub fetch {
	my ($self) = @_;

	return $self->_command( 'fetch', { quiet => 1 } );
}

sub checkout {
	my ($self, $branch) = @_;

	return $self->_command( 'checkout', $branch, { quiet => 1 } );
}

sub checkout_track {
	my ($self, $branch) = @_;

	return $self->_command( 'checkout', '--track', '-b', $branch, , "origin/$branch", { quiet => 1 } );
}

sub rebase {
	my ($self, $release) = @_;

	return $self->_command( 'rebase', $release, { quiet => 1 } );
}

sub merge_no_ff {
	my ($self, $branch) = @_;

	return $self->_command( 'merge', '--no-ff', $branch, { quiet => 1 } );
}

sub pull {
	my ($self, $branch) = @_;

	return $self->_command( 'pull', 'origin', $branch, { quiet => 1 } );
}

sub push {
	my ($self, $branch) = @_;

	return $self->_command( 'push', 'origin', $branch, { quiet => 1 } );
}

sub get_latest_rc_branch {
	my ($self, $issue) = @_;

	return '' unless $issue;

	my $repo = $self->{repo};
	my $output = $repo->run( 'branch', '-r' );
	my @matches = ($output =~ /origin\/($issue[^\s]+rc)(\d+)\s/g);

	my $top_rc     = 0;
	my $top_branch = '';
	while (scalar(@matches)) {
		my $base = shift @matches;
		my $rc   = shift @matches;
		if ($rc > $top_rc) {
			$top_rc = $rc;
			$top_branch = $base . $rc;
		}
	}
	return $top_branch;
}

sub get_merged_branches {
	my ($self, $release) = @_;

	return () unless $release;

	my ($code, $stdout, $stderr) = $self->_command( 'branch', '--merged', { quiet => 1 } );
	return split(/\s+/, $stdout);
}

sub get_last_commits {
	my ($self, $branch, $number) = @_;

	return () unless $branch && $number;

	my ($code, $stdout, $stderr) = $self->_command( 'log', $branch, '--pretty=format:%H', "-$number", { quiet => 1 } );
	return split(/\s+/, $stdout);
}

sub format_patch {
	my ($self, $release) = @_;

	return '' unless $release;

	my ($code, $stdout, $stderr) = $self->_command( 'format-patch', $release, '--stdout', { quiet => 1 } );
	return $stdout;
}

sub check_apply_patch {
	my ($self, $patch) = @_;

	return (0, '', '') unless $patch;

	my $repo = $self->{repo};
	return $self->_command( 'apply', $patch, '--check', { quiet => 1 } );
}

1;
