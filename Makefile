install: config
	cpan Git::Repository
	cpan Crypt::Mode::CBC
	cpan Crypt::PBKDF2
	cpan DBD::SQLite
	@echo ""
	@echo ""
	@echo "Don't forget to edit your lib/deploy/Config.pm"

config: lib/deploy/Config.pm

lib/deploy/Config.pm:
	cp lib/deploy/Config.pm-default lib/deploy/Config.pm
