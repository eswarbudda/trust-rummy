package com.trustrummy.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

/**
 * Append-only audit log of every move made during a game session.
 * Written asynchronously; the live game loop itself relies on the
 * in-memory GameStateService, not this table.
 */
@Entity
@Table(name = "game_moves_log")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GameMoveLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "session_id", nullable = false)
    private GameSession gameSession;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "move_type", nullable = false, length = 16)
    private MoveType moveType;

    @Lob
    @Column(name = "move_data")
    private String moveData;

    @Column(name = "sequence_no")
    private Long sequenceNo;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }
}
