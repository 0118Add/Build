        # --- 整合 QiuSimons/luci-app-honk 的宿主机编译环境依赖 ---
        echo "🔧 正在搜索并配置 luci-app-honk 所需的宿主机工具链..."
        
        # 1. 安装 Rust 环境（如果尚未安装）
        if ! command -v rustup &> /dev/null; then
          curl --retry 3 --retry-delay 2 --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path
        fi
        export PATH="$HOME/.cargo/bin:$PATH"
        
        # 2. 限定在 package 和 feeds 目录下快速精准搜索 honk_toolchain.sh
        HONK_TOOLCHAIN_PATH=""
        for candidate in \
          "package/luci-app-honk/honk/honk_toolchain.sh" \
          "package/luci-app-honk/honk_toolchain.sh" \
          "feeds/luci/applications/luci-app-honk/honk/honk_toolchain.sh"; do
          if [ -f "$candidate" ]; then
            HONK_TOOLCHAIN_PATH="$candidate"
            break
          fi
        done
        
        # 如果预置路径未命中，仅在 package 目录下浅层查找，绝不进行全盘耗时扫描
        if [ -z "$HONK_TOOLCHAIN_PATH" ] && [ -d "package" ]; then
          HONK_TOOLCHAIN_PATH=$(find package -maxdepth 4 -type f -name "honk_toolchain.sh" | head -n 1)
        fi
        
        # 3. 如果找到了脚本，则自动执行并安装依赖
        if [ -n "$HONK_TOOLCHAIN_PATH" ] && [ -f "$HONK_TOOLCHAIN_PATH" ]; then
          HONK_DIR=$(dirname "$HONK_TOOLCHAIN_PATH")
          echo "✅ 成功找到 honk 工具链脚本: $HONK_TOOLCHAIN_PATH (所在目录: $HONK_DIR)"
          
          # 【修复错误】进入 honk_toolchain.sh 所在目录执行，确保其能正确读取同级 Makefile 解析版本
          eval "$(cd "$HONK_DIR" && bash "$(basename "$HONK_TOOLCHAIN_PATH")")"
          
          # 检查版本变量是否成功获取，避免后续下载链接变成空值
          if [ -z "${BPF_LINKER_VERSION:-}" ] || [ -z "${ZIG_VERSION:-}" ]; then
            echo "❌ 错误: 未能从 honk_toolchain.sh 正确解析出版本号" >&2
            exit 1
          fi
          
          # 安装 bpf-linker
          echo "📦 正在安装 bpf-linker v${BPF_LINKER_VERSION}..."
          curl --retry 3 --retry-delay 2 -fsSL -o /tmp/bpf-linker.tar.zst "https://github.com/aya-rs/bpf-linker/releases/download/v${BPF_LINKER_VERSION}/bpf-linker-x86_64-unknown-linux-musl.tar.zst"
          echo "${BPF_LINKER_SHA256}  /tmp/bpf-linker.tar.zst" | sha256sum -c -
          sudo tar --zstd -xf /tmp/bpf-linker.tar.zst -C /usr/local/bin
          
          # 安装 Zig 编译器（直接读取官方 index.json 真实 tarball 链接，彻底杜绝 404）
          echo "🔍 正在获取 Zig 最新稳定版真实下载地址..."
          ZIG_JSON=$(curl -fsSL https://ziglang.org)

          if [ -n "${ZIG_VERSION:-}" ]; then
              ZIG_URL=$(echo "$ZIG_JSON" | jq -r ".\"${ZIG_VERSION}\".\"x86_64-linux\".tarball // empty")
          fi

          # 如果指定版本未找到，则自动提取最新稳定版（排除 master 开发版）的下载地址
          if [ -z "${ZIG_URL:-}" ]; then
              ZIG_URL=$(echo "$ZIG_JSON" | jq -r 'to_entries | map(select(.key != "master")) | .[0].value."x86_64-linux".tarball')
          fi

          [ -n "$ZIG_URL" ] && [ "$ZIG_URL" != "null" ] || { echo "❌ 错误：未能从 Zig 官方索引获取到下载地址！"; exit 1; }
          echo "📥 正在下载 Zig: $ZIG_URL"

          curl --retry 5 --retry-delay 3 -fsSL -o /tmp/zig.tar.xz "$ZIG_URL"
          sudo rm -rf /usr/local/zig-*
          sudo tar -xJf /tmp/zig.tar.xz -C /usr/local
          ZIG_DIR=$(find /usr/local -maxdepth 1 -type d -name "zig-*" | head -n1)
          sudo ln -sf "${ZIG_DIR}/zig" /usr/local/bin/zig
          rm -f /tmp/zig.tar.xz

          echo "✅ Zig 安装完成: $(zig version)"
          echo "✅ honk 专用宿主机工具链安装完成！"
        else
          echo "⚠️ 指定目录未检测到 honk_toolchain.sh 脚本，跳过专用工具链安装。"
          exit 1
        fi
        # ---------------------------------------------
