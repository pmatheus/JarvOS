#!/usr/bin/env python3
"""Render the current JarvOS lockscreen proverb as a Pango-markup interlinear
block (A2 — Calligraphic Interlinear): pinyin / hanzi / arrow / gloss, plus the
English meaning in a muted line below.

The proverb is read from the same runtime cache `proverb.sh` fills, so the
hanzi block and any other proverb label always agree. Emits markup on stdout.

Token spec format: "<hanzi>|<pinyin>|<gloss>" fields joined by ";" (spaces are
allowed inside a gloss).
"""

import os
import subprocess
import sys

HELPERS = os.path.dirname(os.path.abspath(__file__))

# Style (points are Pango units: points * 1024).
# The label's base font_size (set in hyprlock.conf) must be 12 to keep the
# padding spaces on the same cell grid. JetBrains Mono advances 0.6pt/pt and
# the CJK face 1.0pt/pt, so a 28.8pt hanzi is exactly 4 mono cells wide.
SZ_PINYIN = 11264
SZ_HANZI = 29491
SZ_ARROW = 11264
SZ_GLOSS = 12288
SZ_MEAN = 13312
CJK_CELLS = 4

COL_HANZI = "#f5f7fa"
COL_PINYIN = "#8a8f98"
COL_ARROW = "#9aa0a8"
COL_GLOSS = "#c0c8d0"
COL_MEAN = "#d8dce2"
COL_RULE = "#3a3a42"

FONT_MONO = "JetBrainsMono NF Light"
FONT_CJK = "Noto Serif CJK SC"


def T(cn, en, tag, spec):
    tokens = []
    for item in spec.split(";"):
        char, pinyin, gloss = item.split("|")
        tokens.append((char, pinyin, gloss))
    return {"cn": cn, "en": en, "tag": tag, "tokens": tokens}


