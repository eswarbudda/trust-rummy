package com.trustrummy.backend.users;

import java.util.Collection;
import java.util.Map;
import java.util.Optional;

/**
 * Read-only user lookup for social modules (Friends, Play Groups, etc.).
 */
public interface UserLookupPort {

    Optional<UserSummary> findById(long userId);

    Optional<UserSummary> findByUsername(String username);

    /** Returns a map keyed by user id for the ids that exist. */
    Map<Long, UserSummary> findByIds(Collection<Long> userIds);
}
