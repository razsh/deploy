package Google::Chrome::CookieJar;

use strict;
use warnings;

use Crypt::Mode::CBC;
use Crypt::PBKDF2;
use DBI;

sub _get_osx_chrome_pass {
	my $p = `/usr/bin/security find-generic-password  -a 'Chrome' -s 'Chrome Safe Storage' -g 2>&1`;
	if($p =~ /^\s*password:\s*"([^"]+)"/m) {
		return $1;
	}
	return '';
}

our $jar_file;
our $crypto   = {
	salt       => 'saltysalt',
	iv         => ' ' x 16,
	output_len => 16
};

if ($^O eq 'linux') {
	$jar_file             = "$ENV{HOME}/.config/google-chrome/Default/Cookies";
	$crypto->{pass}       = 'peanuts';
	$crypto->{iterations} = 1;
} elsif ($^O eq 'darwin') {
	$jar_file             = "$ENV{HOME}/Library/Application Support/Google/Chrome/Default/Cookies";
	$crypto->{pass}       = _get_osx_chrome_pass();
	$crypto->{iterations} = 1003;
} else {
	die "Your OS is not supported\n";
}

our $pbkdf2 = Crypt::PBKDF2->new(
	hash_class => 'HMACSHA1',
	iterations => $crypto->{iterations},
	output_len => $crypto->{output_len},
	salt_len   => length($crypto->{salt})
);

our $hash = $pbkdf2->PBKDF2(
	$crypto->{salt},
	$crypto->{pass},
	$crypto->{iterations},
	undef,
	$crypto->{output_len}
);

sub new {
	my ($class) = @_;

	my $self = {
		loaded => 0,
		hash   => $hash,
		rows   => []
	};

	return bless $self, $class;
}

sub load {
	my ($self) = @_;

	return if $self->{loaded};

	my $dbh = DBI->connect( "dbi:SQLite:dbname=$jar_file", '', '',
		{ sqlite_see_if_its_a_number => 1 }
	);

	my $sth = $dbh->prepare( 'SELECT host_key, name, value, encrypted_value FROM cookies' );
	$sth->execute;

	$self->{rows}   = $sth->fetchall_arrayref();
	$self->{loaded} = 1;

	return 1;
}

sub get_cookie_string {
	my ($self, $host) = @_;

	return '' unless $host;

	$self->load() unless $self->{loaded};

	my $cookie_str = '';
	foreach my $row ( @{ $self->{rows} } ) {
		my ($host_key, $name, $value, $encrypted_value) = @{$row};

		next unless $host_key =~ /$host/;

		my $decrypted_value;
		if ( $value || $encrypted_value !~ /^v10/) {
			$decrypted_value = $value;
		} else {
			$decrypted_value = $self->_decrypt_data($encrypted_value);
		}
		$cookie_str .= "$name=$decrypted_value;";
	}
	return $cookie_str;
}

sub _decrypt_data {
	my ($self, $encrypted_value) = @_;

	$encrypted_value =~ s/^v10//;

	my $m = Crypt::Mode::CBC->new('AES');
	my $plaintext = $m->decrypt($encrypted_value, $self->{hash}, $crypto->{iv});

	return $plaintext;
}

1;
