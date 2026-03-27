# Card Pack Design — NFSW Server

## Система запчастей

Каждая запчасть имеет два параметра:

**Грейд** (★ звёздочки) — мощность детали:

| Грейд | ★ | В магазине? | Ценовой диапазон (engine) |
|-------|---|-------------|---------------------------|
| Street | ★1 | ✅ Да | 13,000 – 48,000 |
| Race | ★2 | ✅ Да | 33,000 – 72,000 |
| Pro | ★3 | ❌ Только из паков | 53,000 – 96,000 |
| Uber | ★4 | ❌ Только из паков | 73,000 – 120,000 |
| Elite | ★5 | ❌ Только из паков | 70,000 – 96,000 |

**Цвет** (качество внутри грейда):
Grey → Common → Uncommon → Rare → **Elite**

> Elite ★5 имеет только 3 цвета (Grey/Common/Uncommon) — Rare и Elite цветов в игре нет.

Средняя стоимость **5 случайных деталей** в магазине:
- Street ★1: ~80,000 CASH
- Race ★2: ~145,000 CASH
- Pro/Uber/Elite: в магазине не продаются

---

## Финальная схема паков

### Паки запчастей (5 слотов, только детали, без паверапов)

| Пак | entitlementTag | Цена | Грейд | Логика |
|-----|----------------|------|-------|--------|
| T1 Pack | `cardpack_t1_bronze` | 70,000 CASH | Street ★1 | Рандом × 5, чуть дешевле магазина |
| T2 Pack | `cardpack_t1_silver` | 130,000 CASH | Race ★2 | Рандом × 5, чуть дешевле магазина |
| T3 Pack | `cardpack_t1_gold` | 200,000 CASH | Pro ★3 | Эксклюзив, недоступен в магазине |
| T4 Pack | `cardpack_t1_platinumA` | 350,000 CASH | Uber ★4 | Эксклюзив, недоступен в магазине |
| Black Diamond | `cardpack_blackdiamond` | 500,000 CASH | Elite ★5 | Топ эксклюзив, недоступен в магазине |

**Дропы — все 5 слотов одинаковые, равный шанс на стили:**

| Пак | Reward tables (по 20% каждая) |
|-----|-------------------------------|
| T1 | `street_improved_parts` / `street_sport_parts` / `street_tuned_parts` / `street_custom_parts` / `street_elite_parts` |
| T2 | `race_improved_parts` / `race_sport_parts` / `race_tuned_parts` / `race_custom_parts` / `race_elite_parts` |
| T3 | `pro_improved_parts` / `pro_sport_parts` / `pro_tuned_parts` / `pro_custom_parts` / `pro_elite_parts` |
| T4 | `ultra_improved_parts` / `ultra_sport_parts` / `ultra_tuned_parts` / `ultra_custom_parts` / `ultra_elite_parts` |
| Black Diamond | `elite_improved_parts` / `elite_sport_parts` / `elite_tuned_parts` (по ~33%) |

---

### Паки паверапов (5 слотов)

| Пак | entitlementTag | Цена | Слоты |
|-----|----------------|------|-------|
| Powerup Pack | `cardpack_silver` | 75,000 CASH | 2× powerups_bronze(18шт) + 2× powerups_silver(24шт) + 1× powerups_gold(30шт) |
| Premium Powerup Pack | `cardpack_gold` | 200,000 CASH | 2× powerups_platinum(36шт) + 2× powerups_diamond(42шт) + 1× powerups_diamond_upper(48шт) |

---

### Aftermarket Pack (визуал)

| Пак | entitlementTag | Цена | Содержимое |
|-----|----------------|------|------------|
| Aftermarket Pack | `cardpack_aftermarket` | 50,000 CASH | 5× случайный visual part (bodykit, hood, spoiler, wheels, neon…) |

---

### Скилл-моды

| Пак | entitlementTag | Цена | Шанс |
|-----|----------------|------|------|
| Skillmods Mystery | `cardpack_skillmods_mystery` | 80,000 CASH | ★1=30% / ★2=30% / ★3=25% / ★4=12% / ★5=3% |

---

## Итого в магазине (порядок отображения)

```
[Детали]
  Aftermarket Pack →   65,000 CASH   (Visual parts, визуал)
  T1 Parts Pack    →   70,000 CASH   (Street ★1)
  T2 Parts Pack    →  130,000 CASH   (Race ★2)
  T3 Parts Pack    →  200,000 CASH   (Pro ★3, эксклюзив)
  T4 Parts Pack    →  350,000 CASH   (Uber ★4, эксклюзив)
  Diamond Pack     →  500,000 CASH   (Elite ★5, топ эксклюзив)

[Паверапы]
  Powerup Pack          →   75,000 CASH   (cardpack_silver, серебряная карточка)
  Premium Powerup Pack  →  200,000 CASH   (cardpack_gold, золотая карточка)

[Скилл-моды]
  Mystery Skill Pack    →   80,000 CASH
```
