package com.trustrummy.backend.dto;

import jakarta.validation.constraints.Email;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class UpdateProfileRequest {
    private String displayName;

    @Email
    private String email;
}
