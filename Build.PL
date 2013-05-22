use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
	module_name         => 'Mojolicious::Plugin::Mail',
	license             => 'perl',
	dist_author         => 'Anatoly Sharifulin <sharifulin@gmail.com>',
	dist_version_from   => 'lib/Mojolicious/Plugin/Mail.pm',
	dist_abstract       => 'Mojolicious Plugin for send mail',
	build_requires => {
		'Test::More' => 0,
	},
	requires => {
		'perl'           => 5.001001,
		'Encode'         => 0,
		'MIME::Lite'     => 3.027,
		'MIME::EncWords' => 0,
		'Mojolicious'    => 4.0,
	},
	add_to_cleanup  => [],
	meta_merge => {
		resources => {
			repository => 'http://github.com/sharifulin/Mojolicious-Plugin-Mail',
		},
		keywords => ['mojo', 'mojolicious', 'mime', 'mail', 'plugin'],
	},
	create_makefile_pl => 'traditional',
);

$builder->create_build_script();