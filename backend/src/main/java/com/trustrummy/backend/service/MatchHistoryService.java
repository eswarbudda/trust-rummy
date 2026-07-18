package com.trustrummy.backend.service;

import com.trustrummy.backend.dto.MatchHistoryDetailResponse;
import com.trustrummy.backend.dto.MatchHistoryItemResponse;
import com.trustrummy.backend.dto.MatchPlayerResultResponse;
import com.trustrummy.backend.dto.MoveLogResponse;
import com.trustrummy.backend.dto.ScorecardSummaryResponse;
import com.trustrummy.backend.entity.GameSession;
import com.trustrummy.backend.entity.RoomPlayer;
import com.trustrummy.backend.entity.SessionStatus;
import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.exception.ForbiddenOperationException;
import com.trustrummy.backend.exception.ResourceNotFoundException;
import com.trustrummy.backend.repository.GameMoveLogRepository;
import com.trustrummy.backend.repository.GameSessionRepository;
import com.trustrummy.backend.repository.RoomPlayerRepository;
import com.trustrummy.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MatchHistoryService {

    private final UserRepository userRepository;
    private final GameSessionRepository gameSessionRepository;
    private final GameMoveLogRepository gameMoveLogRepository;
    private final RoomPlayerRepository roomPlayerRepository;

    public Page<MatchHistoryItemResponse> listMyMatches(String username, Pageable pageable) {
        User user = getUser(username);
        return gameSessionRepository.findByParticipantUserId(user.getId(), pageable)
                .map(session -> toItem(session, user.getId()));
    }

    public MatchHistoryDetailResponse getMatchDetail(String username, Long sessionId) {
        User user = getUser(username);
        GameSession session = getSessionForParticipant(sessionId, user.getId());

        List<RoomPlayer> players = roomPlayerRepository.findByGameRoomId(session.getGameRoom().getId());
        players.sort(Comparator.comparing(rp -> rp.getSeatNumber() == null ? Integer.MAX_VALUE : rp.getSeatNumber()));

        return MatchHistoryDetailResponse.builder()
                .sessionId(session.getId())
                .roomCode(session.getGameRoom().getRoomCode())
                .gameVariant(session.getGameRoom().getGameVariant() != null ? session.getGameRoom().getGameVariant().name() : null)
                .stakeAmount(session.getGameRoom().getStakeAmount())
                .status(session.getStatus().name())
                .winnerUsername(session.getWinner() != null ? session.getWinner().getUsername() : null)
                .startedAt(session.getStartedAt())
                .endedAt(session.getEndedAt())
                .players(players.stream()
                        .map(rp -> MatchPlayerResultResponse.builder()
                                .userId(rp.getUser().getId())
                                .username(rp.getUser().getUsername())
                                .seatNumber(rp.getSeatNumber())
                                .finalScore(rp.getScore())
                                .status(rp.getStatus().name())
                                .build())
                        .toList())
                .build();
    }

    public Page<MoveLogResponse> getMatchMoves(String username, Long sessionId, Pageable pageable) {
        User user = getUser(username);
        GameSession session = getSessionForParticipant(sessionId, user.getId());
        return gameMoveLogRepository.findByGameSessionIdOrderBySequenceNoAsc(session.getId(), pageable)
                .map(MoveLogResponse::from);
    }

    public ScorecardSummaryResponse getScorecard(String username) {
        User user = getUser(username);
        List<GameSession> sessions = gameSessionRepository
                .findByParticipantUserId(user.getId(), Pageable.unpaged())
                .getContent();

        int total = 0;
        int wins = 0;
        int losses = 0;
        BigDecimal netChips = BigDecimal.ZERO;
        Integer bestDealScore = null;

        for (GameSession session : sessions) {
            if (session.getStatus() != SessionStatus.COMPLETED) {
                continue;
            }
            total++;

            boolean won = session.getWinner() != null && session.getWinner().getId().equals(user.getId());
            BigDecimal stake = session.getGameRoom().getStakeAmount() != null
                    ? session.getGameRoom().getStakeAmount() : BigDecimal.ZERO;
            int participantCount = roomPlayerRepository.findByGameRoomId(session.getGameRoom().getId()).size();

            if (won) {
                wins++;
                netChips = netChips.add(stake.multiply(BigDecimal.valueOf(Math.max(participantCount - 1, 0))));
            } else {
                losses++;
                netChips = netChips.subtract(stake);
            }

            Integer myScore = roomPlayerRepository.findByGameRoomIdAndUserId(session.getGameRoom().getId(), user.getId())
                    .map(RoomPlayer::getScore)
                    .orElse(null);
            if (myScore != null && (bestDealScore == null || myScore < bestDealScore)) {
                bestDealScore = myScore;
            }
        }

        return ScorecardSummaryResponse.builder()
                .totalMatches(total)
                .wins(wins)
                .losses(losses)
                .netChips(netChips)
                .bestDealScore(bestDealScore)
                .build();
    }

    private GameSession getSessionForParticipant(Long sessionId, Long userId) {
        GameSession session = gameSessionRepository.findWithDetailsById(sessionId)
                .orElseThrow(() -> new ResourceNotFoundException("Match not found: " + sessionId));

        boolean participant = roomPlayerRepository
                .findByGameRoomIdAndUserId(session.getGameRoom().getId(), userId)
                .isPresent();
        if (!participant) {
            throw new ForbiddenOperationException("You did not participate in this match");
        }
        return session;
    }

    private MatchHistoryItemResponse toItem(GameSession session, Long userId) {
        Integer myScore = roomPlayerRepository.findByGameRoomIdAndUserId(session.getGameRoom().getId(), userId)
                .map(RoomPlayer::getScore)
                .orElse(null);

        return MatchHistoryItemResponse.builder()
                .sessionId(session.getId())
                .roomCode(session.getGameRoom().getRoomCode())
                .gameVariant(session.getGameRoom().getGameVariant() != null ? session.getGameRoom().getGameVariant().name() : null)
                .stakeAmount(session.getGameRoom().getStakeAmount())
                .status(session.getStatus().name())
                .winnerUsername(session.getWinner() != null ? session.getWinner().getUsername() : null)
                .myFinalScore(myScore)
                .startedAt(session.getStartedAt())
                .endedAt(session.getEndedAt())
                .build();
    }

    private User getUser(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("Unknown user: " + username));
    }
}
