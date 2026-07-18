package com.trustrummy.backend.service;

import com.trustrummy.backend.entity.GameMoveLog;
import com.trustrummy.backend.entity.GameSession;
import com.trustrummy.backend.entity.MoveType;
import com.trustrummy.backend.entity.RoomStatus;
import com.trustrummy.backend.entity.SessionStatus;
import com.trustrummy.backend.repository.GameMoveLogRepository;
import com.trustrummy.backend.repository.GameRoomRepository;
import com.trustrummy.backend.repository.GameSessionRepository;
import com.trustrummy.backend.repository.RoomPlayerRepository;
import com.trustrummy.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Map;

/**
 * Durable, audit-trail persistence for the Rummy engine. Every method here
 * is {@code @Async} — {@code RummyEngineService} fires-and-forgets these
 * calls so the WebSocket hot path (draw/discard/declare/drop) never blocks
 * on a database round-trip.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class GamePersistenceService {

    private final GameRoomRepository gameRoomRepository;
    private final GameSessionRepository gameSessionRepository;
    private final GameMoveLogRepository gameMoveLogRepository;
    private final RoomPlayerRepository roomPlayerRepository;
    private final UserRepository userRepository;

    @Async
    @Transactional
    public void recordMatchStart(String roomCode) {
        gameRoomRepository.findByRoomCode(roomCode).ifPresentOrElse(room -> {
            room.setStatus(RoomStatus.IN_PROGRESS);
            gameRoomRepository.save(room);

            GameSession session = GameSession.builder()
                    .gameRoom(room)
                    .status(SessionStatus.ACTIVE)
                    .build();
            gameSessionRepository.save(session);
        }, () -> log.warn("recordMatchStart: unknown room {}", roomCode));
    }

    @Async
    @Transactional
    public void recordMove(String roomCode, Long userId, MoveType moveType, String moveDataJson, long sequenceNo) {
        gameRoomRepository.findByRoomCode(roomCode).ifPresent(room ->
                gameSessionRepository.findFirstByGameRoomIdOrderByStartedAtDesc(room.getId()).ifPresent(session ->
                        userRepository.findById(userId).ifPresent(user -> {
                            GameMoveLog moveLog = GameMoveLog.builder()
                                    .gameSession(session)
                                    .user(user)
                                    .moveType(moveType)
                                    .moveData(moveDataJson)
                                    .sequenceNo(sequenceNo)
                                    .build();
                            gameMoveLogRepository.save(moveLog);
                        })));
    }

    @Async
    @Transactional
    public void recordMatchEnd(String roomCode, Long winnerUserId, Map<Long, Integer> finalScores) {
        gameRoomRepository.findByRoomCode(roomCode).ifPresent(room -> {
            room.setStatus(RoomStatus.COMPLETED);
            gameRoomRepository.save(room);

            gameSessionRepository.findFirstByGameRoomIdOrderByStartedAtDesc(room.getId()).ifPresent(session -> {
                session.setStatus(SessionStatus.COMPLETED);
                session.setEndedAt(Instant.now());
                if (winnerUserId != null) {
                    userRepository.findById(winnerUserId).ifPresent(session::setWinner);
                }
                gameSessionRepository.save(session);
            });

            finalScores.forEach((userId, score) ->
                    roomPlayerRepository.findByGameRoomIdAndUserId(room.getId(), userId).ifPresent(roomPlayer -> {
                        roomPlayer.setScore(score);
                        roomPlayerRepository.save(roomPlayer);
                    }));
        });
    }
}
