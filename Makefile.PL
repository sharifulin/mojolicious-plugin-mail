# Note: this file was auto-generated by Module::Build::Compat version 0.4210
require 5.001001;
use ExtUtils::MakeMaker;
WriteMakefile
(
  'EXE_FILES' => [],
  'NAME' => 'Mojolicious::Plugin::Mail',
  'PREREQ_PM' => {
                   'MIME::Lite' => '3.027',
                   'Encode' => 0,
                   'Test::More' => 0,
                   'MIME::EncWords' => 0,
                   'Mojolicious' => '5'
                 },
  'INSTALLDIRS' => 'site',
  'PL_FILES' => {},
  'VERSION_FROM' => 'lib/Mojolicious/Plugin/Mail.pm'
)
;
