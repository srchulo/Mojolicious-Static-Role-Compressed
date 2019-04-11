package Mojolicious::Static::Role::Compressed;
use Mojo::Base -role;
use Mojo::Util   ();
use Scalar::Util ();

our $VERSION = '0.01';

has compression_types  => sub { ['br', {ext => 'gz', encoding => 'gzip'}] };
has _compression_types => sub {
    [map { Scalar::Util::reftype($_) ? $_ : {ext => $_, encoding => $_} }
          @{shift->compression_types}]
};

has should_serve_asset => sub {
    sub { $_->path !~ /\.(pdf|jpe?g|gif|png|webp)$/i }
};

before serve_asset => sub {
    my ($self, $c, $asset) = @_;

    return unless $asset->is_file;
    return unless $self->_should_serve_asset($asset);

    my $req_headers               = $c->req->headers;
    my $compression_possibilities = $self->_get_compression_possibilities($req_headers);
    return unless @$compression_possibilities;

    my ($compressed_asset, $compression_type) =
      $self->_get_compressed_asset_and_compression_type($req_headers->accept_encoding,
        $asset, $compression_possibilities);
    return unless $compressed_asset and $compression_type;

    my $res_headers = $c->res->headers;
    $res_headers->append(Vary => 'Accept-Encoding');
    $res_headers->content_encoding($compression_type->{encoding});

    # in case Mojolicious::Static::serve wasn't called first
    $c->app->types->content_type($c, {file => $asset->path});

    # set stash with asset for use in is_fresh before method modifier
    $self->_stash($c, asset            => $asset);
    $self->_stash($c, compression_type => $compression_type);

    $_[2] = $compressed_asset;
};

before is_fresh => sub {
    my ($self, $c, $options) = @_;
    return unless my $asset = $self->_stash($c, 'asset');
    my $compression_type = $self->_stash($c, 'compression_type');

    my $mtime = $asset->mtime;
    my $etag  = Mojo::Util::md5_sum($mtime) . '-' . $compression_type->{encoding};

    @$options{qw/last_modified etag/} = ($mtime, $etag);
};

sub _should_serve_asset {
    my ($self, $asset) = @_;
    return 1 unless my $should_serve_asset = $self->should_serve_asset;

    local $_ = $asset;
    return $should_serve_asset->();
}

sub _get_compression_possibilities {
    my ($self, $accept_encoding) = @_;
    return $accept_encoding
      ? [grep { $accept_encoding =~ /$_->{encoding}/i } @{$self->_compression_types}]
      : [];
}

sub _get_compressed_asset_and_compression_type {
    my ($self, $headers, $asset, $compression_possibilities) = @_;

    my $match = $headers->if_none_match;
    if ($match and $match =~ /-(.*)"$/) {
        if (my @compression_types = grep { $_->{encoding} eq $1 } @{$self->_compression_types}) {
            if (@compression_types > 1) {
                warn
                  "more than one matching compression type found for If-None-Match $match and encoding $1";
                return;
            }

            my $compression_type      = $compression_types[0];
            my $compressed_asset_path = $asset->path . '.' . $compression_type->{ext};
            my $compressed_asset      = $self->_get_compressed_file($compressed_asset_path);
            return ($compressed_asset, $compression_type) if $compressed_asset;

            warn
              "Found compression type with encoding of $compression_type->{encoding} in If-None-Match $match, but asset at $compressed_asset_path does not exist";

            # return and let Mojolicious::Static::is_fresh fail on etag and the uncompressed asset
            # can be served
            return;
        }
    }

    for my $compression_type (@$compression_possibilities) {
        next
          unless my $compressed_asset =
          $self->_get_compressed_file($asset->path . '.' . $compression_type->{ext});
        if ($compressed_asset->size >= $asset->size) {
            warn 'Compressed asset '
              . $compressed_asset->path . ' is '
              . $compressed_asset->size
              . ' bytes, and uncompressed asset '
              . $asset->path . ' is '
              . $asset->size
              . ' bytes. Continuing search for compressed assets.';
        }

        return ($compressed_asset, $compression_type);
    }

    return;
}

sub _get_compressed_file {
    my ($self, $path) = @_;
    return -f -r $path ? Mojo::Asset::File->new(path => $path) : undef;
}

