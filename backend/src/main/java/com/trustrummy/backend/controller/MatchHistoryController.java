package com.trustrummy.backend.controller;

import com.trustrummy.backend.dto.MatchHistoryDetailResponse;
import com.trustrummy.backend.dto.MatchHistoryItemResponse;
import com.trustrummy.backend.dto.MoveLogResponse;
import com.trustrummy.backend.dto.ScorecardSummaryResponse;
import com.trustrummy.backend.service.MatchHistoryService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

/** Long-term, per-user match records — active gameplay stays entirely on the WebSocket (see RULES_ENGINE.md). */
@RestController
@RequestMapping("/api/v1/history")
@RequiredArgsConstructor
public class MatchHistoryController {

    private final MatchHistoryService matchHistoryService;

    @GetMapping("/matches")
    public ResponseEntity<Page<MatchHistoryItemResponse>> myMatches(
            @AuthenticationPrincipal UserDetails principal,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ResponseEntity.ok(matchHistoryService.listMyMatches(principal.getUsername(), PageRequest.of(page, size)));
    }

    @GetMapping("/matches/{sessionId}")
    public ResponseEntity<MatchHistoryDetailResponse> matchDetail(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable Long sessionId
    ) {
        return ResponseEntity.ok(matchHistoryService.getMatchDetail(principal.getUsername(), sessionId));
    }

    @GetMapping("/matches/{sessionId}/moves")
    public ResponseEntity<Page<MoveLogResponse>> matchMoves(
            @AuthenticationPrincipal UserDetails principal,
            @PathVariable Long sessionId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        return ResponseEntity.ok(matchHistoryService.getMatchMoves(principal.getUsername(), sessionId, PageRequest.of(page, size)));
    }

    @GetMapping("/scorecard")
    public ResponseEntity<ScorecardSummaryResponse> scorecard(@AuthenticationPrincipal UserDetails principal) {
        return ResponseEntity.ok(matchHistoryService.getScorecard(principal.getUsername()));
    }
}
