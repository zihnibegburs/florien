package com.florien.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.florien.exception.BadRequestException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.security.GeneralSecurityException;

@Service
@RequiredArgsConstructor
public class GoogleTokenService {

    private final GoogleIdTokenVerifier googleIdTokenVerifier;

    public GoogleIdToken.Payload verify(String idToken) {
        try {
            GoogleIdToken token = googleIdTokenVerifier.verify(idToken);
            if (token == null) {
                throw new BadRequestException("Invalid Google token");
            }

            GoogleIdToken.Payload payload = token.getPayload();
            if (!Boolean.TRUE.equals(payload.getEmailVerified())) {
                throw new BadRequestException("Google email not verified");
            }

            return payload;
        } catch (GeneralSecurityException | IOException e) {
            throw new BadRequestException("Invalid Google token");
        }
    }
}