sub _stash {
    my ($self, $c, $key, $value) = @_;

    $key = "mojolicious_static_role_compressed.$key";
    if ($value) {
        $c->stash->{$key} = $value;
    } else {
        return $c->stash->{$key};
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Mojolicious::Static::Role::Compressed - Role for Mojolicious::Static that
serves pre-compressed versions of static assets

=head1 STATUS

=for html <a href="https://travis-ci.org/srchulo/Mojolicious-Static-Role-Compressed"><img src="https://travis-ci.org/srchulo/Mojolicious-Static-Role-Compressed.svg?branch=master"></a>

=head1 SYNOPSIS

  # Defaults to serving br assets, then gzip, then falls back to the uncompressed asset.
  # By default, this will not look for compressed versions of PDF, PNG, GIF, JP(E)G, or WEBP files.
  $app->static(Mojolicious::Static->new->with_roles('+Compressed');

  # Don't use the defaults
  $app->static(
    Mojolicious::Static->new
        ->with_roles('+Compressed')
        ->compression_types(['br', { ext => 'gzip', encoding => 'gzip'}]) # default ext for gzip is 'gz'. This could also be done as ['br', 'gzip']
        ->should_serve_asset(sub { $_->path ~= /\.(html|js|css)$/i }) # only try to serve compressed html, js, and css assets. $_ contains a Mojo::Asset::File
  );

  # Look for compressed versions of all assets
  $app->static(
    Mojolicious::Static->new
        ->with_roles('+Compressed')
        ->should_serve_asset(undef) # No subroutine means look for compressed versions of all assets
        ->should_serve_asset(sub { 1 }); # Or always return 1
  );

=head1 DESCRIPTION

L<Mojolicious::Static::Role::Compressed> is a role for L<Mojolicious::Static>
that provides the ability to serve pre-compressed versions of static asset.
L<Mojolicious::Static::Role::Compressed> does this by using the before method
modifier on L<Mojolicious::Static/serve_asset> and
L<Mojolicious::Static/is_fresh>. A static asset will be served when all of the
following conditions are met:

=over 4

=item *

The asset passed to L<Mojolicious::Static/serve_asset> is a
L<Mojo::Asset::File> (L<Mojo::Asset/is_file> returns C<1>).

=item *

It is determined that the asset should be served by L</should_serve_asset>
being C<undef> or a subroutine that returns C<1> for the given
L<Mojo::Asset::File>.

=item *

L<Mojo::Headers/accept_encoding> for the request contains at least one encoding
listed in L</compression_types>.

=item *

A compressed version of the asset is found that is smaller than the original
asset. Assets are expected to be located at the path to the original asset,
followed by a period and the extension: C</path/to/asset.css> ->
C</path/to/asset.css.gz>

=back

L<Mojolicious::Static::Role::Compressed> uses the same modified time as the
original asset when setting L<Mojo::Headers/last_modified> in the response, and
modifies the ETag (L<Mojo::Headers/etag>) in the response by appending
C<"-$encoding"> (i.e. "etag-gzip"), where the encoding is specified in
L</compression_types>. This is in line with
L<RFC-7232|https://tools.ietf.org/html/rfc7232#section-2.3.3>, which explicitly
states that ETags should be content-coding aware.

=head1 ATTRIBUTES

=head2 compression_types

  Mojolicious::Static->new
    ->with_roles('+Compressed)
    ->compression_types(['br', {ext => 'gz', encoding => 'gzip'}]); # This is the default

Compression types accepts an arrayref made up of strings and/or hashrefs.
Strings will be used as the file extension and the encoding type. The encoding
type is what is used and expected in request and response headers to specify
the encoding. Below is an example of this and the default for
L</compression_types>:

  ['br', {ext => 'gz', encoding => 'gzip'}]

This means that br is both the extension used when looking for compressed
assets, and the encoding used in headers. Assets are expected to be located at
the path to the original asset, followed by a period and the extension:
C</path/to/asset.css> -> C</path/to/asset.css.gz>

Compression types will be checked for in the order they are specified, with the
first one that matches all of the requirements in L</DESCRIPTION> being used.
L</compression_types> should not be changed once L<Mojo::Static> begins serving
assets, so if you want to change these when the app is already running, you
should create a new L<Mojolicious::Static> object and add the role and your
config again (although I'm not sure why you would want to change this once the
app is already running and serving assets).

=head2 should_serve_asset

  Mojolicious::Static->new
    ->with_roles('+Compressed)
    ->should_serve_asset(sub { $_->path !~ /\.(pdf|jpe?g|gif|png|webp)$/i }); # This is the default

  # undef means try to serve compressed versions of all assets because there is no subroutine to call
  Mojolicious::Static->new
    ->with_roles('+Compressed)
    ->should_serve_asset(undef);

  # subroutine returning 1 also means try to serve compressed versions of all assets.
  # This may be more clear, but will also be slightly less efficient.
  Mojolicious::Static->new
    ->with_roles('+Compressed)
    ->should_serve_asset(sub { 1 });

L</should_serve_asset> is a subroutine that determines whether or not
L<Mojolicious::Static::Role::Compressed> should attempt to serve a compressed
version of a L<Mojo::Asset::File>. The subroutine is passed the
L<Mojo::Asset::File> in C<$_>. The default is to not look for compressed
versions of any assets whose L<Mojo::Asset::File/path> indicates that it is a
pdf, jpg, gif, png, or webp file, as these file types are already compressed:

  sub { $_->path !~ /\.(pdf|jpe?g|gif|png|webp)$/i }) # default for should_serve_asset

To look for compressed versions of all assets, set L</should_serve_asset> to
C<undef>:

  Mojolicious::Static->new
    ->with_roles('+Compressed)
    ->should_serve_asset(undef);

Or alternatively, set it to a subroutine that returns 1:

  Mojolicious::Static->new
    ->with_roles('+Compressed)
    ->should_serve_asset(sub { 1 });

Which may be considered clearer, but will also be less efficient.

=head1 RESERVED STASH KEYS

L<Mojolicious::Static::Role::Compressed> uses the stash keys
C<mojolicious_static_role_compressed.asset> and
C<mojolicious_static_role_compressed.compression_type> internally, so these
should not be used by elsewhere in the L<Mojolicious> app. There are no plans
for other stash keys, but other keys under
C<mojolicious_static_role_compressed.*> should be avoided when using this role.

=head1 AUTHOR

Adam Hopkins E<lt>srchulo@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2019- Adam Hopkins

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item *

L<Mojolicious::Static>

=item *

L<Mojolicious>

=item *

L<https://mojolicious.org>

=back

=cut
