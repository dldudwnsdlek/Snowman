# Snowman ❄️ 눈 내리는 데스크톱

모든 창 위에, 그리고 작업 표시줄(맥은 Dock) 위에 눈이 소복이 쌓이는 장난감 앱입니다.
쌓인 눈을 굴려 눈덩이를 만들고, 쌓아서 눈사람을 만들고, 던지고, 제설차로 밀어 버릴 수 있어요.

- **Windows 10/11** — `windows/` (C# · .NET 8 · WPF)
- **macOS 14+** — `mac/` (Swift · AppKit · SpriteKit)

두 버전은 같은 기능과 같은 그림(눈사람 5종)을 씁니다. 그림은 모두 코드로 그렸어요.
Windows 버전은 바탕화면을 바꾸지 않아요. 겨울 배경화면 10종은 macOS 버전에만 있어요.

## Windows에서 쓰기

1. 이 저장소의 [Releases](https://github.com/dldudwnsdlek/Snowman/releases) 페이지에서 `Snowman-win-x64.zip`을 받아 압축을 풉니다.
2. `Snowman.exe`를 더블클릭합니다. 설치 과정도, .NET을 따로 설치할 필요도 없어요.
3. "Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행**을 누르세요. 서명되지 않은 개인 앱이라 처음 한 번 나오는 경고예요.
4. 화면 오른쪽 아래 알림 영역에 ❄ 아이콘이 생깁니다. 안 보이면 `^`(숨겨진 아이콘)을 눌러 보세요. 아이콘을 누르면 메뉴가 열려요.

- 끄기: ❄ 메뉴 → **끝내기**
- 컴퓨터를 켤 때 자동으로 실행하려면: `Win + R` → `shell:startup` 입력 → 열린 폴더에 `Snowman.exe` 바로 가기를 넣으세요.
- 설정은 `%APPDATA%\Snowman`, 로그는 `%LOCALAPPDATA%\Snowman`에 저장돼요.

## 기능

| # | 기능 | 사용법 |
|---|---|---|
| 1 | 모든 창 위에 쌓이는 눈 | 탐색기, 브라우저, 메신저 등 모든 창 윗면에 쌓여요. 앞 창에 가려진 부분에는 보이지 않아요. |
| 2 | 작업 표시줄(Dock) 위에도 소복이 | 작업 표시줄 크기에 딱 맞게 쌓여요. 자동 숨김이면 함께 숨었다가 다시 나타나요. |
| 3 | 제설차 부르기 | 제설차가 작업 표시줄 위 눈을 밀어내요. 작업 표시줄이 숨어 있으면 화면 아래 눈을 치워요. |
| 4 | 창을 닫으면 우수수 | 닫거나 최소화한 창의 눈이 떨어져 아래에 다시 쌓여요. 창을 세게 흔들어도 털려요. 가상 데스크톱을 바꿀 때는 눈이 그대로 보관돼요. |
| 5 | 굴릴수록 커지는 눈덩이 | 쌓인 눈에 마우스를 올리면 장갑이 나와요. 눌러서 한 줌 뜬 뒤 옆으로 끌면 굴러가며 커지고, 위로 들면 들고 다녀요. |
| 6 | 살아 있는 눈사람 | 숨 쉬고, 눈을 깜빡이고, 커서가 다가오면 손을 흔들어요. 한 번 클릭하면 춤을 춰요. |
| 7 | 쌓으면 눈사람 완성 | 눈덩이를 다른 눈덩이 위에 놓으면 팔 → 눈 → 코 → 입 → 목도리 → 모자 순서로 생겨요. |
| 8 | 눈사람 5종 | 산타 · 비니 · 신사 · 귀마개 · 요정. 모자, 목도리, 표정이 모두 달라요. |
| 9 | 던지면 와장창 | 눈사람을 잡고 휙 던지면 화면 가장자리에 부딪혀 반대로 튕겨요. 아주 세게 던지면 부서져 눈덩이 두 개로 돌아가요. |
| 10 | 눈 양 조절 | 메뉴 `눈 양`에서 조금 / 보통 / 펑펑. `눈 멈추기`로 잠시 멈출 수도 있어요. |
| 11 | 겨울 배경화면 10종 | macOS 버전에만 있어요. Windows 버전은 바탕화면을 건드리지 않아요. |

평소 클릭은 그대로 아래 창으로 전달돼요. 쌓인 눈, 눈덩이, 눈사람 위에 마우스가 있을 때만 앱이 클릭을 받아요.
창을 최대화하면 위쪽에 눈이 쌓일 자리가 없어서, 최대화하지 않은 창에 눈이 쌓여요.

## macOS에서 쓰기

`mac/` 폴더에서 빌드합니다 (Xcode 없이 Command Line Tools만 있으면 돼요).

```bash
cd mac
./build.sh            # Snowman.app 생성
open Snowman.app
```

Dock 크기에 딱 맞추려면 손쉬운 사용 권한이 필요해요. 자세한 내용은 [mac/README.md](mac/README.md)를 보세요.

## 직접 빌드하기 (Windows)

.NET 8 SDK가 필요합니다.

```powershell
dotnet build windows/Snowman.sln -c Release
dotnet run --project windows/tests/Snowman.Checks -c Release        # 로직·그림 검사
dotnet publish windows/src/Snowman.App/Snowman.App.csproj -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o publish
```

`v`로 시작하는 태그를 올리면 GitHub Actions가 Windows에서 빌드·검사·실행 테스트를 거쳐 Releases에 `Snowman-win-x64.zip`을 올려요.

```
windows/
  src/Snowman.Core/     눈 높이맵, 선반·가림 계산, 물리 (순수 로직)
  src/Snowman.Art/      눈사람·제설차·눈송이를 그리는 코드 (SkiaSharp)
  src/Snowman.App/      Windows 앱 (투명 오버레이, 알림 영역 메뉴, 창 추적)
  tests/Snowman.Checks/ 검사 실행기
mac/                    macOS 버전 (Swift)
```
