extends Node
## GameState — autoload com o progresso do jogador (save/load em user://save.cfg).
## Guarda: estrelas, moedas, fase desbloqueada, fases vencidas, tarefas da
## reforma, baús por área, intros vistas, e a config das 300 fases
## (metas + movimentos calibrados via bot).
##
## Fases 1-10: config original mantida intacta (recalibrada em 2026-10-17).
## Fases 11-300: geradas por tests/gen_levels.gd (seed 424242) e calibradas
## com o bot (K=30 jogos sem limite; movimentos = percentil(alvo) + 1).
## Curva de dificuldade por faixa (alvo de win-rate do bot):
##   11-30: 97% | 31-60: 94% | 61-120: 91% (respiros 97%) |
##   121-200: 88% (respiros 96%) | 201-300: 86% (respiros 95%, nunca 3 <88% seguidas).

const TYPE_IDS := {"coco": 0, "guarda_sol": 1, "chinelo": 2, "peixe": 3, "concha": 4}
const TYPE_NAMES := {0: "cocos", 1: "guarda-sóis", 2: "chinelos", 3: "peixes", 4: "conchas"}

const MAX_LEVEL := 300

## 300 entradas {"goals": {nome_tipo: alvo}, "moves": n}. Fases 1-10 idênticas
## às originais; 11-300 geradas por tests/gen_levels.gd.
const LEVELS: Array = [
	{"goals": {"coco": 10}, "moves": 9},                          # 1 - bot 99%
	{"goals": {"concha": 12}, "moves": 10},                       # 2 - bot 100%
	{"goals": {"coco": 10, "concha": 10}, "moves": 10},           # 3 - bot 99%
	{"goals": {"peixe": 15}, "moves": 9},                         # 4 - bot 95%
	{"goals": {"coco": 12, "chinelo": 12}, "moves": 10},          # 5 - bot 96%
	{"goals": {"concha": 15, "guarda_sol": 10}, "moves": 10},     # 6 - bot 96%
	{"goals": {"coco": 20}, "moves": 11},                         # 7 - bot 95%
	{"goals": {"peixe": 15, "chinelo": 15}, "moves": 10},          # 8 - bot 92%
	{"goals": {"concha": 20, "coco": 10}, "moves": 12},            # 9 - bot 94%
	{"goals": {"coco": 20, "concha": 20}, "moves": 11},            # 10 - bot 84%
	{"goals": {"guarda_sol": 16}, "moves": 15},  # 11 - alvo bot 97%
	{"goals": {"concha": 16}, "moves": 11},  # 12 - alvo bot 97%
	{"goals": {"peixe": 17}, "moves": 14},  # 13 - alvo bot 97%
	{"goals": {"guarda_sol": 8, "chinelo": 8}, "moves": 11},  # 14 - alvo bot 97%
	{"goals": {"coco": 16}, "moves": 11},  # 15 - alvo bot 97%
	{"goals": {"guarda_sol": 8, "chinelo": 8}, "moves": 11},  # 16 - alvo bot 97%
	{"goals": {"guarda_sol": 8, "peixe": 8}, "moves": 10},  # 17 - alvo bot 97%
	{"goals": {"coco": 8, "chinelo": 8}, "moves": 9},  # 18 - alvo bot 97%
	{"goals": {"peixe": 8, "concha": 8}, "moves": 11},  # 19 - alvo bot 97%
	{"goals": {"coco": 8, "guarda_sol": 8}, "moves": 11},  # 20 - alvo bot 97%
	{"goals": {"concha": 16}, "moves": 11},  # 21 - alvo bot 97%
	{"goals": {"guarda_sol": 8, "concha": 8}, "moves": 8},  # 22 - alvo bot 97%
	{"goals": {"coco": 8, "peixe": 8}, "moves": 9},  # 23 - alvo bot 97%
	{"goals": {"chinelo": 17}, "moves": 15},  # 24 - alvo bot 97%
	{"goals": {"guarda_sol": 8, "peixe": 8}, "moves": 10},  # 25 - alvo bot 97%
	{"goals": {"peixe": 18}, "moves": 14},  # 26 - alvo bot 97%
	{"goals": {"guarda_sol": 8, "peixe": 8}, "moves": 10},  # 27 - alvo bot 97%
	{"goals": {"guarda_sol": 16}, "moves": 15},  # 28 - alvo bot 97%
	{"goals": {"peixe": 10}, "moves": 13},  # 29 - alvo bot 97%
	{"goals": {"coco": 8, "chinelo": 8}, "moves": 9},  # 30 - alvo bot 97%
	{"goals": {"chinelo": 18}, "moves": 13},  # 31 - alvo bot 94%
	{"goals": {"coco": 11, "chinelo": 15}, "moves": 11},  # 32 - alvo bot 94%
	{"goals": {"guarda_sol": 23}, "moves": 14},  # 33 - alvo bot 94%
	{"goals": {"guarda_sol": 10, "chinelo": 15}, "moves": 11},  # 34 - alvo bot 94%
	{"goals": {"coco": 12, "chinelo": 11}, "moves": 10},  # 35 - alvo bot 94%
	{"goals": {"coco": 14, "guarda_sol": 11}, "moves": 12},  # 36 - alvo bot 94%
	{"goals": {"guarda_sol": 12, "peixe": 10}, "moves": 10},  # 37 - alvo bot 94%
	{"goals": {"peixe": 17}, "moves": 13},  # 38 - alvo bot 94%
	{"goals": {"chinelo": 13, "peixe": 11}, "moves": 10},  # 39 - alvo bot 94%
	{"goals": {"coco": 15}, "moves": 10},  # 40 - alvo bot 94%
	{"goals": {"peixe": 25}, "moves": 15},  # 41 - alvo bot 94%
	{"goals": {"chinelo": 11, "concha": 11}, "moves": 8},  # 42 - alvo bot 94%
	{"goals": {"guarda_sol": 11, "peixe": 15}, "moves": 12},  # 43 - alvo bot 94%
	{"goals": {"coco": 24}, "moves": 15},  # 44 - alvo bot 94%
	{"goals": {"guarda_sol": 18}, "moves": 12},  # 45 - alvo bot 94%
	{"goals": {"coco": 10, "guarda_sol": 14}, "moves": 11},  # 46 - alvo bot 94%
	{"goals": {"guarda_sol": 16}, "moves": 11},  # 47 - alvo bot 94%
	{"goals": {"peixe": 12, "concha": 10}, "moves": 8},  # 48 - alvo bot 94%
	{"goals": {"guarda_sol": 16}, "moves": 11},  # 49 - alvo bot 94%
	{"goals": {"coco": 21}, "moves": 13},  # 50 - alvo bot 94%
	{"goals": {"chinelo": 12, "peixe": 10}, "moves": 10},  # 51 - alvo bot 94%
	{"goals": {"peixe": 13, "concha": 12}, "moves": 9},  # 52 - alvo bot 94%
	{"goals": {"coco": 21}, "moves": 13},  # 53 - alvo bot 94%
	{"goals": {"guarda_sol": 13, "peixe": 10}, "moves": 11},  # 54 - alvo bot 94%
	{"goals": {"guarda_sol": 12, "peixe": 10}, "moves": 10},  # 55 - alvo bot 94%
	{"goals": {"chinelo": 12, "peixe": 13}, "moves": 10},  # 56 - alvo bot 94%
	{"goals": {"concha": 25}, "moves": 14},  # 57 - alvo bot 94%
	{"goals": {"coco": 10, "concha": 13}, "moves": 11},  # 58 - alvo bot 94%
	{"goals": {"chinelo": 13, "peixe": 12}, "moves": 10},  # 59 - alvo bot 94%
	{"goals": {"coco": 15, "concha": 10}, "moves": 12},  # 60 - alvo bot 94%
	{"goals": {"coco": 12, "peixe": 13}, "moves": 10},  # 61 - alvo bot 91%
	{"goals": {"chinelo": 14, "concha": 20}, "moves": 11},  # 62 - alvo bot 91%
	{"goals": {"concha": 24}, "moves": 12},  # 63 - alvo bot 91%
	{"goals": {"peixe": 29}, "moves": 16},  # 64 - alvo bot 91%
	{"goals": {"coco": 21}, "moves": 12},  # 65 - alvo bot 91%
	{"goals": {"guarda_sol": 15}, "moves": 15},  # 66 - alvo bot 97% respiro
	{"goals": {"chinelo": 15, "peixe": 18}, "moves": 12},  # 67 - alvo bot 91%
	{"goals": {"peixe": 13, "concha": 15}, "moves": 10},  # 68 - alvo bot 91%
	{"goals": {"chinelo": 19, "peixe": 12}, "moves": 14},  # 69 - alvo bot 91%
	{"goals": {"coco": 18, "chinelo": 14}, "moves": 12},  # 70 - alvo bot 91%
	{"goals": {"chinelo": 15, "peixe": 13}, "moves": 11},  # 71 - alvo bot 91%
	{"goals": {"chinelo": 12, "concha": 20}, "moves": 11},  # 72 - alvo bot 91%
	{"goals": {"chinelo": 26}, "moves": 15},  # 73 - alvo bot 91%
	{"goals": {"guarda_sol": 30}, "moves": 16},  # 74 - alvo bot 91%
	{"goals": {"coco": 19, "peixe": 14}, "moves": 12},  # 75 - alvo bot 91%
	{"goals": {"guarda_sol": 15}, "moves": 15},  # 76 - alvo bot 97% respiro
	{"goals": {"chinelo": 15, "concha": 13}, "moves": 9},  # 77 - alvo bot 91%
	{"goals": {"coco": 30}, "moves": 16},  # 78 - alvo bot 91%
	{"goals": {"concha": 30}, "moves": 15},  # 79 - alvo bot 91%
	{"goals": {"coco": 18, "chinelo": 15}, "moves": 12},  # 80 - alvo bot 91%
	{"goals": {"peixe": 20}, "moves": 13},  # 81 - alvo bot 91%
	{"goals": {"coco": 14, "concha": 15}, "moves": 12},  # 82 - alvo bot 91%
	{"goals": {"coco": 18, "peixe": 13}, "moves": 12},  # 83 - alvo bot 91%
	{"goals": {"coco": 13, "concha": 12}, "moves": 10},  # 84 - alvo bot 91%
	{"goals": {"coco": 25}, "moves": 15},  # 85 - alvo bot 91%
	{"goals": {"peixe": 18}, "moves": 14},  # 86 - alvo bot 97% respiro
	{"goals": {"coco": 12, "peixe": 20}, "moves": 11},  # 87 - alvo bot 91%
	{"goals": {"coco": 21}, "moves": 12},  # 88 - alvo bot 91%
	{"goals": {"concha": 27}, "moves": 13},  # 89 - alvo bot 91%
	{"goals": {"coco": 17, "chinelo": 13}, "moves": 12},  # 90 - alvo bot 91%
	{"goals": {"coco": 18, "peixe": 14}, "moves": 12},  # 91 - alvo bot 91%
	{"goals": {"coco": 19, "guarda_sol": 13}, "moves": 12},  # 92 - alvo bot 91%
	{"goals": {"peixe": 30}, "moves": 16},  # 93 - alvo bot 91%
	{"goals": {"chinelo": 13, "concha": 19}, "moves": 11},  # 94 - alvo bot 91%
	{"goals": {"coco": 23}, "moves": 13},  # 95 - alvo bot 91%
	{"goals": {"chinelo": 18}, "moves": 15},  # 96 - alvo bot 97% respiro
	{"goals": {"coco": 20, "peixe": 14}, "moves": 12},  # 97 - alvo bot 91%
	{"goals": {"coco": 12, "peixe": 15}, "moves": 10},  # 98 - alvo bot 91%
	{"goals": {"coco": 13, "guarda_sol": 18}, "moves": 11},  # 99 - alvo bot 91%
	{"goals": {"peixe": 30}, "moves": 16},  # 100 - alvo bot 91%
	{"goals": {"coco": 12, "concha": 12}, "moves": 10},  # 101 - alvo bot 91%
	{"goals": {"coco": 19, "peixe": 15}, "moves": 13},  # 102 - alvo bot 91%
	{"goals": {"peixe": 13, "concha": 16}, "moves": 10},  # 103 - alvo bot 91%
	{"goals": {"coco": 14, "concha": 16}, "moves": 12},  # 104 - alvo bot 91%
	{"goals": {"coco": 20, "guarda_sol": 15}, "moves": 12},  # 105 - alvo bot 91%
	{"goals": {"guarda_sol": 15}, "moves": 15},  # 106 - alvo bot 97% respiro
	{"goals": {"chinelo": 15, "peixe": 17}, "moves": 12},  # 107 - alvo bot 91%
	{"goals": {"concha": 25}, "moves": 13},  # 108 - alvo bot 91%
	{"goals": {"chinelo": 29}, "moves": 15},  # 109 - alvo bot 91%
	{"goals": {"coco": 12, "guarda_sol": 13}, "moves": 11},  # 110 - alvo bot 91%
	{"goals": {"coco": 25}, "moves": 15},  # 111 - alvo bot 91%
	{"goals": {"guarda_sol": 20, "concha": 12}, "moves": 12},  # 112 - alvo bot 91%
	{"goals": {"coco": 12, "chinelo": 17}, "moves": 12},  # 113 - alvo bot 91%
	{"goals": {"concha": 29}, "moves": 14},  # 114 - alvo bot 91%
	{"goals": {"coco": 12, "concha": 17}, "moves": 12},  # 115 - alvo bot 91%
	{"goals": {"concha": 19}, "moves": 13},  # 116 - alvo bot 97% respiro
	{"goals": {"coco": 18, "concha": 14}, "moves": 12},  # 117 - alvo bot 91%
	{"goals": {"peixe": 27}, "moves": 15},  # 118 - alvo bot 91%
	{"goals": {"chinelo": 14, "peixe": 13}, "moves": 10},  # 119 - alvo bot 91%
	{"goals": {"coco": 20}, "moves": 12},  # 120 - alvo bot 91%
	{"goals": {"concha": 34}, "moves": 16},  # 121 - alvo bot 88%
	{"goals": {"chinelo": 18, "concha": 24}, "moves": 13},  # 122 - alvo bot 88%
	{"goals": {"coco": 16, "chinelo": 21}, "moves": 13},  # 123 - alvo bot 88%
	{"goals": {"peixe": 25}, "moves": 14},  # 124 - alvo bot 88%
	{"goals": {"chinelo": 20}, "moves": 14},  # 125 - alvo bot 96% respiro
	{"goals": {"coco": 20, "chinelo": 15}, "moves": 12},  # 126 - alvo bot 88%
	{"goals": {"peixe": 26}, "moves": 14},  # 127 - alvo bot 88%
	{"goals": {"peixe": 17, "concha": 16}, "moves": 10},  # 128 - alvo bot 88%
	{"goals": {"coco": 22, "chinelo": 18}, "moves": 13},  # 129 - alvo bot 88%
	{"goals": {"chinelo": 20, "concha": 18}, "moves": 11},  # 130 - alvo bot 88%
	{"goals": {"chinelo": 25}, "moves": 15},  # 131 - alvo bot 88%
	{"goals": {"guarda_sol": 19, "concha": 23}, "moves": 13},  # 132 - alvo bot 88%
	{"goals": {"concha": 25}, "moves": 14},  # 133 - alvo bot 96% respiro
	{"goals": {"peixe": 29}, "moves": 15},  # 134 - alvo bot 88%
	{"goals": {"chinelo": 17, "peixe": 16}, "moves": 12},  # 135 - alvo bot 88%
	{"goals": {"concha": 35}, "moves": 17},  # 136 - alvo bot 88%
	{"goals": {"chinelo": 25}, "moves": 15},  # 137 - alvo bot 88%
	{"goals": {"guarda_sol": 18, "peixe": 15}, "moves": 11},  # 138 - alvo bot 88%
	{"goals": {"guarda_sol": 29}, "moves": 15},  # 139 - alvo bot 88%
	{"goals": {"peixe": 29}, "moves": 15},  # 140 - alvo bot 88%
	{"goals": {"concha": 25}, "moves": 14},  # 141 - alvo bot 96% respiro
	{"goals": {"coco": 16, "chinelo": 15}, "moves": 11},  # 142 - alvo bot 88%
	{"goals": {"peixe": 24, "concha": 16}, "moves": 12},  # 143 - alvo bot 88%
	{"goals": {"chinelo": 28}, "moves": 15},  # 144 - alvo bot 88%
	{"goals": {"coco": 20, "concha": 20}, "moves": 14},  # 145 - alvo bot 88%
	{"goals": {"concha": 25}, "moves": 12},  # 146 - alvo bot 88%
	{"goals": {"chinelo": 32}, "moves": 16},  # 147 - alvo bot 88%
	{"goals": {"guarda_sol": 15, "peixe": 19}, "moves": 12},  # 148 - alvo bot 88%
	{"goals": {"chinelo": 21}, "moves": 14},  # 149 - alvo bot 96% respiro
	{"goals": {"peixe": 21, "concha": 16}, "moves": 11},  # 150 - alvo bot 88%
	{"goals": {"concha": 25}, "moves": 12},  # 151 - alvo bot 88%
	{"goals": {"chinelo": 15, "peixe": 20}, "moves": 13},  # 152 - alvo bot 88%
	{"goals": {"guarda_sol": 29}, "moves": 15},  # 153 - alvo bot 88%
	{"goals": {"coco": 15, "guarda_sol": 20}, "moves": 11},  # 154 - alvo bot 88%
	{"goals": {"chinelo": 21, "concha": 18}, "moves": 12},  # 155 - alvo bot 88%
	{"goals": {"guarda_sol": 31}, "moves": 16},  # 156 - alvo bot 88%
	{"goals": {"peixe": 20}, "moves": 14},  # 157 - alvo bot 96% respiro
	{"goals": {"concha": 30}, "moves": 14},  # 158 - alvo bot 88%
	{"goals": {"chinelo": 29}, "moves": 15},  # 159 - alvo bot 88%
	{"goals": {"guarda_sol": 15, "concha": 25}, "moves": 14},  # 160 - alvo bot 88%
	{"goals": {"guarda_sol": 25}, "moves": 14},  # 161 - alvo bot 88%
	{"goals": {"concha": 27}, "moves": 13},  # 162 - alvo bot 88%
	{"goals": {"guarda_sol": 15, "concha": 18}, "moves": 11},  # 163 - alvo bot 88%
	{"goals": {"concha": 35}, "moves": 17},  # 164 - alvo bot 88%
	{"goals": {"peixe": 23}, "moves": 15},  # 165 - alvo bot 96% respiro
	{"goals": {"chinelo": 21, "peixe": 15}, "moves": 13},  # 166 - alvo bot 88%
	{"goals": {"chinelo": 15, "concha": 18}, "moves": 10},  # 167 - alvo bot 88%
	{"goals": {"coco": 16, "peixe": 24}, "moves": 12},  # 168 - alvo bot 88%
	{"goals": {"concha": 25}, "moves": 12},  # 169 - alvo bot 88%
	{"goals": {"coco": 19, "guarda_sol": 21}, "moves": 12},  # 170 - alvo bot 88%
	{"goals": {"coco": 28}, "moves": 15},  # 171 - alvo bot 88%
	{"goals": {"concha": 29}, "moves": 14},  # 172 - alvo bot 88%
	{"goals": {"peixe": 23}, "moves": 15},  # 173 - alvo bot 96% respiro
	{"goals": {"coco": 19, "chinelo": 23}, "moves": 14},  # 174 - alvo bot 88%
	{"goals": {"coco": 19, "peixe": 16}, "moves": 12},  # 175 - alvo bot 88%
	{"goals": {"chinelo": 32}, "moves": 16},  # 176 - alvo bot 88%
	{"goals": {"peixe": 26}, "moves": 14},  # 177 - alvo bot 88%
	{"goals": {"coco": 25}, "moves": 15},  # 178 - alvo bot 88%
	{"goals": {"peixe": 24, "concha": 15}, "moves": 12},  # 179 - alvo bot 88%
	{"goals": {"coco": 17, "peixe": 22}, "moves": 11},  # 180 - alvo bot 88%
	{"goals": {"peixe": 21}, "moves": 14},  # 181 - alvo bot 96% respiro
	{"goals": {"coco": 25, "chinelo": 19}, "moves": 13},  # 182 - alvo bot 88%
	{"goals": {"coco": 24, "peixe": 19}, "moves": 14},  # 183 - alvo bot 88%
	{"goals": {"guarda_sol": 22, "concha": 20}, "moves": 13},  # 184 - alvo bot 88%
	{"goals": {"guarda_sol": 20, "chinelo": 20}, "moves": 12},  # 185 - alvo bot 88%
	{"goals": {"chinelo": 34}, "moves": 16},  # 186 - alvo bot 88%
	{"goals": {"guarda_sol": 21, "chinelo": 20}, "moves": 12},  # 187 - alvo bot 88%
	{"goals": {"guarda_sol": 16, "concha": 16}, "moves": 11},  # 188 - alvo bot 88%
	{"goals": {"chinelo": 23}, "moves": 15},  # 189 - alvo bot 96% respiro
	{"goals": {"peixe": 24, "concha": 15}, "moves": 12},  # 190 - alvo bot 88%
	{"goals": {"concha": 35}, "moves": 17},  # 191 - alvo bot 88%
	{"goals": {"peixe": 16, "concha": 21}, "moves": 12},  # 192 - alvo bot 88%
	{"goals": {"guarda_sol": 25}, "moves": 14},  # 193 - alvo bot 88%
	{"goals": {"coco": 15, "peixe": 24}, "moves": 12},  # 194 - alvo bot 88%
	{"goals": {"chinelo": 32}, "moves": 16},  # 195 - alvo bot 88%
	{"goals": {"coco": 20, "guarda_sol": 15}, "moves": 12},  # 196 - alvo bot 88%
	{"goals": {"guarda_sol": 24}, "moves": 16},  # 197 - alvo bot 96% respiro
	{"goals": {"concha": 27}, "moves": 13},  # 198 - alvo bot 88%
	{"goals": {"guarda_sol": 29}, "moves": 15},  # 199 - alvo bot 88%
	{"goals": {"coco": 24, "guarda_sol": 16}, "moves": 13},  # 200 - alvo bot 88%
	{"goals": {"chinelo": 22, "concha": 25}, "moves": 13},  # 201 - alvo bot 86%
	{"goals": {"chinelo": 22, "concha": 23}, "moves": 13},  # 202 - alvo bot 86%
	{"goals": {"peixe": 28}, "moves": 16},  # 203 - alvo bot 95% respiro
	{"goals": {"chinelo": 31}, "moves": 15},  # 204 - alvo bot 86%
	{"goals": {"guarda_sol": 34}, "moves": 16},  # 205 - alvo bot 86%
	{"goals": {"coco": 25}, "moves": 16},  # 206 - alvo bot 95% respiro
	{"goals": {"guarda_sol": 20, "concha": 28}, "moves": 14},  # 207 - alvo bot 86%
	{"goals": {"coco": 39}, "moves": 19},  # 208 - alvo bot 86%
	{"goals": {"chinelo": 26}, "moves": 17},  # 209 - alvo bot 95% respiro
	{"goals": {"chinelo": 30, "concha": 22}, "moves": 15},  # 210 - alvo bot 86%
	{"goals": {"coco": 21, "guarda_sol": 21}, "moves": 12},  # 211 - alvo bot 86%
	{"goals": {"coco": 30}, "moves": 17},  # 212 - alvo bot 95% respiro
	{"goals": {"guarda_sol": 24, "peixe": 28}, "moves": 16},  # 213 - alvo bot 86%
	{"goals": {"coco": 35}, "moves": 16},  # 214 - alvo bot 86%
	{"goals": {"guarda_sol": 27}, "moves": 17},  # 215 - alvo bot 95% respiro
	{"goals": {"peixe": 40}, "moves": 19},  # 216 - alvo bot 86%
	{"goals": {"guarda_sol": 36}, "moves": 17},  # 217 - alvo bot 86%
	{"goals": {"chinelo": 25}, "moves": 17},  # 218 - alvo bot 95% respiro
	{"goals": {"coco": 27, "peixe": 22}, "moves": 15},  # 219 - alvo bot 86%
	{"goals": {"chinelo": 37}, "moves": 17},  # 220 - alvo bot 86%
	{"goals": {"coco": 28}, "moves": 16},  # 221 - alvo bot 95% respiro
	{"goals": {"guarda_sol": 32}, "moves": 16},  # 222 - alvo bot 86%
	{"goals": {"coco": 21, "peixe": 24}, "moves": 12},  # 223 - alvo bot 86%
	{"goals": {"guarda_sol": 28}, "moves": 17},  # 224 - alvo bot 95% respiro
	{"goals": {"guarda_sol": 22, "peixe": 27}, "moves": 14},  # 225 - alvo bot 86%
	{"goals": {"peixe": 29, "concha": 24}, "moves": 14},  # 226 - alvo bot 86%
	{"goals": {"peixe": 30}, "moves": 17},  # 227 - alvo bot 95% respiro
	{"goals": {"coco": 28, "chinelo": 22}, "moves": 15},  # 228 - alvo bot 86%
	{"goals": {"coco": 25, "guarda_sol": 28}, "moves": 15},  # 229 - alvo bot 86%
	{"goals": {"concha": 26}, "moves": 14},  # 230 - alvo bot 95% respiro
	{"goals": {"guarda_sol": 32}, "moves": 16},  # 231 - alvo bot 86%
	{"goals": {"peixe": 38}, "moves": 19},  # 232 - alvo bot 86%
	{"goals": {"guarda_sol": 28}, "moves": 17},  # 233 - alvo bot 95% respiro
	{"goals": {"coco": 24, "chinelo": 20}, "moves": 13},  # 234 - alvo bot 86%
	{"goals": {"peixe": 28, "concha": 23}, "moves": 13},  # 235 - alvo bot 86%
	{"goals": {"chinelo": 26}, "moves": 17},  # 236 - alvo bot 95% respiro
	{"goals": {"chinelo": 28, "concha": 22}, "moves": 15},  # 237 - alvo bot 86%
	{"goals": {"coco": 27, "chinelo": 25}, "moves": 15},  # 238 - alvo bot 86%
	{"goals": {"concha": 25}, "moves": 14},  # 239 - alvo bot 95% respiro
	{"goals": {"chinelo": 26, "peixe": 23}, "moves": 15},  # 240 - alvo bot 86%
	{"goals": {"chinelo": 34}, "moves": 16},  # 241 - alvo bot 86%
	{"goals": {"concha": 28}, "moves": 15},  # 242 - alvo bot 95% respiro
	{"goals": {"coco": 23, "chinelo": 20}, "moves": 13},  # 243 - alvo bot 86%
	{"goals": {"peixe": 39}, "moves": 19},  # 244 - alvo bot 86%
	{"goals": {"concha": 29}, "moves": 15},  # 245 - alvo bot 95% respiro
	{"goals": {"guarda_sol": 29, "peixe": 20}, "moves": 16},  # 246 - alvo bot 86%
	{"goals": {"coco": 39}, "moves": 19},  # 247 - alvo bot 86%
	{"goals": {"concha": 26}, "moves": 14},  # 248 - alvo bot 95% respiro
	{"goals": {"guarda_sol": 20, "peixe": 26}, "moves": 14},  # 249 - alvo bot 86%
	{"goals": {"peixe": 21, "concha": 23}, "moves": 13},  # 250 - alvo bot 86%
	{"goals": {"peixe": 29}, "moves": 17},  # 251 - alvo bot 95% respiro
	{"goals": {"coco": 30}, "moves": 15},  # 252 - alvo bot 86%
	{"goals": {"peixe": 22, "concha": 23}, "moves": 13},  # 253 - alvo bot 86%
	{"goals": {"concha": 26}, "moves": 14},  # 254 - alvo bot 95% respiro
	{"goals": {"chinelo": 31}, "moves": 15},  # 255 - alvo bot 86%
	{"goals": {"coco": 24, "chinelo": 23}, "moves": 13},  # 256 - alvo bot 86%
	{"goals": {"guarda_sol": 26}, "moves": 17},  # 257 - alvo bot 95% respiro
	{"goals": {"coco": 30, "guarda_sol": 20}, "moves": 15},  # 258 - alvo bot 86%
	{"goals": {"concha": 37}, "moves": 17},  # 259 - alvo bot 86%
	{"goals": {"chinelo": 29}, "moves": 18},  # 260 - alvo bot 95% respiro
	{"goals": {"coco": 27, "guarda_sol": 23}, "moves": 14},  # 261 - alvo bot 86%
	{"goals": {"coco": 38}, "moves": 18},  # 262 - alvo bot 86%
	{"goals": {"concha": 28}, "moves": 15},  # 263 - alvo bot 95% respiro
	{"goals": {"coco": 36}, "moves": 16},  # 264 - alvo bot 86%
	{"goals": {"guarda_sol": 34}, "moves": 16},  # 265 - alvo bot 86%
	{"goals": {"peixe": 25}, "moves": 15},  # 266 - alvo bot 95% respiro
	{"goals": {"chinelo": 23, "concha": 27}, "moves": 13},  # 267 - alvo bot 86%
	{"goals": {"concha": 31}, "moves": 14},  # 268 - alvo bot 86%
	{"goals": {"guarda_sol": 27}, "moves": 17},  # 269 - alvo bot 95% respiro
	{"goals": {"chinelo": 21, "concha": 28}, "moves": 13},  # 270 - alvo bot 86%
	{"goals": {"chinelo": 24, "concha": 27}, "moves": 13},  # 271 - alvo bot 86%
	{"goals": {"coco": 27}, "moves": 16},  # 272 - alvo bot 95% respiro
	{"goals": {"coco": 30, "concha": 23}, "moves": 16},  # 273 - alvo bot 86%
	{"goals": {"coco": 37}, "moves": 18},  # 274 - alvo bot 86%
	{"goals": {"chinelo": 27}, "moves": 18},  # 275 - alvo bot 95% respiro
	{"goals": {"coco": 32}, "moves": 15},  # 276 - alvo bot 86%
	{"goals": {"peixe": 33}, "moves": 16},  # 277 - alvo bot 86%
	{"goals": {"coco": 27}, "moves": 16},  # 278 - alvo bot 95% respiro
	{"goals": {"coco": 21, "chinelo": 20}, "moves": 13},  # 279 - alvo bot 86%
	{"goals": {"guarda_sol": 33}, "moves": 16},  # 280 - alvo bot 86%
	{"goals": {"concha": 26}, "moves": 14},  # 281 - alvo bot 95% respiro
	{"goals": {"guarda_sol": 22, "chinelo": 20}, "moves": 12},  # 282 - alvo bot 86%
	{"goals": {"coco": 20, "peixe": 30}, "moves": 14},  # 283 - alvo bot 86%
	{"goals": {"peixe": 25}, "moves": 15},  # 284 - alvo bot 95% respiro
	{"goals": {"guarda_sol": 22, "peixe": 23}, "moves": 14},  # 285 - alvo bot 86%
	{"goals": {"chinelo": 23, "concha": 23}, "moves": 13},  # 286 - alvo bot 86%
	{"goals": {"peixe": 26}, "moves": 16},  # 287 - alvo bot 95% respiro
	{"goals": {"coco": 22, "concha": 27}, "moves": 15},  # 288 - alvo bot 86%
	{"goals": {"guarda_sol": 20, "peixe": 30}, "moves": 17},  # 289 - alvo bot 86%
	{"goals": {"coco": 26}, "moves": 16},  # 290 - alvo bot 95% respiro
	{"goals": {"coco": 26, "chinelo": 23}, "moves": 14},  # 291 - alvo bot 86%
	{"goals": {"chinelo": 40}, "moves": 18},  # 292 - alvo bot 86%
	{"goals": {"peixe": 30}, "moves": 17},  # 293 - alvo bot 95% respiro
	{"goals": {"guarda_sol": 24, "peixe": 24}, "moves": 14},  # 294 - alvo bot 86%
	{"goals": {"coco": 21, "guarda_sol": 20}, "moves": 12},  # 295 - alvo bot 86%
	{"goals": {"guarda_sol": 29}, "moves": 18},  # 296 - alvo bot 95% respiro
	{"goals": {"chinelo": 33}, "moves": 16},  # 297 - alvo bot 86%
	{"goals": {"chinelo": 29, "peixe": 24}, "moves": 16},  # 298 - alvo bot 86%
	{"goals": {"coco": 29}, "moves": 17},  # 299 - alvo bot 95% respiro
	{"goals": {"coco": 20, "guarda_sol": 27}, "moves": 15},  # 300 - alvo bot 86%
]

