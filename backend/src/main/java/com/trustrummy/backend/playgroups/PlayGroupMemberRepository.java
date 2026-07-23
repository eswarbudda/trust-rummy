package com.trustrummy.backend.playgroups;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PlayGroupMemberRepository extends JpaRepository<PlayGroupMemberEntity, Long> {

    List<PlayGroupMemberEntity> findByGroupIdAndStatus(long groupId, PlayGroupMemberStatus status);

    Optional<PlayGroupMemberEntity> findByGroupIdAndUserId(long groupId, long userId);

    long countByGroupIdAndStatus(long groupId, PlayGroupMemberStatus status);

    boolean existsByGroupIdAndUserIdAndStatus(long groupId, long userId, PlayGroupMemberStatus status);
}
