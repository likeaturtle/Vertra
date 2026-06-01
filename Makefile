# Makefile for File Transfer System (Full Stack)

.PHONY: build clean run dev frontend backend fullstack help build-armv7

# 构建参数
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
BINARY_NAME=file-transfer-server
BINARY_UNIX=$(BINARY_NAME)_unix
SCRIPT_DIR=./

# 默认构建 - 完整的前后端
build: fullstack

# 完整的前后端构建（SSG + Go嵌入）
fullstack:
	@echo "🚀 开始全栈构建..."
	@$(SCRIPT_DIR)build-fullstack.sh

# 开发模式构建
dev:
	@echo "🔧 开发模式构建..."
	@$(SCRIPT_DIR)build-fullstack.sh --dev --verbose

# 只构建前端（SSG）
frontend:
	@echo "🎨 构建前端..."
	@$(SCRIPT_DIR)build-fullstack.sh --frontend-only

# 只构建后端（需要前端已构建）
backend:
	@echo "⚙️ 构建后端..."
	@$(SCRIPT_DIR)build-fullstack.sh --backend-only

# 传统 Go 构建（不包含嵌入的前端）
build-go:
	@echo "📦 传统 Go 构建..."
	$(GOBUILD) -o $(BINARY_NAME) -v ./cmd

# 清理所有构建文件
clean:
	@echo "🧹 清理构建文件..."
	@$(SCRIPT_DIR)build-fullstack.sh --clean
	$(GOCLEAN)
	rm -f $(BINARY_NAME)
	rm -f $(BINARY_UNIX)

# 运行应用（先构建）
run: build
	@echo "🚀 启动应用..."
	./$(BINARY_NAME)

# 快速运行（使用现有二进制）
run-quick:
	@echo "⚡ 快速启动..."
	./$(BINARY_NAME)

# Linux 交叉编译
build-linux:
	@echo "🐧 Linux 交叉编译..."
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) -o $(BINARY_UNIX) -v ./cmd

# ARMv7 交叉编译 (ARM Cortex-A7, 32-bit)
build-armv7:
	@echo "🦾 ARMv7 交叉编译 (Cortex-A7)..."
	mkdir -p dist
	CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 $(GOBUILD) -ldflags="-s -w -extldflags '-static'" -o dist/file-transfer-server-linux-armv7 -v ./cmd
	@echo "✅ 输出: dist/file-transfer-server-linux-armv7"

# 安装依赖
install-deps:
	@echo "📦 安装 Go 依赖..."
	$(GOCMD) mod download
	$(GOCMD) mod tidy
	@echo "📦 安装前端依赖..."
	cd chuan-next && yarn install

# 检查代码
check:
	@echo "🔍 代码检查..."
	$(GOCMD) vet ./...
	$(GOCMD) fmt ./...
	cd chuan-next && yarn lint

# 测试
test:
	@echo "🧪 运行测试..."
	$(GOCMD) test -v ./...

# 显示帮助
help:
	@echo "🛠️  可用的构建命令："
	@echo ""
	@echo "主要命令："
	@echo "  make build       - 完整构建（前端SSG + Go嵌入）"
	@echo "  make dev         - 开发模式构建（包含调试信息）"
	@echo "  make run         - 构建并运行应用"
	@echo "  make clean       - 清理所有构建文件"
	@echo ""
	@echo "分离构建："
	@echo "  make frontend    - 只构建前端（Next.js SSG）"
	@echo "  make backend     - 只构建后端（需要前端已构建）"
	@echo "  make build-go    - 传统 Go 构建（不含前端）"
	@echo ""
	@echo "其他命令："
	@echo "  make run-quick   - 直接运行现有二进制"
	@echo "  make build-linux - Linux amd64 交叉编译"
	@echo "  make build-armv7 - ARMv7 (Cortex-A7) 交叉编译"
	@echo "  make build-linux - Linux 交叉编译"
	@echo "  make install-deps- 安装所有依赖"
	@echo "  make check       - 代码检查和格式化"
	@echo "  make test        - 运行测试"
	@echo "  make help        - 显示此帮助"
	@echo ""
	@echo "详细构建选项（直接调用脚本）："
	@echo "  ./build-fullstack.sh --help"
