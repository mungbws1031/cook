# 타워의 광장 (Tower of Towers)

허브 광장에 **난이도별 타워 10개**가 서 있는 로블록스 타워 오비(JToH 스타일)입니다.
아주 쉬움 타워부터 시작해 악마 난이도 타워까지 하나씩 정복하세요.

| # | 타워 | 난이도 | 체크포인트 |
|---|------|--------|-----------|
| 1 | 새싹의 탑 | 아주 쉬움 | 3 |
| 2 | 산들바람 탑 | 쉬움 | 4 |
| 3 | 구름다리 탑 | 보통 | 5 |
| 4 | 돌풍의 탑 | 어려움 | 6 |
| 5 | 화염의 탑 | 매우 어려움 | 7 |
| 6 | 심연의 탑 | 도전 | 8 |
| 7 | 폭풍의 탑 | 격렬 | 9 |
| 8 | 그림자의 탑 | 무자비 | 10 |
| 9 | 광기의 탑 | 광기 | 11 |
| 10 | 악마의 탑 | 악마 | 12 |

기획 상세는 [`docs/기획서.md`](docs/기획서.md) 참고.

## 실행 방법 (Rojo)

1. **툴 설치** — [Rokit](https://github.com/rojo-rbx/rokit) 설치 후 저장소 폴더에서:
   ```bash
   rokit install
   ```
   (또는 [Rojo 공식 설치](https://rojo.space/docs/v7/getting-started/installation/) 후 `rojo` 명령만 있어도 됩니다.)

2. **서버 켜기**
   ```bash
   rojo serve
   ```

3. **Studio 연결** — Roblox Studio에서 빈 Baseplate를 열고
   플러그인 목록의 **Rojo → Connect** 클릭. 스크립트가 자동으로 동기화됩니다.

4. **Play** 누르면 서버 스크립트가 허브와 타워 10개를 그 자리에서 생성합니다.
   (맵은 코드로 만들어지므로 저장할 파트가 없습니다. 시드가 고정이라 어느 서버든 모양이 같습니다.)

> 진행도 저장(DataStore)을 Studio에서 테스트하려면
> **Game Settings → Security → Enable Studio Access to API Services**를 켜세요.
> 꺼져 있으면 경고만 남기고 메모리 전용으로 동작합니다.

한 번에 `.rbxl` 파일로 만들고 싶다면:
```bash
rojo build -o TowerOfTowers.rbxl
```

## 조작

| 키 | 동작 |
|----|------|
| 이동/점프 | 기본 조작 |
| `R` | 마지막 체크포인트로 복귀 |
| `H` | 허브 광장으로 복귀 |

모바일은 화면 하단 버튼으로 같은 동작을 합니다.

## 구조

```
default.project.json     Rojo 매핑 (여기서 Remote/서비스 트리 정의)
src/
  shared/Config.lua      난이도 10단계 · 타워 10개 · 태그 이름 (밸런스는 전부 여기서)
  server/
    init.server.lua      진입점 (맵 생성 → 서비스 시작)
    TowerBuilder.lua     허브 + 타워 절차적 생성
    HazardService.lua    장치 런타임 (Heartbeat 1개로 전부 처리)
    DataService.lua      DataStore 저장/불러오기 + 재시도
    ProgressService.lua  체크포인트 · 부활 · 포탈 · 클리어 · leaderstats
  client/
    init.client.lua      입력 → 리모트
    Hud.lua              상단 상태창 · 타이머 · 토스트 · 버튼
docs/기획서.md
```

## 밸런스 조정하기

`src/shared/Config.lua` 한 파일만 고치면 됩니다.

- 타워를 추가하려면 `Config.Towers`에 항목 하나 추가 (허브 포탈·맵 배치는 자동)
- 난이도를 바꾸려면 `Config.Difficulties`의 `platformSize`(발판 크기),
  `gap`(간격), `rise`(높이), `speed`(장치 속도), `hazards`(기믹 종류) 수정
- `Config.Seed`를 바꾸면 맵 배치가 통째로 새로 생성됩니다

## 기믹

| 기믹 | 동작 |
|------|------|
| 넓은 발판 | 안전 지대 |
| 컨베이어 | 밟으면 앞/뒤로 밀림 |
| 이동 발판 | 좌우 왕복, 위에 선 캐릭터를 태우고 이동 |
| 회전 막대 | 발판 위를 회전, 맞으면 낙하 |
| 사라지는 발판 | 주기적으로 사라짐 (사라지기 전 빨갛게 예고) |
| 용암 | 닿으면 즉시 사망 |
| 공허 | 맵 아래로 떨어지면 사망 |
