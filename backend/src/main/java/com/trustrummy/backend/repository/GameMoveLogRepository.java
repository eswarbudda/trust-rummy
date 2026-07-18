package com.trustrummy.backend.repository;

import com.trustrummy.backend.entity.GameMoveLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface GameMoveLogRepository extends JpaRepository<GameMoveLog, Long> {

    List<GameMoveLog> findByGameSessionIdOrderBySequenceNoAsc(Long sessionId);

    Page<GameMoveLog> findByGameSessionIdOrderBySequenceNoAsc(Long sessionId, Pageable pageable);
}
