#!/usr/bin/env bash

set -o noclobber -o noglob -o nounset -o pipefail
IFS=$'\n'

FILE_PATH="${1}"
PV_WIDTH="${2}"
PV_HEIGHT="${3}"
IMAGE_CACHE_PATH="${4}"
PV_IMAGE_ENABLED="${5}"

FILE_NAME="${FILE_PATH##*/}"
FILE_EXTENSION=""
if [[ "${FILE_NAME}" == *.* ]]; then
  FILE_EXTENSION="${FILE_NAME##*.}"
fi
FILE_EXTENSION_LOWER="$(printf "%s" "${FILE_EXTENSION}" | tr '[:upper:]' '[:lower:]')"

PREVIEW_MAX_BYTES="${RANGER_PREVIEW_MAX_BYTES:-1048576}"
BAT_LINE_RANGE="${RANGER_BAT_LINE_RANGE:-:200}"
QLOOK_SIZE="${RANGER_QLOOK_SIZE:-2048}"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

file_size_bytes() {
  wc -c < "${FILE_PATH}" | tr -d '[:space:]'
}

preview_bat() {
  command_exists bat || return 1
  bat --paging=never \
    --force-colorization \
    --style=plain \
    --terminal-width "${PV_WIDTH}" \
    --line-range "${BAT_LINE_RANGE}" \
    -- "${FILE_PATH}"
}

preview_plaintext() {
  if [[ "$(file_size_bytes)" -gt "${PREVIEW_MAX_BYTES}" ]]; then
    exit 2
  fi

  preview_bat && exit 5
  exit 2
}

preview_markdown() {
  command_exists glow && glow -s auto -w "${PV_WIDTH}" -- "${FILE_PATH}" && exit 5
  preview_plaintext
}

preview_json() {
  jq --color-output . "${FILE_PATH}" && exit 5
  preview_bat && exit 5
  exit 2
}

preview_plist() {
  plutil -p "${FILE_PATH}" && exit 5
  plutil -convert json -r -o - -- "${FILE_PATH}" | jq --color-output . && exit 5
  exit 1
}

preview_office_text() {
  textutil -convert txt -stdout -- "${FILE_PATH}" && exit 5
  exit 1
}

preview_pdf_text() {
  pdftotext -l 10 -nopgbrk -q -- "${FILE_PATH}" - | fmt -w "${PV_WIDTH}" && exit 5
  exit 1
}

preview_archive_list() {
  bsdtar --list --file "${FILE_PATH}" && exit 5
  zipinfo -1 -- "${FILE_PATH}" && exit 5
  exit 1
}

preview_metadata() {
  mdls "${FILE_PATH}" && exit 5
  file --dereference --brief -- "${FILE_PATH}" && exit 5
  exit 1
}

preview_ql_image() {
  command_exists qlmanage || return 1

  local tmp_dir preview_file
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ranger-ql.XXXXXX")" || return 1

  if ! qlmanage -t -s "${QLOOK_SIZE}" -o "${tmp_dir}" -- "${FILE_PATH}" >/dev/null 2>&1; then
    rm -rf "${tmp_dir}"
    return 1
  fi

  preview_file="$(find "${tmp_dir}" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | sed -n '1p')"
  if [[ -z "${preview_file}" ]]; then
    rm -rf "${tmp_dir}"
    return 1
  fi

  cp -f "${preview_file}" "${IMAGE_CACHE_PATH}" || {
    rm -rf "${tmp_dir}"
    return 1
  }

  rm -rf "${tmp_dir}"
  return 0
}

handle_extension() {
  case "${FILE_EXTENSION_LOWER}" in
  md | markdown | mkd | mdown | mkdn | rst)
    preview_markdown
    ;;
  json | geojson | ipynb)
    preview_json
    ;;
  plist | mobileconfig)
    preview_plist
    ;;
  pdf)
    preview_pdf_text
    ;;
  doc | docx | odt | rtf)
    preview_office_text
    ;;
  htm | html | xhtml)
    preview_office_text
    ;;
  a | appx | bz | bz2 | cpio | gz | jar | tar | tbz | tbz2 | tgz | txz | war | xar | xpi | xz | zip)
    preview_archive_list
    ;;
  7z | rar)
    preview_archive_list
    ;;
  esac
}

handle_image() {
  local mimetype="${1}"
  case "${mimetype}" in
  image/*)
    case "${FILE_EXTENSION_LOWER}" in
    avif | heic | icns | ico | psd | raw | svg | tif | tiff)
      preview_ql_image && exit 6
      ;;
    *)
      exit 7
      ;;
    esac
    ;;
  application/pdf | video/* | application/epub+zip | application/msword | application/postscript | \
    application/rtf | application/vnd.apple.keynote | application/vnd.ms-excel | \
    application/vnd.ms-powerpoint | application/vnd.oasis.opendocument.presentation | \
    application/vnd.oasis.opendocument.spreadsheet | application/vnd.oasis.opendocument.text | \
    application/vnd.openxmlformats-officedocument.presentationml.presentation | \
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet | \
    application/vnd.openxmlformats-officedocument.wordprocessingml.document | \
    application/x-mobipocket-ebook | font/* | application/font* | application/*opentype | text/rtf)
    preview_ql_image && exit 6
    ;;
  esac
}

handle_mime() {
  local mimetype="${1}"
  case "${mimetype}" in
  application/json)
    preview_json
    ;;
  application/pdf)
    preview_pdf_text
    ;;
  application/msword | application/rtf | application/vnd.oasis.opendocument.text | \
    application/vnd.openxmlformats-officedocument.wordprocessingml.document | text/html | text/rtf)
    preview_office_text
    ;;
  application/x-plist)
    preview_plist
    ;;
  text/markdown)
    preview_markdown
    ;;
  application/epub+zip | application/x-mobipocket-ebook | application/vnd.apple.keynote | \
    application/vnd.apple.numbers | application/vnd.apple.pages | application/vnd.ms-excel | \
    application/vnd.ms-powerpoint | application/vnd.oasis.opendocument.presentation | \
    application/vnd.oasis.opendocument.spreadsheet | \
    application/vnd.openxmlformats-officedocument.presentationml.presentation | \
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet | \
    font/* | application/font* | application/*opentype)
    preview_metadata
    ;;
  text/* | */xml | application/javascript)
    preview_plaintext
    ;;
  image/* | video/* | audio/*)
    preview_metadata
    ;;
  esac
}

handle_fallback() {
  file --dereference --brief -- "${FILE_PATH}" && exit 5
  exit 1
}

MIMETYPE="$(file --dereference --brief --mime-type -- "${FILE_PATH}")"
if [[ "${PV_IMAGE_ENABLED}" == 'True' ]]; then
  handle_image "${MIMETYPE}"
fi
handle_extension
handle_mime "${MIMETYPE}"
handle_fallback
