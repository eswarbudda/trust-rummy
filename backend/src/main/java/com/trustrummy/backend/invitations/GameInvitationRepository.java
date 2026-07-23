package com.trustrummy.backend.invitations;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface GameInvitationRepository extends JpaRepository<GameInvitationEntity, UUID> {

    Optional<GameInvitationEntity> findByRoomIdAndInviteeId(long roomId, long inviteeId);

    List<GameInvitationEntity> findByInviteeIdAndStatusOrderByCreatedAtDesc(long inviteeId, InvitationStatus status);

    List<GameInvitationEntity> findByRoomIdOrderByCreatedAtDesc(long roomId);

    @Query("""
            select i from GameInvitationEntity i
            where i.roomId = :roomId and i.status = :status
            order by i.createdAt desc
            """)
    List<GameInvitationEntity> findByRoomIdAndStatus(
            @Param("roomId") long roomId,
            @Param("status") InvitationStatus status
    );
}
