package com.trustrummy.backend.recentplayers;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "recent_player_encounters", uniqueConstraints = {
        @UniqueConstraint(name = "uk_recent_encounter_pair", columnNames = {"user_id", "opponent_id"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RecentPlayerEncounterEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "opponent_id", nullable = false)
    private Long opponentId;

    @Column(name = "last_room_id")
    private Long lastRoomId;

    @Column(name = "last_room_code", length = 16)
    private String lastRoomCode;

    @Column(name = "last_played_at", nullable = false)
    private Instant lastPlayedAt;

    @Column(name = "match_count", nullable = false)
    @Builder.Default
    private int matchCount = 1;
}
