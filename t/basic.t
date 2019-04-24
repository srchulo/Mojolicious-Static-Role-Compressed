use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;
use FindBin;
use lib "$FindBin::Bin/lib";
use TestHelpers;

local $ENV{MOJO_GZIP} = 0;

app->static->with_roles('+Compressed');

my $hello_etag          = etag('hello.txt');
my $hello_last_modified = last_modified('hello.txt');

my ($goodbye_etag, $goodbye_etag_br, $goodbye_etag_gzip) = etag('goodbye.txt', 'br', 'gzip');
my $goodbye_last_modified = last_modified('goodbye.txt');

my $t = Test::Mojo->new;

# hello.txt has no compressed files
$t->get_ok('/hello.txt' => {'Accept-Encoding' => 'br, gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is(ETag => $hello_etag)
    ->header_is('Last-Modified' => $hello_last_modified)
    ->content_is("Hello Mojo from a static file!\n");
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

$t->get_ok('/goodbye.txt')->status_is(200)->content_type_is('text/plain;charset=UTF-8')
    ->header_is(ETag => $goodbye_etag)->header_is('Last-Modified' => $goodbye_last_modified)
    ->content_is("Goodbye Mojo from a static file!\n");
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

$t->get_ok('/goodbye.txt' => {'Accept-Encoding' => ''})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is(ETag => $goodbye_etag)
    ->header_is('Last-Modified' => $goodbye_last_modified)
    ->content_is("Goodbye Mojo from a static file!\n");
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

$t->get_ok('/goodbye.txt' => {'Accept-Encoding' => 'nothing'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is(ETag => $goodbye_etag)
    ->header_is('Last-Modified' => $goodbye_last_modified)
    ->content_is("Goodbye Mojo from a static file!\n");
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

$t->get_ok('/goodbye.txt' => {'Accept-Encoding' => 'br, gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is('Content-Encoding' => 'br')
    ->header_is(ETag => $goodbye_etag_br)->header_is('Last-Modified' => $goodbye_last_modified)
    ->header_is(Vary => 'Accept-Encoding')->content_is("Goodbye Mojo from a br file!\n");
$t->get_ok('/goodbye.txt' => {'Accept-Encoding' => 'gzip, br'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is('Content-Encoding' => 'br')
    ->header_is(ETag => $goodbye_etag_br)->header_is('Last-Modified' => $goodbye_last_modified)
    ->header_is(Vary => 'Accept-Encoding')->content_is("Goodbye Mojo from a br file!\n");
$t->get_ok('/goodbye.txt' => {'Accept-Encoding' => 'br'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is('Content-Encoding' => 'br')
    ->header_is(ETag => $goodbye_etag_br)->header_is('Last-Modified' => $goodbye_last_modified)
    ->header_is(Vary => 'Accept-Encoding')->content_is("Goodbye Mojo from a br file!\n");
$t->get_ok('/goodbye.txt' => {'Accept-Encoding' => 'gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is('Content-Encoding' => 'gzip')
    ->header_is(ETag => $goodbye_etag_gzip)->header_is('Last-Modified' => $goodbye_last_modified)
    ->header_is(Vary => 'Accept-Encoding')->content_is("Goodbye Mojo from a gz file!\n");

# test when file is dir
my $tmpdir = Mojo::File::tempdir();
push @{app->static->paths}, $tmpdir;

Mojo::File->new("$tmpdir/basic_dir.txt")->spurt('Hello from the dir file!');
my ($dir_etag, $dir_etag_gzip) = etag(app->static, 'basic_dir.txt', 'gzip');
my $dir_last_modified = last_modified(app->static, 'basic_dir.txt');
my $dir_gzip_path     = "$tmpdir/basic_dir.txt.gz";
mkdir "$dir_gzip_path" or die 'failed to make dir';
$t->get_ok('/basic_dir.txt' => {'Accept-Encoding' => 'br, gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is(ETag => $dir_etag)
    ->header_is('Last-Modified' => $dir_last_modified)->content_is('Hello from the dir file!');
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

# test when we cannot read compressed asset path
# first, test that we can read it
Mojo::File->new("$tmpdir/basic_unreadable.txt")->spurt('Hello from the uncompressed file!');
my $unreadable_compressed_file
    = Mojo::File->new("$tmpdir/basic_unreadable.txt.gz")->spurt('Hello from the compressed file!');

my ($unreadable_etag, $unreadable_etag_gzip) = etag(app->static, 'basic_unreadable.txt', 'gzip');
my $unreadable_last_modified = last_modified(app->static, 'basic_unreadable.txt');
$t->get_ok('/basic_unreadable.txt' => {'Accept-Encoding' => 'br, gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is('Content-Encoding' => 'gzip')
    ->header_is(ETag            => $unreadable_etag_gzip)
    ->header_is('Last-Modified' => $unreadable_last_modified)->header_is(Vary => 'Accept-Encoding')
    ->content_is('Hello from the compressed file!');

# make compressed file unreadable
$unreadable_compressed_file->chmod(0000);
my $unreadable_compressed_path = $unreadable_compressed_file->path;
$t->get_ok('/basic_unreadable.txt' => {'Accept-Encoding' => 'br, gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is(ETag => $unreadable_etag)
    ->header_is('Last-Modified' => $unreadable_last_modified)
    ->content_is('Hello from the uncompressed file!');
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

# make file readable again and test that it works, then delete and test that we get warning
$unreadable_compressed_file->chmod(0777);
$t->get_ok('/basic_unreadable.txt' => {'Accept-Encoding' => 'br, gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is('Content-Encoding' => 'gzip')
    ->header_is(ETag            => $unreadable_etag_gzip)
    ->header_is('Last-Modified' => $unreadable_last_modified)->header_is(Vary => 'Accept-Encoding')
    ->content_is('Hello from the compressed file!');

unlink $unreadable_compressed_path;
$t->get_ok('/basic_unreadable.txt' => {'Accept-Encoding' => 'br, gzip'})->status_is(200)
    ->content_type_is('text/plain;charset=UTF-8')->header_is(ETag => $unreadable_etag)
    ->header_is('Last-Modified' => $unreadable_last_modified)
    ->content_is('Hello from the uncompressed file!');
ok !!$t->tx->res->headers->every_header('Content-Encoding'), 'content-encoding header is not set';
ok !!$t->tx->res->headers->every_header('Vary'),             'vary header is not set';

done_testing;
