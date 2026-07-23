package com.trustrummy.backend.playgroups;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PlayGroupRepository extends JpaRepository<PlayGroupEntity, Long> {

    @Query("""
            SELECT g FROM PlayGroupEntity g
            WHERE g.status = com.trustrummy.backend.playgroups.PlayGroupStatus.ACTIVE
              AND g.id IN (
                SELECT m.groupId FROM PlayGroupMemberEntity m
                WHERE m.userId = :userId
                  AND m.status = com.trustrummy.backend.playgroups.PlayGroupMemberStatus.ACTIVE
              )
            ORDER BY g.updatedAt DESC
            """)
    List<PlayGroupEntity> findActiveGroupsForUser(@Param("userId") long userId);

    Optional<PlayGroupEntity> findByIdAndStatusNot(long id, PlayGroupStatus status);
}
