SKYNET_ROOT := ../../skynet/
LUA_STATICLIB := $(SKYNET_ROOT)3rd/lua/liblua.a

LUA_LIB ?= $(LUA_STATICLIB)
LUA_INC ?= $(SKYNET_ROOT)3rd/lua

SRC_DIR = ./
MCSERVICE_PATH = ../cservice/
CFLAGS := -g -O2 -Wall -I$(LUA_INC) $(MYCFLAGS)

# 自动检测平台并设置共享库编译选项
UNAME_S := $(shell uname -s)

# TLS 配置
TLS_MODULE = ltls

ifeq ($(UNAME_S),Darwin)
    # macOS
    SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
    CC ?= gcc
	# macOS - 使用 Homebrew 的 OpenSSL
    OPENSSL_PREFIX := $(shell brew --prefix openssl@3 2>/dev/null || brew --prefix openssl 2>/dev/null)
    ifneq ($(OPENSSL_PREFIX),)
        TLS_LIB = $(OPENSSL_PREFIX)/lib
        TLS_INC = $(OPENSSL_PREFIX)/include
    else
        $(warning OpenSSL not found via Homebrew, disabling TLS support)
        TLS_MODULE =
        TLS_LIB =
        TLS_INC =
    endif

else
    # Linux 和其他 Unix 系统
    SHARED := -fPIC -shared
    CC ?= gcc
	# Linux - 检测 OpenSSL 路径（支持 Ubuntu/Debian）
    # 优先尝试 pkg-config，然后尝试常见路径
    OPENSSL_PREFIX := $(shell pkg-config --variable=prefix openssl 2>/dev/null)
    ifneq ($(OPENSSL_PREFIX),)
        TLS_LIB = $(OPENSSL_PREFIX)/lib
        TLS_INC = $(OPENSSL_PREFIX)/include
    else
        # 尝试常见的 Ubuntu/Debian 路径
        ifneq ($(wildcard /usr/lib/x86_64-linux-gnu/libssl.so),)
            TLS_LIB = /usr/lib/x86_64-linux-gnu
            TLS_INC = /usr/include
        else ifneq ($(wildcard /usr/lib/aarch64-linux-gnu/libssl.so),)
            TLS_LIB = /usr/lib/aarch64-linux-gnu
            TLS_INC = /usr/include
        else
            TLS_LIB = /usr/lib
            TLS_INC = /usr/include
        endif
    endif
endif

# jemalloc 配置
JE_MALLOC_INC := $(SKYNET_ROOT)3rd/jemalloc/include/jemalloc
JE_MALLOC_LIB := $(SKYNET_ROOT)3rd/jemalloc/lib/libjemalloc_pic.a

MCSERVICE = skiplist time aoi rand openssl cjson tz lcrypt pb consistenthash lfs gzip
all :  $(foreach v, $(MCSERVICE), $(MCSERVICE_PATH)$(v).so) \
	$(MCSERVICE_PATH)lutil.so \
	$(MCSERVICE_PATH)lkcp.so \
	$(MCSERVICE_PATH)utf8.so \
	$(MCSERVICE_PATH)crab.so

.PHONY : all clean cleanall

$(MCSERVICE_PATH) :
	mkdir -p $(MCSERVICE_PATH)

# skiplist - 链接 jemalloc 库
# skiplist - 添加 jemalloc 命名空间
# skiplist - 简化版本，不使用内存统计
$(MCSERVICE_PATH)skiplist.so : $(SRC_DIR)/skiplist.c $(SRC_DIR)/lua-skiplist.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I$(SKYNET_ROOT)skynet-src

$(MCSERVICE_PATH)time.so : $(SRC_DIR)/lua-time.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I$(SKYNET_ROOT)skynet-src

