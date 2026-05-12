# =============================================================================
# rest-ftp-daemon Dockerfile
# =============================================================================
# 修复说明:
#   1. 升级 Ruby 至 2.7-slim (原 2.3 已 EOL)
#   2. Gemfile 源改为 HTTPS
#   3. 捆绑安装参数更新 (--no-rdoc --no-ri → --no-document)
#   4. 应用 .dockerignore 优化构建上下文
#   5. 创建 rftpd 用户/组，提升容器安全
#   6. 内置 docker/rftpd.yml 配置文件
#   7. 移除 newrelic/rollbar 等外部服务的默认启用
# =============================================================================

FROM ruby:2.7-slim
LABEL maintainer="Bruno MEDICI <rest-ftp-daemon@bmconseil.com>"

# 环境变量
ENV LANG=C.UTF-8 \
    INSTALL_PATH=/app/ \
    DEBIAN_FRONTEND=noninteractive

# 第一阶段: 安装构建依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      git \
      && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 更新 RubyGems 并安装 bundler (使用当前 Bundler 版本)
RUN gem update --system --no-document && \
    gem install bundler --no-document

# 安装 gem 依赖 (先复制 gem 描述文件，利用 Docker 层缓存)
RUN mkdir -p $INSTALL_PATH
WORKDIR $INSTALL_PATH

COPY Gemfile rest-ftp-daemon.gemspec $INSTALL_PATH
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4

# 复制应用代码
COPY . $INSTALL_PATH

# 创建 rftpd 系统用户
RUN groupadd -r rftpd && \
    useradd -r -g rftpd -d $INSTALL_PATH -s /sbin/nologin rftpd

# 放置 Docker 环境专用配置文件
COPY docker/rftpd.yml /etc/rftpd.yml

# 确保日志目录可写
RUN mkdir -p /tmp && chown -R rftpd:rftpd /tmp $INSTALL_PATH

# 清理构建依赖 (减小最终镜像体积)
RUN apt-get purge -y --auto-remove build-essential git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 应用运行
EXPOSE 3000
USER rftpd
CMD ["bin/rest-ftp-daemon", "-e", "docker", "-c", "/etc/rftpd.yml", "-f", "start"]