package com.trustrummy.backend.users;

import com.trustrummy.backend.entity.User;
import com.trustrummy.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class JpaUserLookup implements UserLookupPort {

    private final UserRepository userRepository;

    @Override
    public Optional<UserSummary> findById(long userId) {
        return userRepository.findById(userId).map(this::toSummary);
    }

    @Override
    public Optional<UserSummary> findByUsername(String username) {
        if (username == null || username.isBlank()) {
            return Optional.empty();
        }
        return userRepository.findByUsername(username.trim()).map(this::toSummary);
    }

    @Override
    public Map<Long, UserSummary> findByIds(Collection<Long> userIds) {
        Map<Long, UserSummary> out = new LinkedHashMap<>();
        if (userIds == null || userIds.isEmpty()) {
            return out;
        }
        for (User user : userRepository.findAllById(userIds)) {
            out.put(user.getId(), toSummary(user));
        }
        return out;
    }

    private UserSummary toSummary(User user) {
        String display = user.getDisplayName();
        if (display == null || display.isBlank()) {
            display = user.getUsername();
        }
        return new UserSummary(user.getId(), user.getUsername(), display);
    }
}
