package com.trustrummy.backend.playgroups;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Entity
@Table(name = "play_group_members", uniqueConstraints = {
        @UniqueConstraint(name = "uk_play_group_member", columnNames = {"group_id", "user_id"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PlayGroupMemberEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "group_id", nullable = false)
    private Long groupId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private PlayGroupMemberRole role;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    @Builder.Default
    private PlayGroupMemberStatus status = PlayGroupMemberStatus.ACTIVE;

    @Column(name = "added_by_id")
    private Long addedById;

    @Column(name = "joined_at", nullable = false, updatable = false)
    private Instant joinedAt;

    @Column(name = "left_at")
    private Instant leftAt;

    @PrePersist
    protected void onCreate() {
        if (joinedAt == null) {
            joinedAt = Instant.now();
        }
        if (status == null) {
            status = PlayGroupMemberStatus.ACTIVE;
        }
    }
}
