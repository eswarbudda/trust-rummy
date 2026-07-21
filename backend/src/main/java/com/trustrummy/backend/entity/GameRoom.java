package com.trustrummy.backend.entity;

import com.trustrummy.backend.game.model.GameType;
import com.trustrummy.backend.game.model.GameVariant;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "game_rooms", uniqueConstraints = {
        @UniqueConstraint(columnNames = "room_code")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GameRoom {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "room_code", nullable = false, length = 12)
    private String roomCode;

    @Column(length = 64)
    private String name;

    @Column(name = "max_players", nullable = false)
    @Builder.Default
    private Integer maxPlayers = 6;

    @Column(name = "stake_amount", precision = 19, scale = 2)
    @Builder.Default
    private BigDecimal stakeAmount = BigDecimal.ZERO;

    /** Which game this room plays; {@code gameVariant} below is a RUMMY-specific sub-selector. */
    @Enumerated(EnumType.STRING)
    @Column(name = "game_type", length = 16)
    @Builder.Default
    private GameType gameType = GameType.RUMMY;

    @Enumerated(EnumType.STRING)
    @Column(name = "game_variant", length = 16)
    @Builder.Default
    private GameVariant gameVariant = GameVariant.POOL_101;

    /**
     * Deals in a {@link GameVariant#DEALS} match. Null for pool and for
     * {@link GameVariant#POINTS} (single-deal; room create clears any client value).
     */
    @Column(name = "deals_per_match")
    private Integer dealsPerMatch;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    @Builder.Default
    private RoomStatus status = RoomStatus.WAITING;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by")
    private User createdBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = Instant.now();
    }
}
