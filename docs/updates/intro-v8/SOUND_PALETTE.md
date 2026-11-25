# Клинок Памяти — звуковая палитра

9 ноября 2026

31 звук в четырёх шинах: музыка ведёт эмоцию, атмосфера строит пространство, эффекты отмечают то, что видно на экране, голос рассказывает. Скрипт сам запускает их по тайм-кодам, приглушает музыку под голос и ставит Горнило и клинок в объёмный звук. Любой звук без ID пропускается, ролик от этого не падает.

## Как звук работает в ролике

Четыре шины, у каждой своя работа:

- **Музыка**, 5 кусков: ведёт эмоцию. Куски сводятся кроссфейдом по тайм-кодам.
- **Атмосфера**, 5 слоёв: строит пространство (пустота, коридор, зал, Горнило, живой клинок).
- **События**, 16 звуков: отмечают то, что видно на экране, в точный момент.
- **Голос**, 5 реплик: рассказывает. Пока он звучит, музыка уходит на 60 %, атмосфера на 80 %.

На пяти решениях держится весь звук:

1. **Одна тональность.** Все куски музыки и гул клинка строятся от ре минор, поэтому кроссфейды не фальшивят.
2. **Горнило и клинок звучат из своих мест.** `ForgeFire` сидит в чаше Горнила, `BladeHum` в клинке. Чем ближе камера, тем громче, а на отъезде звук отдаляется сам.
3. **Заряд слышно.** Каждая прилетевшая душа даёт тик (`SoulTick`), его высота растёт с наполнением клинка. Гул клинка поднимается по тону и громкости. Игрок слышит шкалу заряда, не глядя на неё.
4. **Тишина как удар.** На 24,9 с музыка обрывается за 0,35 с, остаются удар, скрежет и резонанс клинка. После этого вход Пробуждённого звучит громче любого оркестра.
5. **У каждого звука своя полоса.** Ниже 60 Гц живут только `SubHum`, `HallReveal`, `BladeFull`, `Thud` и `FinalHit`, поэтому удары не тонут в музыке. Область 1–4 кГц оставлена голосу, музыка и `Absorb` там мягкие.

## Карта по времени

Время в секундах от начала ролика. Всё ниже скрипт запускает сам, вам нужно только сделать файлы.

| Время | На экране | Что звучит |
| --- | --- | --- |
| 0:00 | Чёрный экран | `MusicVoid` (вход 2,5 с), `AmbCorridor`, `SubHum` |
| 0:01 | Тьма | `Hammer` |
| 0:02 | Холодный голубой свет проявляется вдали | `LightOn` |
| 0:03 | Свет растёт | `ForgeFire` входит издалека (объёмный) |
| 0:04 | Коридор Хранилища | `Voice1` на 4,3 |
| 0:10 | Конец коридора | кроссфейд `MusicVoid` → `MusicHall`, `AmbCorridor` → `AmbHall` (с 10,2) |
| 0:11 | Выход в зал: Горнило, Колесо Клинков, парящие клинки | `HallReveal`, `Voice2` на 11,3 |
| 0:17 | Клинки начинают потухать | `MusicRot` входит (с 17,4) |
| 0:18 | Стеклянный клинок с гниющей памятью | `Voice3` на 18,3 |
| 0:19 | Силуэт глючит и сереет | `Corrupt` |
| 0:21 | Силуэт рассыпается в кубики, они летят в пустой клинок | `Absorb`, `BladeHum` входит, с 22,5 `SoulTick` на каждую душу |
| 0:24,9 | Клинок полон: вспышка, кольцо кубиков по полу | `BladeFull`, `Scrape`, `MusicRot` обрывается; на 25,4 `Thud` |
| 0:26 | Пробуждённый собирается из кубиков | `Materialize`, `MusicAwaken` входит (3 с), `Voice4` на 26,2 |
| 0:27,6 | Рука смыкается на рукояти | `Grip` |
| 0:29,5 | Клинок идёт вверх, герой встаёт | `BladeRise` |
| 0:30,5 | Глаза открываются | `EyesOpen` |
| 0:33 | Клинок уходит в центр, камера отъезжает | `Whoosh`, `MusicFinale` входит (1,2 с), `MusicAwaken` гаснет, `Voice5` на 33,4, `Absorb` на 33,6 (70 % громкости) |
| 0:34 | Название | `TitleSting` |
| 0:37,9 | Пик, обрыв | Всё останавливается, звучит только `FinalHit` |
| 0:38,5 | Чёрный экран, титр | Хвост `FinalHit` гаснет за 0,8 с |

