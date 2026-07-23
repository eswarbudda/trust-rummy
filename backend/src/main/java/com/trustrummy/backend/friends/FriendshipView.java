package com.trustrummy.backend.friends;

import java.time.Instant;

public record FriendshipView(
        long friendshipId,
        FriendshipStatus status,
        long requesterId,
        long addresseeId,
        Instant createdAt,
        Instant respondedAt
) {
    static FriendshipView from(FriendshipEntity entity) {
        return new FriendshipView(
                entity.getId(),
                entity.getStatus(),
                entity.getRequesterId(),
                entity.getAddresseeId(),
                entity.getCreatedAt(),
                entity.getRespondedAt()
        );
    }
}
