# Анимированные VFX для аномалий (anomaly_fx)

Пакет подготовлен агентом-подготовщиком по прямому запросу пользователя.
**Код игры не трогал** — ниже описание всего, что приготовлено, и как это
встроить. Всё содержимое — оригинальные процедурные ассеты (CC0, см. CREDITS.md).

## Что это и почему так

Просили модели для аномалий, лучше анимированные. Поиск открытых источников
показал: готовых CC0-моделей аномалий (электра/вихрь/кислота…) с прямыми
ссылками не существует — Sketchfab отдаёт скачивание только под логином,
poly.pizza без API-ключа не отдаёт список, у Kenney/Quaternius VFX-паков нет.
Поэтому пакет сделан так, как это делают сами игры зоны: **процедурные
анимированные эффекты** — GDShader (анимация по `TIME`) + GPUParticles3D +
мерцающий OmniLight3D. Они «анимированы» по построению, весят копейки
и крутятся параметрами в инспекторе.

Ручные кандидаты, если захочется готовых мешей (скачивать руками):
- Sketchfab: [Animated Crystal (markskovrup)](https://sketchfab.com/3d-models/animated-crystal-b0d04fbd1dd24da899048cbae316f5f4),
  [порталы metaclubmedia](https://sketchfab.com/metaclubmedia/collections/portal-87120033f3c941a7b4287d6108caa867)
- BlendKit: [Animated Blue Vortex Portal](https://www.blendkit.com/asset-gallery-detail/fd5651f8-303c-4864-99e9-976a5bc25671)

## Состав (17 префабов под каждый тип из anomalies/)

| Префаб (scenes/) | Аномалия проекта | Что внутри |
|---|---|---|
| fx_electra.tscn | electric_anomaly | пульсирующее ядро + 4 billboard-молнии + искры + свет |
| fx_tesla.tscn | electric_tesla | 6 молний, светящийся столб, фонтан искр |
| fx_vortex.tscn | gravity_vortex | спиральный диск на земле + воронка-конус + мусор |
| fx_whirlwind.tscn | gravity_whirlwind | высокий смерч + пыль + искры |
| fx_gravity_lift.tscn | gravity_lift | обратная закрутка + восходящий столб + пар |
| fx_fry.tscn | heat_anomaly | 3 языка процедурного огня + жар на земле + угли |
| fx_comet.tscn | thermal_comet | огненное ядро + хвост + шлейф искр |
| fx_steam.tscn | thermal_steam | столб пара, мягкая подсветка |
| fx_acid_pool.tscn | acid_anomaly | пузырящаяся лужа + брызги |
| fx_acid_cloud.tscn | chemical_acid_cloud | 4 слоя газа + капли |
| fx_gas.tscn | chemical_gas | серые клубы без резких акцентов |
| fx_jelly.tscn | chemical_jelly | колышущийся полупрозрачный блоб + лужа |
| fx_burning_fluff.tscn | bio_burning_fluff | огонь + тёмное ядро + летящие «пушинки» |
| fx_radiation.tscn | radiation_hotspot | пульсирующий жар + «гейгер»-дрожь + пылинки |
| fx_teleport.tscn | teleport | закрученный портал + столб + кольца |
| fx_time_dilation.tscn | time_dilation | расходящаяся рябь на земле + купол |
| fx_base.tscn | base_anomaly | нейтральное ядро (заглушка общего вида) |

Плюс:
- `shaders/` — 12 GDShader-ов (spatial, все параметры — uniform-ы).
- `textures/` — 7 процедурных спрайтов частиц (glow, spark, smoke, ring,
  streak, атлас молний 4 кадра).
- `scripts/fx_flicker.gd` — мерцание OmniLight3D (fast-шум поверх медленной
  волны; `flicker_speed`, `flicker_amount`, `base_energy`).
- `scripts/showcase_camera.gd` — облёт витрины (колесо мыши — высота).
- `demo/anomaly_showcase.tscn` — все 17 эффектов в сетке с Label3D-подписями,
  тёмный пол, туман, орбитальная камера. Открыть как сцену и запустить.

## Как встроить (рекомендация, не делал сам)

1. Папку `anomaly_fx/` положить в корень проекта (`res://anomaly_fx/`).
2. В сцене аномалии (например `anomalies/electric_anomaly.tscn`) добавить
   дочерним узлом instance `res://anomaly_fx/scenes/fx_electra.tscn`.
3. У существующего `MeshInstance3D` снять галку **Visible** — НЕ удалять его:
   `BaseAnomaly._update_size()`/`_update_color()` продолжат работать с ним
   (код аномалий не меняется вообще).
4. Масштаб эффекта — `scale` корня instance (эффекты собраны под радиус
  ~4-5 м). Цвета/скорости — uniform-ы ShaderMaterial в инспекторе.
5. Витрину `demo/anomaly_showcase.tscn` можно запускать отдельно для выбора
   вида, она ничего из игры не тянет.

## Технические заметки

- Билборды сделаны **ручным vertex-билбордом** (MODELVIEW_MATRIX), без
  `render_mode billboard` — совместимо со всеми рендерерами, включая
  compatibility.
- Проверено в Godot 4.3 (headless: импорт и запуск витрины — без ошибок
  скриптов/шейдеров/сцен). Проект на 4.6 — используемый синтаксис между
  версиями стабилен, но **первый визуальный запуск за основным агентом**.
- В headless-режиме dummy-рендерер печатает безобидные `Parameter "m" is null`
  на любые меши — это шум заглушки, не дефект (на реальном рендерере их нет).
- Партиклы — GPUParticles3D + ParticleProcessMaterial (без turbulence,
  для широкой совместимости). Текстуры партиклов белые — тонировка через
  color ramp.
