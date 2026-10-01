# Шаблон темы

Создавайте новую тему через `Редактор → Создать тему`: EditorPlugin скопирует этот каталог,
обновит `ThemeId`/`DisplayName` и активирует результат. Для автоматизации допустимо скопировать
`example` в `themes/<theme-id>` вручную и изменить те же поля manifest. Не переименовывайте файлы экранов,
корневые узлы и значения `exchanger_binding_id`: они являются контрактом приложения.

Тема `example` сама является валидным минимальным пакетом manifest v2: в ней находятся все
девять production-сцен, 481 immutable и 17 supplemental обязательных биндингов, включая готовые
экранные клавиатуры SETTINGS. Её можно активировать, проверить и
собрать до начала оформления новой темы.

Если теме нужен интерактивный питомец, добавьте его production-сцену в `package/components/`,
скрипты и ресурсы — внутрь `package/`, затем задайте `InteractivePetScene` в manifest. Базовый и
необязательный составной runtime-контракты описаны в
[`docs/SCRIPTING.md`](../../docs/SCRIPTING.md), а дизайнерский workflow — в
[`docs/COMPOSITE_PET_ANIMATIONS.md`](../../docs/COMPOSITE_PET_ANIMATIONS.md); памятка для автора лежит в
[`source/interactive_pet/README.md`](source/interactive_pet/README.md).

Оригиналы, рабочие файлы графического редактора и локальные референсы храните в `source/`.
В PCK экспортируется только содержимое `package/`. Скрипт сборки временно копирует его в
изолированный проект под канонический runtime-путь `res://exchanger_theme_dlc/` и удаляет
workspace после export.

Каталог темы всегда виден в Godot FileSystem. `.gdignore` не добавляйте: package использует
относительные ссылки, поэтому сцены можно открывать и редактировать непосредственно в
`res://themes/<theme-id>/package/scenes/`.
