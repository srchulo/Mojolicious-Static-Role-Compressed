package TestHelpers;
use Mojo::Base -strict;
use Mojo::Date;
use Mojo::Asset::File;
use Mojo::Util ();
use FindBin;

our @ISA    = qw(Exporter);
our @EXPORT = qw/etag last_modified/;

sub etag {
    my ($file, @encodings) = @_;
    my $md5 = Mojo::Util::md5_sum(_mtime($file));

    my $etag = qq{"$md5"};
    return wantarray ? ($etag, map {qq{"$md5-$_"}} @encodings) : $etag;
}

sub last_modified { Mojo::Date->new(_mtime(shift))->to_string }

sub _mtime {
    Mojo::Asset::File->new(path => "$FindBin::Bin/public/@{[shift]}")->mtime;
}

1;
