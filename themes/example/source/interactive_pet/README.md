# Шаблон логики интерактивного питомца

Production-компонент питомца создаётся в `package/components/interactive_pet.tscn`, а его
GDScript и ресурсы остаются внутри `package/`. Поле `InteractivePetScene` в manifest должно
ссылаться на эту сцену через канонический namespace `res://exchanger_theme_dlc/`.

Пошаговая раскадровка, структура `VisualRoot`, политики движения и checklist дизайнера описаны в
[`docs/COMPOSITE_PET_ANIMATIONS.md`](../../../../docs/COMPOSITE_PET_ANIMATIONS.md).

Сначала реализуйте обязательный animation API из `docs/SCRIPTING.md`. Если уникальное действие
состоит из нескольких анимаций и перемещений, реализуйте весь optional composite API целиком:
`has_pet_composite_action`, `start_pet_composite_action`, `cancel_pet_composite_action` и два
сигнала `pet_composite_action_started` / `pet_composite_action_finished`. Частичная реализация
считается ошибкой валидатора.

Сценарий работает как корутина темы. Host передаёт scoped runtime: через него тема временно
приостанавливает обычную навигацию, разрешает выход за границы, игнорирует опоры, перемещает
экранную опорную точку и затем явно возвращает её на объявленную поверхность. Перед каждым
`await` проверяйте `runtime.IsActive()` и run id. При отмене немедленно прекращайте корутину,
возвращайте локальный scale/визуальные состояния и не управляйте старым runtime.

После реализации активируйте тему и откройте `PET` в preview. Обычные кнопки проверяют каждый
клип отдельно, а «СОСТАВНОЕ ДЕЙСТВИЕ: INTERACT» — полный сценарий с проходом через границу и
посадкой на верхнюю тестовую опору.
