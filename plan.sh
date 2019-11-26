pkg_name=dbgis11
pkg_origin=devoptimist
pkg_version="11.2"
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_license=("Apache-2.0")
pkg_source="https://ftp.postgresql.org/pub/source/v${pkg_version}/postgresql-${pkg_version}.tar.bz2"
pkg_shasum="2676b9ce09c21978032070b6794696e0aa5a476e3d21d60afc036dc0a9c09405"
pkg_dirname="postgresql-${pkg_version}"

pkg_deps=(
  core/bash
  core/gawk
  core/glibc
  core/grep
  core/libossp-uuid
  core/openssl
  core/perl
  core/readline
  core/zlib
  # for postgis
  core/libxml2
  core/geos
  core/proj
  core/gdal
)

pkg_build_deps=(
  core/coreutils
  core/gcc
  core/make
  # for postgis
  core/perl
  core/diffutils
)

pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)
pkg_exports=(
  [port]=port
  [superuser_name]=superuser.name
  [superuser_password]=superuser.password
)
pkg_exposes=(port)

ext_postgis_version=2.5.0
ext_postgis_source=http://download.osgeo.org/postgis/source/postgis-${ext_postgis_version}.tar.gz
ext_postgis_filename=postgis-${ext_postgis_version}.tar.gz
ext_postgis_shasum="be73abd747e9665f29748e0e7dc6b3f7b1ce98f32e3567f08259420ca10e36d5"

do_before() {
  ext_postgis_dirname="postgis-${ext_postgis_version}"
  ext_postgis_cache_path="$HAB_CACHE_SRC_PATH/${ext_postgis_dirname}"
}

do_download() {
  do_default_download
  download_file $ext_postgis_source $ext_postgis_filename $ext_postgis_shasum
}

do_verify() {
  do_default_verify
  verify_file $ext_postgis_filename $ext_postgis_shasum
}

do_clean() {
  do_default_clean
  rm -rf "$ext_postgis_cache_path"
}

do_unpack() {
  do_default_unpack
  unpack_file $ext_postgis_filename
}
do_build() {
    # ld manpage: "If -rpath is not used when linking an ELF
    # executable, the contents of the environment variable LD_RUN_PATH
    # will be used if it is defined"
    ./configure --disable-rpath \
              --with-openssl \
              --prefix="$pkg_prefix" \
              --with-uuid=ossp \
              --with-includes="$LD_INCLUDE_PATH" \
              --with-libraries="$LD_LIBRARY_PATH" \
              --sysconfdir="$pkg_svc_config_path" \
              --localstatedir="$pkg_svc_var_path"
    make --jobs="$(nproc)" world
}

do_install() {
  make install-world
  # make and install PostGIS extension
  HAB_LIBRARY_PATH="$(pkg_path_for proj)/lib:${pkg_prefix}/lib"
  export LIBRARY_PATH="${LIBRARY_PATH}:${HAB_LIBRARY_PATH}"
  build_line "Added habitat libraries to LIBRARY_PATH: ${HAB_LIBRARY_PATH}"

  export PATH="${PATH}:${pkg_prefix}/bin"
  build_line "Added postgresql binaries to PATH: ${pkg_prefix}/bin"

  pushd "$ext_postgis_cache_path" > /dev/null

  build_line "Building ${ext_postgis_dirname}"
  ./configure --prefix="$pkg_prefix"
  make

  build_line "Installing ${ext_postgis_dirname}"
  make install

  popd > /dev/null
}

# Postgresql9X plans source this plan to get build instructions.
#  This helper method allows those plans to copy hooks and config
#  from this plan.
#  This should be run in do_begin()
_copy_service_files() {
  build_line "Copying hooks"
  cp -a "${PLAN_CONTEXT}/../postgresql/hooks" "${PLAN_CONTEXT}/"
  build_line "Copying config"
  cp -a "${PLAN_CONTEXT}/../postgresql/config" "${PLAN_CONTEXT}/"
  build_line "Copying default.toml"
  cp -a "${PLAN_CONTEXT}/../postgresql/default.toml" "${PLAN_CONTEXT}/"
}

# Cleanup from the above function.
# This should be run in do_end()
_cleanup_copied_service_files() {
  build_line "Removing copied files"
  rm -rf "${PLAN_CONTEXT:?}/config"
  rm -rf "${PLAN_CONTEXT:?}/hooks"
  rm -f "${PLAN_CONTEXT:?}/default.toml"
}
