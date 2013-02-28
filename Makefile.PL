use inc::Module::Install;
name 'AnyEvent-APNS-Server';
all_from 'lib/AnyEvent/APNS/Server.pm';

requires 'Cache::LRU';
requires 'Log::Minimal';
requires 'Mouse';
requires 'AnyEvent::MPRPC';
requires 'AnyEvent::APNS';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