## 5 áreas de 60 fases: reforma, intro (3 falas; área 1 não tem) e história
## (6-7 falas). Artes em res://assets/ui/areas/.
const AREAS: Array = [
	{
		"id": 1, "name": "A ressaca", "subtitle": "limpar a praia",
		"from": 1, "to": 60,
		"before": "res://assets/ui/areas/media-generation-area1-praia-antes-0-3d214f1a-86f2-4856-b1a6-9cf14fd5cb2e.webp",
		"after": "res://assets/ui/areas/media-generation-area1-praia-depois-0-0a894c4e-8a1a-4e82-ab14-d86b5d5cf38c.webp",
		"tasks": [
			["task_rubble", "Recolher o entulho da areia"],
			["task_chairs", "Desentortar as espreguiçadeiras"],
			["task_deck", "Varrer o deck do quiosque"],
			["task_plants", "Replantar a vegetação"],
			["task_flag", "Içar a bandeira do quiosque"],
			["a1_task_sign", "Consertar a placa do quiosque"],
			["a1_task_towels", "Estender as toalhas de praia"],
			["a1_task_shells", "Recolher as conchas quebradas"],
		],
		"intro": [],
		"story": [
			["Marina", "Não acredito... o quiosque do vovô..."],
			["Seu Toninho", "A ressaca levou metade do telhado, minha neta. Mas quiosque se reconstrói. O importante é que você veio."],
			["Marina", "Eu vou levantar esse quiosque de novo, vô. Nem que seja com as minhas próprias mãos!"],
			["Bia", "E com as minhas! Trouxe meu açaí e minha força de vontade!"],
			["Seu Waldomiro", "Hah! Vão precisar de mais que força de vontade... vão precisar de um milagre!"],
			["Marina", "Pode anotar, Waldomiro: até o fim do verão, o MARÉ ALTA vai reabrir. E vai ser o quiosque mais bonito dessa praia!"],
			["Cláudio", "Mas o que a Marina ainda não sabia... é que o Waldomiro tinha um plano para impedir a reforma."],
		],
	},
	{
		"id": 2, "name": "O bar", "subtitle": "a proposta do Waldomiro",
		"from": 61, "to": 120,
		"before": "res://assets/ui/areas/media-generation-area2-bar-antes-0-5758e0e3-6822-4a6c-bf08-081292865402.webp",
		"after": "res://assets/ui/areas/media-generation-area2-bar-depois-0-4e0be8d9-9105-4b8a-86bb-d85e1ceccab8.webp",
		"tasks": [
			["a2_counter", "Levantar o balcão"],
			["a2_awning", "Trocar o toldo rasgado"],
			["a2_stools", "Desentortar as banquetas"],
			["a2_sign", "Pintar a placa do bar"],
			["a2_shelves", "Organizar as prateleiras"],
			["a2_lights", "Pendurar as luminárias"],
			["a2_varnish", "Envernizar o balcão"],
			["a2_stock", "Estocar os cocos"],
		],
		"intro": [
			["Marina", "A praia tá limpa! Agora é a vez do bar..."],
			["Seu Toninho", "O balcão do seu bisavô ainda tá inteiro embaixo da sujeira."],
			["Bia", "Bar sem caipirinha não é bar. Bora!"],
		],
		"story": [
			["Marina", "O bar tá de pé! Olha só esse balcão, vô!"],
			["Seu Toninho", "Igualzinho ao do meu pai... você tem as mãos dele, minha neta."],
			["Seu Waldomiro", "Bonito... bonito. Sabe o que seria mais bonito? Uma placa de 'VENDE-SE' aqui."],
			["Marina", "O quiosque não está à venda, Waldomiro."],
			["Seu Waldomiro", "Tudo tem preço, menina. Minha oferta só vale até a festa do deck."],
			["Bia", "Ele tá blefando. Ou não tá?"],
			["Cláudio", "Naquela noite, um envelope misterioso apareceu na porta do quiosque..."],
		],
	},
	{
		"id": 3, "name": "A cozinha", "subtitle": "a receita secreta",
		"from": 121, "to": 180,
		"before": "res://assets/ui/areas/media-generation-area3-cozinha-antes-0-04513e93-ff36-44e7-8019-281dcf1ae7a8.webp",
		"after": "res://assets/ui/areas/media-generation-area3-cozinha-depois-0-553366d9-4440-4da4-8970-fbdcec3f53ec.webp",
		"tasks": [
			["a3_sink", "Desentupir a pia"],
			["a3_stove", "Instalar o fogão novo"],
			["a3_pots", "Repor as panelas"],
			["a3_tiles", "Azulejar a parede"],
			["a3_counter", "Montar a bancada"],
			["a3_utensils", "Pendurar os utensílios"],
			["a3_fridge", "Ligar a geladeira"],
			["a3_recipe", "Procurar a receita perdida"],
		],
		"intro": [
			["Marina", "Hora da cozinha — o coração do quiosque."],
			["Seu Toninho", "Foi aqui que seu bisavô criou o bobó famoso."],
			["Cláudio", "E foi aqui que eu provei... digo, vi provarem."],
		],
		"story": [
			["Marina", "A cozinha tá pronta! Mas falta o mais importante..."],
			["Seu Toninho", "A receita do bobó de camarão do seu bisavô. Se perdeu na ressaca."],
			["Bia", "E se a gente recriar? Eu provo tudo! Sacrifício, né?"],
			["Seu Waldomiro", "Procurando um papel velho? Que coincidência... eu ACHEI um papel velho na praia."],
			["Marina", "Waldomiro! Devolve a receita do meu bisavô!"],
			["Seu Waldomiro", "Devolvo... se você me vender o quiosque. Troca justa."],
			["Cláudio", "Mas o papel que o Waldomiro guardava... não era bem uma receita."],
		],
	},
	{
		"id": 4, "name": "O deck", "subtitle": "a festa de reinauguração",
		"from": 181, "to": 240,
		"before": "res://assets/ui/areas/media-generation-area4-deck-antes-0-16de1e78-0e44-4815-9493-dac97a2c3002.webp",
		"after": "res://assets/ui/areas/media-generation-area4-deck-depois-0-4e3fd1cf-01e3-4fb8-9653-7e45c2022687.webp",
		"tasks": [
			["a4_sand", "Lixar o assoalho"],
			["a4_screws", "Apertar os parafusos"],
			["a4_loungers", "Estender as espreguiçadeiras"],
			["a4_umbrellas", "Abrir os guarda-sóis"],
			["a4_flags", "Pendurar as bandeirinhas"],
			["a4_bar", "Montar o bar de apoio"],
			["a4_rail", "Iluminar o corrimão"],
			["a4_walkway", "Varrer a passarela"],
		],
		"intro": [
			["Marina", "O deck vai ser a nossa vitrine!"],
			["Bia", "Festa de reinauguração! Eu cuido dos convites!"],
			["Seu Waldomiro", "Festa? Veremos..."],
		],
		"story": [
			["Marina", "O deck tá lindo! A festa de reinauguração vai ser amanhã!"],
			["Bia", "Já chamei a praia inteira! Vai ter açaí pra todo mundo!"],
			["Seu Toninho", "Seu bisavô ia chorar de alegria vendo isso."],
			["Seu Waldomiro", "Festa? Que pena... seria uma pena se CHOVESSE amanhã."],
			["Marina", "Você não ousaria estragar a festa, Waldomiro."],
			["Seu Waldomiro", "Eu? Jamais. Mas o céu... o céu ninguém controla. Ou controla?"],
			["Cláudio", "Na manhã da festa, o céu estava azul. Azul demais para ser verdade..."],
		],
	},
	{
		"id": 5, "name": "O palco", "subtitle": "o grande show do verão",
		"from": 241, "to": 300,
		"before": "res://assets/ui/areas/media-generation-area5-palco-antes-0-33180ae1-b7e1-48a7-9a4d-8a79fdfd7e64.webp",
		"after": "res://assets/ui/areas/media-generation-area5-palco-depois-0-545bcc3e-16af-4fb0-885f-9b88ab484276.webp",
		"tasks": [
			["a5_frame", "Montar a estrutura"],
			["a5_canopy", "Esticar a lona"],
			["a5_speakers", "Instalar as caixas de som"],
			["a5_cables", "Passar os cabos"],
			["a5_lights", "Pendurar os refletores"],
			["a5_mic", "Testar o microfone"],
			["a5_chairs", "Espalhar as cadeiras"],
			["a5_curtains", "Subir as cortinas"],
		],
		"intro": [
			["Marina", "O palco... o sonho do vovô."],
			["Seu Toninho", "Ele sempre quis música ao vivo no quiosque."],
			["Marina", "Então vai ter o maior show que essa praia já viu!"],
		],
		"story": [
			["Marina", "O palco tá pronto! O show do verão vai lotar essa praia!"],
			["Bia", "Você vai cantar? Por favor, diz que vai cantar!"],
			["Seu Toninho", "Minha neta, do quiosque destruído ao maior show da praia... seu bisavô tá aplaudindo de onde estiver."],
			["Seu Waldomiro", "Aproveitem os aplausos... porque tenho uma última carta na manga."],
			["Marina", "Chega, Waldomiro! Esse quiosque é da minha família. E família não se vende!"],
			["Cláudio", "E assim, o MARÉ ALTA brilhou na noite mais mágica do verão..."],
		],
	},
]

