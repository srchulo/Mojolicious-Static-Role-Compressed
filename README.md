# NAME

Mojolicious::Static::Role::Compressed - Role for Mojolicious::Static that
serves pre-compressed versions of static assets

# STATUS

<div>
    <a href="https://travis-ci.org/srchulo/Mojolicious-Static-Role-Compressed"><img src="https://travis-ci.org/srchulo/Mojolicious-Static-Role-Compressed.svg?branch=master"></a>
</div>

# SYNOPSIS

    # Defaults to serving br assets (with extension ".br"), then gzip (with extension ".gz"),
    # then falls back to the uncompressed asset. By default, this will not look for
    # compressed versions of PDF, PNG, GIF, JP(E)G, or WEBP files since these files
    # are already compressed.
    $app->static->with_roles('+Compressed');

    # Mojolicious::Lite
    app->static->with_roles('+Compressed');

    # or
    $app->static(Mojolicious::Static->new->with_roles('+Compressed'));

    # Don't use the defaults
    $app->static
        ->with_roles('+Compressed')
        ->compression_types(['br', {ext => 'gzip', encoding => 'gzip'}]) # default ext for gzip is 'gz'. This could also be done as ['br', 'gzip']
        ->should_serve_asset(sub { $_->path =~ /\.(html|js|css)$/i }); # only try to serve compressed html, js, and css assets. $_ contains the Mojo::Asset::File to be served

    # Look for compressed versions of all assets
    $app->static
        ->with_roles('+Compressed')
        ->should_serve_asset(sub { 1 });

    # Or just pass in 1 to look for compressed versions of all assets (slightly faster)
    $app->static
        ->with_roles('+Compressed')
        ->should_serve_asset(1);

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
being a true scalar value or a subroutine that returns true for the given
[Mojo::Asset::File](https://metacpan.org/pod/Mojo::Asset::File).
- ["accept\_encoding" in Mojo::Headers](https://metacpan.org/pod/Mojo::Headers#accept_encoding) for the request contains at least one encoding
listed in ["compression\_types"](#compression_types).
- A compressed version of the asset is found that is smaller than the original
asset. Assets are expected to be located at the path of the original asset,
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

    $app->static
        ->with_roles('+Compressed')
        ->compression_types(['br', {ext => 'gz', encoding => 'gzip'}]); # This is the default

Compression types accepts an arrayref made up of strings and/or hashrefs.
Strings will be used as both the file extension and the encoding type. The
encoding type is what is used and expected in request and response headers to
specify the encoding. Below is an example of this and the default for
["compression\_types"](#compression_types):

    ['br', {ext => 'gz', encoding => 'gzip'}]

This means that br is both the extension used when looking for compressed
assets, and the encoding used in headers. Internally, `'br'` will be converted
to `{ext =` 'br', encoding => 'br'}>, and this is how it will appear if you
call ["compression\_types"](#compression_types) as a getter.

Assets are expected to be located at the path of the original asset, followed
by a period and the extension: `/path/to/asset.css` ->
`/path/to/asset.css.gz`

Compression types will be checked for in the order they are specified, with the
first one that matches all of the requirements in ["DESCRIPTION"](#description) being used.
["compression\_types"](#compression_types) cannot be changed once [Mojo::Static](https://metacpan.org/pod/Mojo::Static) begins serving
compressed assets (["serve\_asset" in Mojo::Static](https://metacpan.org/pod/Mojo::Static#serve_asset) is called, either directly or
indirectly, such as by ["serve" in Mojo::Static](https://metacpan.org/pod/Mojo::Static#serve), and we succeed in finding and
serving a compressed asset). If you want to change these when the app is
already running, you should create a new [Mojolicious::Static](https://metacpan.org/pod/Mojolicious::Static) object and add
the role and your ["compression\_types"](#compression_types) again. I'm not sure why you would want
to change this once the app is already running and serving assets, and this may
cause assets that are being served in compressed chunks to be re-served as the
uncompressed asset or a different compressed asset.

`ext` and `encoding` must be unique across different compression types.

## should\_serve\_asset

    $app->static
        ->with_roles('+Compressed')
        ->should_serve_asset(sub { $_->path !~ /\.(pdf|jpe?g|gif|png|webp)$/i }); # This is the default

    # subroutine returning 1 means try to serve compressed versions of all assets.
    $app->static
        ->with_roles('+Compressed')
        ->should_serve_asset(sub { 1 });

    # using 1 directly also tries to serve compressed versions of all assets and is slightly faster
    $app->static
        ->with_roles('+Compressed')
        ->should_serve_asset(1);

["should\_serve\_asset"](#should_serve_asset) is a subroutine (or scalar) that determines whether or
not [Mojolicious::Static::Role::Compressed](https://metacpan.org/pod/Mojolicious::Static::Role::Compressed) should attempt to serve a
compressed version of a [Mojo::Asset::File](https://metacpan.org/pod/Mojo::Asset::File). If it is a subroutine, `$_` is
set to the [Mojo::Asset::File](https://metacpan.org/pod/Mojo::Asset::File) that will be served. The default is to not look
for compressed versions of any assets whose ["path" in Mojo::Asset::File](https://metacpan.org/pod/Mojo::Asset::File#path) indicates
that it is a pdf, jpg, gif, png, or webp file, as these file types are already
compressed:

    sub { $_->path !~ /\.(pdf|jpe?g|gif|png|webp)$/i }) # default for should_serve_asset

To look for compressed versions of all assets, set ["should\_serve\_asset"](#should_serve_asset) to a
subroutine that always returns `1`:

    $app->static
        ->with_roles('+Compressed')
        ->should_serve_asset(sub { 1 });

Or you can set ["should\_serve\_asset"](#should_serve_asset) to 1, which is slightly faster:

    $app->static
        ->with_roles('+Compressed')
        ->should_serve_asset(1);

Setting ["should\_serve\_asset"](#should_serve_asset) to a scalar that evaluates to false, such as
`undef`, will cause a warning. If ["should\_serve\_asset"](#should_serve_asset) is a false scalar,
there is no point in loading [Mojolicious::Static::Role::Compressed](https://metacpan.org/pod/Mojolicious::Static::Role::Compressed).

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
