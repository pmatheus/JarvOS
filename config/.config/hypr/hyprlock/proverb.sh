#!/usr/bin/env bash
# Pick a Chinese strategic proverb (Sun Tzu, 36 Stratagems, Tao Te Ching).
# Argument: `cn` (Chinese characters) or `en` (English translation).
# Caches the choice for 4 minutes so cn/en pair stays consistent.
set -euo pipefail

which="${1:-cn}"
cache="${XDG_RUNTIME_DIR:-/tmp}/hyprlock-proverb"
ttl=240

proverbs=(
    "兵者，诡道也|all warfare is based on deception"
    "不战而屈人之兵|subdue the enemy without fighting"
    "知己知彼，百战不殆|know yourself and your enemy, never lose"
    "兵贵神速|in war, speed is everything"
    "攻其无备，出其不意|attack the unprepared, appear unexpected"
    "致人而不致于人|bring the enemy to you, never the reverse"
    "兵无常势，水无常形|warfare has no constant form, like water"
    "胜兵先胜而后求战|the victorious win first, then go to battle"
    "瞒天过海|deceive the heavens to cross the sea"
    "围魏救赵|besiege Wei to rescue Zhao"
    "借刀杀人|kill with a borrowed knife"
    "以逸待劳|wait at ease for the exhausted enemy"
    "趁火打劫|loot a burning house"
    "声东击西|make noise east, strike west"
    "无中生有|create something from nothing"
    "暗渡陈仓|march secretly to Chencang"
    "隔岸观火|watch the fire from across the river"
    "笑里藏刀|hide the knife behind a smile"
    "李代桃僵|sacrifice the plum to save the peach"
    "顺手牵羊|seize the goat in passing"
    "打草惊蛇|beat the grass to startle the snake"
    "借尸还魂|borrow a corpse to raise the soul"
    "调虎离山|lure the tiger from the mountain"
    "欲擒故纵|to capture, first release"
    "抛砖引玉|toss a brick to draw jade"
    "擒贼擒王|catch the king to capture the bandits"
    "釜底抽薪|pull firewood from under the pot"
    "浑水摸鱼|catch fish in muddy water"
    "金蝉脱壳|shed the cicada's shell"
    "关门捉贼|close the door to catch the thief"
    "远交近攻|befriend the distant, attack the near"
    "假道伐虢|borrow the road to conquer Guo"
    "偷梁换柱|swap the beams, switch the pillars"
    "指桑骂槐|point at the mulberry, curse the locust"
    "假痴不癫|feign madness, stay sharp"
    "上屋抽梯|climb the roof, then pull the ladder"
    "树上开花|decorate the tree with false flowers"
    "反客为主|turn the guest into the host"
    "空城计|the empty city ruse"
    "反间计|turn their spy against them"
    "苦肉计|wound yourself to win their trust"
    "连环计|forge them into a single chain"
    "走为上|when nothing works, retreat"
    "大道至简|the great way is simple"
    "千里之行，始于足下|a thousand-mile road begins with one step"
    "上善若水|the highest good is like water"
    "知人者智，自知者明|knowing others is wisdom; knowing yourself, enlightenment"
    "柔弱胜刚强|the soft and weak overcome the hard and strong"
)

if [ -f "$cache" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$cache") ))
    if [ "$age" -ge "$ttl" ]; then
        rm -f "$cache"
    fi
fi

if [ ! -f "$cache" ]; then
    i=$((RANDOM % ${#proverbs[@]}))
    printf '%s\n' "${proverbs[$i]}" > "$cache"
fi

IFS='|' read -r cn en < "$cache"
case "$which" in
    cn) printf '%s' "$cn" ;;
    en) printf '%s' "$en" ;;
    *) echo "usage: $0 {cn|en}" >&2; exit 2 ;;
esac