const SAVE_PATH := "user://save.cfg"

## Caminho do save (sobrescrito nos testes para não tocar no save real).
var save_path: String = SAVE_PATH

var stars: int = 0
var coins: int = 120
var unlocked_level: int = 1
var current_level: int = 1
var levels_won: Dictionary = {} # n (int) -> true
var tasks_done: Array = []      # ids de tarefa (String)
var current_area: int = 1
var chests_claimed: Dictionary = {} # área (int) -> true
var intros_seen: Array = []         # ids de área (int) cuja intro já foi vista

## LEGADO (área 1): espelho de chests_claimed[1]. Mantido para o renovation.gd
## atual não quebrar; código novo deve usar chests_claimed / claim_chest_area(a).
var chest_claimed: bool:
	get:
		return bool(chests_claimed.get(1, false))
	set(v):
		if v:
			chests_claimed[1] = true
		else:
			chests_claimed.erase(1)


func _ready() -> void:
	load_game()


## Devolve {"goals": {type_id: alvo}, "moves": n} da fase (1-based).
func get_level(n: int) -> Dictionary:
	var cfg: Dictionary = LEVELS[clampi(n, 1, MAX_LEVEL) - 1]
	var typed := {}
	for name in (cfg["goals"] as Dictionary).keys():
		typed[int(TYPE_IDS[name])] = int((cfg["goals"] as Dictionary)[name])
	return {"goals": typed, "moves": int(cfg["moves"])}


