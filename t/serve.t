use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;

local $ENV{MOJO_GZIP} = 0;

app->static->with_roles('+Compressed');

get '/hello'   => sub { shift->reply->static('hello.txt') };
get '/goodbye' => sub { shift->reply->static('goodbye.txt') };

my $t = Test::Mojo->new;

# hello.txt has no compressed files
$t->get_ok('/hello' => {'Accept-Encoding' => 'br, gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->content_is("Hello Mojo from a static file!\n");
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

$t->get_ok('/goodbye')->status_is(200)->content_type_is('text/plain;charset=UTF-8')
    ->content_is("Goodbye Mojo from a static file!\n");
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

$t->get_ok('/goodbye' => {'Accept-Encoding' => ''})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->content_is("Goodbye Mojo from a static file!\n");
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

$t->get_ok('/goodbye' => {'Accept-Encoding' => 'nothing'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->content_is("Goodbye Mojo from a static file!\n");
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

$t->get_ok('/goodbye' => {'Accept-Encoding' => 'br, gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is('Content-Encoding' => 'br')
    ->header_is(Vary => 'Accept-Encoding')->content_is("Goodbye Mojo from a br file!\n");
$t->get_ok('/goodbye' => {'Accept-Encoding' => 'gzip, br'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is('Content-Encoding' => 'br')
    ->header_is(Vary => 'Accept-Encoding')->content_is("Goodbye Mojo from a br file!\n");
$t->get_ok('/goodbye' => {'Accept-Encoding' => 'br'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is('Content-Encoding' => 'br')
    ->header_is(Vary => 'Accept-Encoding')->content_is("Goodbye Mojo from a br file!\n");
$t->get_ok('/goodbye' => {'Accept-Encoding' => 'gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is('Content-Encoding' => 'gzip')
    ->header_is(Vary => 'Accept-Encoding')->content_is("Goodbye Mojo from a gz file!\n");

done_testing;