## Музыка

Пять кусков вместо одного трека: генераторы не умеют попадать в тайм-коды, а кусок можно переделать отдельно. Скрипт вводит и гасит куски кроссфейдом, поэтому длина файла не меньше указанной, лучше на 2 с больше.

**Общая палитра для всех пяти:** низкие струнные, стеклянные колокольчики (челеста, стеклянная гармоника), хор без слов, редкий рояль. Ре минор, свободный темп без сетки. Бас не ниже D2 (73 Гц). Без гитар, барабанных партий, электроники и дропов.

| Ключ | Слот в ролике | Файл, мин. | Что делает |
| --- | --- | --- | --- |
| `MusicVoid` | 0:00 → 0:12,6 | 14 с | Делает пустоту и холод. Без мелодии, чтобы `Voice1` остался главным. Тихо, концом чуть тревожнее. |
| `MusicHall` | 0:10,2 → 0:19,6 | 11 с | Даёт масштаб зала. Входит хор, в струнах первая светлая нота. Здесь первый раз звучит мотив из четырёх нот на челесте, его потом повторяют `MusicAwaken` и `MusicFinale`. Начинается с той же квинты D–A, чтобы стык с `MusicVoid` не был слышен. |
| `MusicRot` | 0:17,4 → 0:25,3 | 9 с | Делает тревогу: расстроенные струны, тремоло, глючные текстуры, нарастание без разрешения. Скрипт обрывает кусок на 24,9, поэтому пишите его на нарастание до максимума, без затухания в конце. |
| `MusicAwaken` | 0:26 → 0:34,6 | 10 с | Делает пробуждение. Первые 3 с почти тишина (скрипт вводит кусок плавно): рояль или челеста с мотивом. Пик с хором на 5,7 с куска, это 31,7 в ролике, клинок поднят. Тёмная тональность к пику светлеет. Тепло, но с весом. |
| `MusicFinale` | 0:33 → 0:37,9 | 6 с | Даёт кульминацию: хор и струнные растут до fortissimo, мотив наверху. Заканчивать на пике, без хвоста: скрипт обрывает всё на 37,9 и сразу бьёт `FinalHit`. |

**Промпты** (на английском, так генераторы понимают точнее):

- `MusicVoid`: Dark cinematic ambient, 14 seconds, free tempo, no beat. Cold bowed low strings and cello harmonics over a D2 pedal, faint glass harmonica shimmer, nothing melodic, slowly swelling from pianissimo to mezzo-piano, ending on a hanging open fifth D–A. No drums, no guitar, no vocals.
- `MusicHall`: Dark fantasy cinematic cue, 11 seconds, free tempo. Starts on a hanging open fifth D–A, distant wordless choir enters, legato strings rise, a four-note rising minor motif on solo celesta with long cathedral reverb, awe and scale, mezzo-piano to mezzo-forte. No drums, no guitar, no lyrics.
- `MusicRot`: Tense dark cinematic cue, 9 seconds, free tempo. Detuned strings with tremolo, low brass drone, reversed and glitchy glass textures, a dissonant cluster building continuously to fortissimo, no resolution, no fade-out: it must end at full intensity. No drums, no lyrics.
- `MusicAwaken`: Emotional dark fantasy cue, 10 seconds, free tempo, D minor. Starts almost silent with solo piano or celesta playing a four-note rising minor motif, low strings enter at 3 seconds, a wordless choir swells to a peak at 5.5 seconds where the harmony brightens toward D major, then sustains warmly with weight. Hopeful but heavy. No drums, no guitar, no lyrics.
- `MusicFinale`: Epic dark fantasy climax, 6 seconds, D minor. Wordless choir and strings crescendo from mezzo-piano to fortissimo with the rising motif on top, one deep cinematic drum hit allowed but no rhythm, ends sustained at full volume with no decay and no ring-out. No guitar, no lyrics.

Если куски не стыкуются на слух, есть запасной вариант: один трек на 38,5 с с теми же точками (0 / 11 / 18 / 24,9 тишина / 26 / 33 / 37,9 обрыв) в ключ `Music`. Тогда куски не играют, а обрыв на 24,9 нужно сделать в самом файле.

## Атмосфера

Пять слоёв без тональности (кроме гула клинка), чтобы не спорить с музыкой. Зацикленные файлы должны стыковаться без щелчка: начало и конец на одной громкости, без нарастаний внутри.

