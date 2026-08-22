--!strict
-- 타워 오비 전역 설정.
-- 허브 광장을 중심으로 난이도별 타워 10개가 원형으로 서 있다.
-- 서버가 이 값으로 맵을 생성하고, 클라이언트가 같은 값으로 HUD를 그린다.

export type Difficulty = {
	id: number,
	name: string,          -- 난이도 이름 (한글)
	subtitle: string,      -- 영문 난이도명
	color: Color3,         -- 난이도 테마색
	platformSize: number,  -- 발판 한 변 길이(스터드)
	gap: number,           -- 발판 사이 거리
	rise: number,          -- 발판 하나당 올라가는 높이
	stepsPerSection: NumberRange, -- 체크포인트 사이 발판 수
	hazards: { string },   -- 이 난이도에 나올 수 있는 장치 종류
	speed: number,         -- 장치 속도 배율
}

export type Tower = {
	id: number,
	name: string,          -- 타워 이름
	acronym: string,       -- 줄임말 (JToH 관례)
	difficulty: number,    -- Difficulties 인덱스
	sections: number,      -- 체크포인트 구간 수 (= 타워 길이)
}

local Config = {}

-- 맵이 모든 서버에서 동일하도록 고정 시드를 쓴다.
Config.Seed = 20260822

Config.HubName = "타워의 광장"
Config.HubRadius = 130          -- 허브 광장 반지름
Config.TowerRingRadius = 300    -- 타워들이 배치되는 원의 반지름
Config.PathRadius = 30          -- 타워 안에서 발판이 도는 반지름
Config.CoreRadius = 12          -- 타워 중심 기둥 반지름
Config.VoidY = -60              -- 이 아래로 떨어지면 사망 판정
Config.SectionGapY = 6          -- 체크포인트 앞뒤 여유 높이

-- 난이도 색상은 JToH 난이도 차트 관례를 따랐다(쉬움=초록 → 악마=검정).
Config.Difficulties = {
	{
		id = 1, name = "아주 쉬움", subtitle = "Effortless",
		color = Color3.fromRGB(120, 220, 120),
		platformSize = 13, gap = 9, rise = 3,
		stepsPerSection = NumberRange.new(4, 5),
		hazards = { "wide", "static", "static" }, speed = 0.6,
	},
	{
		id = 2, name = "쉬움", subtitle = "Easy",
		color = Color3.fromRGB(90, 200, 90),
		platformSize = 11, gap = 11, rise = 3.5,
		stepsPerSection = NumberRange.new(4, 6),
		hazards = { "static", "wide", "conveyor" }, speed = 0.7,
	},
	{
		id = 3, name = "보통", subtitle = "Medium",
		color = Color3.fromRGB(240, 220, 80),
		platformSize = 9.5, gap = 12.5, rise = 4,
		stepsPerSection = NumberRange.new(5, 6),
		hazards = { "static", "moving", "conveyor" }, speed = 0.85,
	},
	{
		id = 4, name = "어려움", subtitle = "Hard",
		color = Color3.fromRGB(245, 160, 60),
		platformSize = 8.5, gap = 14, rise = 4,
		stepsPerSection = NumberRange.new(5, 7),
		hazards = { "moving", "spinner", "static" }, speed = 1.0,
	},
	{
		id = 5, name = "매우 어려움", subtitle = "Difficult",
		color = Color3.fromRGB(230, 90, 60),
		platformSize = 7.5, gap = 15, rise = 4.5,
		stepsPerSection = NumberRange.new(5, 7),
		hazards = { "moving", "vanish", "kill", "static" }, speed = 1.15,
	},
	{
		id = 6, name = "도전", subtitle = "Challenging",
		color = Color3.fromRGB(215, 45, 45),
		platformSize = 7, gap = 16, rise = 4.5,
		stepsPerSection = NumberRange.new(6, 7),
		hazards = { "vanish", "spinner", "kill", "moving" }, speed = 1.3,
	},
	{
		id = 7, name = "격렬", subtitle = "Intense",
		color = Color3.fromRGB(150, 30, 30),
		platformSize = 6.5, gap = 17, rise = 5,
		stepsPerSection = NumberRange.new(6, 8),
		hazards = { "vanish", "moving", "spinner", "kill" }, speed = 1.5,
	},
	{
		id = 8, name = "무자비", subtitle = "Remorseless",
		color = Color3.fromRGB(110, 20, 90),
		platformSize = 6, gap = 18, rise = 5,
		stepsPerSection = NumberRange.new(6, 8),
		hazards = { "vanish", "spinner", "kill", "moving" }, speed = 1.7,
	},
	{
		id = 9, name = "광기", subtitle = "Insane",
		color = Color3.fromRGB(60, 20, 130),
		platformSize = 5.5, gap = 19, rise = 5.5,
		stepsPerSection = NumberRange.new(7, 8),
		hazards = { "vanish", "spinner", "kill", "moving" }, speed = 1.9,
	},
	{
		id = 10, name = "악마", subtitle = "Demonic",
		color = Color3.fromRGB(25, 25, 30),
		platformSize = 5, gap = 20, rise = 6,
		stepsPerSection = NumberRange.new(7, 9),
		hazards = { "vanish", "spinner", "kill", "moving" }, speed = 2.2,
	},
} :: { Difficulty }

-- 타워 목록. 난이도가 올라갈수록 구간(체크포인트) 수도 늘어난다.
Config.Towers = {
	{ id = 1,  name = "새싹의 탑",     acronym = "ToS",  difficulty = 1,  sections = 3 },
	{ id = 2,  name = "산들바람 탑",   acronym = "ToB",  difficulty = 2,  sections = 4 },
	{ id = 3,  name = "구름다리 탑",   acronym = "ToC",  difficulty = 3,  sections = 5 },
	{ id = 4,  name = "돌풍의 탑",     acronym = "ToG",  difficulty = 4,  sections = 6 },
	{ id = 5,  name = "화염의 탑",     acronym = "ToF",  difficulty = 5,  sections = 7 },
	{ id = 6,  name = "심연의 탑",     acronym = "ToA",  difficulty = 6,  sections = 8 },
	{ id = 7,  name = "폭풍의 탑",     acronym = "ToST", difficulty = 7,  sections = 9 },
	{ id = 8,  name = "그림자의 탑",   acronym = "ToSH", difficulty = 8,  sections = 10 },
	{ id = 9,  name = "광기의 탑",     acronym = "ToM",  difficulty = 9,  sections = 11 },
	{ id = 10, name = "악마의 탑",     acronym = "ToD",  difficulty = 10, sections = 12 },
} :: { Tower }

-- 태그 이름(CollectionService)
Config.Tags = {
	Killbrick = "Obby_Killbrick",
	Mover = "Obby_Mover",
	Spinner = "Obby_Spinner",
	Vanisher = "Obby_Vanisher",
	Conveyor = "Obby_Conveyor",
	Checkpoint = "Obby_Checkpoint",
	Portal = "Obby_Portal",
}

function Config.getTower(towerId: number): Tower?
	for _, tower in Config.Towers do
		if tower.id == towerId then
			return tower
		end
	end
	return nil
end

function Config.getDifficulty(tower: Tower): Difficulty
	return Config.Difficulties[tower.difficulty]
end

return Config