$(MCSERVICE_PATH)lutil.so : $(SRC_DIR)/lutil.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(MCSERVICE_PATH)lkcp.so : $(SRC_DIR)/lkcp.c $(SRC_DIR)kcp/ikcp.c $(SRC_DIR)kcp/ikcp.h | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) $(filter %.c,$^) -o $@

$(MCSERVICE_PATH)aoi.so : $(SRC_DIR)/aoi.c $(SRC_DIR)/lua-aoi.c $(SRC_DIR)/aoi.h | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) $(filter %.c,$^) -o $@

$(MCSERVICE_PATH)utf8.so : $(SRC_DIR)/lua-utf8.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(MCSERVICE_PATH)crab.so : $(SRC_DIR)/lua-crab.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(MCSERVICE_PATH)rand.so : $(SRC_DIR)/lua-rand/rand.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@

SSL_SRCS := $(shell find lua-openssl/src -name '*.c') lua-openssl/deps/auxiliar/auxiliar.c lua-openssl/deps/auxiliar/subsidiar.c
SSL_HDRS := $(shell find lua-openssl/src -name '*.h')
SSL_INCS := $(sort $(dir $(SSL_HDRS)))  # 获取所有子目录路径
SSL_CFLAGS = $(CFLAGS)
SSL_CFLAGS += $(foreach dir,$(SSL_INCS),-I$(dir))  # 添加递归搜索路径
SSL_CFLAGS += -Ilua-openssl/deps/auxiliar -Ilua-openssl/deps/lua-compat/c-api

$(MCSERVICE_PATH)openssl.so : $(SSL_SRCS) | $(MCSERVICE_PATH)
	$(CC) $(SSL_CFLAGS) $(SHARED) -I$(TLS_INC) $^ -o $@ -L$(TLS_LIB) -lssl -lcrypto

$(MCSERVICE_PATH)cjson.so : lua-cjson/lua_cjson.c lua-cjson/strbuf.c lua-cjson/fpconv.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilua-cjson $^ -o $@

$(MCSERVICE_PATH)tz.so : lua-tz/src/tz.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilua-tz/src $^ -o $@ 

CRYPT_SRCS := $(shell find lua-crypt/src -name '*.c')
$(MCSERVICE_PATH)lcrypt.so :  $(CRYPT_SRCS) | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilua-crypt/src -I$(TLS_INC) $^ -o $@ -L$(TLS_LIB) -lssl -lcrypto

$(MCSERVICE_PATH)pb.so : lua-protobuf/pb.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilua-protobuf $^ -o $@

$(MCSERVICE_PATH)consistenthash.so : lua-consistent-hash/consistenthash.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilua-consistent-hash/src $^ -o $@ 

$(MCSERVICE_PATH)lfs.so : lua-lfs/src/lfs.c | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilua-lfs/src $^ -o $@

# gzip - 使用 zlib（优先使用系统 zlib，否则编译子模块中的 zlib）
ZLIB_DIR := lua-gzip/zlib

# 检测系统是否有 zlib（macOS 和 Linux 通常都有）
ifeq ($(UNAME_S),Darwin)
    # macOS 使用系统 zlib
    ZLIB_INC := /usr/include
    ZLIB_LINK := -lz
else
    # Linux 尝试使用系统 zlib
    ZLIB_INC := /usr/include
    ZLIB_LINK := -lz
endif

# 确保 zlib 子模块已初始化（用于头文件）
$(ZLIB_DIR)/zlib.h:
	@if [ ! -f "$(ZLIB_DIR)/zlib.h" ]; then \
		cd lua-gzip && git submodule update --init --recursive; \
	fi

# 编译 gzip.so，使用系统 zlib 或子模块中的 zlib 头文件
$(MCSERVICE_PATH)gzip.so : lua-gzip/lgzip.c $(ZLIB_DIR)/zlib.h | $(MCSERVICE_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(ZLIB_DIR) $< -o $@ $(ZLIB_LINK)

clean :
	rm -f $(MCSERVICE_PATH)*.so