| Ключ | Когда | Файл | Что делает |
| --- | --- | --- | --- |
| `SubHum` | 0:00, один раз | 8 с | Заполняет чёрные первые секунды суббасом (36–45 Гц): нарастает 3 с, держится, затухает к 7 с. Без него начало звучит пусто. |
| `AmbCorridor` | 0:00 → 0:12,7, петля | 20 с, цикл | Делает тесное холодное пространство: каменный воздух, редкие капли, далёкий скрип ржавых доспехов. |
| `AmbHall` | 0:10,2 → конец, петля | 20 с, цикл | Делает простор: глубокий полый резонанс, редкий стеклянный перезвон парящих клинков, тихие тики камня. Рядом с коридором должен звучать «больше». |
| `ForgeFire` | 0:03 → конец, петля, объёмный | 12 с, цикл, моно | Живое Горнило. Сидит в чаше: полная громкость в 14 студах, до 120 студов затухает до нуля. Заранее показывает, куда идёт камера, ещё до того как Горнило видно. |
| `BladeHum` | 0:21 → 0:37,9, петля, объёмный | 8 с, цикл, моно | Голос клинка. Один ровный хрустальный тон (D3, около 147 Гц), без вибрато и без нарастания внутри файла. Высоту и громкость ведёт скрипт: от 0,8× до 1,4× по мере наполнения клинка, игрок слышит заряд. Полная громкость в 6 студах, до 90 затухает. |

`ForgeFire` и `BladeHum` делайте моно: источник один, панораму даёт движок.

**Промпты:**

- `SubHum`: Deep sub-bass drone, 8 seconds, a pure sine-like tone around 40 Hz with a slow swell over 3 seconds, sustained, then a gentle decay, no rhythm, no melody.
- `AmbCorridor`: Seamless loop, 20 seconds. Cold stone dungeon corridor room tone, very quiet, occasional distant water drips with long echo, faint creak of old rusty metal armor, distant low wind through pipes. No music, no tonal pitch.
- `AmbHall`: Seamless loop, 20 seconds. Huge stone hall ambience, deep hollow reverberant air, occasional soft glass chimes and crystal tinkles from far away, rare tiny stone ticks and falling dust, very quiet and spacious. No music, no melody.
- `ForgeFire`: Seamless loop, 12 seconds, mono. Blacksmith furnace fire: low steady roar of flames, crackling coals, occasional ember pops and soft sparks. No voices, no hammering, no music.
- `BladeHum`: Seamless loop, 8 seconds, mono. A single steady crystalline singing-glass hum at D3 (about 147 Hz) with faint harmonic overtones and slight beating, magical sword resonance. No vibrato, no volume change, no melody, no whoosh.

## События

16 коротких звуков, каждый привязан к конкретному кадру. Файлы начинайте сразу с звука, без тишины в начале: скрипт запускает их ровно в тайм-код.

