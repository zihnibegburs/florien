package com.florien.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.florien.domain.entity.User;
import com.florien.domain.enums.AuthProvider;
import com.florien.domain.repository.UserRepository;
import com.florien.dto.auth.AuthResponse;
import com.florien.dto.auth.GoogleLoginRequest;
import com.florien.dto.auth.LoginRequest;
import com.florien.dto.auth.RegisterRequest;
import com.florien.dto.auth.UpdateProfileRequest;
import com.florien.exception.BadRequestException;
import com.florien.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final GoogleTokenService googleTokenService;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new BadRequestException("Email already registered");
        }

        User user = User.builder()
                .email(request.email().toLowerCase().trim())
                .passwordHash(passwordEncoder.encode(request.password()))
                .displayName(request.displayName().trim())
                .build();

        userRepository.save(user);
        return buildAuthResponse(user);
    }

    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.email().toLowerCase().trim())
                .orElseThrow(() -> new BadRequestException("Invalid email or password"));

        if (user.getPasswordHash() == null) {
            throw new BadRequestException("This account uses Google sign-in");
        }

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BadRequestException("Invalid email or password");
        }

        return buildAuthResponse(user);
    }

    @Transactional
    public AuthResponse loginWithGoogle(GoogleLoginRequest request) {
        GoogleIdToken.Payload payload = googleTokenService.verify(request.idToken());

        String googleId = payload.getSubject();
        String email = payload.getEmail().toLowerCase().trim();
        String displayName = resolveDisplayName(payload, email);

        return userRepository.findByGoogleId(googleId)
                .map(this::buildAuthResponse)
                .orElseGet(() -> linkOrCreateGoogleUser(googleId, email, displayName));
    }

    private AuthResponse linkOrCreateGoogleUser(String googleId, String email, String displayName) {
        return userRepository.findByEmail(email)
                .map(user -> linkGoogleAccount(user, googleId))
                .orElseGet(() -> createGoogleUser(googleId, email, displayName));
    }

    private AuthResponse linkGoogleAccount(User user, String googleId) {
        if (user.getGoogleId() != null && !user.getGoogleId().equals(googleId)) {
            throw new BadRequestException("Email linked to another Google account");
        }

        if (user.getGoogleId() == null) {
            user.setGoogleId(googleId);
            userRepository.save(user);
        }

        return buildAuthResponse(user);
    }

    private AuthResponse createGoogleUser(String googleId, String email, String displayName) {
        User user = User.builder()
                .email(email)
                .googleId(googleId)
                .displayName(displayName)
                .authProvider(AuthProvider.GOOGLE)
                .build();

        userRepository.save(user);
        return buildAuthResponse(user);
    }

    private String resolveDisplayName(GoogleIdToken.Payload payload, String email) {
        Object name = payload.get("name");
        if (name instanceof String value && !value.isBlank()) {
            return value.trim();
        }
        int atIndex = email.indexOf('@');
        return atIndex > 0 ? email.substring(0, atIndex) : email;
    }

    public AuthResponse getMe(User user) {
        return buildAuthResponse(user);
    }

    @Transactional
    public AuthResponse updateProfile(User user, UpdateProfileRequest request) {
        if (request.displayName() != null) {
            user.setDisplayName(request.displayName().trim());
        }
        if (request.avatarColor() != null) {
            user.setAvatarColor(request.avatarColor());
        }
        userRepository.save(user);
        return buildAuthResponse(user);
    }

    private AuthResponse buildAuthResponse(User user) {
        String token = jwtService.generateToken(user.getId(), user.getEmail());
        return new AuthResponse(
                token,
                user.getId(),
                user.getEmail(),
                user.getDisplayName(),
                user.getAvatarColor()
        );
    }
}
