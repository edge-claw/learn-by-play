#!/usr/bin/env bash
# 从 index.html 游戏清单自动统计游戏数/关卡数/领域数，更新 README.md 和 banner.svg
# 用法: bash scripts/update-stats.sh [--check]
#   --check: 只检查是否需要更新，不修改文件（CI 用）
set -euo pipefail
cd "$(dirname "$0")/.."

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

# --- 统计 ---
read -r GAME_COUNT LEVEL_COUNT DOMAIN_COUNT < <(node <<'NODE'
const fs = require('fs');
const vm = require('vm');

const html = fs.readFileSync('index.html', 'utf8');
const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map((m) => m[1]);
const noop = () => {};
const element = () => ({
  className: '',
  id: '',
  innerHTML: '',
  value: '',
  style: {},
  appendChild: noop,
  addEventListener: noop
});
const sandbox = {
  document: {
    body: { firstChild: null, insertBefore: noop, appendChild: noop },
    createElement: element,
    getElementById: element
  },
  window: {},
  console: { log: noop, error: noop }
};
const result = vm.runInNewContext(
  `${scripts.join('\n')}\n({ games, totalGames, totalLevels });`,
  sandbox,
  { filename: 'index.html' }
);
const missing = result.games
  .flatMap((cat) => cat.items.map((game) => game.file))
  .filter((file) => !fs.existsSync(file));
if (missing.length) {
  throw new Error(`index.html 引用了不存在的游戏文件: ${missing.join(', ')}`);
}
process.stdout.write(`${result.totalGames} ${result.totalLevels} ${result.games.length}\n`);
NODE
)

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