func level_won_before(n: int) -> bool:
	return bool(levels_won.get(n, false))


## Registra vitória. Retorna true se foi a PRIMEIRA vitória (vale +1 estrela).
func on_level_won(n: int) -> bool:
	var first := not level_won_before(n)
	levels_won[n] = true
	if first:
		stars += 1
	unlocked_level = maxi(unlocked_level, mini(n + 1, MAX_LEVEL))
	save_game()
	return first


func spend_star() -> bool:
	if stars <= 0:
		return false
	stars -= 1
	save_game()
	return true


func complete_task(task_id: String) -> void:
	if not tasks_done.has(task_id):
		tasks_done.append(task_id)
		save_game()


func task_done(task_id: String) -> bool:
	return tasks_done.has(task_id)


func add_coins(n: int) -> void:
	coins += n
	save_game()


## Marca o baú da área `a` como resgatado (sem moedas: quem dá as moedas é quem chama).
func claim_chest_area(a: int) -> void:
	chests_claimed[int(a)] = true
	save_game()


func chest_claimed_area(a: int) -> bool:
	return bool(chests_claimed.get(int(a), false))


## LEGADO (área 1): mantido para o renovation.gd atual. Novo código: claim_chest_area(a).
func claim_chest() -> void:
	claim_chest_area(1)


