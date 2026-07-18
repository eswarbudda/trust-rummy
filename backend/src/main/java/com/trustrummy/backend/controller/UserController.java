package com.trustrummy.backend.controller;

import com.trustrummy.backend.dto.ChangePasswordRequest;
import com.trustrummy.backend.dto.UpdateProfileRequest;
import com.trustrummy.backend.dto.UserProfileResponse;
import com.trustrummy.backend.service.UserProfileService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserProfileService profileService;

    @GetMapping("/me")
    public ResponseEntity<UserProfileResponse> me(@AuthenticationPrincipal UserDetails principal) {
        return ResponseEntity.ok(profileService.getProfile(principal.getUsername()));
    }

    @PutMapping("/me")
    public ResponseEntity<UserProfileResponse> updateMe(
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody UpdateProfileRequest request
    ) {
        return ResponseEntity.ok(profileService.updateProfile(principal.getUsername(), request));
    }

    @PutMapping("/me/password")
    public ResponseEntity<Void> changePassword(
            @AuthenticationPrincipal UserDetails principal,
            @Valid @RequestBody ChangePasswordRequest request
    ) {
        profileService.changePassword(principal.getUsername(), request);
        return ResponseEntity.noContent().build();
    }
}
