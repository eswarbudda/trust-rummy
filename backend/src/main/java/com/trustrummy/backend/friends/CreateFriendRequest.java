package com.trustrummy.backend.friends;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Size;

public record CreateFriendRequest(
        @Size(max = 32) String username,
        Long userId
) {
    @AssertTrue(message = "Provide username or userId")
    public boolean isTargetPresent() {
        return (username != null && !username.isBlank()) || userId != null;
    }
}