# ------------------------------------------------------------ áreas

## Área (1-5) da fase n (1-300).
func area_of_level(n: int) -> int:
	return clampi((n - 1) / 60 + 1, 1, AREAS.size())


func _area_dict(a: int) -> Dictionary:
	if a < 1 or a > AREAS.size():
		return {}
	return AREAS[a - 1]


## Área 1 sempre liberada; as demais exigem a reforma da anterior completa.
func area_unlocked(a: int) -> bool:
	if a == 1:
		return true
	if a < 1 or a > AREAS.size():
		return false
	return area_renovation_done(a - 1)


## True quando as 8 tarefas da área estão em tasks_done.
func area_renovation_done(a: int) -> bool:
	var ad := _area_dict(a)
	if ad.is_empty():
		return false
	for t in (ad["tasks"] as Array):
		if not tasks_done.has((t as Array)[0]):
			return false
	return true


## As 8 [id, texto] da área ([] se inválida).
func area_tasks(a: int) -> Array:
	return ((_area_dict(a).get("tasks", [])) as Array).duplicate()


## As 3 [falante, fala] da intro (área 1: []; [] se inválida).
func area_intro(a: int) -> Array:
	return ((_area_dict(a).get("intro", [])) as Array).duplicate()


## As 6-7 [falante, fala] da história da área ([] se inválida).
func area_story(a: int) -> Array:
	return ((_area_dict(a).get("story", [])) as Array).duplicate()


