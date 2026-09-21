#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
COMMENT_CHECKER="${SWIFT_COMMENT_CHECKER:-${HOME}/.agents/skills/swift-comment-checker/scripts/check-comments.sh}"

if [[ ! -f "$COMMENT_CHECKER" ]]; then
  echo "错误: 未找到注释检测脚本: $COMMENT_CHECKER" >&2
  exit 1
fi

mode="${1:---check}"
exec "$COMMENT_CHECKER" "$mode" "$PACKAGE_DIR/Sources"
