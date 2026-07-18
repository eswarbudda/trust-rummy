package com.trustrummy.backend.repository;

import com.trustrummy.backend.entity.GameMoveLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface GameMoveLogRepository extends JpaRepository<GameMoveLog, Long> {

    List<GameMoveLog> findByGameSessionIdOrderBySequenceNoAsc(Long sessionId);
}
