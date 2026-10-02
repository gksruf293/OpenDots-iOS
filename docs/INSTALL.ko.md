# Windows + 아이폰 설치 안내

아이폰에서는 OpenDots를 사용하고, PC에서는 Codex·서버·HTTPS 연결 프로그램을
실행합니다. 맥 없이 GitHub의 macOS 환경에서 빌드할 수 있지만, 아이폰 설치에는
Apple 계정 서명이 별도로 필요합니다. 이 버전은 개인용 실험 버전입니다.

## 1. PC 서버 설치

Windows x64, PowerShell 7, Git, Node.js **24 LTS**를 준비하세요.
검증한 Codex CLI는 **0.157.1**입니다. Codex를 사용할 수 있는 ChatGPT 계정이
필요하며, 사용량은 해당 계정 한도에 포함됩니다. 새 CLI 버전은 호환성 확인 후
업데이트하세요.

```powershell
git clone https://github.com/gksruf293/OpenDots-iOS.git
cd OpenDots-iOS
npm install -g @openai/codex@0.157.1
codex login
codex login status
pwsh -File ./scripts/setup-server.ps1
pwsh -File ./scripts/start-server.ps1
```

로그인은 직접 인증하세요. 설치 스크립트가 npm 의존성과 서버를 빌드하고,
Windows 네이티브 `codex.exe`를 찾아 `server/.env`에 설정합니다.
기존 `.env`가 있으면 덮어쓰지 않습니다. 서버 토큰은 무작위로 생성됩니다.

터미널을 켜 둔 채 `http://127.0.0.1:4310`을 열고
`.local-tools/connection.txt`의 **서버 토큰**을 입력하세요. 먼저 PC에서 대화가
되는지 확인합니다. 대화·문서는 `server/data/opendots.sqlite`에 저장됩니다.

## 2. VPN 없이 고정 HTTPS 주소 연결

[ngrok 공식 Windows 앱](https://ngrok.com/download/windows)을 설치하고 계정
대시보드에서 본인의 dev domain을 확인하세요. 도메인을 구매할 필요가 없으며,
아이폰에 ngrok 앱을 설치하지 않습니다.

```powershell
ngrok config add-authtoken YOUR_NGROK_AUTHTOKEN
ngrok http http://127.0.0.1:4310 --url https://YOUR_ASSIGNED_DOMAIN --inspect=false
```

자리표시자를 본인의 값으로 바꿉니다. **ngrok 토큰은 PC 연결용**이며,
**OpenDots 서버 토큰은 아이폰 앱 인증용**입니다. 서로 다른 값입니다.
서버와 ngrok을 둘 다 켜 두세요. 주소는 계정에 고정되어 다시 실행해도 유지됩니다.
무료 플랜에는 현재 월 1GB·HTTP 요청 20,000회 등의 제한이 있습니다.
[최신 제한](https://ngrok.com/docs/pricing-limits/free-plan-limits)을 확인하세요.

서버 주소는 인터넷에서 접근 가능해집니다. API는 토큰으로 보호되지만, TLS를
처리하는 ngrok은 전송 내용을 볼 수 있습니다. 종단간 암호화는 없습니다.
`--inspect=false`는 로컬 요청 검사만 끕니다. 토큰·대화 DB는 공개하지 마세요.

자동 실행은 [ngrok 서비스 안내](https://ngrok.com/docs/agent/cli/#ngrok-service)와
Windows 시작프로그램의 `start-server.ps1` 바로가기로 별도 설정할 수 있습니다.
바로가기에는 본인 체크아웃의 절대 경로를 쓰세요. 저장소 스크립트는 시스템 서비스나
시작프로그램을 자동 등록하지 않습니다. PC가 꺼지거나 절전 상태면 연결이 끊깁니다.

## 3. GitHub에서 아이폰용 IPA 빌드

1. 이 저장소를 Fork하고 Actions를 활성화합니다.
2. **iPhone package (unsigned)** → Run workflow를 누릅니다.
3. 성공하면 **OpenDots-iPhone-Unsigned** 아티팩트를 다운로드합니다.
4. 압축을 풀어 `OpenDots-Unsigned.ipa`를 확인합니다.

이 파일은 실제 아이폰용이지만 **서명 전**이라 바로 설치되지 않습니다.
다른 워크플로의 시뮬레이터 ZIP은 아이폰에 설치할 수 없습니다. 실행 시간은 GitHub
계정의 macOS runner 사용 제한을 따릅니다. CI에는 Apple 로그인·서명 키가 필요 없습니다.

## 4. Windows에서 서명하고 설치

[AltStore 공식 Windows 안내](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)에
따라 AltServer와 필요한 Apple iTunes·iCloud 구성요소를 설치하세요.
아이폰을 USB로 연결해 잠금을 풀고 ‘이 컴퓨터를 신뢰’를 누릅니다.
Apple 로그인과 2단계 인증은 설치 프로그램에서 직접 진행합니다.

PC 트레이의 AltServer 아이콘을 **Shift를 누른 채 클릭 → Sideload .ipa…**로
열어 IPA를 선택합니다. 직접 설치 방식이면 아이폰에 AltStore를 먼저 설치하지
않아도 됩니다. 설정의 **일반 → VPN 및 기기 관리**에서 개발자 프로필을 신뢰하고,
**개인정보 보호 및 보안 → 개발자 모드**를 켠 뒤 안내대로 재부팅하세요.
프로필이 ‘VPN 및 기기 관리’에 표시되는 것과 VPN 연결이 필요한 것은 별개입니다.

무료 Apple 계정으로 서명한 앱은 일반적으로 **7일마다 갱신**해야 합니다.
직접 설치했다면 다시 서명·설치하고, 아이폰 AltStore를 사용한다면 갱신 기능을
이용할 수 있습니다. 현재는 App Store·TestFlight 배포판이 아닙니다.
맥이 있다면 XcodeGen으로 프로젝트를 만들고 본인 팀·번들 ID로 서명해도 됩니다.

## 5. 앱 연결

OpenDots에 본인의 **ngrok HTTPS 주소**와 **OpenDots 서버 토큰**을 입력합니다.
주소에 `/api`나 다른 경로를 붙이지 마세요. ‘연결’ 후 Dot을 골라 대화를 보내고,
문서로 저장·편집해 보세요. ngrok 방식이면 Tailscale VPN을 끈 상태로 셀룰러에서도
확인할 수 있습니다. 앱 토큰은 아이폰 Keychain에 저장됩니다.

## 문제 해결

| 문제 | 확인할 것 |
| --- | --- |
| 401 / 토큰 오류 | ngrok 토큰이 아닌 OpenDots 서버 토큰인지 확인 |
| 접속 안 됨 | 서버·ngrok 실행, PC 절전, 서비스 사용 한도 |
| Codex 준비 안 됨 | `codex login status`, 실행 파일 경로, 계정 한도 |
| iCloud 오류 1722 | [AltStore 문제 해결](https://faq.altstore.io/altstore-classic/troubleshooting-guide). Windows 보안을 끄지 마세요. |
| Apple 오류 -22411 | 계정·2단계 인증 확인. 코드만으로 원인 확정 불가 |
| iTunes 오류 -45054 | [Apple 복구 안내](https://support.apple.com/en-us/108339). 인증 폴더는 먼저 백업 |
| IPA 설치 실패 | 실제 기기용인지, 별도 서명을 했는지 확인 |

버그 제보에는 OS·CLI 버전과 오류 문구를 적고, 인증 파일·토큰·대화 DB·개인
계정이 보이는 화면은 첨부하지 마세요. 다른 플랫폼은 [English guide](INSTALL.md)를 참고하세요.