PROVERBS = [
    T("兵者，诡道也", "All warfare is based on deception.", "Doutrina 01/13",
      "兵|bīng|warfare;者|zhě|is;诡|guǐ|deceit;道|dào|a way;也|yě|indeed"),
    T("不战而屈人之兵", "Subdue the enemy without fighting.", "Doutrina 02/13",
      "不|bù|not;战|zhàn|fighting;而|ér|yet;屈|qū|subdue;人|rén|the;之|zhī|enemy's;兵|bīng|army"),
    T("知己知彼，百战不殆", "Know yourself and your enemy, never lose.", "Doutrina 03/13",
      "知|zhī|know;己|jǐ|yourself;知|zhī|know;彼|bǐ|the foe;百|bǎi|a hundred;战|zhàn|battles;不|bù|no;殆|dài|peril"),
    T("兵贵神速", "In war, speed is everything.", "Doutrina 04/13",
      "兵|bīng|war;贵|guì|prizes;神|shén|divine;速|sù|speed"),
    T("攻其无备，出其不意", "Attack where they are unprepared, appear where least expected.", "Doutrina 05/13",
      "攻|gōng|attack;其|qí|their;无|wú|un-;备|bèi|guarded;出|chū|appear;其|qí|their;不|bù|un-;意|yì|expected"),
    T("致人而不致于人", "Bring the enemy to you, never the reverse.", "Doutrina 06/13",
      "致|zhì|bring;人|rén|the foe;而|ér|and;不|bù|not;致|zhì|be led;于|yú|by;人|rén|the foe"),
    T("兵无常势，水无常形", "Warfare has no constant form, just like water.", "Doutrina 07/13",
      "兵|bīng|war;无|wú|no;常|cháng|fixed;势|shì|form;水|shuǐ|water;无|wú|no;常|cháng|fixed;形|xíng|shape"),
    T("胜兵先胜而后求战", "The victorious win first, then go to battle.", "Doutrina 08/13",
      "胜|shèng|victors;兵|bīng|army;先|xiān|first;胜|shèng|wins;而|ér|then;后|hòu|after;求|qiú|seeks;战|zhàn|battle"),
    T("瞒天过海", "Deceive the heavens to cross the sea.", "Estratagema 01/36",
      "瞒|mán|deceive;天|tiān|heavens;过|guò|cross;海|hǎi|sea"),
    T("围魏救赵", "Besiege Wei to rescue Zhao.", "Estratagema 02/36",
      "围|wéi|besiege;魏|Wèi|Wei;救|jiù|rescue;赵|Zhào|Zhao"),
    T("借刀杀人", "Kill with a borrowed knife.", "Estratagema 03/36",
      "借|jiè|borrow;刀|dāo|a knife;杀|shā|kill;人|rén|the foe"),
    T("以逸待劳", "Wait at ease for the exhausted enemy.", "Estratagema 04/36",
      "以|yǐ|in;逸|yì|ease;待|dài|await;劳|láo|the tired"),
    T("趁火打劫", "Loot a burning house.", "Estratagema 05/36",
      "趁|chèn|seize;火|huǒ|the fire;打|dǎ|raid;劫|jié|plunder"),
    T("声东击西", "Make noise in the east, strike in the west.", "Estratagema 06/36",
      "声|shēng|noise;东|dōng|east;击|jī|strike;西|xī|west"),
    T("无中生有", "Create something out of nothing.", "Estratagema 07/36",
      "无|wú|nothing;中|zhōng|from;生|shēng|create;有|yǒu|something"),
    T("暗渡陈仓", "March secretly to Chencang.", "Estratagema 08/36",
      "暗|àn|secretly;渡|dù|cross;陈|Chén|Chen;仓|cāng|Cang"),
    T("隔岸观火", "Watch the fire from across the river.", "Estratagema 09/36",
      "隔|gé|across;岸|àn|the bank;观|guān|watch;火|huǒ|the fire"),
    T("笑里藏刀", "Hide the dagger behind a smile.", "Estratagema 10/36",
      "笑|xiào|smile;里|lǐ|within;藏|cáng|hide;刀|dāo|a blade"),
    T("李代桃僵", "Sacrifice the plum tree to save the peach tree.", "Estratagema 11/36",
      "李|lǐ|plum;代|dài|replaces;桃|táo|peach;僵|jiāng|withers"),
    T("顺手牵羊", "Seize the goat in passing.", "Estratagema 12/36",
      "顺|shùn|along;手|shǒu|the hand;牵|qiān|leads;羊|yáng|a goat"),
    T("打草惊蛇", "Beat the grass to startle the snake.", "Estratagema 13/36",
      "打|dǎ|beat;草|cǎo|the grass;惊|jīng|startle;蛇|shé|the snake"),
    T("借尸还魂", "Borrow a corpse to resurrect the soul.", "Estratagema 14/36",
      "借|jiè|borrow;尸|shī|a corpse;还|huán|restore;魂|hún|the soul"),
    T("调虎离山", "Lure the tiger away from the mountain.", "Estratagema 15/36",
      "调|diào|lure;虎|hǔ|the tiger;离|lí|off;山|shān|the mount"),
    T("欲擒故纵", "To catch something, first let it go.", "Estratagema 16/36",
      "欲|yù|to catch;擒|qín|first;故|gù|let;纵|zòng|it go"),
    T("抛砖引玉", "Cast a brick to attract jade.", "Estratagema 17/36",
      "抛|pāo|cast;砖|zhuān|a brick;引|yǐn|to draw;玉|yù|jade"),
    T("擒贼擒王", "Capture the ringleader to dissolve the bandits.", "Estratagema 18/36",
      "擒|qín|catch;贼|zéi|the thief;擒|qín|catch;王|wáng|the king"),
    T("釜底抽薪", "Pull firewood from beneath the cauldron.", "Estratagema 19/36",
      "釜|fǔ|cauldron;底|dǐ|below;抽|chōu|pull;薪|xīn|the wood"),
    T("浑水摸鱼", "Catch fish in troubled waters.", "Estratagema 20/36",
      "浑|hún|muddy;水|shuǐ|waters;摸|mō|grab;鱼|yú|the fish"),
    T("金蝉脱壳", "Shed the cicada's golden shell.", "Estratagema 21/36",
      "金|jīn|golden;蝉|chán|cicada;脱|tuō|sheds;壳|qiào|its shell"),
    T("关门捉贼", "Shut the door to catch the thief.", "Estratagema 22/36",
      "关|guān|shut;门|mén|the door;捉|zhuō|to catch;贼|zéi|the thief"),
    T("远交近攻", "Befriend the distant, attack the near.", "Estratagema 23/36",
      "远|yuǎn|distant;交|jiāo|befriend;近|jìn|the near;攻|gōng|attack"),
    T("假道伐虢", "Borrow a path to conquer Guo.", "Estratagema 24/36",
      "假|jiǎ|borrow;道|dào|a path;伐|fá|conquer;虢|Guó|Guo"),
    T("偷梁换柱", "Steal the beams and swap the pillars.", "Estratagema 25/36",
      "偷|tōu|steal;梁|liáng|beams;换|huàn|swap;柱|zhù|pillars"),
    T("指桑骂槐", "Point at the mulberry, revile the locust tree.", "Estratagema 26/36",
      "指|zhǐ|point;桑|sāng|mulberry;骂|mà|scold;槐|huái|locust"),
    T("假痴不癫", "Feign ignorance without going mad.", "Estratagema 27/36",
      "假|jiǎ|feign;痴|chī|fool;不|bù|not;癫|diān|mad"),
    T("上屋抽梯", "Lead them onto the roof, then remove the ladder.", "Estratagema 28/36",
      "上|shàng|onto;屋|wū|the roof;抽|chōu|pull;梯|tī|the ladder"),
    T("树上开花", "Make artificial flowers bloom upon the tree.", "Estratagema 29/36",
      "树|shù|tree;上|shàng|upon;开|kāi|bloom;花|huā|false flowers"),
    T("反客为主", "Turn the guest into the host.", "Estratagema 30/36",
      "反|fǎn|turn;客|kè|guest;为|wéi|into;主|zhǔ|host"),
    T("空城计", "The empty city ruse.", "Estratagema 31/36",
      "空|kōng|empty;城|chéng|city;计|jì|ruse"),
    T("反间计", "Turn their spy against them.", "Estratagema 32/36",
      "反|fǎn|counter;间|jiàn|spy;计|jì|ruse"),
    T("苦肉计", "Wound yourself to win their trust.", "Estratagema 33/36",
      "苦|kǔ|bitter;肉|ròu|flesh;计|jì|ruse"),
    T("连环计", "Forge them into a single chain.", "Estratagema 34/36",
      "连|lián|chained;环|huán|links;计|jì|ruse"),
    T("走为上", "When nothing works, retreat.", "Estratagema 35/36",
      "走|zǒu|retreat;为|wéi|is;上|shàng|best"),
    T("大道至简", "The great way is simple.", "Doutrina 09/13",
      "大|dà|great;道|dào|way;至|zhì|is;简|jiǎn|simple"),
    T("千里之行，始于足下", "A thousand-mile road begins with one step.", "Doutrina 10/13",
      "千|qiān|a thousand;里|lǐ|miles;之|zhī|'s;行|xíng|road;始|shǐ|begins;于|yú|with;足|zú|the foot;下|xià|step"),
    T("上善若水", "The highest good is like water.", "Doutrina 11/13",
      "上|shàng|highest;善|shàn|good;若|ruò|is like;水|shuǐ|water"),
    T("知人者智，自知者明", "Knowing others is wisdom; knowing yourself, enlightenment.", "Doutrina 12/13",
      "知|zhī|know;人|rén|others;者|zhě|is;智|zhì|wisdom;自|zì|know;知|zhī|yourself;者|zhě|is;明|míng|clarity"),
    T("柔弱胜刚强", "The soft and weak overcome the hard and strong.", "Doutrina 13/13",
      "柔|róu|soft;弱|ruò|supple;胜|shèng|beats;刚|gāng|the hard;强|qiáng|the strong"),
]

