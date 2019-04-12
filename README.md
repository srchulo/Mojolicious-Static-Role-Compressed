# NAME

Mojolicious::Static::Role::Compressed - Role for Mojolicious::Static that
serves pre-compressed versions of static assets

# STATUS

<div>
    <a href="https://travis-ci.org/srchulo/Mojolicious-Static-Role-Compressed"><img src="https://travis-ci.org/srchulo/Mojolicious-Static-Role-Compressed.svg?branch=master"></a>
</div>

# SYNOPSIS

    # Defaults to serving br assets, then gzip, then falls back to the uncompressed asset.
    # By default, this will not look for compressed versions of PDF, PNG, GIF, JP(E)G, or WEBP files.
    $app->static(Mojolicious::Static->new->with_roles('+Compressed'));

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

# DESCRIPTION

[Mojolicious::Static::Role::Compressed](https://metacpan.org/pod/Mojolicious::Static::Role::Compressed) is a role for [Mojolicious::Static](https://metacpan.org/pod/Mojolicious::Static)
that provides the ability to serve pre-compressed versions of static asset.
[Mojolicious::Static::Role::Compressed](https://metacpan.org/pod/Mojolicious::Static::Role::Compressed) does this by using the before method
modifier on ["serve\_asset" in Mojolicious::Static](https://metacpan.org/pod/Mojolicious::Static#serve_asset) and
["is\_fresh" in Mojolicious::Static](https://metacpan.org/pod/Mojolicious::Static#is_fresh). A static asset will be served when all of the
following conditions are met:

- The asset passed to ["serve\_asset" in Mojolicious::Static](https://metacpan.org/pod/Mojolicious::Static#serve_asset) is a
[Mojo::Asset::File](https://metacpan.org/pod/Mojo::Asset::File) (["is\_file" in Mojo::Asset](https://metacpan.org/pod/Mojo::Asset#is_file) returns `1`).
- It is determined that the asset should be served by ["should\_serve\_asset"](#should_serve_asset)
being `undef` or a subroutine that returns `1` for the given
[Mojo::Asset::File](https://metacpan.org/pod/Mojo::Asset::File).
- ["accept\_encoding" in Mojo::Headers](https://metacpan.org/pod/Mojo::Headers#accept_encoding) for the request contains at least one encoding
listed in ["compression\_types"](#compression_types).
- A compressed version of the asset is found that is smaller than the original
asset. Assets are expected to be located at the path to the original asset,
followed by a period and the extension: `/path/to/asset.css` ->
`/path/to/asset.css.gz`

[Mojolicious::Static::Role::Compressed](https://metacpan.org/pod/Mojolicious::Static::Role::Compressed) uses the same modified time as the
original asset when setting ["last\_modified" in Mojo::Headers](https://metacpan.org/pod/Mojo::Headers#last_modified) in the response, and
modifies the ETag (["etag" in Mojo::Headers](https://metacpan.org/pod/Mojo::Headers#etag)) in the response by appending
`"-$encoding"` (i.e. "etag-gzip"), where the encoding is specified in
["compression\_types"](#compression_types). This is in line with
[RFC-7232](https://tools.ietf.org/html/rfc7232#section-2.3.3), which explicitly
states that ETags should be content-coding aware.

# ATTRIBUTES

## compression\_types

    Mojolicious::Static->new
      ->with_roles('+Compressed)
      ->compression_types(['br', {ext => 'gz', encoding => 'gzip'}]); # This is the default

Compression types accepts an arrayref made up of strings and/or hashrefs.
Strings will be used as the file extension and the encoding type. The encoding
type is what is used and expected in request and response headers to specify
the encoding. Below is an example of this and the default for
["compression\_types"](#compression_types):

    ['br', {ext => 'gz', encoding => 'gzip'}]

This means that br is both the extension used when looking for compressed
assets, and the encoding used in headers. Assets are expected to be located at
the path to the original asset, followed by a period and the extension:
`/path/to/asset.css` -> `/path/to/asset.css.gz`

Compression types will be checked for in the order they are specified, with the
first one that matches all of the requirements in ["DESCRIPTION"](#description) being used.
["compression\_types"](#compression_types) should not be changed once [Mojo::Static](https://metacpan.org/pod/Mojo::Static) begins serving
assets, so if you want to change these when the app is already running, you
should create a new [Mojolicious::Static](https://metacpan.org/pod/Mojolicious::Static) object and add the role and your
config again (although I'm not sure why you would want to change this once the
app is already running and serving assets).

## should\_serve\_asset

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

["should\_serve\_asset"](#should_serve_asset) is a subroutine that determines whether or not
[Mojolicious::Static::Role::Compressed](https://metacpan.org/pod/Mojolicious::Static::Role::Compressed) should attempt to serve a compressed
version of a [Mojo::Asset::File](https://metacpan.org/pod/Mojo::Asset::File). The subroutine is passed the
[Mojo::Asset::File](https://metacpan.org/pod/Mojo::Asset::File) in `$_`. The default is to not look for compressed
versions of any assets whose ["path" in Mojo::Asset::File](https://metacpan.org/pod/Mojo::Asset::File#path) indicates that it is a
pdf, jpg, gif, png, or webp file, as these file types are already compressed:

    sub { $_->path !~ /\.(pdf|jpe?g|gif|png|webp)$/i }) # default for should_serve_asset

To look for compressed versions of all assets, set ["should\_serve\_asset"](#should_serve_asset) to
`undef`:

    Mojolicious::Static->new
      ->with_roles('+Compressed)
      ->should_serve_asset(undef);

Or alternatively, set it to a subroutine that returns 1:

    Mojolicious::Static->new
      ->with_roles('+Compressed)
      ->should_serve_asset(sub { 1 });

Which may be considered clearer, but will also be less efficient.

# RESERVED STASH KEYS

[Mojolicious::Static::Role::Compressed](https://metacpan.org/pod/Mojolicious::Static::Role::Compressed) uses the stash keys
`mojolicious_static_role_compressed.asset` and
`mojolicious_static_role_compressed.compression_type` internally, so these
should not be used by elsewhere in the [Mojolicious](https://metacpan.org/pod/Mojolicious) app. There are no plans
for other stash keys, but other keys under
`mojolicious_static_role_compressed.*` should be avoided when using this role.

# AUTHOR

Adam Hopkins <srchulo@cpan.org>

# COPYRIGHT

Copyright 2019- Adam Hopkins

# LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

# SEE ALSO

- [Mojolicious::Static](https://metacpan.org/pod/Mojolicious::Static)
- [Mojolicious](https://metacpan.org/pod/Mojolicious)
- [https://mojolicious.org](https://mojolicious.org)
