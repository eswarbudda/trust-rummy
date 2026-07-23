package com.trustrummy.backend.playgroups;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Size;

public record AddPlayGroupMemberRequest(
        Long userId,
        @Size(max = 32) String username
) {
    @AssertTrue(message = "Provide userId or username")
    public boolean isTargetPresent() {
        return userId != null || (username != null && !username.isBlank());
    }
}