| Ключ | Когда | Файл | Что делает |
| --- | --- | --- | --- |
| `Hammer` | 0:01 | 4 с | Один далёкий удар молота по металлу. Рвёт чёрный экран и сообщает: кузня жива, кто-то только что ковал. |
| `LightOn` | 0:02 | 4 с | Звук самого света: голубой свет проявляется вдали, хрустальный тон нарастает вместе с ним. |
| `HallReveal` | 0:11 | 3 с | Выход из коридора в зал. Воздушный подъём и мягкий глубокий удар ниже 60 Гц: пространство вдруг стало огромным. |
| `Corrupt` | 0:19 | 2,5 с | Память гниёт: силуэт глючит и сереет (эффект длится 1,9 с). Битый стеклянный треск, обратные шёпоты без слов, низкое рычание. |
| `Absorb` | 0:21 и 0:33,6 | 3 с | Фирменный звук поглощения: восходящий стеклянный свист, шорох кубиков, мягкий низкий хлопок в конце. Первый раз души летят в клинок, второй (70 % громкости) клинок втягивает всё вокруг. Середину 1–4 кГц оставьте чистой: во второй раз он идёт вместе с `Voice5`. Тот же звук потом пойдёт в игру. |
| `SoulTick` | 0:22,5 → 0:24,9, на каждую душу | 0,25 с | Крошечный стеклянный «тик». Скрипт играет его на каждую прилетевшую душу и поднимает высоту от 0,85× до 1,75×: наполнение клинка слышно как шкала. |
| `BladeFull` | 0:24,9 | 4 с | Клинок полон. Яркий колокольный удар по стеклу, субовый провал ниже 60 Гц, длинный мерцающий хвост до 0:28, он связывает наполнение с пробуждением. |
| `Scrape` | 0:24,9 | 1,2 с | Клинок содрогается на полу: болезненный высокий металлический скрежёт по камню. |
| `Thud` | 0:25,4 | 2 с | Глухой тяжёлый удар с субовым хвостом: ударная волна колец кубиков по полу. Падает в тишину после обрыва музыки. |
| `Materialize` | 0:26 | 1,2 с | Из кубиков собирается герой: быстрый рой крошечных стеклянных щёлков сходится в точку, тёплая низкая волна, мягкий «пуф» в конце. |
| `Grip` | 0:27,6 | 1 с | Рука смыкается на рукояти: кожа и металл, один низкий пульс как удар сердца, тихий «пинг» клинка. Момент, когда клинок выбрал героя. |
| `BladeRise` | 0:29,5 | 2,5 с | Герой поднимает меч: металл, протянутый сквозь воздух, поднимающийся звон, шорох ткани, выдох усилия без слов. |
| `EyesOpen` | 0:30,5 | 2,5 с | Глаза открываются: два низких удара сердца, вдох, два стеклянных тона вверх, кристалльный «динь». Длина совпадает с открытием глаз (2,2 с). |
| `Whoosh` | 0:33 | 1 с | Клинок уходит в центр, камера отъезжает: короткий мягкий проход воздуха. Склейка кадров звучит без щелчка. |
| `TitleSting` | 0:34 | 3,5 с | Появляется название: стеклянно-металлический удар колокола и глубокий резонанс, нарастающий под титр. |
| `FinalHit` | 0:37,9 | 2 с | Пик и обрыв: глубокий удар и хвост, потом тишина. Слышен около 1,4 с, дальше скрипт гасит его за 0,8 с. |

**Промпты:**

- `Hammer`: Single distant blacksmith hammer strike on an anvil inside a huge stone cavern, heavy metallic clang with a long natural reverb tail, 4 seconds, no other sounds.
- `LightOn`: A pure crystal singing-bowl tone slowly swelling with soft glassy shimmer, cold and magical, rising in volume over 3 seconds and holding, 4 seconds total, no melody.
- `HallReveal`: Cinematic reveal swell, 3 seconds: a soft airy whoosh with a wordless choir breath, ending in a deep gentle sub boom below 60 Hz with long hall reverb. Epic scale, not aggressive.
- `Corrupt`: Digital corruption glitch with organic horror, 2.5 seconds: bit-crushed breaking glass, reversed unintelligible whisper clusters, a low distorted growl, ending in a tape-stop slowdown. No clear words.
- `Absorb`: Magical energy absorption, 3 seconds: a rising crystalline glass whistle pulled toward a point, rustling of many tiny cubes, ending with a soft low thump. Clean and bright, leave the midrange free for a voice.
- `SoulTick`: A tiny crystal pluck, a short glassy tink with a soft click at the start, 0.25 seconds, clean, mid-pitched, no reverb tail.
- `BladeFull`: Magical sword reaching full power, 4 seconds: a bright bell-like strike on glass and metal, a deep sub drop below 60 Hz, then a long shimmering resonant tail that fades slowly.
- `Scrape`: A painful metal sword blade scraping and shuddering across a stone floor, high and harsh, 1.2 seconds.
- `Thud`: Deep heavy cinematic impact, 2 seconds: a dull low thud with a sub-bass tail and a short stone shockwave rumble, no metal ring.
- `Materialize`: Magical materialization, 1.2 seconds: a swarm of tiny glass clicks converging into one point, a warm low swell, ending in a soft airy puff.
- `Grip`: A leather glove closing tight on a metal sword hilt with a small creak, one soft low heartbeat-like pulse and a faint blade ping, 1 second.
- `BladeRise`: A sword lifted through the air, 2.5 seconds: metal drawn with a rising ringing tone, rustling cloth, a quiet effort exhale without words.
- `EyesOpen`: Awakening, 2.5 seconds: two slow low heartbeats, a deep soft inhale, two glass tones rising by a fifth, ending with a crystalline chime.
- `Whoosh`: Short soft air whoosh, 1 second, smooth and quiet, no impact, no hiss.
- `TitleSting`: Fantasy game title sting, 3.5 seconds: a glass-and-metal bell strike with a deep resonant boom swelling underneath, ending with a clean shimmering tail.
- `FinalHit`: Massive deep cinematic impact, 2 seconds: a huge low boom with sub-bass and a short dark reverb tail, then clean silence.

