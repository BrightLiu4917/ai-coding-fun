# OpenSpec 变更

每个非简单任务创建一个 change：

```text
openspec/changes/<change-id>/
├── proposal.md
├── design.md
├── tasks.md
└── specs/
    └── <capability>/
        └── spec.md
```

`proposal.md`：为什么做、做什么、不做什么、风险和确认问题。  
`design.md`：技术方案、数据/API/UI/架构影响、备选方案和取舍。  
`tasks.md`：可验证的任务清单。  
`specs/`：对当前能力规格的新增、修改或废弃说明。

用户确认前禁止编码。
