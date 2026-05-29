# 项目适配规则

## 目标

让同一套控制系统可以接入不同项目，而不是绑定某个历史项目、目录或技术栈。

## 项目画像

初始化或接入检查时应生成：

```text
.ai-control/project.env
.ai-control/project-profile.md
```

`project.env` 记录机器可读的技术栈识别结果；`project-profile.md` 记录给人看的项目画像。

## 优先级

1. 目标项目已有约定。
2. OpenSpec 已确认规格。
3. `.ai-control/project.env` 的项目画像。
4. 本控制系统的通用规则。
5. 技术栈默认实践。

## 禁止事项

- 禁止引用不存在的历史项目作为强制依赖。
- 禁止把某个项目的响应体、异常、分页、权限、目录结构直接套到另一个项目。
- 禁止因为脚手架方便而强行引入目标项目不需要的依赖。
- 禁止把检测结果当作业务事实；检测结果只能作为工程提示。

## 接入后必须检查

```bash
bash scripts/check-project-ready.sh
```

