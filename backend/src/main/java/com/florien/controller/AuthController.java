package com.florien.controller;

import com.florien.dto.auth.AuthResponse;
import com.florien.dto.auth.GoogleLoginRequest;
import com.florien.dto.auth.LoginRequest;
import com.florien.dto.auth.RegisterRequest;
import com.florien.dto.auth.UpdateProfileRequest;
import com.florien.security.CurrentUserService;
import com.florien.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final CurrentUserService currentUserService;

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/google")
    public AuthResponse loginWithGoogle(@Valid @RequestBody GoogleLoginRequest request) {
        return authService.loginWithGoogle(request);
    }

    @GetMapping("/me")
    public AuthResponse me() {
        return authService.getMe(currentUserService.getCurrentUser());
    }

    @PatchMapping("/me")
    public AuthResponse updateProfile(@Valid @RequestBody UpdateProfileRequest request) {
        return authService.updateProfile(currentUserService.getCurrentUser(), request);
    }
}
