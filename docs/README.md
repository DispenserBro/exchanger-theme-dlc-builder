# Документация Exchanger Theme DLC Builder

Документы разделены по назначению, чтобы человек или новый ИИ-агент мог работать без доступа к
контексту основного проекта.

## Начать работу

- [QUICK_START.md](QUICK_START.md) — установка, VS Code, первая активация и happy path.
- [APPLY_THEME.md](APPLY_THEME.md) — пошаговое применение изменённой темы в Exchanger: preview,
  проверки, сборка, установка и перезапуск.
- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) — текущее состояние, подтверждённые ограничения и
  ближайшие задачи; обязательное чтение для нового ИИ-агента.
- [CONTRIBUTING.md](../CONTRIBUTING.md) — правила изменения и checklist перед передачей результата.

## Понять систему

- [ARCHITECTURE.md](ARCHITECTURE.md) — границы Theme Builder/Exchanger и дерево каталогов.
- [BINDING_CONTRACT.md](BINDING_CONTRACT.md) — manifest v2, девять сцен, 481 immutable и 24
  supplemental runtime-биндингов, metadata и безопасная синхронизация с host.
- [WORKFLOW.md](WORKFLOW.md) — полный цикл activate → edit → live reload → save → validate → build
  → install.

## Создавать и проверять темы

- [THEME_AUTHORING.md](THEME_AUTHORING.md) — практические правила визуальной разработки.
- [SCRIPTING.md](SCRIPTING.md) — GDScript, сигналы и произвольная runtime-логика доверенной темы.
- [COMPOSITE_PET_ANIMATIONS.md](COMPOSITE_PET_ANIMATIONS.md) — пошаговая сборка составного
  действия питомца для дизайнера.
- [THEME_INTEGRATION.md](THEME_INTEGRATION.md) — установка PCK и runtime-проверка в Exchanger.
- [QA_AND_TROUBLESHOOTING.md](QA_AND_TROUBLESHOOTING.md) — visual QA, команды и типовые ошибки.
- [SPACE_PIXEL.md](SPACE_PIXEL.md) — решения, инвентаризация и ограничения темы `space-pixel`.

Корневой [README](../README.md) — короткая стартовая страница. Инструкции ИИ находятся только в
[AGENTS.md](../AGENTS.md).