BY_CN = {p["cn"]: p for p in PROVERBS}


def dwidth(text):
    """Display width in terminal cells (CJK counts as CJK_CELLS)."""
    return sum(CJK_CELLS if ord(c) > 0x2E80 else 1 for c in text)


def line(tokens, text_of, style_of, field):
    parts = []
    for tok in tokens:
        text = text_of(tok)
        pad = max(0, field - dwidth(text))
        left = pad // 2
        right = pad - left
        parts.append(" " * left + style_of(text) + " " * right)
    return "".join(parts)


def render(entry):
    tokens = entry["tokens"]
    field = max(8, max(max(dwidth(p), dwidth(h), dwidth(g)) for h, p, g in tokens) + 4)
    if field % 2:
        field += 1

    pinyin = line(
        tokens, lambda t: t[1],
        lambda s: f'<span font_family="{FONT_MONO}" font_style="italic" size="{SZ_PINYIN}" foreground="{COL_PINYIN}" underline="single" underline_color="{COL_RULE}">{s}</span>',
        field)
    hanzi = line(
        tokens, lambda t: t[0],
        lambda s: f'<span font_family="{FONT_CJK}" size="{SZ_HANZI}" foreground="{COL_HANZI}">{s}</span>',
        field)
    arrow = line(
        tokens, lambda t: "\u2193",
        lambda s: f'<span font_family="{FONT_MONO}" size="{SZ_ARROW}" foreground="{COL_ARROW}">{s}</span>',
        field)
    gloss = line(
        tokens, lambda t: t[2],
        lambda s: f'<span font_family="{FONT_MONO}" size="{SZ_GLOSS}" foreground="{COL_GLOSS}" underline="single" underline_color="{COL_RULE}">{s}</span>',
        field)

    lines = [
        pinyin,
        hanzi,
        arrow,
        gloss,
        f'<span font_family="{FONT_CJK}" font_style="italic" size="{SZ_MEAN}" foreground="{COL_MEAN}">\u201c{entry["en"]}\u201d</span>',
    ]
    return "\n".join(lines)


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "block"
    proverb = os.path.join(HELPERS, "proverb.sh")
    try:
        cn = subprocess.check_output([proverb, "cn"], text=True).strip()
        en = subprocess.check_output([proverb, "en"], text=True).strip()
    except Exception:
        cn, en = "", ""

    if not cn:
        print("")
        return 0

    entry = BY_CN.get(cn)
    if entry is None:
        # Unknown proverb: degrade gracefully to the plain pair.
        print(cn if which != "en" else en)
        return 0

    if which == "cn":
        print(entry["cn"])
    elif which == "en":
        print(entry["en"])
    elif which == "tag":
        print(entry["tag"])
    elif which == "pinyin":
        print(" ".join(p for _, p, _ in entry["tokens"]))
    else:
        print(render(entry))
    return 0


if __name__ == "__main__":
    sys.exit(main())
