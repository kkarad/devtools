#!/usr/bin/env bash

openjdk_16_win_url="https://github.com/AdoptOpenJDK/openjdk16-binaries/releases/download/jdk-16.0.1%2B9/OpenJDK16U-jdk_x64_windows_hotspot_16.0.1_9.zip"
openjdk_16_osx_url="https://github.com/AdoptOpenJDK/openjdk16-binaries/releases/download/jdk-16.0.1%2B9/OpenJDK16U-jdk_x64_mac_hotspot_16.0.1_9.tar.gz"
maven_3_8_1_url="https://mirrors.gethosted.online/apache/maven/maven-3/3.8.1/binaries/apache-maven-3.8.1-bin.zip"
nodejs_14_win_url="https://nodejs.org/dist/v14.17.0/node-v14.17.0-win-x64.zip"
nodejs_14_osx_url="https://nodejs.org/dist/v14.17.0/node-v14.17.0-darwin-x64.tar.gz"

function install_archive() {
  local tool="${1}"
  local version_dir="${2}"
  local archive_url="${3}"
  local archive="${archive_url##*/}"
  curl -L -o "${TMP_DIR}/${archive}" "${archive_url}" || {
    echo "Unable to download ${tool} from '${archive_url}'"
    exit 1
  }
  local tmp_install_dir="${TMP_DIR}/${tool}/${version_dir}/"
  mkdir -p "${tmp_install_dir}" && {
    unzip -q "${TMP_DIR}/${archive}" -d "${tmp_install_dir}"
  }
  local install_dir="${HOME_DIR}/${tool}/${version_dir}"
  mkdir -p "${install_dir}" && {
    mv "${tmp_install_dir}"*/* "${install_dir}"
  }
}

function ensure_tool() {
  local tool="${1}"
  local version_dir="${2}"
  local archive_url="${3}"
  local install_dir="${HOME_DIR}/${tool}/${version_dir}/"
  [ ! -d "${install_dir}" ] && {
    echo -e "* Installing ${tool} on ${install_dir} \n  from ${archive_url}...\n"
    install_archive "${tool}" "${version_dir}" "${archive_url}"
  } || echo -e "* Already installed ${tool} on ${install_dir}\n"
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
  HOME_DIR="${HOME}/dev/tools"
  local usage="Devtools update.
  Usage:
    update.sh -d
    update.sh -h | --help

  Options:
    -d --install-dir <PATH> Devtools installation directory [default: '${HOME_DIR}']
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
      echo "Unsupported option ${1}"
      exit 1
      ;;
    *) # preserve positional args
      args="${args} ${1}"
      shift 1
      ;;
    esac
  done
  eval set -- "${args}" #set positional args in their proper place

  mkdir -p "${HOME_DIR}"
  cd "${HOME_DIR}" || exit
  readonly machine="$(machine)"
  [[ ${machine} == "windows" || ${machine} == "osx" ]] || {
    echo >&2 "Unsupported operating system: ${machine}"
    exit 1
  }
  TMP_DIR="$(mktemp -d -t 'devtools.XXXXXX')"
  trap 'rm -rf -- "${TMP_DIR}"' EXIT

  echo -e "* Installing devtools on ${HOME_DIR}...\n"
  case "${machine}" in
  windows)
    ensure_tool "java" "openjdk-16.0.1_9" ${openjdk_16_win_url}
    ensure_tool "maven" "apache-maven-3.8.1" ${maven_3_8_1_url}
    ensure_tool "nodejs" "node-v14.17.0" ${nodejs_14_win_url}
    ;;
  osx)
    ensure_tool "java" "openjdk-16.0.1_9" ${openjdk_16_win_url}
    ensure_tool "maven" "apache-maven-3.8.1" ${maven_3_8_1_url}
    ensure_tool "nodejs" "node-v14.17.0" ${nodejs_14_win_url}
    ;;
  esac
  echo -e "* Completed devtools installation\n"
}

main "$@"