func intro_seen(a: int) -> bool:
	return intros_seen.has(int(a))


func mark_intro_seen(a: int) -> void:
	if not intros_seen.has(int(a)):
		intros_seen.append(int(a))
		save_game()


# ------------------------------------------------------------ nuvem

## Foto serializável de TODO o progresso (o CloudSync envia p/ o Supabase).
func get_cloud_data() -> Dictionary:
	return {
		"stars": stars,
		"coins": coins,
		"unlocked_level": unlocked_level,
		"current_area": current_area,
		"levels_won": levels_won.keys(),
		"tasks_done": tasks_done.duplicate(),
		"chests_claimed": chests_claimed.keys(),
		"intros_seen": intros_seen.duplicate(),
	}


## Aplica dados vindos da nuvem (tolerante a chaves ausentes/antigas).
## Grava local SEM reagendar sync (evita eco nuvem->nuvem).
func apply_cloud_data(d: Dictionary) -> void:
	stars = int(d.get("stars", stars))
	coins = int(d.get("coins", coins))
	unlocked_level = clampi(int(d.get("unlocked_level", unlocked_level)), 1, MAX_LEVEL)
	current_area = clampi(int(d.get("current_area", current_area)), 1, AREAS.size())
	levels_won = {}
	for n in d.get("levels_won", []):
		levels_won[int(n)] = true
	tasks_done = Array(d.get("tasks_done", []))
	chests_claimed = {}
	for a in d.get("chests_claimed", []):
		chests_claimed[int(a)] = true
	# Compat: nuvem antiga podia mandar o bool legado.
	if bool(d.get("chest_claimed", false)):
		chests_claimed[1] = true
	intros_seen = Array(d.get("intros_seen", []))
	_write_save()


