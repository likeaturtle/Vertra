#!/bin/bash

# =============================================================================
# 全栈应用构建脚本
# 
# 功能：
# 1. 构建 Next.js SSG 静态文件
# 2. 将静态文件复制到 Go 嵌入目录
# 3. 构建 Go 二进制文件，包含嵌入的前端文件
# 4. 生成多平台静态二进制文件 (Windows/macOS/Linux)
#
# 使用方法：
#   ./build-fullstack.sh
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
FRONTEND_DIR="$PROJECT_ROOT/chuan-next"
FRONTEND_OUT_DIR="$FRONTEND_DIR/out"
GO_WEB_DIR="$PROJECT_ROOT/internal/web"
FRONTEND_EMBED_DIR="$GO_WEB_DIR/frontend"
DIST_DIR="$PROJECT_ROOT/dist"

# 平台配置
PLATFORMS=(
    "windows/amd64:file-transfer-server.exe"
    "darwin/amd64:file-transfer-server-macos-amd64"
    "darwin/arm64:file-transfer-server-macos-arm64"  
    "linux/amd64:file-transfer-server-linux-amd64"
    "linux/arm64:file-transfer-server-linux-arm64"
    "linux/arm:file-transfer-server-linux-armv7"
)

# 打印函数
print_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}🚀 $1${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_verbose() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# 检查依赖
check_dependencies() {
    print_step "检查构建依赖..."
    
    local missing_deps=()
    
    if ! command -v node &> /dev/null; then
        missing_deps+=("Node.js")
    fi
    
    if ! command -v yarn &> /dev/null; then
        missing_deps+=("Yarn")
    fi
    
    if ! command -v go &> /dev/null; then
        missing_deps+=("Go")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "缺少必要的依赖: ${missing_deps[*]}"
        print_info "请安装缺少的依赖后重试"
        exit 1
    fi
    
    print_verbose "Node.js 版本: $(node --version)"
    print_verbose "Yarn 版本: $(yarn --version)"
    print_verbose "Go 版本: $(go version)"
    
    print_success "依赖检查完成"
}

# 清理函数
clean_all() {
    print_step "清理构建文件..."
    
    # 清理前端构建
    [ -d "$FRONTEND_DIR/.next" ] && rm -rf "$FRONTEND_DIR/.next"
    [ -d "$FRONTEND_OUT_DIR" ] && rm -rf "$FRONTEND_OUT_DIR"
    
    # 清理嵌入的前端文件
    if [ -d "$FRONTEND_EMBED_DIR" ]; then
        find "$FRONTEND_EMBED_DIR" -name "*.html" -o -name "*.js" -o -name "*.css" -o -name "*.json" -o -name "*.png" -o -name "*.jpg" -o -name "*.svg" -o -name "*.ico" | xargs rm -f 2>/dev/null || true
    fi
    
    # 清理输出目录
    [ -d "$DIST_DIR" ] && rm -rf "$DIST_DIR"
    
    print_success "清理完成"
}

# 构建前端
build_frontend() {
    print_step "构建 Next.js 前端..."
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        print_error "前端目录不存在: $FRONTEND_DIR"
        exit 1
    fi
    
    cd "$FRONTEND_DIR"
    
    # 安装依赖
    print_verbose "安装前端依赖..."
    yarn install --silent
    
    # 临时移除 API 目录
    api_backup_name=""
    if [ -d "src/app/api" ]; then
        api_backup_name="next-api-backup-$(date +%s)-$$"
        mv src/app/api "/tmp/$api_backup_name" 2>/dev/null || true
        print_verbose "API 目录已备份到: /tmp/$api_backup_name"
    fi
    
    # 构建
    print_verbose "执行 SSG 构建..."
    if ! NEXT_EXPORT=true NODE_ENV=production NEXT_PUBLIC_BACKEND_URL= NEXT_PUBLIC_WS_URL= NEXT_PUBLIC_API_BASE_URL= yarn build > build.log 2>&1; then
        print_error "前端构建失败，查看 $FRONTEND_DIR/build.log"
        cat build.log
        # 恢复 API 目录后再退出
        if [ -n "$api_backup_name" ] && [ -d "/tmp/$api_backup_name" ]; then
            mv "/tmp/$api_backup_name" src/app/api 2>/dev/null || true
        fi
        exit 1
    fi
    rm -f build.log
    
    # 恢复 API 目录
    if [ -n "$api_backup_name" ] && [ -d "/tmp/$api_backup_name" ]; then
        mv "/tmp/$api_backup_name" src/app/api 2>/dev/null || true
        print_verbose "已恢复 API 目录"
    fi
    
    # 清理历史备份文件
    find /tmp -name "next-api-backup-*" -mmin +60 -exec rm -rf {} \; 2>/dev/null || true
    
    cd "$PROJECT_ROOT"
    
    # 验证构建结果
    if [ ! -d "$FRONTEND_OUT_DIR" ] || [ ! -f "$FRONTEND_OUT_DIR/index.html" ]; then
        print_error "前端构建失败：输出文件不存在"
        exit 1
    fi
    
    print_success "前端构建完成"
}

# 复制前端文件到嵌入目录
copy_frontend_files() {
    print_step "复制前端文件到嵌入目录..."
    
    mkdir -p "$FRONTEND_EMBED_DIR"
    
    # 清理现有文件（除了 .gitkeep）
    find "$FRONTEND_EMBED_DIR" -type f ! -name ".gitkeep" -delete 2>/dev/null || true
    
    # 复制所有文件
    if [ -d "$FRONTEND_OUT_DIR" ]; then
        cp -r "$FRONTEND_OUT_DIR"/* "$FRONTEND_EMBED_DIR/" 2>/dev/null || true
        
        file_count=$(find "$FRONTEND_EMBED_DIR" -type f ! -name ".gitkeep" | wc -l)
        total_size=$(du -sh "$FRONTEND_EMBED_DIR" 2>/dev/null | cut -f1 || echo "未知")
        
        print_verbose "复制了 $file_count 个文件，总大小: $total_size"
        print_success "前端文件复制完成"
    else
        print_error "前端输出目录不存在: $FRONTEND_OUT_DIR"
        exit 1
    fi
}

# 构建多平台后端
build_backend() {
    print_step "构建多平台 Go 后端..."
    
    cd "$PROJECT_ROOT"
    
    # 创建输出目录
    mkdir -p "$DIST_DIR"
    
    # 构建参数
    local ldflags="-s -w -extldflags '-static'"
    
    print_verbose "构建参数: $ldflags"
    
    # 为每个平台构建
    for platform_config in "${PLATFORMS[@]}"; do
        IFS=':' read -r platform binary_name <<< "$platform_config"
        IFS='/' read -r goos goarch <<< "$platform"
        
        output_path="$DIST_DIR/$binary_name"
        
        print_verbose "构建 $platform -> $binary_name"
        
        # 构建 ARM 32位 时指定 ARMv7 架构 (Cortex-A7 等)
        local goarm_env=""
        if [ "$goarch" = "arm" ]; then
            goarm_env="GOARM=7"
        fi
        
        # 设置环境变量并构建
        if ! env CGO_ENABLED=0 GOOS="$goos" GOARCH="$goarch" $goarm_env go build \
            -ldflags "$ldflags" \
            -o "$output_path" \
            ./cmd; then
            print_error "构建 $platform 失败"
            exit 1
        fi
        
        # 验证构建结果
        if [ ! -f "$output_path" ]; then
            print_error "构建验证失败: $output_path 不存在"
            exit 1
        fi
        
        binary_size=$(du -sh "$output_path" | cut -f1)
        print_verbose "✓ $binary_name ($binary_size)"
    done
    
    print_success "多平台后端构建完成"
}

# 验证最终结果
verify_build() {
    print_step "验证构建结果..."
    
    local errors=()
    
    # 检查前端嵌入文件
    if [ ! -d "$FRONTEND_EMBED_DIR" ]; then
        errors+=("前端嵌入目录不存在")
    else
        embedded_files=$(find "$FRONTEND_EMBED_DIR" -type f ! -name ".gitkeep" | wc -l)
        if [ "$embedded_files" -eq 0 ]; then
            errors+=("没有嵌入的前端文件")
        fi
    fi
    
    # 检查所有平台的二进制文件
    for platform_config in "${PLATFORMS[@]}"; do
        IFS=':' read -r platform binary_name <<< "$platform_config"
        binary_path="$DIST_DIR/$binary_name"
        
        if [ ! -f "$binary_path" ]; then
            errors+=("$platform 二进制文件不存在: $binary_name")
        fi
    done
    
    if [ ${#errors[@]} -gt 0 ]; then
        print_error "构建验证失败:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        exit 1
    fi
    
    print_success "构建验证通过"
}

# 显示构建摘要
show_summary() {
    print_header "构建完成"
    
    echo -e "${GREEN}🎉 多平台全栈应用构建成功！${NC}"
    echo ""
    
    print_info "� 构建输出目录: $DIST_DIR"
    
    if [ -d "$FRONTEND_EMBED_DIR" ]; then
        embedded_files=$(find "$FRONTEND_EMBED_DIR" -type f ! -name ".gitkeep" | wc -l)
        echo "   - 嵌入的前端文件: $embedded_files 个"
    fi
    
    echo ""
    print_info "� 生成的二进制文件:"
    
    for platform_config in "${PLATFORMS[@]}"; do
        IFS=':' read -r platform binary_name <<< "$platform_config"
        binary_path="$DIST_DIR/$binary_name"
        
        if [ -f "$binary_path" ]; then
            binary_size=$(du -sh "$binary_path" | cut -f1)
            echo "   ✅ $binary_name ($platform) - $binary_size"
        else
            echo "   ❌ $binary_name ($platform) - 构建失败"
        fi
    done
    
    echo ""
    print_info "� 部署说明:"
    echo "   1. 选择对应平台的二进制文件进行部署"
    echo "   2. 运行命令: ./二进制文件名"
    echo "   3. 访问地址: http://localhost:8080"
    echo ""
    print_info "🌟 特性:"
    echo "   ✅ 前端界面完全嵌入"
    echo "   ✅ 静态编译，无外部依赖"
    echo "   ✅ 支持多平台部署"
    echo "   ✅ 单文件部署"
}

# 错误处理
error_cleanup() {
    print_error "构建过程中发生错误"
    
    # 尝试恢复 API 目录
    local api_backups=$(ls /tmp/next-api-backup-*-$$ 2>/dev/null || true)
    
    if [ -n "$api_backups" ]; then
        for backup in $api_backups; do
            if [ -d "$backup" ] && [ -d "$FRONTEND_DIR" ]; then
                mv "$backup" "$FRONTEND_DIR/src/app/api" 2>/dev/null || true
                print_verbose "已恢复 API 目录: $backup"
                break
            fi
        done
    fi
    
    exit 1
}

# 主函数
main() {
    print_header "多平台全栈应用构建"
    
    # 设置错误处理
    trap error_cleanup ERR INT TERM
    
    # 执行构建步骤
    check_dependencies
    clean_all
    build_frontend
    copy_frontend_files
    build_backend
    verify_build
    show_summary
}

# 如果脚本被直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
