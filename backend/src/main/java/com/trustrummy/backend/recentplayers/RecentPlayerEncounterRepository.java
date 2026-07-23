package com.trustrummy.backend.recentplayers;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface RecentPlayerEncounterRepository extends JpaRepository<RecentPlayerEncounterEntity, Long> {

    List<RecentPlayerEncounterEntity> findByUserIdOrderByLastPlayedAtDesc(long userId, Pageable pageable);

    Optional<RecentPlayerEncounterEntity> findByUserIdAndOpponentId(long userId, long opponentId);

    @Modifying
    @Query(value = """
            INSERT INTO recent_player_encounters
                (user_id, opponent_id, last_room_id, last_room_code, last_played_at, match_count)
            VALUES
                (:userId, :opponentId, :roomId, :roomCode, :playedAt, 1)
            ON CONFLICT (user_id, opponent_id) DO UPDATE SET
                last_room_id = EXCLUDED.last_room_id,
                last_room_code = EXCLUDED.last_room_code,
                last_played_at = EXCLUDED.last_played_at,
                match_count = recent_player_encounters.match_count + 1
            """, nativeQuery = true)
    void upsertEncounter(
            @Param("userId") long userId,
            @Param("opponentId") long opponentId,
            @Param("roomId") Long roomId,
            @Param("roomCode") String roomCode,
            @Param("playedAt") Instant playedAt
    );
}