# ------------------------------------------------------------ persistência

func save_game() -> void:
	_write_save()
	# Hook da nuvem: nunca pode quebrar se o nó não existir (ex.: testes).
	var tree := get_tree()
	if tree == null:
		return
	var cs := tree.root.get_node_or_null("CloudSync")
	if cs != null and cs.has_method("schedule_sync"):
		cs.schedule_sync()


func _write_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "unlocked_level", unlocked_level)
	cfg.set_value("progress", "current_area", current_area)
	cfg.set_value("progress", "levels_won", levels_won.keys())
	cfg.set_value("progress", "tasks_done", tasks_done)
	cfg.set_value("progress", "chests_claimed", chests_claimed.keys())
	cfg.set_value("progress", "intros_seen", intros_seen)
	cfg.save(save_path)


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	stars = int(cfg.get_value("progress", "stars", 0))
	coins = int(cfg.get_value("progress", "coins", 120))
	unlocked_level = clampi(int(cfg.get_value("progress", "unlocked_level", 1)), 1, MAX_LEVEL)
	current_area = clampi(int(cfg.get_value("progress", "current_area", 1)), 1, AREAS.size())
	levels_won = {}
	for n in cfg.get_value("progress", "levels_won", []):
		levels_won[int(n)] = true
	tasks_done = Array(cfg.get_value("progress", "tasks_done", []))
	chests_claimed = {}
	for a in cfg.get_value("progress", "chests_claimed", []):
		chests_claimed[int(a)] = true
	# Migração graciosa: saves antigos guardavam o bool único (vira área 1).
	if bool(cfg.get_value("progress", "chest_claimed", false)):
		chests_claimed[1] = true
	intros_seen = Array(cfg.get_value("progress", "intros_seen", []))


func reset_progress() -> void:
	stars = 0
	coins = 120
	unlocked_level = 1
	current_level = 1
	levels_won = {}
	tasks_done = []
	current_area = 1
	chests_claimed = {}
	intros_seen = []
	save_game()
