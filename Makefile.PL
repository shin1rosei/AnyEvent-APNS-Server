use inc::Module::Install;
name 'AnyEvent-APNS-Server';
all_from 'lib/AnyEvent/APNS/Server.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
