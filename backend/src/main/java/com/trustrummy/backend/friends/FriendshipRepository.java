package com.trustrummy.backend.friends;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface FriendshipRepository extends JpaRepository<FriendshipEntity, Long> {

    @Query("""
            SELECT f FROM FriendshipEntity f
            WHERE (f.requesterId = :a AND f.addresseeId = :b)
               OR (f.requesterId = :b AND f.addresseeId = :a)
            """)
    Optional<FriendshipEntity> findPair(@Param("a") long a, @Param("b") long b);

    @Query("""
            SELECT f FROM FriendshipEntity f
            WHERE (f.requesterId = :userId OR f.addresseeId = :userId)
              AND f.status = :status
            ORDER BY f.updatedAt DESC
            """)
    List<FriendshipEntity> findByUserAndStatus(
            @Param("userId") long userId,
            @Param("status") FriendshipStatus status
    );

    @Query("""
            SELECT CASE WHEN COUNT(f) > 0 THEN true ELSE false END
            FROM FriendshipEntity f
            WHERE f.status = com.trustrummy.backend.friends.FriendshipStatus.ACCEPTED
              AND ((f.requesterId = :a AND f.addresseeId = :b)
                OR (f.requesterId = :b AND f.addresseeId = :a))
            """)
    boolean areFriends(@Param("a") long a, @Param("b") long b);
}