## Голос

Голос рассказывает историю, поэтому он главный на миксе: пока звучит реплика, скрипт за 0,4 с приглушает музыку до 60 % и атмосферу до 80 %, а после возвращает за 1 с. Подача, эквалайзер и громкость голоса записаны в `VOICE_BRIEF.md`, здесь только место в ролике.

| Ключ | Когда | Макс. длина | Текст |
| --- | --- | --- | --- |
| `Voice1` | 0:04,3 | 6,5 с | Мир помнит всё… Даже то, что должен был забыть. |
| `Voice2` | 0:11,3 | 6,5 с | Первый Кузнец захотел сохранить каждую душу. Каждое эхо. Каждую боль. |
| `Voice3` | 0:18,3 | 7,5 с | Но память гниёт. Воспоминания становятся чудовищами. А мир… начинает забываться. |
| `Voice4` | 0:26,2 | 6,5 с | Ты — Пробуждённый. У тебя нет имени. Нет прошлого. Есть только пустой клинок… и чужие воспоминания. |
| `Voice5` | 0:33,4 | 3 с | Впитай. Или забудь. |

## Порядок производства

31 файл за один мах не нужен: ролик звучит уже на 14 файлах, дальше каждый уровень добавляет вес. Скрипт ничего не правится, достаточно вписать новые ID.

| Уровень | Файлы | Что даёт |
| --- | --- | --- |
| 1. Ролик звучит (14) | `Voice1`–`Voice5`, `MusicVoid`, `MusicHall`, `MusicRot`, `MusicAwaken`, `MusicFinale`, `Absorb`, `SoulTick`, `BladeFull`, `FinalHit` | История слышна, заряд клинка читается на слух, тишина на 24,9 и обрыв на 37,9 уже работают. |
| 2. Мир живой (+7) | `ForgeFire`, `BladeHum`, `AmbCorridor`, `AmbHall`, `Hammer`, `Thud`, `Scrape` | Пространство, Горнило и клинок звучат из своих мест, у момента «клинок полон» есть вес. |
| 3. Студийный лоск (+10) | `SubHum`, `LightOn`, `HallReveal`, `Corrupt`, `Materialize`, `Grip`, `BladeRise`, `EyesOpen`, `Whoosh`, `TitleSting` | Каждое движение героя и каждая склейка имеют звук. |

Внутри уровня сначала голос, потом `Absorb` и `SoulTick` (их слышно чаще всего, `Absorb` ещё пойдёт в игру), последней музыка.

## Микс, загрузка, проверка

**Стартовая громкость исходников.** Голос −16 LUFS (как в `VOICE_BRIEF.md`), куски музыки около −22 LUFS, атмосфера около −30 LUFS, эффекты по пику −3 дБ, а `FinalHit`, `Thud` и `BladeFull` до −1 дБ. Это старт, окончательно решает слух: дальше подстраивайте `volume` в `CFG.SOUNDS`, файлы переделывать не нужно.

**Формат.** mp3 или ogg. `ForgeFire`, `BladeHum` и `SoulTick` делайте моно, остальное стерео (голос можно моно). В начале файла не должно быть тишины, кроме кусков музыки, где тихий вход заложен в музыку.

**Загрузка.** Creator Hub → Assets → Audio, потом ID в `CFG.SOUNDS`. Звук должен принадлежать аккаунту или группе, которым принадлежит игра, иначе он не заиграет. После загрузки звук может несколько минут проходить проверку.

**Проверка на слух** (в наушниках, ролик запускать кнопкой Play):

1. Голос разборчив поверх музыки, музыка под ним не пропадает.
2. `ForgeFire` растёт к залу и слева/справа переходит вместе с камерой.
3. Тики душ поднимаются по высоте до 24,9.
4. На 24,9 музыка обрывается, на 37,9 обрывается всё кроме `FinalHit`.
5. Ничего не играет после закрытия ролика или нажатия «Пропустить».

Если звук не играет, скрипт молча его пропускает, ошибок в Output не будет. Чаще всего причина одна из трёх: `id = 0`, файл ещё на модерации, звук загружен не тем аккаунтом.

**Что я проверил.** На заглушке Roblox все 31 звук запускаются в нужный момент (журнал запусков совпадает с картой выше), музыка приглушается под голос, гул клинка растёт от 0,8× до 1,4×, после ролика и после пропуска звуки и группы убираются. В самой Studio и на слух я звук не проверял: громкости и тайм-коды подгоняйте после первого прогона.
