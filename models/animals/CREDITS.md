# Анимированные модели мутантов — источники и лицензии

Все модели в этой папке — **CC0 / Public Domain** (Quaternius, через poly.pizza).
Разрешено любое использование, включая коммерческое, указание авторства не требуется,
но мы его сохраняем здесь из вежливости.

Источник: https://poly.pizza (автор Quaternius, https://quaternius.com)
Формат: GLB (FBX2glTF v0.9.7), скелет + анимации внутри каждой модели.

| Файл в игре | Исходная модель | Кто играет в игре | Клипы |
|---|---|---|---|
| dog_mutant_anim.glb | Husky | Плоть-пёс (dog_mutant) | Attack, Death, Eating, Gallop, Idle, Idle_2, Walk, Jump_ToIdle, HitReact x2 |
| pseudodog_anim.glb | Shiba Inu | Псевдопёс (pseudodog) | тот же набор |
| chimera_anim.glb | Wolf | Химера (chimera) | тот же набор |
| flesh_anim.glb | Bull | Плоть (flesh) | Attack_Headbutt, Attack_Kick, Death, Gallop, Idle, Walk ... |
| snork_anim.glb | Orc | Снорк (snork) | Walk, Run, Punch, Death, Idle, HitReact ... |
| zombie_anim.glb | Orc Enemy | Зомби (zombie) | Walk, Bite_Front, Death, Idle, Jump |
| pseudogiant_anim.glb | Yeti | Псевдогигант (pseudogiant) | Walk, Bite_Front, Death, Idle, Dance, Jump |
| controller_anim.glb | Alien | Контролёр (controller) | Walk, Run, Punch, Death, Idle, HitReact ... |
| poltergeist_anim.glb | Ghost | Полтергейст (poltergeist) | Flying_Idle, Fast_Flying, Headbutt, Death, HitReact |

Страницы паков:
- Animated Animal Pack: https://poly.pizza/bundle/Animated-Animal-Pack-ILAPXeUYiS
- Ultimate Monsters Bundle: https://poly.pizza/bundle/Ultimate-Monsters-Bundle-5oyGWAmOB6

Порядок импорта в Godot: клипы получают имена вида «AnimalArmature|Walk» —
их подбирает по суффиксам проигрыватель в `base_mutant.gd`, вручную ничего
подключать не нужно.
