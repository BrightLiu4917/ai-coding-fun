# 控制系统规格变更

## 功能模块

### 项目画像

系统必须支持生成 `.ai-control/project.env` 和 `.ai-control/project-profile.md`，用于记录目标项目技术栈、推荐 profile、前后端目录和测试命令。

### 多项目 Profile

系统必须支持 `fullstack-admin`、`java-springboot`、`vue3-admin`、`react-admin`、`go-gin`、`php`、`minimal`、`default` 和 `gupo` profile。

### 规则分层

系统必须区分通用规则、技术栈规则和功能规则。

## 数据结构

- `.agent/`：本机配置、密钥、日志和审查产物，默认忽略。
- `.ai-control/`：项目画像，不存放密钥，目标项目可以提交。

## 异常处理

安装冲突时，系统必须要求用户选择备份、覆盖或停止，不得静默覆盖。

## 日志说明

测试和 deepv4 运行产物必须写入 `.agent/`，不得写入源码目录。
