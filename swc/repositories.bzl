"""Declare runtime dependencies

These are needed for local dev, and users must install them as well.
See https://docs.bazel.build/versions/main/skylark/deploying.html#dependencies
"""

load("@aspect_rules_js//js:npm_import.bzl", "npm_import", "translate_package_lock")
load("//swc/private:toolchains_repo.bzl", "PLATFORMS", "toolchains_repo")
load("//swc/private:versions.bzl", "TOOL_VERSIONS")

_DOC = "Fetch external tools needed for swc toolchain"
_ATTRS = {
    "swc_version": attr.string(mandatory = True, values = TOOL_VERSIONS.keys()),
    "platform": attr.string(mandatory = True, values = PLATFORMS.keys()),
}

def _swc_repo_impl(repository_ctx):
    filename = "swc.%s.node" % repository_ctx.attr.platform
    url = "https://github.com/swc-project/swc/releases/download/{0}/{1}".format(
        repository_ctx.attr.swc_version,
        filename,
    )
    repository_ctx.download(
        output = filename,
        url = url,
        integrity = TOOL_VERSIONS[repository_ctx.attr.swc_version][repository_ctx.attr.platform],
    )
    build_content = """#Generated by swc/repositories.bzl
load("@aspect_rules_swc//swc:toolchain.bzl", "swc_toolchain")
swc_toolchain(name = "swc_toolchain", node_binding = "%s")
""" % filename

    # Base BUILD file for this repository
    repository_ctx.file("BUILD.bazel", build_content)

swc_repositories = repository_rule(
    _swc_repo_impl,
    doc = _DOC,
    attrs = _ATTRS,
)

# Wrapper macro around everything above, this is the primary API
def swc_register_toolchains(name, **kwargs):
    """Convenience macro for users which does typical setup.

    - create a repository for each built-in platform like "swc_linux_amd64" -
      this repository is lazily fetched when node is needed for that platform.
    - TODO: create a convenience repository for the host platform like "swc_host"
    - create a repository exposing toolchains for each platform like "swc_platforms"
    - register a toolchain pointing at each platform
    Users can avoid this macro and do these steps themselves, if they want more control.
    Args:
        name: base name for all created repos, like "swc"
        **kwargs: passed to each node_repositories call
    """
    for platform in PLATFORMS.keys():
        swc_repositories(
            name = name + "_" + platform,
            platform = platform,
            **kwargs
        )
        native.register_toolchains("@%s_toolchains//:%s_toolchain" % (name, platform))

    toolchains_repo(
        name = name + "_toolchains",
        user_repository_name = name,
    )

    npm_import(
        integrity = "sha512-hNelzQ5ShAaaf2SHy4oZQ0dB8VCI4AaVchWEe5bZtirW3sY0gOqVL5V7x0b5Zzo0FyjlMnGIbX1k5IuX5uyn8A==",
        package = "@swc/core",
        version = "1.2.119",
        deps = [
            "@npm__napi-rs_triples-1.1.0",
            "@npm__node-rs_helper-1.2.1",
        ],
    )

    npm_import(
        integrity = "sha512-R5wEmm8nbuQU0YGGmYVjEc0OHtYsuXdpRG+Ut/3wZ9XAvQWyThN08bTh2cBJgoZxHQUPtvRfeQuxcAgLuiBISg==",
        package = "@node-rs/helper",
        version = "1.2.1",
    )

    npm_import(
        integrity = "sha512-XQr74QaLeMiqhStEhLn1im9EOMnkypp7MZOwQhGzqp2Weu5eQJbpPxWxixxlYRKWPOmJjsk6qYfYH9kq43yc2w==",
        package = "@napi-rs/triples",
        version = "1.1.0",
    )

    translate_package_lock(
        name = "swc_cli",
        package_lock = "@aspect_rules_swc//swc/private:package-lock.json",
    )
