#!/usr/bin/env bash
# 从 games/ 目录自动统计游戏数/关卡数/领域数，更新 README.md 和 banner.svg
# 用法: bash scripts/update-stats.sh [--check]
#   --check: 只检查是否需要更新，不修改文件（CI 用）
set -euo pipefail
cd "$(dirname "$0")/.."

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

# --- 统计 ---
GAME_COUNT=$(find games -name '*.html' | wc -l | tr -d ' ')
DOMAIN_COUNT=$(find games -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')

LEVEL_COUNT=0
for f in games/*/*.html; do
  n=$(grep -oE '[0-9]+[[:space:]]*个关卡' "$f" | head -1 | grep -oE '[0-9]+' || echo "1")
  LEVEL_COUNT=$((LEVEL_COUNT + n))
done

echo "📊 ${GAME_COUNT} 个游戏 | ${LEVEL_COUNT}+ 个关卡 | ${DOMAIN_COUNT} 大领域"

if $CHECK_ONLY; then
  # 检查 README.md 中的数字是否匹配
  if grep -q "games-${GAME_COUNT}-blue" README.md && \
     grep -q "levels-${LEVEL_COUNT}+-green" README.md && \
     grep -q "共 \*\*${GAME_COUNT} 个游戏\*\*" README.md; then
    echo "✅ 统计数字已是最新"
    exit 0
  else
    echo "❌ 统计数字需要更新，请运行: bash scripts/update-stats.sh"
    exit 1
  fi
fi

# --- 跨平台 sed -i ---
sedi() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# --- 更新 README.md ---
sedi "s/games-[0-9]*-blue/games-${GAME_COUNT}-blue/" README.md
sedi "s/levels-[0-9]*+-green/levels-${LEVEL_COUNT}+-green/" README.md
sedi "s/共 \*\*[0-9]* 个游戏\*\*/共 **${GAME_COUNT} 个游戏**/" README.md
sedi "s/\*\*[0-9]*+ 个关卡\*\*/**${LEVEL_COUNT}+ 个关卡**/" README.md
sedi "s/覆盖 \*\*[0-9]* 大领域\*\*/覆盖 **${DOMAIN_COUNT} 大领域**/" README.md
sedi "s/alt=\"[0-9]* games\"/alt=\"${GAME_COUNT} games\"/" README.md
sedi "s/alt=\"[0-9]*+ levels\"/alt=\"${LEVEL_COUNT}+ levels\"/" README.md

# --- 更新 banner.svg ---
python3 -c "
import re

with open('banner.svg', 'r') as f:
    svg = f.read()

def replace_stat(svg, label, value):
    pattern = r'(>)([^<]*)(</text>\s*\n\s*<text[^>]*>' + label + ')'
    return re.sub(pattern, r'\g<1>' + str(value) + r'\g<3>', svg)

svg = replace_stat(svg, '个游戏', ${GAME_COUNT})
svg = replace_stat(svg, '个关卡', '${LEVEL_COUNT}+')
svg = replace_stat(svg, '大领域', ${DOMAIN_COUNT})

with open('banner.svg', 'w') as f:
    f.write(svg)
"

echo "✅ README.md 和 banner.svg 已更新"
