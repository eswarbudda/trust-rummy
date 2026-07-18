package com.trustrummy.backend.repository;

import com.trustrummy.backend.entity.GameMoveLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface GameMoveLogRepository extends JpaRepository<GameMoveLog, Long> {

    /** {@code JOIN FETCH} — see the note on {@code RoomPlayerRepository} re: lazy `user` + open-in-view=false. */
    @Query("SELECT gml FROM GameMoveLog gml JOIN FETCH gml.user WHERE gml.gameSession.id = :sessionId ORDER BY gml.sequenceNo ASC")
    List<GameMoveLog> findByGameSessionIdOrderBySequenceNoAsc(@Param("sessionId") Long sessionId);

    @Query(
            value = "SELECT gml FROM GameMoveLog gml JOIN FETCH gml.user WHERE gml.gameSession.id = :sessionId ORDER BY gml.sequenceNo ASC",
            countQuery = "SELECT COUNT(gml) FROM GameMoveLog gml WHERE gml.gameSession.id = :sessionId"
    )
    Page<GameMoveLog> findByGameSessionIdOrderBySequenceNoAsc(@Param("sessionId") Long sessionId, Pageable pageable);
}
