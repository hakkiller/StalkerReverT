# Текстуры и ассеты — источники и лицензии

## Пак «мрачная атмосфера» (assets/textures/pbr/)

18 PBR-материалов: **ambientCG.com, лицензия CC0 1.0 (общественное достояние)**.
Разрешено любое использование без атрибуции; источник упомянут из вежливости.
Конкретные ассеты — см. `pbr/manifest.json` (категория -> ID ambientCG).

Категории: asphalt_old/worn, brick_dark, concrete_floor, concrete_wall_clean/dirty,
corrugated_metal/rust, dead_grass, dirt_dry, gravel_dirty/fine, leak_stains(2),
moss, plaster_cracked, rust_heavy, wood_planks_old.
Каждая: albedo.jpg, normal.png (OpenGL), roughness.jpg, ao.jpg, displacement.jpg.

## Декали (assets/textures/decals/)

16 прозрачных PNG 512×512 (трещины, ржавчина, пятна, мох, пулевые отверстия,
знак «Радіація», разметка) — процедурные, из архива карты Припяти,
ограничений на использование нет.

## Сетка Kenney Prototype (grid_light.png, grid_dark.png, grid_green.png)

**Kenney.nl, CC0 1.0**. Ранее использовалась на строениях; после перехода на
PBR-пак осталась в проекте как утилитарные тайлы (может пригодиться для
отладочной разметки).

## Карта Припяти (будущая интеграция, data карт-архива)

- Картовые данные: © участники **OpenStreetMap, ODbL 1.0** — при распространении
  игры обязательна атрибуция (добавить в экран меню/README билда).
- Высоты: AWS Terrain Tiles / SRTM (открытые данные NASA/USGS).
- Декали и шейдеры архива — оригинальные процедурные, без ограничений.
