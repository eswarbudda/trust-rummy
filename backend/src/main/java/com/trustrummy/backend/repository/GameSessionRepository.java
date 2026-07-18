package com.trustrummy.backend.repository;

import com.trustrummy.backend.entity.GameSession;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface GameSessionRepository extends JpaRepository<GameSession, Long> {

    List<GameSession> findByGameRoomId(Long roomId);

    Optional<GameSession> findFirstByGameRoomIdOrderByStartedAtDesc(Long roomId);
}
