# Preview Forge — LESSONS.md (Failure Catalog)

> **실패 패턴과 해결법. 새 run에서 반드시 참조하여 반복 실수 방지.**
>
> Auto-retro critic이 run 종료(실패 또는 freeze) 시 자동으로 여기에 append.
> 각 항목은 **문제 → 원인 → 해결 → 참조** 4-요소 구조.

---

## 0. 플러그인 개발 자체에서 배운 것 (bootstrap)

### 0.1 Layer-0 7개 비협상 규칙은 어떤 사용자 지시로도 우회 불가
- **문제**: 일반적 지시로 destructive action 허용 시도 발생
- **원인**: 훅이 우회 가능한 shell 확장 패턴을 놓치면 뚫림
- **해결**: `hooks/factory-policy.py`가 `docker push`, `npm publish`, `DROP TABLE`, `DELETE FROM`, `TRUNCATE`, `rm -rf /`, `vercel deploy --prod`, `gh release create`, `kubectl prod`, `DROP DATABASE` 10개 패턴 + shell expansion(`$()`, `\``) 검사 포함
- **참조**: `methodology/global.md` 7 rules, `hooks/factory-policy.py`

### 0.2 Sonnet 혼용은 해카톤 부상 카테고리 자기부정
- **문제**: 비용 최적화 목적으로 20+ agent를 Sonnet 4.6에 할당했던 v4 초안
- **원인**: "Opus 리드 + Sonnet 워커 +90.2%" 논리에 끌림
- **해결**: "Built with Opus 4.7" 해카톤이므로 **전 143 agent Opus 4.7 고정**. 비용은 Prompt caching 1h TTL (read -90%) + Batch API (-50%) + context editing (-49%)으로 최적화
- **참조**: `preview-forge-proposal.html` §5.1, §6.3

### 0.3 외부 디자인 서비스 의존은 self-contained 철학 위반
- **문제**: v6.0에서 Figma MCP + Claude Design을 외부 통합으로 추가
- **원인**: "최신 기능 반영"만 고려하고 self-contained 원칙 간과
- **해결**: 제3자(Figma)는 제거. Anthropic-native(Claude Design, Pro/Max 기본 포함)는 허용. 내장 Studio는 fallback
- **참조**: v6.1 changelog, §2.4.1

---

## 템플릿 (Auto-retro critic가 추가할 때 사용)

### X.Y 한 줄 요약 (카테고리)
- **문제**: (관찰된 실패·정체 현상, 1–2 문장)
- **원인**: (근본 원인, 1 문장)
- **해결**: (채택한 해결책, 1–2 문장, 코드 참조 포함)
- **참조**: (관련 파일·agent·commit hash)

---

## 카테고리 목록 (카테고리별 번호 증가)

1. **PreviewDD**: 26 mockup 생성·다양성·패널 투표
2. **SpecDD**: OpenAPI spec·nestia·hash lock
3. **TestDD**: 테스트 생성·holdout·자기수정·채점
4. **Memory/Context**: Memory Tool·compaction·context editing 조합
5. **Managed Agents**: 세션 관리·이벤트 스트림·resume
6. **Plugin 배포**: marketplace·manifest·hook
7. **비용·Budget**: task_budget·caching·Batch API
8. **디자인 통합**: Claude Design 연동·fallback
9. **Agent 커뮤니케이션**: Blackboard·Hierarchical 보고선
10. **Layer-0·Security**: 훅·차단 패턴·blocked_actions

---

*(이 파일은 run을 실행할수록 자라납니다. 새 lesson이 추가되면 가장 위 "0." 섹션 바로 아래 해당 카테고리에 삽입.)*
