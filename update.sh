#!/bin/bash

set +x

DEVTOOLS_RC="${HOME}/.devtoolsrc"

openjdk_16_win_url="https://github.com/AdoptOpenJDK/openjdk16-binaries/releases/download/jdk-16.0.1%2B9/OpenJDK16U-jdk_x64_windows_hotspot_16.0.1_9.zip"
openjdk_16_osx_url="https://github.com/AdoptOpenJDK/openjdk16-binaries/releases/download/jdk-16.0.1%2B9/OpenJDK16U-jdk_x64_mac_hotspot_16.0.1_9.tar.gz"
maven_3_8_1_url="https://mirrors.gethosted.online/apache/maven/maven-3/3.8.1/binaries/apache-maven-3.8.1-bin.zip"
nodejs_14_win_url="https://nodejs.org/dist/v14.17.0/node-v14.17.0-win-x64.zip"
nodejs_14_osx_url="https://nodejs.org/dist/v14.17.0/node-v14.17.0-darwin-x64.tar.gz"

function stderr_and_exit() {
  stderr "$*"
  exit 1
}

function stderr() {
  echo -e "$*" >&2
}

function devtools_rc_append() {
    echo -e "$*" >> "${DEVTOOLS_RC}"
}

function extract() {
  local archive="${1}"
  local extraction_dir="${2}"
  local filename=$(basename -- "${archive}")

  case "${filename}" in
  *.zip)
    unzip -q "${archive}" -d "${extraction_dir}"
    ;;
  *.tar.gz)
    tar -xf "${archive}" -C "${extraction_dir}"
    ;;
  *)
    stderr "Unsupported archive extension for: ${filename}"
    return 1
    ;;
  esac
}

function install_archive() {
  local tool="${1}"
  local version_dir="${2}"
  local archive_url="${3}"
  local archive="${archive_url##*/}"
  curl -L -o "${TMP_DIR}/${archive}" "${archive_url}" || { stderr "Unable to download ${tool} from '${archive_url}'"; return 1; }
  stderr ""
  local tmp_install_dir="${TMP_DIR}/${tool}/${version_dir}/"
  mkdir -p "${tmp_install_dir}" && extract "${TMP_DIR}/${archive}" "${tmp_install_dir}" || return $?
  local install_dir="${HOME_DIR}/${tool}/${version_dir}"
  mkdir -p "${install_dir}" && mv "${tmp_install_dir}"*/* "${install_dir}" || return $?
}

function ensure_tool() {
  local tool="${1}"
  local version_dir="${2}"
  local archive_url="${3}"
  local install_dir="${HOME_DIR}/${tool}/${version_dir}/"
  [ ! -d "${install_dir}" ] && {
    stderr "* installing ${tool} on ${install_dir} \n  from ${archive_url}...\n"
    install_archive "${tool}" "${version_dir}" "${archive_url}"
  } || stderr "* already installed ${tool} on ${install_dir}\n"
}

function machine() {
  local unameOut="$(uname -s)"
  case "${unameOut}" in
  Linux*) machine="linux" ;;
  Darwin*) machine="osx" ;;
  CYGWIN*) machine="cygwin" ;;
  MINGW*) machine="windows" ;;
  *) machine="unknown:${unameOut}" ;;
  esac
  echo "${machine}"
}

function main() {
  HOME_DIR="${HOME}/devtools"
  local usage="Devtools update.
  Usage:
    update.sh -d
    update.sh -h | --help

  Options:
    -d --install-dir <path> Devtools installation directory [default: '${HOME_DIR}']
    -h --help               Show this message
  "

  while (("$#")); do
    case "$1" in
    -h | --help)
      echo "${usage}" >&2
      exit 1
      ;;
    -d | --home-dir)
      HOME_DIR="${2}"
      shift 2
      ;;
    --) # end argument parsing
      shift
      break
      ;;
    -* | --*) # unsupported flags
      stderr_and_exit "Unsupported option ${1}"
      ;;
    *) # preserve positional args
      args="${args} ${1}"
      shift 1
      ;;
    esac
  done
  eval set -- "${args}" #set positional args in their proper place

  mkdir -p "${HOME_DIR}"
  cd "${HOME_DIR}" || stderr_and_exit "Unable to access: ${HOME_DIR}"
  echo "" > "${DEVTOOLS_RC}" || stderr_and_exit "Unable to create: ${DEVTOOLS_RC}"
  readonly machine="$(machine)"
  [[ ${machine} == "windows" || ${machine} == "osx" ]] || stderr_and_exit "Unsupported operating system: ${machine}"
  TMP_DIR="$(mktemp -d -t 'devtools.XXXXXX')"
  trap 'rm -rf -- "${TMP_DIR}"' EXIT

  stderr "* updating devtools on ${HOME_DIR}...\n"
  case "${machine}" in
  windows)
    local openjdk_home_relative_dir=""
    local openjdk_16_url="${openjdk_16_win_url}"
    local nodejs_14_url="${nodejs_14_win_url}"
    ;;
  osx)
    local openjdk_home_relative_dir="/Contents/Home"
    local openjdk_16_url="${openjdk_16_osx_url}"
    local nodejs_14_url="${nodejs_14_osx_url}"
    ;;
  esac

  local path=()
  ensure_tool "java" "openjdk-16.0.1_9" ${openjdk_16_url} && {
    devtools_rc_append "export JAVA_16=\"${HOME_DIR}/java/openjdk-16.0.1_9${openjdk_home_relative_dir}\""
    devtools_rc_append "export JAVA_HOME=\"${HOME_DIR}/java/openjdk-16.0.1_9${openjdk_home_relative_dir}\""
    path+=("\$JAVA_HOME/bin")
  }
  ensure_tool "maven" "apache-maven-3.8.1" ${maven_3_8_1_url} && {
    devtools_rc_append "export MVN_HOME=\"${HOME_DIR}/maven/apache-maven-3.8.1\""
    path+=("\$MVN_HOME/bin")
  }
  ensure_tool "nodejs" "node-v14.17.0" ${nodejs_14_url} && {
    devtools_rc_append "export NODE_HOME=\"${HOME_DIR}/nodejs/node-v14.17.0\""
    path+=("\$NODE_HOME/bin")
  }
  devtools_rc_append "\nPATH=\"$(IFS=: ; echo "${path[*]}"):\$PATH\""

  stderr "* devtools installation completed! (f not done already add '.devtoolsrc' to your bash profile: 'source ~/.devtoolsrc'"
}

main "$@"
