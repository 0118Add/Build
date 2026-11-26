        # --- 整合 QiuSimons/luci-app-honk 的宿主机编译环境依赖 ---
set -e

HONK_DIR="package/openwrt-honk/honk"
HONK_BIN="${HONK_DIR}/files/honk-core.bin"

echo "📥 正在直接获取预编译的 honk-core.bin（跳过 Zig/Rust 工具链）..."

# 从 kenzok8/openwrt-honk 或 daeuniverse/honk 的最新 Release 获取 x86_64 核心
DOWNLOAD_URL=$(curl -fsSL "https://github.com" | \
  grep -oE '"browser_download_url": *"[^"]+honk-core-[^"]*x86_64[^"]*\.tar\.gz"' | \
  head -n1 | cut -d'"' -f4)

[ -n "$DOWNLOAD_URL" ] || { echo "❌ 未找到预编译核心下载链接！"; exit 1; }

curl -fsSL --retry 3 -o /tmp/honk-core.tar.gz "$DOWNLOAD_URL"
rm -rf /tmp/honkpkg && mkdir -p /tmp/honkpkg
tar -xzf /tmp/honk-core.tar.gz -C /tmp/honkpkg

CORE_FILE=$(find /tmp/honkpkg -type f -name "honk-core*" ! -name "*.tar.gz" -print -quit)
[ -n "$CORE_FILE" ] || { echo "❌ 压缩包内未找到 honk-core！"; exit 1; }

mkdir -p "${HONK_DIR}/files"
cp -f "$CORE_FILE" "$HONK_BIN"
chmod +x "$HONK_BIN"
rm -rf /tmp/honk-core.tar.gz /tmp/honkpkg

echo "✅ honk-core.bin 预放完成！大小: $(du -h "$HONK_BIN" | cut -f1)"
